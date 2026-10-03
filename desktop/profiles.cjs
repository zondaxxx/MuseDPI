const { defaults, normalizeSettings, targetDomains, ports, engineIps } = require('./settings.cjs');

const profiles = [
  { id: 'gentle', name: 'Мягкий SNI', detail: 'Одно разбиение, без TTL и OOB', tls: ['-s1+s'] },
  { id: 'multisplit', name: 'SNI Multisplit', detail: 'Несколько TCP-фрагментов', tls: ['-s1', '-s1+s', '-s3+s', '-s6+s'] },
  { id: 'mid-sni', name: 'Середина SNI', detail: 'Не зависит от длины имени сервиса', tls: ['-s1', '-s0+sm'] },
  { id: 'tls-record', name: 'TLS Record', detail: 'Экспериментальный профиль TLS-записей', tls: ['-r0+sm', '-s1'] }
];

function commandArgs(id, input = defaults(), files = {}) {
  const profile = profiles.find(item => item.id === id);
  if (!profile) throw new Error('Неизвестная стратегия');
  const settings = normalizeSettings(input);
  const args = [];
  const list = (key, value) => files[key] || `:${value.split('\n').join(' ')}`;
  if (settings.excludeIps) args.push('-j', list('excludeIps', engineIps(settings.excludeIps).join('\n')), '-An');
  if (settings.excludedDomains) args.push('-Kt,h', '-H', list('excludedDomains', settings.excludedDomains), '-An');
  if (settings.game.enabled) {
    const scope = settings.ipMode === 'only' ? ['-j', list('includeIps', engineIps(settings.includeIps).join('\n'))] : [];
    for (const port of ports(settings.game.udpPorts)) args.push('-Ku', `-V${port}`, ...scope, `-a${settings.game.udpFakes}`, `-t${settings.game.ttl}`, '-An');
    for (const port of ports(settings.game.tcpPorts)) args.push(`-V${port}`, ...scope, '-s1', '-An');
  }
  const targets = targetDomains(settings);
  const scopes = [];
  if (settings.ipMode !== 'only' && targets.length) scopes.push(['-H', files.domains || `:${targets.join(' ')}`]);
  if (settings.ipMode !== 'off') scopes.push(['-j', list('includeIps', engineIps(settings.includeIps).join('\n'))]);
  for (const scope of scopes) args.push('-Kt', ...scope, ...profile.tls, '-An', '-Kh', ...scope, '-Mh,d,r', '-s1+h', '-An');
  return args;
}

module.exports = { profiles, commandArgs };
