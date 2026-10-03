const test = require('node:test');
const assert = require('node:assert/strict');
const { mkdtemp, readFile, writeFile, rm } = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const { defaults, domains, ipEntries, engineIps, ports, normalizeSettings, loadSettings, saveSettings } = require('../settings.cjs');
const { commandArgs, Controller } = require('../controller.cjs');

test('domains accept comments and subdomains, reject URLs and arguments', () => {
  assert.deepEqual(domains('*.Example.com\nexample.com # duplicate\nпример.рф'), ['example.com', 'xn--e1afmkfd.xn--p1ai']);
  for (const invalid of ['https://example.com', '--ip=example.com', '127.0.0.1', '-H:example.com', 'bad..example.com']) assert.throws(() => domains(invalid), /Неверный/);
});

test('IP lists validate both address families, masks and zero-prefix expansion', () => {
  assert.deepEqual(ipEntries('192.0.2.1, 192.0.2.1 # duplicate\n2001:DB8::/32'), ['192.0.2.1', '2001:db8::/32']);
  assert.deepEqual(ipEntries('0.0.0.0/0\n::/0'), ['0.0.0.0/1', '128.0.0.0/1', '::/1', '8000::/1']);
  for (const invalid of ['1.2.3.4/33', '1.2.3.4/', '::/129', 'fe80::1%en0', '--ip', '1.2.3.999', 'example.com']) assert.throws(() => ipEntries(invalid), /Неверный/);
});

test('game ranges expand, deduplicate, sort and remain bounded', () => {
  assert.deepEqual(ports('27017,27015-27017'), [27015, 27016, 27017]);
  for (const invalid of ['0', '65536', '10-1', '1-300', '-p 80', '1.5']) assert.throws(() => ports(invalid));
});

test('engine IP sets include IPv4-mapped IPv6 addresses used by UDP', () => {
  assert.deepEqual(engineIps('192.0.2.0/24\n127.0.0.1'), ['192.0.2.0/24', '::ffff:192.0.2.0/120', '127.0.0.1', '::ffff:127.0.0.1/128']);
});

test('combined game rules remain below the core group bitmask limit', () => {
  const config = defaults();
  config.game = { ...config.game, tcpPorts: '1-36', udpPorts: '100-121' };
  assert.throws(() => normalizeSettings(config), /56/);
});

test('invalid settings cannot silently broaden scope', () => {
  assert.throws(() => normalizeSettings({ ...defaults(), serviceIds: ['unknown'] }), /Неизвестный/);
  assert.throws(() => normalizeSettings({ ...defaults(), ipMode: 'only' }), /хотя бы/);
  const config = defaults();
  config.game = { ...config.game, enabled: true, tcpPorts: '', udpPorts: '' };
  assert.throws(() => normalizeSettings(config), /хотя бы/);
});

test('empty service selection produces pass-through, not a global bypass', () => {
  assert.deepEqual(commandArgs('gentle', { ...defaults(), serviceIds: [] }), []);
});

test('service selection only includes chosen domains', () => {
  const args = commandArgs('gentle', { ...defaults(), serviceIds: ['steam'] });
  assert.match(args.join(' '), /steampowered.com/);
  assert.doesNotMatch(args.join(' '), /discord|youtube/);
});

test('IP extension is OR matching and exclusions precede every bypass group', () => {
  const args = commandArgs('gentle', { ...defaults(), ipMode: 'extend', includeIps: '192.0.2.0/24', excludeIps: '192.0.2.1', excludedDomains: 'safe.example' });
  assert.deepEqual(args.slice(0, 7), ['-j', ':192.0.2.1 ::ffff:192.0.2.1/128', '-An', '-Kt,h', '-H', ':safe.example', '-An']);
  const groups = args.join(' ').split(' -An');
  assert.ok(groups.some(group => group.includes('-H') && group.includes('-s1+s')));
  assert.ok(groups.some(group => group.includes('-j :192.0.2.0/24') && group.includes('-s1+s') && !group.includes('-H')));
});

test('IP-only scope also limits games and uses exact single-port filters', () => {
  const config = { ...defaults(), ipMode: 'only', includeIps: '192.0.2.0/24' };
  config.game = { ...config.game, enabled: true, tcpPorts: '27015-27016', udpPorts: '27015' };
  const args = commandArgs('gentle', config);
  assert.doesNotMatch(args.join(' '), /-H|27015-27016/);
  assert.deepEqual(args.slice(0, 7), ['-Ku', '-V27015', '-j', ':192.0.2.0/24 ::ffff:192.0.2.0/120', '-a3', '-t8', '-An']);
  assert.ok(args.includes('-V27016'));
  assert.equal(args.at(-1), '-An');
});

test('large sets use file references without command-line expansion', () => {
  const args = commandArgs('gentle', { ...defaults(), ipMode: 'extend', includeIps: '192.0.2.1' }, { domains: '/tmp/domains.txt', includeIps: '/tmp/include.txt' });
  assert.ok(args.includes('/tmp/include.txt'));
  assert.doesNotMatch(args.join(' '), /192.0.2.1|discord.com/);
});

test('settings persist canonically and damaged files are preserved', async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'muse-settings-test-'));
  const filename = path.join(directory, 'settings.json');
  try {
    assert.equal((await loadSettings(filename)).warning, '');
    await saveSettings(filename, { ...defaults(), customDomains: 'EXAMPLE.com # comment' });
    assert.equal((await loadSettings(filename)).settings.customDomains, 'example.com');
    await writeFile(filename, 'broken');
    assert.ok((await loadSettings(filename)).warning);
    assert.equal(await readFile(filename, 'utf8'), 'broken');
  } finally { await rm(directory, { recursive: true, force: true }); }
});

test('failed apply restores the previously running rules', async () => {
  const controller = new Controller('/missing');
  controller.state.phase = 'running';
  const previous = controller.snapshot().settings;
  controller.start = async id => {
    if (controller.settings.serviceIds.includes('steam')) throw new Error('test failure');
    controller.state.phase = 'running';
    controller.state.profile = id;
  };
  await assert.rejects(controller.configure({ ...defaults(), serviceIds: ['steam'] }), /test failure/);
  assert.deepEqual(controller.snapshot().settings, previous);
  assert.equal(controller.state.phase, 'running');
});

test('auto selection without supported probes leaves a running proxy intact', async () => {
  const controller = new Controller('/missing', { settings: { ...defaults(), serviceIds: ['steam'] } });
  controller.state.phase = 'running';
  await assert.rejects(controller.selectBest(), /Discord/);
  assert.equal(controller.state.phase, 'running');
});
