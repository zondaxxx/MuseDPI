const { createHash } = require('node:crypto');
const { gunzipSync } = require('node:zlib');
const data = require('./data/flowseal.json');

const payloadOptions = [{ id: 'standard', name: 'Стандартная приманка ByeDPI' }, ...data.payloads.map(({ id, name, bytes }) => ({ id, name: `${name} · ${bytes} байт` }))];
const sourceInfo = { release: data.release, revision: data.revision, checkedAt: data.checkedAt, ipsetEntries: data.ipset.entries };

function verify(bytes, entry) {
  if (bytes.length !== entry.bytes || createHash('sha256').update(bytes).digest('hex') !== entry.sha256) throw new Error('Данные Flowseal повреждены. Переустанови приложение из проверенного релиза.');
  return bytes;
}

function payloadBytes(id) {
  if (id === 'standard') return null;
  const entry = data.payloads.find(item => item.id === id);
  if (!entry || !/^(?:[0-9a-f]{2})+$/.test(entry.hex) || entry.bytes > 2046) throw new Error('Неизвестная UDP-приманка');
  return verify(Buffer.from(entry.hex, 'hex'), entry);
}

function bundledIpSet() {
  const bytes = gunzipSync(Buffer.from(data.ipset.gzipBase64, 'base64'), { maxOutputLength: 2097152 });
  return verify(bytes, data.ipset).toString('utf8');
}

module.exports = { payloadOptions, payloadBytes, bundledIpSet, sourceInfo };
