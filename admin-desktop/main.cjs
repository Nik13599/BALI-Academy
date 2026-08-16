const { app, BrowserWindow, ipcMain, safeStorage } = require('electron');
const fs = require('node:fs');
const path = require('node:path');

function settingsPath() { return path.join(app.getPath('userData'), 'settings.json'); }
function readSettings() {
  try {
    const raw = JSON.parse(fs.readFileSync(settingsPath(), 'utf8'));
    return {
      gatewayUrl: raw.gatewayUrl || '',
      adminKey: raw.adminKey ? safeStorage.decryptString(Buffer.from(raw.adminKey, 'base64')) : ''
    };
  } catch { return { gatewayUrl: '', adminKey: '' }; }
}
function saveSettings(settings) {
  const payload = {
    gatewayUrl: String(settings.gatewayUrl || '').replace(/\/$/, ''),
    adminKey: settings.adminKey ? safeStorage.encryptString(String(settings.adminKey)).toString('base64') : ''
  };
  fs.mkdirSync(path.dirname(settingsPath()), { recursive: true });
  fs.writeFileSync(settingsPath(), JSON.stringify(payload, null, 2));
  return { ok: true };
}

async function api(pathname, options = {}) {
  const settings = readSettings();
  if (!settings.gatewayUrl || !settings.adminKey) throw new Error('Сначала заполните настройки подключения.');
  const response = await fetch(`${settings.gatewayUrl}${pathname}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'X-Admin-Key': settings.adminKey,
      ...(options.headers || {})
    }
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.error || `HTTP ${response.status}`);
  return body;
}

function createWindow() {
  const win = new BrowserWindow({
    width: 1440,
    height: 900,
    minWidth: 1100,
    minHeight: 720,
    backgroundColor: '#0a0b0d',
    title: 'BALI Academy Admin',
    webPreferences: { preload: path.join(__dirname, 'preload.cjs'), contextIsolation: true, nodeIntegration: false }
  });
  win.loadFile('index.html');
}

app.whenReady().then(() => {
  ipcMain.handle('settings:get', () => readSettings());
  ipcMain.handle('settings:save', (_, value) => saveSettings(value));
  ipcMain.handle('employees:list', () => api('/api/admin-employees'));
  ipcMain.handle('content:get', () => api('/api/admin-content'));
  ipcMain.handle('content:save', (_, bundle) => api('/api/admin-content', { method: 'PUT', body: JSON.stringify(bundle) }));
  createWindow();
  app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});
app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
