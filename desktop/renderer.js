const byId = id => document.getElementById(id);
let state;
let pending = false;
let draft;
let dirty = false;
let actionError = '';
let notice = '';

function errorMessage(error) {
  return error.message.replace(/^Error invoking remote method '[^']+': (?:Error: )?/, '');
}

function showPage(page) {
  document.querySelectorAll('[data-panel]').forEach(panel => { panel.hidden = panel.dataset.panel !== page; });
  document.querySelectorAll('.sidebar [data-page]').forEach(button => {
    if (button.dataset.page === page) button.setAttribute('aria-current', 'page');
    else button.removeAttribute('aria-current');
  });
  document.querySelector('main').scrollTop = 0;
}

function optionRow(item, type, name) {
  const row = document.createElement('label');
  row.className = 'option-row';
  const text = document.createElement('span');
  const title = document.createElement('strong');
  title.textContent = item.name;
  const detail = document.createElement('small');
  detail.textContent = item.detail;
  text.append(title, detail);
  const input = document.createElement('input');
  input.type = type;
  input.name = name;
  input.value = item.id;
  row.append(text, input);
  return row;
}

function populate() {
  byId('service-options').replaceChildren(...state.services.map(service => optionRow(service, 'checkbox', 'service')));
  byId('profile-options').replaceChildren(...state.profiles.map(profile => optionRow(profile, 'radio', 'profile')));
}

function fillForm() {
  draft = structuredClone(state.settings);
  document.querySelectorAll('[name="service"]').forEach(input => { input.checked = draft.serviceIds.includes(input.value); });
  document.querySelectorAll('[name="profile"]').forEach(input => { input.checked = draft.profile === input.value; });
  byId('custom-domains').value = draft.customDomains;
  byId('excluded-domains').value = draft.excludedDomains;
  byId('ip-mode').value = draft.ipMode;
  byId('include-ips').value = draft.includeIps;
  byId('exclude-ips').value = draft.excludeIps;
  byId('game-enabled').checked = draft.game.enabled;
  byId('tcp-ports').value = draft.game.tcpPorts;
  byId('udp-ports').value = draft.game.udpPorts;
  byId('udp-fakes').value = draft.game.udpFakes;
  byId('game-ttl').value = draft.game.ttl;
  dirty = false;
}

function readForm() {
  draft = {
    version: 1,
    profile: document.querySelector('[name="profile"]:checked')?.value || state.settings.profile,
    serviceIds: [...document.querySelectorAll('[name="service"]:checked')].map(input => input.value),
    customDomains: byId('custom-domains').value,
    excludedDomains: byId('excluded-domains').value,
    ipMode: byId('ip-mode').value,
    includeIps: byId('include-ips').value,
    excludeIps: byId('exclude-ips').value,
    game: { enabled: byId('game-enabled').checked, tcpPorts: byId('tcp-ports').value, udpPorts: byId('udp-ports').value, udpFakes: Number(byId('udp-fakes').value), ttl: Number(byId('game-ttl').value) }
  };
  dirty = JSON.stringify(draft) !== JSON.stringify(state.settings);
  notice = '';
  actionError = '';
  render(state);
}

