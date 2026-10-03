const test = require('node:test');
const assert = require('node:assert/strict');
const net = require('node:net');
const dgram = require('node:dgram');
const { once } = require('node:events');
const { Controller } = require('../controller.cjs');
const { defaults } = require('../settings.cjs');

async function sendRequest(proxyPort, targetPort, host) {
  const socket = net.connect(proxyPort, '127.0.0.1');
  socket.setTimeout(4000, () => socket.destroy(new Error('Test SOCKS timeout')));
  try {
    await once(socket, 'connect');
    const greeting = once(socket, 'data');
    socket.write(Buffer.from([5, 1, 0]));
    assert.equal((await greeting)[0][1], 0);
    const response = once(socket, 'data');
    socket.write(Buffer.from([5, 1, 0, 1, 127, 0, 0, 1, targetPort >> 8, targetPort & 255]));
    assert.equal((await response)[0][1], 0);
    const received = once(socket, 'data');
    socket.write(`GET / HTTP/1.1\r\nHost: ${host}\r\nConnection: close\r\n\r\n`);
    await received;
  } finally { socket.destroy(); }
}

test('native routing applies domains and IP sets without modifying excluded traffic', { skip: !process.env.MUSE_TEST_ENGINE, timeout: 60000 }, async () => {
  let request;
  const server = net.createServer(socket => {
    let buffer = '';
    socket.on('data', chunk => {
      buffer += chunk.toString();
      if (!buffer.includes('\r\n\r\n')) return;
      request = buffer;
      socket.end('HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK');
    });
  });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const controller = new Controller(process.env.MUSE_TEST_ENGINE);
  const config = { ...defaults(), serviceIds: [], customDomains: 'selected.test' };
  const cases = [
    { changes: {}, host: 'selected.test', modified: true },
    { changes: {}, host: 'other.test', modified: false },
    { changes: { excludedDomains: 'selected.test' }, host: 'selected.test', modified: false },
    { changes: { ipMode: 'extend', includeIps: '127.0.0.1' }, host: 'other.test', modified: true },
    { changes: { ipMode: 'extend', includeIps: '127.0.0.1', excludeIps: '127.0.0.1' }, host: 'selected.test', modified: false },
    { changes: { ipMode: 'only', includeIps: '192.0.2.0/24' }, host: 'selected.test', modified: false }
  ];
  try {
    for (const scenario of cases) {
      await controller.stop();
      await controller.configure({ ...config, ...scenario.changes });
      await controller.start('gentle');
      request = '';
      await sendRequest(controller.state.port, server.address().port, scenario.host);
      assert.equal(!request.includes(`Host: ${scenario.host}\r\n`), scenario.modified, JSON.stringify(scenario));
    }
  } finally {
    await controller.close();
    await new Promise(resolve => server.close(resolve));
  }
});

test('native game UDP rules affect only selected ports and respect IP exclusions', { skip: !process.env.MUSE_TEST_ENGINE, timeout: 30000 }, async () => {
  const receiver = dgram.createSocket('udp4');
  receiver.bind(0, '127.0.0.1');
  await once(receiver, 'listening');
  const port = receiver.address().port;
  const controller = new Controller(process.env.MUSE_TEST_ENGINE);
  const payload = Buffer.from('musedpi-local-game-test');
  try {
    for (const scenario of [{ match: true, exclude: false }, { match: false, exclude: false }, { match: true, exclude: true }]) {
      await controller.stop();
      const settings = defaults();
      settings.serviceIds = [];
      settings.excludedDomains = 'unrelated.test';
      settings.excludeIps = scenario.exclude ? '127.0.0.1' : '';
      settings.game = { enabled: true, tcpPorts: '', udpPorts: String(scenario.match ? port : port === 65535 ? 65534 : port + 1), udpFakes: 3, ttl: 8 };
      await controller.configure(settings);
      await controller.start('gentle');
      const control = net.connect(controller.state.port, '127.0.0.1');
      const sender = dgram.createSocket('udp4');
      control.setTimeout(4000, () => control.destroy(new Error('UDP association timeout')));
      let timer;
      let listener;
      try {
        await once(control, 'connect');
        const greeting = once(control, 'data');
        control.write(Buffer.from([5, 1, 0]));
        assert.equal((await greeting)[0][1], 0);
        const association = once(control, 'data');
        control.write(Buffer.from([5, 3, 0, 1, 0, 0, 0, 0, 0, 0]));
        const response = (await association)[0];
        assert.equal(response[1], 0);
        const relayPort = response.readUInt16BE(response.length - 2);
        let fakes = 0;
        const received = new Promise((resolve, reject) => {
          timer = setTimeout(() => reject(new Error('UDP payload not received')), 4000);
          listener = message => {
            if (message.equals(payload)) resolve();
            else fakes++;
          };
          receiver.on('message', listener);
        });
        const header = Buffer.from([0, 0, 0, 1, 127, 0, 0, 1, port >> 8, port & 255]);
        sender.send(Buffer.concat([header, payload]), relayPort, '127.0.0.1');
        await received;
        assert.equal(fakes, scenario.match && !scenario.exclude ? 3 : 0, JSON.stringify(scenario));
      } finally {
        clearTimeout(timer);
        if (listener) receiver.off('message', listener);
        sender.close();
        control.destroy();
      }
    }
  } finally {
    receiver.close();
    await controller.close();
  }
});
