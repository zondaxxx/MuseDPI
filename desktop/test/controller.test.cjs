const test = require('node:test');
const assert = require('node:assert/strict');
const { Controller, commandArgs } = require('../controller.cjs');

test('unknown profile cannot inject arbitrary engine arguments', () => {
  assert.throws(() => commandArgs('--ip 0.0.0.0'), /Неизвестная/);
});

test('built-in profiles scope TLS and HTTP separately and pass other traffic through', () => {
  for (const id of ['gentle', 'multisplit', 'mid-sni', 'tls-record']) {
    const args = commandArgs(id);
    assert.equal(args[0], '-Kt');
    assert.ok(args.includes('-Kh'));
    assert.equal(args.at(-1), '-An');
    assert.ok(args.every(argument => !argument.includes('\n')));
  }
});

test('duplicate user operations are rejected', async () => {
  const controller = new Controller('/missing');
  let release;
  const first = controller.exclusive(() => new Promise(resolve => { release = resolve; }));
  await assert.rejects(controller.exclusive(async () => {}), /Дождись/);
  release();
  await first;
  assert.equal(controller.busy, false);
});

test('missing engine fails within bounded time and leaves no running state', async () => {
  const controller = new Controller('/definitely-missing-muse-engine');
  await assert.rejects(controller.start('gentle'), /Не удалось/);
  assert.equal(controller.state.phase, 'error');
  assert.equal(controller.child, null);
  await controller.close();
});

test('closed controller cannot restart the engine', async () => {
  const controller = new Controller('/missing');
  await controller.close();
  await assert.rejects(controller.start('gentle'), /закрывается/);
});

test('failed automatic selection restores previous profile', async () => {
  const controller = new Controller('/missing');
  controller.state.phase = 'running';
  controller.state.profile = 'mid-sni';
  controller.start = async id => { controller.state.profile = id; controller.state.phase = 'running'; };
  controller.diagnose = async () => [{ reachable: false }];
  await assert.rejects(controller.selectBest(), /не найден/);
  assert.equal(controller.state.profile, 'mid-sni');
  assert.equal(controller.state.phase, 'running');
  assert.equal(controller.state.testing, false);
});

test('automatic selection prefers complete reachability and verifies winner', async () => {
  const controller = new Controller('/missing');
  controller.start = async id => { controller.state.profile = id; controller.state.phase = 'running'; };
  controller.diagnose = async () => controller.state.profile === 'mid-sni'
    ? [{ reachable: true, milliseconds: 200 }, { reachable: true, milliseconds: 200 }]
    : [{ reachable: true, milliseconds: 1 }, { reachable: false }];
  await controller.selectBest();
  assert.equal(controller.state.profile, 'mid-sni');
  assert.equal(controller.state.testing, false);
});

test('native engine accepts all profiles and preserves its port', { skip: !process.env.MUSE_TEST_ENGINE }, async () => {
  const controller = new Controller(process.env.MUSE_TEST_ENGINE);
  let port;
  try {
    for (const id of ['gentle', 'multisplit', 'mid-sni', 'tls-record']) {
      await controller.start(id);
      assert.equal(controller.state.phase, 'running');
      if (port) assert.equal(controller.state.port, port);
      port = controller.state.port;
    }
  } finally { await controller.close(); }
  assert.equal(controller.child, null);
});