function render(next) {
  const initial = !state;
  state = next;
  if (initial) { populate(); fillForm(); }
  const running = state.phase === 'running';
  const busy = pending || state.testing || state.checking || ['starting', 'stopping'].includes(state.phase);
  const selected = state.services.filter(service => state.settings.serviceIds.includes(service.id));
  const hasProbes = selected.some(service => service.probe);
  const status = state.testing ? 'Подбор стратегии' : state.phase === 'starting' ? 'Подключаемся…' : state.phase === 'stopping' ? 'Отключаемся…' : running ? 'Работает' : state.phase === 'error' ? 'Не удалось подключиться' : 'Отключён';
  byId('status').textContent = 'Локальный прокси';
  byId('connection-title').textContent = status;
  byId('active-profile').textContent = state.profiles.find(profile => profile.id === state.profile)?.name || '';
  byId('dot').classList.toggle('active', running);
  byId('sidebar-status').lastChild.textContent = status;
  byId('sidebar-status').querySelector('.dot').classList.toggle('active', running);
  byId('connect').textContent = busy ? 'Подождите…' : running ? 'Отключить' : 'Подключить';
  byId('connect').disabled = busy || (dirty && !running);
  byId('diagnose').disabled = busy || !running || !hasProbes;
  byId('diagnose').textContent = state.checking ? 'Проверяем…' : 'Проверить';
  byId('auto').disabled = busy || dirty || !hasProbes;
  byId('copy').disabled = !running;
  byId('address').textContent = running ? `127.0.0.1:${state.port}` : 'Появится после подключения';
  byId('service-count').textContent = String(draft.serviceIds.length);
  byId('savebar').hidden = !dirty;
  byId('save').textContent = running ? 'Применить и переподключить' : 'Сохранить';
  byId('save').disabled = busy;
  byId('discard').disabled = busy;
  document.querySelectorAll('.settings-fields').forEach(fieldset => { fieldset.disabled = busy; });
  for (const id of ['tcp-ports', 'udp-ports', 'udp-fakes', 'game-ttl']) byId(id).disabled = busy || !draft.game.enabled;
  byId('ip-mode-help').textContent = draft.ipMode === 'only' ? 'Обход только для IP из списка. Доменные правила сервисов не применяются.' : draft.ipMode === 'extend' ? 'Обход для выбранных доменов и, отдельно, для IP из списка.' : 'Включающий IP-список не используется. Исключения IP остаются активными.';
  const count = draft.includeIps.split(/[\s,;]+/).filter(Boolean).length;
  byId('include-count').textContent = count ? `Записей до проверки: ${count}` : 'Список пуст';
  byId('scope-summary').textContent = `${state.settings.ipMode === 'only' ? 'Обход по IP-набору' : `Выбрано сервисов: ${selected.length}`}${state.settings.game.enabled ? ' · игровой фильтр включён' : ''}`;
  byId('message').textContent = actionError || notice || (dirty ? 'Сохрани изменения, чтобы применить их к подключению.' : state.message);
  byId('message').classList.toggle('error', Boolean(actionError));
  const rows = selected.map(service => {
    const result = state.results.find(item => item.id === service.id);
    const row = document.createElement('div');
    row.className = 'service';
    const label = document.createElement('strong');
    label.textContent = service.name;
    const value = document.createElement('span');
    value.textContent = !service.probe ? 'Без HTTP-теста' : result ? result.reachable ? `${result.milliseconds} мс · доступен` : 'Проверка не пройдена' : state.checking ? 'Проверяем…' : 'Не проверен';
    if (result) value.className = result.reachable ? 'ok' : 'failed';
    row.append(label, value);
    return row;
  });
  if (!rows.length) {
    const empty = document.createElement('p');
    empty.textContent = 'Выбери сервисы для проверки в разделе «Сервисы».';
    rows.push(empty);
  }
  byId('results').replaceChildren(...rows);
  const checkedAt = Math.max(0, ...state.results.map(result => result.checkedAt || 0));
  byId('checked').textContent = checkedAt ? `HTTP-проверка: ${new Date(checkedAt).toLocaleTimeString()}. Игры и звонки не проверяются.` : 'HTTP-проверка доступна для Discord и YouTube.';
}

async function action(name, payload) {
  if (pending || !state) return;
  pending = true;
  actionError = '';
  notice = '';
  render(state);
  try {
    const next = await window.muse.action(name, payload);
    state = next;
    if (name === 'configure' || name === 'auto') fillForm();
    if (name === 'copy') notice = 'Адрес SOCKS5 скопирован';
  } catch (error) { actionError = errorMessage(error); }
  finally { pending = false; render(state); }
}

document.querySelectorAll('[data-page]').forEach(button => button.addEventListener('click', () => showPage(button.dataset.page)));
document.querySelectorAll('.settings-fields').forEach(fieldset => fieldset.addEventListener('input', readForm));
byId('connect').addEventListener('click', () => action(state.phase === 'running' ? 'disconnect' : 'connect'));
byId('auto').addEventListener('click', () => action('auto'));
byId('diagnose').addEventListener('click', () => action('diagnose'));
byId('copy').addEventListener('click', () => action('copy'));
byId('save').addEventListener('click', () => action('configure', draft));
byId('discard').addEventListener('click', () => { fillForm(); actionError = ''; notice = ''; render(state); });
document.querySelectorAll('[data-import]').forEach(button => button.addEventListener('click', async () => {
  if (pending) return;
  pending = true;
  render(state);
  try {
    const imported = await window.muse.action('import-ipset');
    if (imported !== null) {
      const input = byId(button.dataset.import);
      input.value = [input.value.trim(), imported].filter(Boolean).join('\n');
      readForm();
      notice = 'Файл добавлен в список. Сохрани изменения.';
    }
  } catch (error) { actionError = errorMessage(error); }
  finally { pending = false; render(state); }
}));
if (window.muse) {
  window.muse.subscribe(render);
  window.muse.action('state').then(render).catch(error => { byId('message').textContent = error.message; });
} else {
  byId('message').textContent = 'Открой MuseDPI Desktop, чтобы подключаться и менять настройки. В браузере доступна только разметка интерфейса.';
  document.querySelectorAll('.settings-fields').forEach(fieldset => { fieldset.disabled = true; });
  byId('auto').disabled = true;
}
