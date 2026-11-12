const test = require('node:test');
const assert = require('node:assert/strict');
const { access } = require('node:fs/promises');
const path = require('node:path');
const { payloadBytes, payloadOptions, bundledIpSet } = require('../flowseal.cjs');
const { defaults, normalizeSettings, ipEntries } = require('../settings.cjs');
const { Controller, commandArgs } = require('../controller.cjs');
const { profiles } = require('../profiles.cjs');

test('all Flowseal payloads pass pinned SHA256 verification and reject paths', () => {
  assert.equal(payloadBytes('standard'), null);
  for (const { id } of payloadOptions.slice(1)) assert.ok(payloadBytes(id).length >= 1200);
  assert.throws(() => payloadBytes('../../engine/ciadpi'), /Неизвестная/);
  const legacy = defaults();
  delete legacy.game.udpPayload;
  assert.equal(normalizeSettings(legacy).game.udpPayload, 'standard');
  assert.throws(() => normalizeSettings({ ...legacy, game: { ...legacy.game, udpPayload: 'external-file' } }), /Неизвестная/);
});

test('Flowseal IP snapshot is the actual backup, not the upstream disabled marker', () => {
  const entries = ipEntries(bundledIpSet());
  assert.equal(entries.length, 33336);
  assert.notDeepEqual(entries, ['203.0.113.113/32']);
  const normalized = normalizeSettings({ ...defaults(), ipMode: 'extend', includeIps: entries.join('\n') });
  assert.equal(normalized.includeIps.split('\n').length, 33336);
  assert.throws(() => ipEntries('192.0.2.1\n'.repeat(50001)), /50000/);
});

test('Flowseal payload is opt-in, does not add ports, and cannot silently fall back', () => {
  const config = defaults();
  config.game.udpPayload = 'flowseal-steam';
  assert.ok(!commandArgs('gentle', config).includes('-l'));
  config.game.enabled = true;
  config.game.udpPorts = '27015';
  assert.throws(() => commandArgs('gentle', config), /Не подготовлен/);
  const args = commandArgs('gentle', config, { udpPayload: '/verified/payload.bin' });
  assert.ok(args.includes('/verified/payload.bin'));
  assert.ok(args.includes('-V27015'));
  assert.ok(!args.includes('-V443'));
  config.game.udpFakes = 12;
  assert.ok(commandArgs('gentle', config, { udpPayload: '/verified/payload.bin' }).includes('-a12'));
  config.game.udpFakes = 13;
  assert.throws(() => normalizeSettings(config), /12/);
});

test('profile definitions are unique and accepted by settings without duplicated ID lists', () => {
  assert.equal(profiles.length, 8);
  assert.equal(new Set(profiles.map(profile => profile.id)).size, profiles.length);
  assert.equal(new Set(profiles.map(profile => JSON.stringify(profile.tls))).size, profiles.length);
  for (const profile of profiles) assert.equal(normalizeSettings({ ...defaults(), profile: profile.id }).profile, profile.id);
});

test('selection retains a report and does not restart an already winning profile', async () => {
  const controller = new Controller('/missing');
  controller.state.phase = 'running';
  const result = [{ id: 'discord', reachable: true, milliseconds: 20 }];
  let candidateProfile;
  controller.createCandidate = () => ({ start: async id => { candidateProfile = id; }, diagnose: async () => result.map(item => ({ ...item, milliseconds: candidateProfile === 'multisplit' ? 1 : 20 })), close: async () => {} });
  controller.start = async () => assert.fail('already winning profile must not be restarted');
  controller.diagnose = async () => result;
  await controller.selectBest();
  assert.equal(controller.state.selectionResults.length, 8);
  assert.equal(controller.state.profile, 'multisplit');
  assert.equal(controller.state.phase, 'running');
  const snapshot = controller.snapshot();
  snapshot.selectionResults[0].count = 999;
  assert.notEqual(controller.state.selectionResults[0].count, 999);
});

test('native engine accepts the full Flowseal IP set and cleans payload files', { skip: !process.env.MUSE_TEST_ENGINE, timeout: 20000 }, async () => {
  const settings = { ...defaults(), serviceIds: [], ipMode: 'only', includeIps: bundledIpSet() };
  settings.game = { ...settings.game, enabled: true, tcpPorts: '', udpPorts: '443', udpPayload: 'flowseal-google' };
  const controller = new Controller(process.env.MUSE_TEST_ENGINE, { settings, ephemeral: true });
  let directory;
  try {
    await controller.start('multisplit');
    directory = controller.runtimeDirectory;
    await access(path.join(directory, 'udp-payload.bin'));
    assert.equal(controller.state.phase, 'running');
  } finally { await controller.close(); }
  await assert.rejects(access(directory));
});
