const { spawn, execFile } = require('node:child_process');
const { promisify } = require('node:util');
const net = require('node:net');
const { EventEmitter } = require('node:events');
const { commandArgs, profiles } = require('./profiles.cjs');
const { defaults, normalizeSettings, targetDomains, serviceCatalog, saveSettings, engineIps } = require('./settings.cjs');
const { mkdtemp, writeFile, rm } = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');

const execute = promisify(execFile);
const delay = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

async function freePort(preferredPort) {
  const server = net.createServer();
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(preferredPort || 0, '127.0.0.1', resolve);
  });
  const port = server.address().port;
  await new Promise(resolve => server.close(resolve));
  return port;
}

function handshake(port) {
  return new Promise((resolve, reject) => {
    const socket = net.connect(port, '127.0.0.1');
    let received = Buffer.alloc(0);
    const finish = error => {
      socket.destroy();
      if (error) reject(error); else resolve();
    };
    socket.setTimeout(700, () => finish(new Error('SOCKS timeout')));
    socket.once('error', finish);
    socket.once('connect', () => socket.write(Buffer.from([5, 1, 0])));
    socket.on('data', data => {
      received = Buffer.concat([received, data]);
      if (received.length >= 2) finish(received[0] === 5 && received[1] === 0 ? null : new Error('SOCKS rejected'));
    });
    socket.once('end', () => finish(new Error('SOCKS closed')));
  });
}

async function probe(port, service) {
  const startedAt = Date.now();
  try {
    const { stdout } = await execute('curl', [
      '--disable', '--silent', '--show-error', '--noproxy', '', '--proxy', `socks5h://127.0.0.1:${port}`,
      '--connect-timeout', '5', '--max-time', '12', '--range', '0-8191',
      '--write-out', '\n%{http_code}\n%{time_total}\n%{size_download}', service.url
    ], { encoding: 'buffer', timeout: 14000, maxBuffer: 1024 * 1024, windowsHide: true });
    const boundary = stdout.lastIndexOf(Buffer.from('\n'), stdout.lastIndexOf(Buffer.from('\n')) - 1);
    const statusBoundary = stdout.lastIndexOf(Buffer.from('\n'), boundary - 1);
    const status = Number(stdout.subarray(statusBoundary + 1, boundary).toString());
    const payload = stdout.subarray(0, statusBoundary);
    const validPayload = service.id === 'discord'
      ? /"url"\s*:\s*"wss:\/\//.test(payload.toString())
      : payload[0] === 0xff && payload[1] === 0xd8;
    return { id: service.id, name: service.name, reachable: status >= 200 && status < 300 && validPayload, milliseconds: Date.now() - startedAt, checkedAt: Date.now(), status };
  } catch {
    return { id: service.id, name: service.name, reachable: false, milliseconds: null, checkedAt: Date.now() };
  }
}

class Controller extends EventEmitter {
  constructor(enginePath, options = {}) {
    super();
    this.enginePath = enginePath;
    this.child = null;
    this.busy = false;
    this.closed = false;
    this.listenPort = null;
    this.settings = normalizeSettings(options.settings || defaults());
    this.settingsPath = options.settingsPath;
    this.runtimeDirectory = null;
    this.state = { phase: 'idle', profile: this.settings.profile, port: null, results: [], message: '', testing: false, checking: false };
  }

  update(values) {
    Object.assign(this.state, values);
    this.emit('state', this.snapshot());
  }

  snapshot() {
    return { ...this.state, results: [...this.state.results], profiles, services: serviceCatalog, settings: structuredClone({ ...this.settings, profile: this.state.profile }) };
  }

  async exclusive(operation) {
    if (this.busy) throw new Error('Дождись завершения текущей операции');
    this.busy = true;
    try { return await operation(); } finally { this.busy = false; }
  }

