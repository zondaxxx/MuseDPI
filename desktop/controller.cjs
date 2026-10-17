const { spawn } = require('node:child_process');
const net = require('node:net');
const { EventEmitter } = require('node:events');
const { commandArgs, profiles } = require('./profiles.cjs');
const { defaults, normalizeSettings, targetDomains, serviceCatalog, saveSettings, engineIps } = require('./settings.cjs');
const { mkdtemp, writeFile, rm } = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { probe } = require('./probe.cjs');

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

class Controller extends EventEmitter {
  constructor(enginePath, options = {}) {
    super();
    this.enginePath = enginePath;
    this.child = null;
    this.busy = false;
    this.closed = false;
    this.listenPort = null;
    this.ephemeral = Boolean(options.ephemeral);
    this.probeRequest = options.probe || probe;
    this.activeCheck = null;
    this.selection = null;
    this.operation = null;
    this.settings = normalizeSettings(options.settings || defaults());
    this.settingsPath = options.settingsPath;
    this.runtimeDirectory = null;
    this.state = { phase: 'idle', profile: this.settings.profile, port: null, results: [], message: '', testing: false, checking: false, progress: null };
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
    if (this.closed) throw new Error('Приложение закрывается');
    this.busy = true;
    this.operation = Promise.resolve().then(operation);
    try { return await this.operation; } finally { this.busy = false; this.operation = null; }
  }

  async start(id, signal) {
    if (this.closed) throw new Error('Приложение закрывается');
    signal?.throwIfAborted();
    commandArgs(id, this.settings);
    await this.stop();
    this.update({ phase: 'starting', profile: id, results: [], message: '' });
    let port;
    try { port = await freePort(this.ephemeral ? this.listenPort : this.settings.proxyPort); }
    catch { this.update({ phase: 'error', message: `Порт ${this.settings.proxyPort} недоступен. Выбери другой порт SOCKS5 в разделе «Подключение».` }); throw new Error(this.state.message); }
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
      signal?.throwIfAborted();
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
        signal?.throwIfAborted();
        if (this.closed) throw new Error('Приложение закрывается');
        try {
          await handshake(port);
          if (failed || this.child !== child) break;
          signal?.throwIfAborted();
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
    this.cancel();
    await this.operation?.catch(() => {});
    await this.stop();
  }

  cancel() {
    this.activeCheck?.abort();
    this.selection?.abort();
  }

  async diagnose(signal) {
    if (this.state.phase !== 'running') throw new Error('Сначала запусти локальный прокси');
    if (this.activeCheck) throw new Error('Проверка уже выполняется');
    const port = this.state.port;
    const child = this.child;
    const services = serviceCatalog.filter(service => this.settings.serviceIds.includes(service.id) && service.probe);
    const check = new AbortController();
    const abort = () => check.abort();
    signal?.addEventListener('abort', abort, { once: true });
    if (signal?.aborted) check.abort();
    this.activeCheck = check;
    this.update({ results: [], checking: true });
    try {
      const results = await Promise.all(services.map(async service => {
        const result = await this.probeRequest(port, { ...service, ...service.probe }, { signal: check.signal });
        check.signal.throwIfAborted();
        if (this.state.phase === 'running' && this.state.port === port && this.child === child) {
          const completed = [...this.state.results, result];
          this.update({ results: services.flatMap(item => completed.filter(value => value.id === item.id)) });
        }
        return result;
      }));
      if (this.state.phase !== 'running' || this.state.port !== port || this.child !== child) throw new Error('Прокси остановился во время проверки. Подключись снова.');
      return results;
    } catch (error) {
      if (!check.signal.aborted || signal) throw error;
      this.update({ message: 'Проверка отменена. Подключение продолжает работать.' });
      return this.state.results;
    } finally {
      check.abort();
      signal?.removeEventListener('abort', abort);
      this.activeCheck = null;
      this.update({ checking: false });
    }
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

  createCandidate() {
    return new Controller(this.enginePath, { settings: this.settings, ephemeral: true, probe: this.probeRequest });
  }

  async selectBest() {
    if (!serviceCatalog.some(service => this.settings.serviceIds.includes(service.id) && service.probe)) throw new Error('Для автоподбора выбери Discord или YouTube — для них доступна HTTP-проверка.');
    const previous = this.state.profile;
    const wasRunning = this.state.phase === 'running';
    const selection = new AbortController();
    this.selection = selection;
    const { signal } = selection;
    const candidate = this.createCandidate();
    let best = null;
    let switched = false;
    this.update({ testing: true });
    try {
      for (const [index, profile] of profiles.entries()) {
        signal.throwIfAborted();
        if (this.closed) throw new Error('Приложение закрывается');
        this.update({ progress: { current: index + 1, total: profiles.length, name: profile.name }, message: `Проверяем: ${profile.name}. Текущее подключение не меняется.` });
        try {
          await candidate.start(profile.id, signal);
          const results = await candidate.diagnose(signal);
          const reachable = results.filter(result => result.reachable);
          const count = reachable.length;
          const latency = reachable.reduce((total, result) => total + result.milliseconds, 0);
          if (count && (!best || count > best.count || (count === best.count && latency < best.latency))) best = { id: profile.id, count, latency, services: reachable.map(result => result.id) };
        } catch (error) { if (signal.aborted || this.closed) throw error; }
      }
      if (!best) throw new Error('Рабочий профиль не найден. Предыдущая настройка сохранена.');
      this.update({ progress: { current: profiles.length, total: profiles.length, name: 'Повторная проверка' } });
      await candidate.start(best.id, signal);
      const confirmation = await candidate.diagnose(signal);
      const confirms = results => best.services.every(id => results.some(result => result.id === id && result.reachable));
      if (!confirms(confirmation)) throw new Error('Профиль не прошёл повторную проверку. Предыдущая настройка сохранена.');
      await candidate.close();
      signal.throwIfAborted();
      this.update({ progress: { current: profiles.length, total: profiles.length, name: 'Применяем профиль' } });
      switched = true;
      await this.start(best.id, signal);
      if (!confirms(await this.diagnose(signal))) throw new Error('Профиль не прошёл проверку на основном порту. Предыдущая настройка сохранена.');
      signal.throwIfAborted();
      if (this.settingsPath) await saveSettings(this.settingsPath, { ...this.settings, profile: best.id });
      this.settings.profile = best.id;
      this.update({ message: 'Лучший из проверенных профилей подключён. Это HTTP-проверка, не тест видеопотока.' });
    } catch (error) {
      let message = signal.aborted ? 'Подбор отменён. Предыдущая настройка сохранена.' : error.message;
      if (switched) {
        if (wasRunning && !this.closed) {
          try { await this.start(previous); }
          catch { message += ' Восстановить подключение не удалось — попробуй подключиться вручную.'; }
        } else await this.stop();
      }
      this.update({ profile: previous, message });
      if (!signal.aborted) throw new Error(message);
    } finally {
      await candidate.close();
      this.selection = null;
      this.update({ testing: false, progress: null });
    }
  }
}

module.exports = { Controller, commandArgs, handshake, probe };
