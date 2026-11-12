const test = require('node:test');
const assert = require('node:assert/strict');
const net = require('node:net');
const { once } = require('node:events');
const { mkdtemp, rm } = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const { Controller, handshake } = require('../controller.cjs');
const { profiles } = require('../profiles.cjs');
const { defaults, normalizeSettings, saveSettings, loadSettings } = require('../settings.cjs');

const reachable = id => ({ id, reachable: true, milliseconds: 20, checkedAt: Date.now() });

test('legacy settings migrate to a persistent port and reject invalid ports', () => {
  const legacy = defaults();
  delete legacy.proxyPort;
  assert.equal(normalizeSettings(legacy).proxyPort, 1080);
  for (const proxyPort of [0, 1023, 65536, 1080.5, '1080', null]) {
    assert.throws(() => normalizeSettings({ ...defaults(), proxyPort }), /Порт SOCKS5/);
  }
});

test('a failed search never stops an already running proxy', async () => {
  const controller = new Controller('/missing');
  controller.state.phase = 'running';
  controller.state.port = 1080;
  controller.state.results = [reachable('discord')];
  controller.child = { pid: 123 };
  controller.start = async () => assert.fail('main proxy must not restart');
  let closed = false;
  controller.createCandidate = () => ({ start: async () => {}, diagnose: async () => [], close: async () => { closed = true; } });
  await assert.rejects(controller.selectBest(), /не найден/);
  assert.equal(controller.child.pid, 123);
  assert.equal(controller.state.results.length, 1);
  assert.equal(controller.state.phase, 'running');
  assert.equal(closed, true);
});

test('verification must confirm the same services, not just their count', async () => {
  const controller = new Controller('/missing');
  let checks = 0;
  controller.createCandidate = () => ({ start: async () => {}, diagnose: async () => [reachable(++checks <= profiles.length ? 'discord' : 'youtube')], close: async () => {} });
  controller.start = async () => assert.fail('unconfirmed winner must not be applied');
  await assert.rejects(controller.selectBest(), /повторную проверку/);
  assert.equal(controller.state.phase, 'idle');
  assert.equal(controller.state.profile, 'multisplit');
});

test('failed final verification restores the active profile', async () => {
  const controller = new Controller('/missing');
  controller.state.phase = 'running';
  controller.createCandidate = () => ({ start: async () => {}, diagnose: async () => [reachable('discord')], close: async () => {} });
  const started = [];
  controller.start = async id => { started.push(id); controller.state.profile = id; };
  controller.diagnose = async () => [];
  await assert.rejects(controller.selectBest(), /основном порту/);
  assert.deepEqual(started, ['gentle', 'multisplit']);
  assert.equal(controller.settings.profile, 'multisplit');
  assert.equal(controller.state.profile, 'multisplit');
});

test('diagnostics publish each completed service before the slow service finishes', async () => {
  let finishSlow;
  const slow = new Promise(resolve => { finishSlow = resolve; });
  let firstResult;
  const first = new Promise(resolve => { firstResult = resolve; });
  const controller = new Controller('/missing', { probe: async (_port, service) => service.id === 'discord' ? reachable('discord') : slow });
  controller.state.phase = 'running';
  controller.state.port = 1080;
  controller.on('state', state => { if (state.results.length === 1) firstResult(); });
  const operation = controller.diagnose();
  await first;
  assert.equal(controller.state.checking, true);
  assert.equal(controller.state.results[0].id, 'discord');
  finishSlow(reachable('youtube'));
  await operation;
  assert.equal(controller.state.results.length, 2);
  assert.equal(controller.state.checking, false);
});

test('cancel interrupts HTTP checks without disconnecting the main proxy', async () => {
  let entered;
  const ready = new Promise(resolve => { entered = resolve; });
  const controller = new Controller('/missing', { probe: async (_port, _service, { signal }) => new Promise((_resolve, reject) => {
    signal.addEventListener('abort', () => reject(signal.reason), { once: true });
    entered();
  }) });
  controller.state.phase = 'running';
  controller.state.port = 1080;
  const operation = controller.exclusive(() => controller.diagnose());
  await ready;
  controller.cancel();
  await operation;
  assert.equal(controller.busy, false);
  assert.equal(controller.state.phase, 'running');
  assert.equal(controller.state.checking, false);
  assert.match(controller.state.message, /отменена/);
});

