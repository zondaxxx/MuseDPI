const net = require('node:net');
const { domainToASCII } = require('node:url');
const { readFile, writeFile, rename, mkdir } = require('node:fs/promises');
const path = require('node:path');

const serviceCatalog = [
  { id: 'discord', name: 'Discord', detail: 'Сайт, API и CDN', domains: ['discord.com', 'discord.gg', 'discordapp.com', 'discordapp.net'], probe: { url: 'https://discord.com/api/v9/gateway', kind: 'discord' } },
  { id: 'youtube', name: 'YouTube', detail: 'Сайт, видео и изображения', domains: ['youtube.com', 'youtu.be', 'googlevideo.com', 'ytimg.com'], probe: { url: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg', kind: 'jpeg' } },
  { id: 'telegram', name: 'Telegram Web', detail: 'Веб-клиент и страницы', domains: ['telegram.org', 't.me', 'telegra.ph', 'telegram-cdn.org'] },
  { id: 'twitch', name: 'Twitch', detail: 'Сайт и видеосерверы', domains: ['twitch.tv', 'ttvnw.net', 'jtvnw.net', 'twitchcdn.net'] },
  { id: 'steam', name: 'Steam', detail: 'Магазин, сообщество и загрузки', domains: ['steampowered.com', 'steamcommunity.com', 'steamstatic.com', 'steamcontent.com', 'steamserver.net', 'steamusercontent.com'] },
  { id: 'roblox', name: 'Roblox', detail: 'Сайт, API и ресурсы', domains: ['roblox.com', 'rbxcdn.com'] }
];
const profileIds = ['gentle', 'multisplit', 'mid-sni', 'tls-record'];

function defaults() {
  return { version: 1, profile: 'multisplit', serviceIds: ['discord', 'youtube'], customDomains: '', excludedDomains: '', ipMode: 'off', includeIps: '', excludeIps: '', game: { enabled: false, tcpPorts: '27015-27050', udpPorts: '', udpFakes: 3, ttl: 8 } };
}

function entries(value, label, maxLength = 524288) {
  if (typeof value !== 'string' || value.length > maxLength) throw new Error(`${label}: слишком большой или неверный список`);
  return value.split('\n').map(line => line.split('#')[0]).join(' ').split(/[\s,;]+/).filter(Boolean);
}

function domains(value) {
  const tokens = entries(value, 'Домены', 65536);
  if (tokens.length > 250) throw new Error('Не более 250 собственных доменов');
  return [...new Set(tokens.map(token => {
    const domain = domainToASCII(token.replace(/^\*\./, '').replace(/\.$/, '').toLowerCase());
    if (!domain || domain.length > 253 || net.isIP(domain) || !domain.includes('.') || !domain.split('.').every(label => /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(label))) throw new Error(`Неверный домен: ${token.slice(0,80)}`);
    return domain;
  }))];
}

function ipEntries(value) {
  const tokens = entries(value, 'IP-набор');
  if (tokens.length > 5000) throw new Error('Не более 5000 IP-адресов или подсетей в списке');
  return [...new Set(tokens.flatMap(token => {
    const [address, prefix, extra] = token.split('/');
    const family = net.isIP(address);
    if (!family || address.includes('%') || extra !== undefined || (prefix !== undefined && (!/^\d{1,3}$/.test(prefix) || Number(prefix) > (family === 4 ? 32 : 128)))) throw new Error(`Неверный IP или CIDR: ${token.slice(0,80)}`);
    if (prefix !== undefined && Number(prefix) === 0) return family === 4 ? ['0.0.0.0/1', '128.0.0.0/1'] : ['::/1', '8000::/1'];
    return [address.toLowerCase() + (prefix === undefined ? '' : `/${Number(prefix)}`)];
  }))];
}

function ports(value) {
  const result = new Set();
  for (const token of entries(value, 'Порты', 4096)) {
    if (!/^\d{1,5}(-\d{1,5})?$/.test(token)) throw new Error(`Неверный порт: ${token.slice(0,40)}`);
    const [start, finish = start] = token.split('-').map(Number);
    if (start < 1 || finish > 65535 || start > finish) throw new Error('Порты должны быть в диапазоне 1–65535');
    if (finish - start >= 56) throw new Error('Не более 56 игровых портов суммарно для TCP и UDP');
    for (let port = start; port <= finish; port++) result.add(port);
    if (result.size > 56) throw new Error('Не более 56 игровых портов суммарно для TCP и UDP');
  }
  return [...result].sort((first, second) => first - second);
}

function engineIps(value) {
  return ipEntries(value).flatMap(entry => {
    const [address, prefix = '32'] = entry.split('/');
    return net.isIP(address) === 4 ? [entry, `::ffff:${address}/${96 + Number(prefix)}`] : [entry];
  });
}

function normalizeSettings(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input) || input.version !== 1 || !input.game || typeof input.game !== 'object') throw new Error('Неверный формат настроек');
  if (!profileIds.includes(input.profile)) throw new Error('Неизвестная стратегия');
  if (!Array.isArray(input.serviceIds) || input.serviceIds.length > serviceCatalog.length || input.serviceIds.some(id => !serviceCatalog.some(service => service.id === id))) throw new Error('Неизвестный сервис');
  if (!['off', 'extend', 'only'].includes(input.ipMode)) throw new Error('Неизвестный режим IP-наборов');
  if (typeof input.game.enabled !== 'boolean' || !Number.isInteger(input.game.udpFakes) || input.game.udpFakes < 1 || input.game.udpFakes > 6 || !Number.isInteger(input.game.ttl) || input.game.ttl < 1 || input.game.ttl > 32) throw new Error('UDP: от 1 до 6 пакетов, TTL от 1 до 32');
  if (ports(input.game.tcpPorts).length + ports(input.game.udpPorts).length > 56) throw new Error('Не более 56 игровых портов суммарно для TCP и UDP');
  const settings = { version: 1, profile: input.profile, serviceIds: [...new Set(input.serviceIds)], customDomains: domains(input.customDomains).join('\n'), excludedDomains: domains(input.excludedDomains).join('\n'), ipMode: input.ipMode, includeIps: ipEntries(input.includeIps).join('\n'), excludeIps: ipEntries(input.excludeIps).join('\n'), game: { enabled: input.game.enabled, tcpPorts: input.game.tcpPorts.trim(), udpPorts: input.game.udpPorts.trim(), udpFakes: input.game.udpFakes, ttl: input.game.ttl } };
  if (settings.ipMode !== 'off' && !settings.includeIps) throw new Error('Добавь хотя бы один IP или выбери «Выключено»');
  if (settings.game.enabled && !ports(settings.game.tcpPorts).length && !ports(settings.game.udpPorts).length) throw new Error('Укажи хотя бы один игровой порт');
  return settings;
}

function targetDomains(settings) {
  return [...new Set([...serviceCatalog.filter(service => settings.serviceIds.includes(service.id)).flatMap(service => service.domains), ...domains(settings.customDomains)])];
}

async function loadSettings(filename) {
  try { return { settings: normalizeSettings(JSON.parse(await readFile(filename, 'utf8'))), warning: '' }; }
  catch (error) { return { settings: defaults(), warning: error.code === 'ENOENT' ? '' : 'Не удалось прочитать сохранённые настройки. Используются стандартные; исходный файл не изменён.' }; }
}

async function saveSettings(filename, input) {
  const settings = normalizeSettings(input);
  await mkdir(path.dirname(filename), { recursive: true });
  const temporary = `${filename}.tmp`;
  await writeFile(temporary, JSON.stringify(settings, null, 2), { mode: 0o600 });
  await rename(temporary, filename);
  return settings;
}

module.exports = { serviceCatalog, defaults, normalizeSettings, domains, ipEntries, engineIps, ports, targetDomains, loadSettings, saveSettings };
