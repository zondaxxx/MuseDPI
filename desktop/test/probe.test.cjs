const test = require('node:test');
const assert = require('node:assert/strict');
const { probe } = require('../probe.cjs');

const discord = { id: 'discord', name: 'Discord', url: 'https://discord.com/api/v9/gateway', kind: 'discord' };
const response = (payload, status = 200) => ({ stdout: Buffer.concat([Buffer.from(payload), Buffer.from(`\n${status}\n0.25\n${Buffer.byteLength(payload)}`)]) });

test('probe pins SOCKS DNS, ignores curl config, and passes cancellation', async () => {
  const signal = new AbortController().signal;
  const result = await probe(1080, discord, { signal, run: async (file, args, options) => {
    assert.match(file, /^curl(?:\.exe)?$/);
    assert.equal(args[0], '--disable');
    assert.ok(args.includes('socks5h://127.0.0.1:1080'));
    assert.equal(options.signal, signal);
    assert.equal(options.timeout, 14000);
    return response('{"url":"wss://gateway.discord.gg"}');
  } });
  assert.equal(result.reachable, true);
  assert.ok(result.checkedAt);
});

test('HTTP errors and spoofed payloads never pass service checks', async () => {
  for (const [payload, status] of [['{"url":"wss://gateway.discord.gg"}', 403], ['<html>blocked</html>', 200], ['{"url":"https://example.com"}', 200], ['{"url":"wss://attacker.invalid"}', 200]]) {
    const result = await probe(1080, discord, { run: async () => response(payload, status) });
    assert.equal(result.reachable, false);
    assert.ok(result.error);
  }
});

test('YouTube probe requires real JPEG bytes including partial responses', async () => {
  const service = { id: 'youtube', kind: 'jpeg', url: 'https://i.ytimg.com/example.jpg' };
  const result = await probe(1080, service, { run: async () => response(Buffer.from([0xff, 0xd8, 0xff]), 206) });
  assert.equal(result.reachable, true);
  assert.equal((await probe(1080, service, { run: async () => response('not a jpeg') })).reachable, false);
});

test('probe reports useful errors without leaking command output', async () => {
  for (const [code, expected] of [['ENOENT', /curl/], [28, /12 секунд/], [6, /адрес/], [60, /сертификата/], [7, /соединение/]]) {
    const result = await probe(1080, discord, { run: async () => { throw Object.assign(new Error('private command output'), { code }); } });
    assert.equal(result.reachable, false);
    assert.match(result.error, expected);
    assert.doesNotMatch(result.error, /private/);
  }
});

test('aborted checks throw cancellation instead of marking services unreachable', async () => {
  const cancellation = new AbortController();
  cancellation.abort();
  await assert.rejects(probe(1080, discord, { signal: cancellation.signal, run: async () => assert.fail('must not spawn curl') }), { name: 'AbortError' });
});
