import { createHash } from 'node:crypto';
import { mkdir, readFile, readdir, copyFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const directory = path.join(root, 'engine');
await mkdir(directory, { recursive: true });
const archive = path.join(directory, 'byedpi-17.3-x86_64-w64.zip');
const expected = '70d2c94147193cb915f9c6eb5144b8d404dacbcfa90bda2383b6b211afafa456';
const url = 'https://github.com/hufrea/byedpi/releases/download/v0.17.3/byedpi-17.3-x86_64-w64.zip';
execFileSync('curl', ['--disable', '--fail', '--location', '--retry', '3', '--max-time', '180', '--output', archive, url], { stdio: 'inherit' });
if (createHash('sha256').update(await readFile(archive)).digest('hex') !== expected) throw new Error('Engine archive checksum mismatch');
const extracted = path.join(directory, 'windows');
await mkdir(extracted, { recursive: true });
if (process.platform === 'win32') {
  const quote = value => `'${value.replaceAll("'", "''")}'`;
  execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', `Expand-Archive -LiteralPath ${quote(archive)} -DestinationPath ${quote(extracted)} -Force`]);
} else {
  execFileSync('unzip', ['-o', archive, '-d', extracted], { stdio: 'inherit' });
}
async function findExecutable(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const filename = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      const nested = await findExecutable(filename);
      if (nested) return nested;
    } else if (entry.name.toLowerCase() === 'ciadpi.exe') return filename;
  }
}
const executable = await findExecutable(extracted);
if (!executable) throw new Error('ciadpi.exe missing in pinned engine archive');
await copyFile(executable, path.join(directory, 'ciadpi.exe'));
console.log('Windows engine verified and prepared');
