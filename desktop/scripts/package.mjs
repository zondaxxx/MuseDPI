import { packager } from '@electron/packager';
import { access, mkdir, copyFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const engine = path.join(root, 'engine', 'ciadpi.exe');
await access(engine);
const resources = path.join(root, 'engine', 'bundle');
await mkdir(resources, { recursive: true });
await copyFile(engine, path.join(resources, 'ciadpi.exe'));
await copyFile(path.join(root, '..', 'Sources', 'ByeDPIC', 'byedpi', 'LICENSE'), path.join(resources, 'BYEDPI-LICENSE.txt'));
await copyFile(path.join(root, '..', 'LICENSE'), path.join(root, 'engine', 'MUSEDPI-LICENSE.txt'));
const packaged = await packager({
  dir: root, name: 'MuseDPI', platform: 'win32', arch: 'x64', out: path.join(root, 'dist'),
  overwrite: true, asar: true, executableName: 'MuseDPI',
  extraResource: [resources, path.join(root, 'engine', 'MUSEDPI-LICENSE.txt')],
  ignore: [/^\/engine/, /^\/dist/, /^\/test/, /^\/scripts/],
  win32metadata: { CompanyName: 'MuseDPI', FileDescription: 'MuseDPI Desktop Alpha', ProductName: 'MuseDPI', OriginalFilename: 'MuseDPI.exe' }
});
for (const directory of packaged) {
  const bundled = path.join(directory, 'resources');
  const { rename } = await import('node:fs/promises');
  await rename(path.join(bundled, 'bundle'), path.join(bundled, 'engine'));
  await copyFile(path.join(root, 'README.md'), path.join(directory, 'README-RU.md'));
  console.log(directory);
}
