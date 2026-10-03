const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('muse', {
  action: (action, id) => ipcRenderer.invoke('action', action, id),
  subscribe: callback => {
    const listener = (_event, state) => callback(state);
    ipcRenderer.on('state', listener);
    return () => ipcRenderer.removeListener('state', listener);
  }
});
