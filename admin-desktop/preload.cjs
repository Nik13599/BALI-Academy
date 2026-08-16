const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('baliAdmin', {
  getSettings: () => ipcRenderer.invoke('settings:get'),
  saveSettings: value => ipcRenderer.invoke('settings:save', value),
  listEmployees: () => ipcRenderer.invoke('employees:list'),
  getContent: () => ipcRenderer.invoke('content:get'),
  saveContent: bundle => ipcRenderer.invoke('content:save', bundle)
});