  async start(id) {
    if (this.closed) throw new Error('Приложение закрывается');
    commandArgs(id, this.settings);
    await this.stop();
    this.update({ phase: 'starting', profile: id, results: [], message: '' });
    let port;
    try { port = await freePort(this.listenPort); }
    catch { this.update({ phase: 'error', message: 'Порт занят другой программой. Перезапусти MuseDPI.' }); throw new Error(this.state.message); }
    this.listenPort = port;
    if (this.closed) throw new Error('Приложение закрывается');
    let args;
    try {
      this.runtimeDirectory = await mkdtemp(path.join(os.tmpdir(), 'musedpi-'));
      const files = {};
      const lists = { domains: targetDomains(this.settings).join('\n'), excludedDomains: this.settings.excludedDomains, includeIps: engineIps(this.settings.includeIps).join('\n'), excludeIps: engineIps(this.settings.excludeIps).join('\n') };
      for (const [name, value] of Object.entries(lists)) {
        if (!value) continue;
        files[name] = path.join(this.runtimeDirectory, `${name}.txt`);
        await writeFile(files[name], value, { mode: 0o600 });
      }
      if (this.closed) throw new Error('Приложение закрывается');
      args = ['-i', '127.0.0.1', '-p', String(port), ...commandArgs(id, this.settings, files)];
      if (args.join(' ').length > 26000) throw new Error('Слишком много игровых правил. Уменьши число портов.');
    } catch (error) {
      await this.stop();
      this.update({ phase: 'error', message: error.message });
      throw error;
    }
    const child = spawn(this.enginePath, args, { stdio: 'ignore', windowsHide: true, shell: false });
    this.child = child;
    let failed = false;
    child.once('error', () => { failed = true; });
    child.once('exit', () => {
      if (this.child === child) {
        this.child = null;
        this.update({ phase: 'error', port: null, results: [], message: 'Ядро остановилось. Попробуй другую стратегию.' });
      }
    });
    try {
      const deadline = Date.now() + 4000;
      while (Date.now() < deadline && !failed && child.exitCode === null) {
        try {
          await handshake(port);
          if (failed || this.child !== child) break;
          this.update({ phase: 'running', port });
          return;
        } catch { await delay(80); }
      }
      throw new Error('Не удалось запустить ядро. Проверь комплектность сборки и выбранную стратегию.');
    } catch (error) {
      await this.stop();
      this.update({ phase: 'error', message: error.message });
      throw error;
    }
  }

  async stop() {
    const child = this.child;
    this.child = null;
    if (child) this.update({ phase: 'stopping' });
    if (child?.pid && child.exitCode === null && child.signalCode === null) {
      await new Promise(resolve => {
        const timer = setTimeout(() => { child.kill('SIGKILL'); }, 2000);
        child.once('close', () => { clearTimeout(timer); resolve(); });
        child.kill();
      });
    }
    if (this.runtimeDirectory) {
      await rm(this.runtimeDirectory, { recursive: true, force: true });
      this.runtimeDirectory = null;
    }
    this.update({ phase: 'idle', port: null, results: [], message: '' });
  }

  async close() {
    this.closed = true;
    await this.stop();
  }

  async diagnose() {
    if (this.state.phase !== 'running') throw new Error('Сначала запусти локальный прокси');
    const port = this.state.port;
    const services = serviceCatalog.filter(service => this.settings.serviceIds.includes(service.id) && service.probe);
    this.update({ results: [], checking: true });
    try {
      const results = await Promise.all(services.map(service => probe(port, { ...service, url: service.probe.url })));
      if (this.state.port === port) this.update({ results });
      return results;
    } finally { this.update({ checking: false }); }
  }

  async configure(input) {
    const next = normalizeSettings(input);
    const previous = structuredClone({ ...this.settings, profile: this.state.profile });
    const wasRunning = this.state.phase === 'running';
    this.settings = next;
    try {
      if (wasRunning) await this.start(next.profile);
      if (this.settingsPath) await saveSettings(this.settingsPath, next);
    } catch (error) {
      this.settings = previous;
      if (wasRunning && !this.closed) {
        try { await this.start(previous.profile); }
        catch { this.update({ message: 'Настройки не применены; восстановить подключение не удалось.' }); }
      }
      this.update({ profile: previous.profile });
      throw error;
    }
    this.update({ profile: next.profile, results: [], message: 'Настройки сохранены' });
    if (wasRunning) await this.diagnose();
  }

  async selectBest() {
    if (!serviceCatalog.some(service => this.settings.serviceIds.includes(service.id) && service.probe)) throw new Error('Для автоподбора выбери Discord или YouTube — для них доступна HTTP-проверка.');
    const previous = this.state.profile;
    const wasRunning = this.state.phase === 'running';
    let best = null;
    this.update({ testing: true });
    try {
      for (const profile of profiles) {
        if (this.closed) throw new Error('Приложение закрывается');
        this.update({ message: `Проверяем: ${profile.name}` });
        try {
          await this.start(profile.id);
          const results = await this.diagnose();
          const reachable = results.filter(result => result.reachable);
          const count = reachable.length;
          const latency = reachable.reduce((total, result) => total + result.milliseconds, 0);
          if (count && (!best || count > best.count || (count === best.count && latency < best.latency))) best = { id: profile.id, count, latency };
        } catch {}
      }
      if (!best) throw new Error('Рабочий профиль не найден. Предыдущая настройка сохранена.');
      await this.start(best.id);
      const confirmation = await this.diagnose();
      if (confirmation.filter(result => result.reachable).length < best.count) throw new Error('Профиль не прошёл повторную проверку. Предыдущая настройка сохранена.');
      if (this.settingsPath) await saveSettings(this.settingsPath, { ...this.settings, profile: best.id });
      this.settings.profile = best.id;
      this.update({ message: 'Лучший из проверенных профилей подключён. Это HTTP-проверка, не тест видеопотока.' });
    } catch (error) {
      if (wasRunning && !this.closed) await this.start(previous); else await this.stop();
      this.update({ profile: previous, message: error.message });
      throw error;
    } finally { this.update({ testing: false }); }
  }
}

module.exports = { Controller, commandArgs, handshake, probe };
