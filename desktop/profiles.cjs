const { defaults, normalizeSettings, targetDomains, ports, engineIps } = require('./settings.cjs');

const profiles = require('./profile-data.cjs');

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
    const udpPorts = ports(settings.game.udpPorts);
    const customPayload = udpPorts.length && settings.game.udpPayload !== 'standard';
    if (customPayload && !files.udpPayload) throw new Error('Не подготовлен файл UDP-приманки');
    const payload = customPayload ? ['-l', files.udpPayload] : [];
    for (const port of udpPorts) args.push('-Ku', `-V${port}`, ...scope, ...payload, `-a${settings.game.udpFakes}`, `-t${settings.game.ttl}`, '-An');
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
