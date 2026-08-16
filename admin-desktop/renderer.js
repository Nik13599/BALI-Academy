const $ = s => document.querySelector(s);
const $$ = s => [...document.querySelectorAll(s)];
let employees = [];
let selectedEmployeeId = null;
let contentBundle = null;

const titles = {
  dashboard: ['Обзор', 'Обучение и результаты персонала'],
  employees: ['Сотрудники', 'Бармены и официанты в одной системе'],
  content: ['База знаний', 'Единый GitHub-контент для приложений'],
  settings: ['Настройки', 'Подключение к BALI Academy Gateway']
};

function status(message, type='ok') {
  const el = $('#status');
  el.textContent = message;
  el.className = `status ${type}`;
  clearTimeout(status.timer);
  status.timer = setTimeout(() => el.className = 'status hidden', 3500);
}

function roleLabel(role) { return role === 'bartender' ? 'Бармен' : role === 'waiter' ? 'Официант' : role; }
function fmtDate(v) { if (!v) return '—'; try { return new Date(v).toLocaleString('ru-RU'); } catch { return v; } }

function showTab(name) {
  $$('.tab').forEach(x => x.classList.toggle('active', x.id === name));
  $$('.nav').forEach(x => x.classList.toggle('active', x.dataset.tab === name));
  $('#pageTitle').textContent = titles[name][0];
  $('#pageSubtitle').textContent = titles[name][1];
  if (name === 'content' && !contentBundle) loadContent();
}

$$('.nav').forEach(btn => btn.addEventListener('click', () => showTab(btn.dataset.tab)));

async function loadEmployees() {
  try {
    const data = await window.baliAdmin.listEmployees();
    employees = data.employees || [];
    renderDashboard();
    renderEmployeeList();
  } catch (e) {
    status(`Не удалось загрузить сотрудников: ${e.message}`, 'error');
  }
}

function renderDashboard() {
  const bartenders = employees.filter(x => x.role === 'bartender');
  const waiters = employees.filter(x => x.role === 'waiter');
  const attempts = employees.reduce((s,x)=>s+(x.stats?.totalAttempts||0),0);
  const avg = employees.length ? Math.round(employees.reduce((s,x)=>s+(x.stats?.avg||0),0)/employees.length) : 0;
  $('#stats').innerHTML = [
    ['Сотрудников', employees.length],
    ['Барменов', bartenders.length],
    ['Официантов', waiters.length],
    ['Всего тестов', attempts],
    ['Средний результат', `${avg}%`]
  ].map(([k,v])=>`<div class="stat"><span>${k}</span><strong>${v}</strong></div>`).join('');

  const recent = [...employees].sort((a,b)=>String(b.stats?.lastAttemptAt||b.lastSeenAt||'').localeCompare(String(a.stats?.lastAttemptAt||a.lastSeenAt||''))).slice(0,8);
  $('#recent').innerHTML = recent.length ? recent.map(e=>`<div class="recent-row"><div><strong>${escapeHtml(e.fio)}</strong><span>${roleLabel(e.role)}</span></div><div class="score">${e.stats?.avg||0}%</div><small>${fmtDate(e.stats?.lastAttemptAt || e.lastSeenAt)}</small></div>`).join('') : '<div class="empty">Пока нет зарегистрированных сотрудников.</div>';
}

function renderEmployeeList() {
  const q = $('#employeeSearch').value.trim().toLowerCase();
  const role = $('#roleFilter').value;
  const list = employees.filter(e => (role === 'all' || e.role === role) && (!q || e.fio.toLowerCase().includes(q)));
  $('#employeeList').innerHTML = list.length ? list.map(e => `
    <button class="employee-card ${e.id===selectedEmployeeId?'selected':''}" data-id="${e.id}">
      <div><strong>${escapeHtml(e.fio)}</strong><span>${roleLabel(e.role)}</span></div>
      <b>${e.stats?.avg||0}%</b>
    </button>`).join('') : '<div class="empty">Ничего не найдено</div>';
  $$('.employee-card').forEach(b => b.addEventListener('click', () => { selectedEmployeeId = b.dataset.id; renderEmployeeList(); renderEmployeeDetail(); }));
}

function renderEmployeeDetail() {
  const e = employees.find(x => x.id === selectedEmployeeId);
  if (!e) return;
  const cats = Object.entries(e.stats?.categories || {}).sort((a,b)=>a[1]-b[1]);
  const weak = e.stats?.weak || [];
  $('#employeeDetail').innerHTML = `
    <div class="detail-head"><div><span class="role-pill">${roleLabel(e.role)}</span><h2>${escapeHtml(e.fio)}</h2><p>Устройств: ${e.deviceCount||0} • Последняя активность: ${fmtDate(e.lastSeenAt)}</p></div><div class="big-score">${e.stats?.avg||0}%<small>средний</small></div></div>
    <div class="mini-stats"><div><span>Попыток</span><b>${e.stats?.totalAttempts||0}</b></div><div><span>Лучший</span><b>${e.stats?.best||0}%</b></div><div><span>Последний тест</span><b>${fmtDate(e.stats?.lastAttemptAt)}</b></div></div>
    <h3>Результаты по категориям</h3>
    <div class="category-bars">${cats.length ? cats.map(([name,score])=>`<div class="bar-row"><span>${escapeHtml(name)}</span><div><i style="width:${Math.max(0,Math.min(100,score))}%"></i></div><b>${score}%</b></div>`).join('') : '<div class="empty">Нет данных</div>'}</div>
    <h3>Слабые вопросы</h3>
    <div class="weak-list">${weak.length ? weak.map(w=>`<span>${escapeHtml(w.key)} <b>×${w.count}</b></span>`).join('') : '<div class="empty">Ошибок пока нет</div>'}</div>`;
}

async function loadContent() {
  try {
    contentBundle = await window.baliAdmin.getContent();
    $('#contentEditor').value = JSON.stringify(contentBundle, null, 2);
  } catch (e) { status(`Контент не загружен: ${e.message}`, 'error'); }
}

$('#saveContentBtn').addEventListener('click', async () => {
  try {
    const parsed = JSON.parse($('#contentEditor').value);
    await window.baliAdmin.saveContent(parsed);
    contentBundle = parsed;
    status('База опубликована в GitHub.');
  } catch (e) { status(`Ошибка публикации: ${e.message}`, 'error'); }
});

$('#saveSettingsBtn').addEventListener('click', async () => {
  await window.baliAdmin.saveSettings({ gatewayUrl: $('#gatewayUrl').value.trim(), adminKey: $('#adminKey').value.trim() });
  status('Настройки сохранены.');
  loadEmployees();
});

$('#refreshBtn').addEventListener('click', () => { loadEmployees(); if ($('#content').classList.contains('active')) loadContent(); });
$('#employeeSearch').addEventListener('input', renderEmployeeList);
$('#roleFilter').addEventListener('change', renderEmployeeList);

function escapeHtml(v='') { return String(v).replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c])); }

(async function init(){
  const s = await window.baliAdmin.getSettings();
  $('#gatewayUrl').value = s.gatewayUrl || '';
  $('#adminKey').value = s.adminKey || '';
  if (s.gatewayUrl && s.adminKey) loadEmployees();
  else showTab('settings');
})();