test('a proxy exit during diagnostics cannot be reported as a successful check', async () => {
  const controller = new Controller('/missing', { probe: async (_port, service) => {
    controller.state.phase = 'error';
    controller.child = null;
    return reachable(service.id);
  } });
  controller.state.phase = 'running';
  controller.state.port = 1080;
  controller.child = { pid: 123 };
  await assert.rejects(controller.diagnose(), /остановился/);
  assert.deepEqual(controller.state.results, []);
  assert.equal(controller.state.checking, false);
});

test('failed settings persistence rolls back the automatic winner', async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'muse-save-failure-'));
  const controller = new Controller('/missing', { settingsPath: directory });
  controller.state.phase = 'running';
  controller.createCandidate = () => ({ start: async () => {}, diagnose: async () => [reachable('discord')], close: async () => {} });
  controller.start = async id => { controller.state.profile = id; };
  controller.diagnose = async () => [reachable('discord')];
  try {
    await assert.rejects(controller.selectBest());
    assert.equal(controller.settings.profile, 'multisplit');
    assert.equal(controller.state.profile, 'multisplit');
    assert.equal(controller.state.phase, 'running');
  } finally {
    await rm(directory, { recursive: true, force: true });
    await rm(`${directory}.tmp`, { force: true });
  }
});

test('close waits for the cancelled operation and rejects subsequent work', async () => {
  const controller = new Controller('/missing');
  let entered;
  const ready = new Promise(resolve => { entered = resolve; });
  let cleaned = false;
  controller.createCandidate = () => ({
    start: async () => {},
    diagnose: async signal => new Promise((_resolve, reject) => { signal.addEventListener('abort', () => reject(signal.reason), { once: true }); entered(); }),
    close: async () => { cleaned = true; }
  });
  const operation = controller.exclusive(() => controller.selectBest());
  await ready;
  await controller.close();
  await operation;
  assert.equal(cleaned, true);
  assert.equal(controller.state.testing, false);
  assert.equal(controller.state.phase, 'idle');
  await assert.rejects(controller.exclusive(async () => {}), /закрывается/);
});

test('native port persists across controllers and occupied-port apply rolls back', { skip: !process.env.MUSE_TEST_ENGINE, timeout: 30000 }, async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'muse-persistent-test-'));
  const filename = path.join(directory, 'settings.json');
  const reservation = net.createServer();
  reservation.listen(0, '127.0.0.1');
  await once(reservation, 'listening');
  const proxyPort = reservation.address().port;
  await new Promise(resolve => reservation.close(resolve));
  let controller;
  try {
    await saveSettings(filename, { ...defaults(), proxyPort, serviceIds: [] });
    for (let attempt = 0; attempt < 2; attempt++) {
      controller = new Controller(process.env.MUSE_TEST_ENGINE, { settings: (await loadSettings(filename)).settings, settingsPath: filename });
      await controller.start('gentle');
      assert.equal(controller.state.port, proxyPort);
      await controller.close();
    }
    controller = new Controller(process.env.MUSE_TEST_ENGINE, { settings: (await loadSettings(filename)).settings, settingsPath: filename });
    await controller.start('multisplit');
    reservation.listen(0, '127.0.0.1');
    await once(reservation, 'listening');
    await assert.rejects(controller.configure({ ...controller.settings, proxyPort: reservation.address().port }), /недоступен/);
    assert.equal(controller.state.phase, 'running');
    assert.equal(controller.state.port, proxyPort);
    assert.equal((await loadSettings(filename)).settings.proxyPort, proxyPort);
    await handshake(proxyPort);
  } finally {
    await controller?.close();
    if (reservation.listening) await new Promise(resolve => reservation.close(resolve));
    await rm(directory, { recursive: true, force: true });
  }
});

test('native search cancellation leaves original PID and SOCKS listener intact', { skip: !process.env.MUSE_TEST_ENGINE, timeout: 15000 }, async () => {
  let entered;
  const ready = new Promise(resolve => { entered = resolve; });
  const controller = new Controller(process.env.MUSE_TEST_ENGINE, { ephemeral: true, probe: async (_port, _service, { signal }) => new Promise((_resolve, reject) => {
    signal.addEventListener('abort', () => reject(signal.reason), { once: true });
    entered();
  }) });
  try {
    await controller.start('multisplit');
    const child = controller.child;
    const port = controller.state.port;
    const operation = controller.exclusive(() => controller.selectBest());
    await ready;
    await handshake(port);
    controller.cancel();
    await operation;
    assert.equal(controller.child, child);
    assert.equal(controller.state.port, port);
    assert.equal(controller.state.testing, false);
    await handshake(port);
  } finally { await controller.close(); }
});
