const { app, BrowserWindow, ipcMain, clipboard, session, dialog } = require('electron');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { Controller } = require('./controller.cjs');
const { loadSettings, ipEntries } = require('./settings.cjs');
const { open } = require('node:fs/promises');

if (!app.requestSingleInstanceLock()) app.quit();
let window;
let controller;
let quitting = false;
const page = pathToFileURL(path.join(__dirname, 'index.html')).href;

app.whenReady().then(async () => {
  const engineName = process.platform === 'win32' ? 'ciadpi.exe' : 'ciadpi';
  const enginePath = app.isPackaged
    ? path.join(process.resourcesPath, 'engine', engineName)
    : path.join(__dirname, 'engine', engineName);
  const settingsPath = path.join(app.getPath('userData'), 'settings.json');
  const loaded = await loadSettings(settingsPath);
  controller = new Controller(enginePath, { settingsPath, settings: loaded.settings });
  controller.state.message = loaded.warning;
  window = new BrowserWindow({ width: 880, height: 720, minWidth: 650, minHeight: 560, backgroundColor: '#24292d', title: 'MuseDPI · Desktop', webPreferences: { preload: path.join(__dirname, 'preload.cjs'), contextIsolation: true, nodeIntegration: false, sandbox: true } });
  window.removeMenu();
  session.defaultSession.setPermissionRequestHandler((_contents, _permission, callback) => callback(false));
  window.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  window.webContents.on('will-navigate', event => event.preventDefault());
  window.loadFile('index.html');
  controller.on('state', state => { if (!window.isDestroyed()) window.webContents.send('state', state); });
  ipcMain.handle('action', async (event, action, id) => {
    if (event.sender !== window.webContents || event.senderFrame?.url !== page) throw new Error('Недопустимый источник команды');
    if (action === 'state') return controller.snapshot();
    if (action === 'import-ipset') {
      const selected = await dialog.showOpenDialog(window, { title: 'Импорт IP-набора', properties: ['openFile'], filters: [{ name: 'IP-наборы', extensions: ['txt', 'cidr', 'list'] }] });
      if (selected.canceled) return null;
      const file = await open(selected.filePaths[0], 'r');
      try {
        const metadata = await file.stat();
        if (!metadata.isFile() || metadata.size > 524288) throw new Error('Нужен текстовый файл размером до 512 КБ');
        const buffer = Buffer.alloc(524289);
        const { bytesRead } = await file.read(buffer, 0, buffer.length, 0);
        if (bytesRead > 524288) throw new Error('Файл больше 512 КБ');
        return ipEntries(buffer.subarray(0, bytesRead).toString('utf8')).join('\n');
      } finally { await file.close(); }
    }
    if (action === 'copy') {
      if (controller.state.phase !== 'running') throw new Error('Прокси не запущен');
      clipboard.writeText(`socks5://127.0.0.1:${controller.state.port}`);
      return controller.snapshot();
    }
    return controller.exclusive(async () => {
      if (action === 'configure') await controller.configure(id);
      else if (action === 'connect') { await controller.start(controller.state.profile); await controller.diagnose(); }
      else if (action === 'disconnect') await controller.stop();
      else if (action === 'diagnose') await controller.diagnose();
      else if (action === 'auto') await controller.selectBest();
      else throw new Error('Неизвестная команда');
      return controller.snapshot();
    });
  });
});

app.on('second-instance', () => { if (window) { window.show(); window.focus(); } });
app.on('window-all-closed', () => app.quit());
app.on('before-quit', event => {
  if (quitting || !controller) return;
  event.preventDefault();
  quitting = true;
  controller.close().finally(() => app.quit());
});
