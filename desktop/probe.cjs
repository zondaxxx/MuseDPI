const { execFile } = require('node:child_process');
const { promisify } = require('node:util');

const execute = promisify(execFile);

async function probe(port, service, { signal, run = execute } = {}) {
  const startedAt = Date.now();
  const result = { id: service.id, name: service.name, reachable: false, milliseconds: null };
  try {
    signal?.throwIfAborted();
    const { stdout } = await run(process.platform === 'win32' ? 'curl.exe' : 'curl', [
      '--disable', '--silent', '--show-error', '--noproxy', '', '--proxy', `socks5h://127.0.0.1:${port}`,
      '--connect-timeout', '5', '--max-time', '12', '--range', '0-8191', '--max-filesize', '524288',
      '--write-out', '\n%{http_code}\n%{time_total}\n%{size_download}', service.url
    ], { encoding: 'buffer', timeout: 14000, maxBuffer: 1048576, windowsHide: true, signal });
    signal?.throwIfAborted();
    const trailer = /\n(\d{3})\n([\d.]+)\n(\d+)\s*$/.exec(stdout.toString('latin1'));
    if (!trailer) throw new Error('Invalid probe response');
    const status = Number(trailer[1]);
    const payload = stdout.subarray(0, trailer.index);
    let validPayload = false;
    if (service.kind === 'discord' || service.id === 'discord') {
      try {
        const gateway = new URL(JSON.parse(payload.toString()).url);
        validPayload = gateway.protocol === 'wss:' && gateway.hostname === 'gateway.discord.gg';
      } catch {}
    } else if (service.kind === 'jpeg' || service.id === 'youtube') {
      validPayload = payload[0] === 0xff && payload[1] === 0xd8;
    }
    const reachable = status >= 200 && status < 300 && validPayload;
    return { ...result, reachable, milliseconds: Date.now() - startedAt, checkedAt: Date.now(), status, error: reachable ? '' : status < 200 || status >= 300 ? `HTTP ${status}` : 'Неожиданный ответ сервиса' };
  } catch (error) {
    signal?.throwIfAborted();
    const message = error.code === 'ENOENT' ? 'curl не найден — нужна современная Windows'
      : error.code === 28 || error.killed ? 'Сервис не ответил за 12 секунд'
      : [5, 6].includes(error.code) ? 'Не удалось определить адрес сервиса'
      : error.code === 60 ? 'Ошибка сертификата TLS — проверь дату и время'
      : error.code === 7 ? 'Не удалось установить соединение'
      : 'Ошибка HTTP-проверки';
    return { ...result, checkedAt: Date.now(), error: message };
  }
}

module.exports = { probe };
