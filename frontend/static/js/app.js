/* MEDICYCLE frontend — wired to the Flask API */
const $ = id => document.getElementById(id);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const num = v => Number(v) || 0;

const STAFF_ROLES = ['DOCTOR', 'NURSE', 'RECEPTIONIST'];
const WRITE_ROLES = ['ADMIN', 'PHARMACIST'];          // roles shown the catalogue editing UI (server still enforces CATALOG_WRITE)
const BATCH_FILTERS = ['ALL', 'VALID', 'EXPIRING_SOON', 'EXPIRED', 'RECALLED', 'QUARANTINED'];
const RECALL_FILTERS = ['ALL', 'ACTIVE', 'COMPLETED', 'TERMINATED'];
const PAGE_SIZE = 20;

const S = { user: null, page: 'dashboard', tok: 0, meds: null, safetyId: '', medQ: '', medOffset: 0,
            batchFilter: 'ALL', expDays: '', recallFilter: 'ALL' };

/* ---------- API ---------- */
async function api(path, opts = {}) {
  const o = { method: 'GET', headers: {}, credentials: 'same-origin', ...opts };
  if (o.body && typeof o.body !== 'string') { o.body = JSON.stringify(o.body); o.headers['Content-Type'] = 'application/json'; }
  try {
    const res = await fetch(path, o);
    let data = {}; try { data = await res.json(); } catch (_) {}
    if (res.status === 401 && S.user && !path.includes('/auth/login')) { forceLogout(); }
    return { ok: res.ok, status: res.status, data, msg: data.message || (res.ok ? '' : `Request failed (${res.status}).`) };
  } catch (_) {
    return { ok: false, status: 0, data: {}, msg: 'Cannot reach the server.' };
  }
}

/* ---------- UI helpers ---------- */
const TONE = {
  ok: 'bg-bioEmerald/10 text-bioEmerald border-bioEmerald/40', warn: 'bg-bioAmber/15 text-bioAmber border-bioAmber/50',
  bad: 'bg-crimson/25 text-crimson-bright border-crimson', dead: 'bg-red-950/60 text-red-400 border-red-800/60',
  info: 'bg-sky-500/10 text-sky-400 border-sky-500/30', mute: 'bg-white/5 text-steelGray border-borderSubtle'
};
const STATUS_TONE = { VALID: 'ok', APPROVED: 'ok', COMPLETED: 'ok', EXPIRING_SOON: 'warn', PENDING: 'warn', QUARANTINED: 'warn',
  RECALLED: 'bad', ACTIVE: 'bad', EXPIRED: 'dead', REJECTED: 'dead', TERMINATED: 'mute', ADMIN: 'bad', DOCTOR: 'info', PHARMACIST: 'info' };
const badge = (t, tone) => `<span class="inline-block px-2 py-0.5 rounded-sm border font-mono text-[10px] tracking-wider ${TONE[tone || STATUS_TONE[t] || 'mute']}">${esc(String(t ?? '—').replace(/_/g, ' '))}</span>`;
const sevTone = s => /LIFE|SEVERE|MAJOR|CONTRA/i.test(s || '') ? 'bad' : /MODERATE/i.test(s || '') ? 'warn' : 'info';

const fmtDate = v => { if (!v) return '—'; const d = new Date(v); return isNaN(d) ? esc(v) : d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }); };
const fmtDT = v => { if (!v) return 'Never'; const d = new Date(v); return isNaN(d) ? esc(v) : d.toLocaleString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }); };

const loading = '<div class="flex items-center gap-3 py-10 justify-center font-mono text-xs text-steelGray"><div class="spinner"></div>Loading records…</div>';
const note = (msg, tone = 'mute') => `<div class="p-4 border rounded-sm font-mono text-xs ${TONE[tone]}">${esc(msg)}</div>`;
const empty = (msg, cols = 1) => `<tr><td colspan="${cols}" class="py-8 text-center font-mono text-xs text-steelGray">${esc(msg)}</td></tr>`;
const heading = (t, color = 'crimson') => `<div class="flex items-center gap-2"><span class="w-1.5 h-5 bg-${color}"></span><h2 class="font-display text-xl font-bold tracking-wide text-white uppercase">${esc(t)}</h2></div>`;
const table = (heads, rows) => `<div class="overflow-x-auto"><table class="w-full text-left border-collapse"><thead><tr class="bg-obsidian/90 border-y border-borderSubtle font-mono text-[11px] text-steelGray uppercase tracking-wider">${heads.map(h => `<th class="py-3 px-3 ${h.startsWith('>') ? 'text-right' : ''}">${esc(h.replace(/^>/, ''))}</th>`).join('')}</tr></thead><tbody class="divide-y divide-borderSubtle/60 text-xs sm:text-sm">${rows}</tbody></table></div>`;
const kv = (label, val, cls = '') => `<div class="p-3.5 bg-obsidian border border-borderSubtle rounded-sm"><div class="font-mono text-[10px] text-steelGray uppercase tracking-wider mb-1">${esc(label)}</div><div class="text-iceWhite text-sm leading-relaxed ${cls}">${val === null || val === undefined || val === '' ? '—' : val}</div></div>`;
const yn = v => v ? 'Yes' : 'No';

function showToast(msg, bad = false) {
  $('tactical-toast-msg').textContent = msg;
  $('toast-dot').className = `w-2 h-2 rounded-full shrink-0 ${bad ? 'bg-bioAmber' : 'bg-crimson-bright hazard-pulse'}`;
  $('tactical-toast').classList.remove('hidden');
  clearTimeout(window._tt); window._tt = setTimeout(() => $('tactical-toast').classList.add('hidden'), 3800);
}

function openModal(code, body, footer = '') {
  $('modal-code').textContent = code; $('modal-body').innerHTML = body;
  $('modal-footer').innerHTML = footer + `<button onclick="closeModal()" class="btn-ghost px-3.5 py-1.5 text-xs font-mono rounded-sm">DISMISS</button>`;
  $('modal').classList.remove('hidden'); $('modal').classList.add('flex');
}
function closeModal() { $('modal').classList.add('hidden'); $('modal').classList.remove('flex'); }
document.addEventListener('keydown', e => { if (e.key === 'Escape') closeModal(); });

/* ---------- Auth ---------- */
let authMode = 'login';
function toggleAuthMode() {
  authMode = authMode === 'login' ? 'register' : 'login';
  const reg = authMode === 'register';
  $('login-form').classList.toggle('hidden', reg); $('register-form').classList.toggle('hidden', !reg);
  $('auth-switch-text').textContent = reg ? 'Already approved?' : 'New staff member?';
  $('auth-switch-btn').textContent = reg ? 'Sign in' : 'Request access';
}
const formErr = (id, msg) => { const el = $(id); el.textContent = msg; el.classList.toggle('hidden', !msg); };

async function handleLogin(e) {
  e.preventDefault(); formErr('login-err', ''); $('login-btn').disabled = true;
  const r = await api('/api/auth/login', { method: 'POST', body: { identifier: $('login-id').value, password: $('login-pw').value } });
  $('login-btn').disabled = false;
  if (!r.ok) return formErr('login-err', r.msg);
  $('login-pw').value = ''; enterApp(r.data.user);
}

async function handleRegister(e) {
  e.preventDefault(); formErr('reg-err', ''); $('reg-btn').disabled = true;
  const r = await api('/api/auth/register', { method: 'POST', body: {
    full_name: $('reg-name').value, username: $('reg-user').value, email: $('reg-email').value, role: $('reg-role').value, password: $('reg-pw').value } });
  $('reg-btn').disabled = false;
  if (!r.ok) return formErr('reg-err', r.msg);
  $('register-form').reset(); toggleAuthMode(); showToast(r.msg || 'Registration submitted.');
}

async function handleSignOut() { await api('/api/auth/logout', { method: 'POST' }); forceLogout('Signed out.'); }
function forceLogout(msg = 'Session expired. Sign in again.') {
  S.user = null; closeModal();
  $('workspace-shell').classList.add('hidden'); $('auth-view').classList.remove('hidden'); showToast(msg);
}

function enterApp(user) {
  S.user = user;
  $('auth-view').classList.add('hidden'); $('workspace-shell').classList.remove('hidden');
  $('side-initial').textContent = (user.full_name || user.username || '?')[0].toUpperCase();
  $('side-name').textContent = user.full_name || user.username;
  $('side-role').textContent = user.role;
  $('nav-admin').classList.toggle('hidden', user.role !== 'ADMIN');
  S.meds = null; navigateTo('dashboard'); refreshRecallBadge();
  showToast(`Signed in as ${user.username}.`);
}

/* ---------- Navigation ---------- */
const META = {
  dashboard: ['DASHBOARD', 'Dashboard overview'], medicines: ['MEDICINE CATALOGUE', 'Medicine catalogue'],
  safety: ['SAFETY & INTERACTIONS', 'Safety & interactions'], recalls: ['RECALL MONITORING', 'Recall monitoring'],
  batches: ['BATCH MANAGEMENT', 'Batch management'], admin: ['USER MANAGEMENT', 'User management'], profile: ['PROFILE', 'My profile']
};
function navigateTo(page, safetyId) {
  if (page === 'admin' && S.user?.role !== 'ADMIN') page = 'dashboard';
  S.page = page; if (safetyId) S.safetyId = String(safetyId);
  if (window.innerWidth < 1024) $('sidebar').classList.add('-translate-x-full');
  document.querySelectorAll('[data-nav]').forEach(b => {
    const on = b.dataset.nav === page; b.classList.toggle('nav-item-active', on); b.classList.toggle('text-steelGray', !on);
  });
  $('page-breadcrumb').textContent = META[page][0]; $('page-title').textContent = META[page][1];
  renderPage();
}
const toggleMobileSidebar = () => $('sidebar').classList.toggle('-translate-x-full');

async function renderPage() {
  const tok = ++S.tok, el = $('page-content'); el.innerHTML = loading;
  const html = await PAGES[S.page]();
  if (tok !== S.tok) return;
  el.innerHTML = `<div class="fade-in-panel">${html}</div>`;
  if (AFTER[S.page]) AFTER[S.page]();
}

async function loadMeds() {
  if (S.meds) return S.meds;
  const r = await api('/api/medicines?limit=100');
  if (r.ok) S.meds = r.data.data || [];
  return S.meds || [];
}
async function refreshRecallBadge() {
  const r = await api('/api/recalls?status=ACTIVE'), b = $('recall-badge');
  const n = r.ok ? r.data.count : 0; b.textContent = n; b.classList.toggle('hidden', !n);
}
async function checkHealth() {
  const r = await api('/api/health'), ok = r.ok;
  $('health-dot').className = `w-2 h-2 rounded-full ${ok ? 'bg-bioEmerald shadow-[0_0_8px_#10B981]' : 'bg-crimson-bright'}`;
  $('health-text').textContent = ok ? 'System online' : 'Database offline';
  return r;
}

/* ---------- Pages ---------- */
const PAGES = {}, AFTER = {};

/* Dashboard */
PAGES.dashboard = async () => {
  const [health, meds, recalls, summary] = await Promise.all([
    checkHealth(), api('/api/medicines?limit=100'), api('/api/recalls?status=ACTIVE'), api('/api/batches/summary')]);
  const m = meds.ok ? meds.data.data : [], sm = summary.ok ? summary.data.data : null, rc = recalls.ok ? recalls.data.count : null;
  const kpi = (label, val, sub, go, tone = 'text-white') => `
    <div onclick="navigateTo('${go}')" class="hud-card hud-brackets p-5 cursor-pointer">
      <div class="font-mono text-xs text-steelGray uppercase tracking-wider">${label}</div>
      <div class="font-display text-4xl font-bold ${tone} mt-3">${val}</div>
      <div class="font-mono text-[11px] text-steelGray mt-2">${sub}</div></div>`;
  const rowStatus = (label, ok, txt) => `<div class="py-3.5 flex items-center justify-between"><span class="text-steelGray">${label}</span><span class="${ok ? 'text-bioEmerald' : 'text-crimson-bright'} font-semibold">${txt}</span></div>`;
  return `<div class="space-y-6">
    <div class="hud-card hud-brackets p-6 sm:p-7 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div><h2 class="font-display text-2xl sm:text-3xl font-bold text-white tracking-wide">Welcome, ${esc(S.user.full_name || S.user.username)}</h2>
        <p class="text-sm text-steelGray mt-1">Monitor medicine safety, inventory batches and recall status.</p></div>
      <div class="font-mono text-sm text-sky-400">${new Date().toLocaleDateString('en-GB', { day: '2-digit', month: 'long', year: 'numeric' })}</div>
    </div>
    <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
      ${kpi('Medicines', meds.ok ? (m.length >= 100 ? '100+' : m.length) : '—', 'Active catalogue records', 'medicines')}
      ${kpi('Active recalls', rc ?? '—', 'Awaiting containment', 'recalls', rc ? 'text-crimson-bright' : 'text-white')}
      ${kpi('Total batches', sm ? num(sm.total_batches) : '—', `${sm ? num(sm.valid_batches) : '—'} valid`, 'batches')}
      ${kpi('Expiring in 30 days', sm ? num(sm.expiring_within_30_days) : '—', `${sm ? num(sm.expired_by_date) : '—'} already expired by date`, 'batches', 'text-bioAmber')}
    </div>
    ${sm && (num(sm.recalled_batches) || num(sm.quarantined_batches)) ? note(`${num(sm.recalled_batches)} recalled and ${num(sm.quarantined_batches)} quarantined batches need attention.`, 'bad') : ''}
    <div class="grid grid-cols-1 lg:grid-cols-12 gap-6">
      <div class="lg:col-span-7 hud-card hud-brackets p-5 sm:p-6">
        <div class="flex items-center justify-between mb-4">${heading('Medicines')}<button onclick="navigateTo('medicines')" class="font-mono text-xs text-sky-400 hover:text-crimson-bright">View all →</button></div>
        ${table(['Medicine', 'Generic', '>Strength'], m.length ? m.slice(0, 6).map(x => `
          <tr onclick="openMedicine(${x.medicine_id})" class="hover:bg-white/[0.03] cursor-pointer">
            <td class="py-3 px-3 font-medium">${esc(x.brand_name)}</td><td class="py-3 px-3 text-steelGray">${esc(x.generic_name)}</td>
            <td class="py-3 px-3 text-right font-mono text-xs">${esc(x.strength)}</td></tr>`).join('') : empty(meds.ok ? 'No medicines yet.' : meds.msg, 3))}
      </div>
      <div class="lg:col-span-5 hud-card hud-brackets p-5 sm:p-6">
        <div class="mb-4">${heading('System overview', 'bioEmerald')}</div>
        <div class="divide-y divide-borderSubtle/70 font-mono text-xs">
          ${rowStatus('Backend API', health.status !== 0, health.status !== 0 ? 'Connected' : 'Unreachable')}
          ${rowStatus('Database', health.ok, health.ok ? esc(health.data.database?.database_name || 'Connected') : 'Offline')}
          ${health.ok ? `<div class="py-3.5 flex justify-between"><span class="text-steelGray">MySQL version</span><span>${esc(health.data.database?.mysql_version)}</span></div>` : ''}
          <div class="py-3.5 flex justify-between items-center"><span class="text-steelGray">Current role</span>${badge(S.user.role)}</div>
        </div>
      </div>
    </div></div>`;
};

/* Medicines */
PAGES.medicines = async () => `
  <div class="hud-card hud-brackets p-5 sm:p-6 space-y-5">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">${heading('Medicine catalogue')}
      ${WRITE_ROLES.includes(S.user.role) ? `<button onclick="openMedForm()" class="btn-crimson px-4 py-2 rounded-sm font-display font-bold text-xs tracking-widest uppercase text-white self-start">+ Add medicine</button>` : ''}</div>
    <input id="med-search" value="${esc(S.medQ)}" oninput="onMedSearch(this.value)" placeholder="Search brand, generic name or manufacturer…" class="field" aria-label="Search medicines">
    <div id="med-results">${loading}</div></div>`;
AFTER.medicines = () => loadMedTable();

let _medTimer;
function onMedSearch(v) { S.medQ = v.trim(); S.medOffset = 0; clearTimeout(_medTimer); _medTimer = setTimeout(loadMedTable, 280); }
function medPage(d) { S.medOffset = Math.max(0, S.medOffset + d * PAGE_SIZE); loadMedTable(); }

async function loadMedTable() {
  const box = $('med-results'); if (!box) return;
  const r = await api(`/api/medicines?q=${encodeURIComponent(S.medQ)}&limit=${PAGE_SIZE}&offset=${S.medOffset}`);
  if (!$('med-results')) return;
  if (!r.ok) { box.innerHTML = note(r.msg, 'bad'); return; }
  const rows = r.data.data;
  const formTone = f => f === 'INJECTION' ? 'bad' : f === 'CAPSULE' ? 'info' : 'mute';
  box.innerHTML = table(['ID', 'Brand', 'Generic', 'Strength', 'Form', 'Category', 'Manufacturer', 'Class'],
    rows.length ? rows.map(m => `<tr onclick="openMedicine(${m.medicine_id})" class="hover:bg-crimson/[0.06] cursor-pointer">
      <td class="py-3.5 px-3 font-mono text-xs text-steelGray">${m.medicine_id}</td><td class="py-3.5 px-3 font-semibold">${esc(m.brand_name)}</td>
      <td class="py-3.5 px-3 text-steelGray">${esc(m.generic_name)}</td><td class="py-3.5 px-3 font-mono text-xs">${esc(m.strength)}</td>
      <td class="py-3.5 px-3">${badge(m.dosage_form, formTone(m.dosage_form))}</td><td class="py-3.5 px-3 text-steelGray">${esc(m.category_name || '—')}</td>
      <td class="py-3.5 px-3 text-steelGray">${esc(m.manufacturer_name || '—')}</td>
      <td class="py-3.5 px-3 font-mono text-[11px] text-steelGray">${esc(String(m.prescription_classification || '—').replace(/_/g, ' '))}</td></tr>`).join('')
      : empty(S.medQ ? `No medicines match "${S.medQ}".` : 'No active medicines in the catalogue.', 8))
    + `<div class="flex items-center justify-between mt-4 font-mono text-xs text-steelGray">
        <span>Showing ${rows.length ? S.medOffset + 1 : 0}–${S.medOffset + rows.length}</span>
        <div class="flex gap-2"><button class="btn-ghost px-3 py-1 rounded-sm" onclick="medPage(-1)" ${S.medOffset === 0 ? 'disabled' : ''}>← Prev</button>
        <button class="btn-ghost px-3 py-1 rounded-sm" onclick="medPage(1)" ${rows.length < PAGE_SIZE ? 'disabled' : ''}>Next →</button></div></div>`;
}

async function openMedicine(id) {
  openModal(`MED-${String(id).padStart(3, '0')}`, loading);
  const r = await api(`/api/medicines/${id}`);
  if (!r.ok) { $('modal-body').innerHTML = note(r.msg, 'bad'); return; }
  const { medicine: m, ingredients, documented_uses: uses, storage: st } = r.data.data;
  $('modal-code').textContent = `MED-${String(id).padStart(3, '0')} // ${m.dosage_form}`;
  $('modal-body').innerHTML = `
    <div class="flex flex-wrap items-start justify-between gap-3 border-b border-borderSubtle pb-4">
      <div><div class="font-mono text-xs text-crimson-bright">${esc(m.manufacturer_name || 'Unknown manufacturer')}${m.manufacturer_country ? ' · ' + esc(m.manufacturer_country) : ''}</div>
        <h2 class="font-display text-2xl sm:text-3xl font-bold text-white">${esc(m.brand_name)}</h2>
        <p class="text-sm text-steelGray">${esc(m.generic_name)} — <span class="font-mono text-iceWhite">${esc(m.strength)}</span></p></div>
      ${m.is_active ? badge('ACTIVE', 'ok') : badge('INACTIVE', 'dead')}</div>
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
      ${kv('Category', esc(m.category_name))}${kv('Route', esc(m.administration_route))}
      ${kv('Classification', esc(String(m.prescription_classification || '').replace(/_/g, ' ')))}${kv('Barcode / NDC', esc([m.barcode_upc, m.ndc_number].filter(Boolean).join(' / ')))}</div>
    <div><div class="font-mono text-[10px] text-steelGray uppercase tracking-wider mb-2">Ingredients</div>
      ${ingredients.length ? ingredients.map(i => `<div class="p-3 mb-2 bg-obsidian border border-borderSubtle rounded-sm text-xs flex justify-between gap-3">
        <div><span class="font-semibold text-iceWhite">${esc(i.generic_name)}</span> <span class="text-steelGray">${esc(i.drug_class || '')}</span></div>
        <div class="font-mono text-right">${esc(i.strength_value ?? '')} ${esc(i.strength_unit || '')} ${i.is_active_ingredient ? badge('ACTIVE', 'info') : ''}</div></div>`).join('') : '<div class="text-xs text-steelGray">No ingredients recorded.</div>'}</div>
    <div><div class="font-mono text-[10px] text-steelGray uppercase tracking-wider mb-2">Documented uses</div>
      ${uses.length ? uses.map(u => `<div class="text-xs mb-1.5">• ${esc(u.indication)}${u.target_condition ? ` <span class="text-steelGray">(${esc(u.target_condition)})</span>` : ''} ${u.is_fda_approved ? badge('FDA APPROVED', 'ok') : ''}</div>`).join('') : '<div class="text-xs text-steelGray">No documented uses.</div>'}</div>
    <div><div class="font-mono text-[10px] text-steelGray uppercase tracking-wider mb-2">Storage</div>
      ${st ? `<div class="p-3.5 bg-obsidian border border-borderSubtle rounded-sm text-xs leading-relaxed">
        <div class="font-mono mb-1">${st.min_temp_celsius ?? '?'}°C – ${st.max_temp_celsius ?? '?'}°C ${st.requires_refrigeration ? badge('COLD CHAIN', 'info') : ''} ${st.light_sensitive ? badge('LIGHT SENSITIVE', 'warn') : ''} ${st.moisture_sensitive ? badge('MOISTURE SENSITIVE', 'warn') : ''}</div>
        ${esc(st.storage_instructions || '')}${st.excursion_limit_hours ? `<div class="text-steelGray mt-1">Excursion limit: ${esc(st.excursion_limit_hours)} h</div>` : ''}</div>` : '<div class="text-xs text-steelGray">No storage rules recorded.</div>'}</div>`;
  const writer = WRITE_ROLES.includes(S.user.role);
  $('modal-footer').insertAdjacentHTML('afterbegin', `
    ${writer ? `<button id="deact-btn" onclick="deactivateMed(${id}, this)" class="btn-ghost px-3.5 py-1.5 text-xs font-mono rounded-sm hover:!text-crimson-bright">DEACTIVATE</button>
    <button onclick='openMedForm(${id}, ${JSON.stringify({ brand_name: m.brand_name, generic_name: m.generic_name, dosage_form: m.dosage_form, strength: m.strength, administration_route: m.administration_route, prescription_classification: m.prescription_classification, barcode_upc: m.barcode_upc, ndc_number: m.ndc_number }).replace(/'/g, '&#39;')})' class="btn-ghost px-3.5 py-1.5 text-xs font-mono rounded-sm">EDIT</button>` : ''}
    <button onclick="closeModal(); navigateTo('safety', ${id})" class="btn-crimson px-4 py-1.5 text-xs font-display font-bold tracking-wider uppercase text-white rounded-sm">View safety →</button>`);
}

async function deactivateMed(id, btn) {
  if (!btn.dataset.armed) { btn.dataset.armed = '1'; btn.textContent = 'CONFIRM DEACTIVATE?'; return; }
  const r = await api(`/api/medicines/${id}`, { method: 'DELETE' });
  showToast(r.ok ? r.data.message : r.msg, !r.ok);
  if (r.ok) { closeModal(); S.meds = null; renderPage(); }
}

function openMedForm(id = null, d = {}) {
  const f = (name, label, opts = {}) => `<div class="${opts.wide ? 'sm:col-span-2' : ''}"><label class="lbl" for="mf-${name}">${label}</label>
    <input id="mf-${name}" name="${name}" class="field" value="${esc(d[name] ?? '')}" ${opts.req === false ? '' : 'required'} ${opts.type ? `type="${opts.type}" min="1"` : ''} ${opts.list ? `list="${opts.list}"` : ''} ${opts.ph ? `placeholder="${opts.ph}"` : ''}></div>`;
  openModal(id ? `EDIT // MED-${id}` : 'NEW MEDICINE', `
    <form id="med-form" onsubmit="submitMedForm(event, ${id})" class="grid grid-cols-1 sm:grid-cols-2 gap-4">
      ${f('brand_name', 'Brand name')}${f('generic_name', 'Generic name')}
      ${f('category_id', 'Category ID', { type: 'number' })}${f('manufacturer_id', 'Manufacturer ID', { type: 'number' })}
      ${f('dosage_form', 'Dosage form', { list: 'dl-form', ph: 'TABLET' })}${f('strength', 'Strength', { ph: '500 mg' })}
      ${f('administration_route', 'Route', { ph: 'ORAL' })}${f('prescription_classification', 'Classification', { list: 'dl-class', req: false, ph: 'PRESCRIPTION_ONLY' })}
      ${f('barcode_upc', 'Barcode (UPC)', { req: false })}${f('ndc_number', 'NDC number', { req: false })}
      ${id ? '<div class="sm:col-span-2 text-xs text-bioAmber font-mono">Re-enter category and manufacturer IDs — the API does not return them for editing.</div>' : ''}
      <datalist id="dl-form"><option>TABLET<option>CAPSULE<option>INJECTION<option>SYRUP<option>OINTMENT</datalist>
      <datalist id="dl-class"><option>PRESCRIPTION_ONLY<option>OVER_THE_COUNTER</datalist>
      <div id="mf-err" class="sm:col-span-2 hidden text-xs font-mono text-crimson-bright"></div>
    </form>`,
    `<button type="submit" form="med-form" class="btn-crimson px-4 py-1.5 text-xs font-display font-bold tracking-wider uppercase text-white rounded-sm">${id ? 'Save changes' : 'Add medicine'}</button>`);
}

async function submitMedForm(e, id) {
  e.preventDefault();
  const body = Object.fromEntries(new FormData(e.target).entries());
  body.category_id = num(body.category_id); body.manufacturer_id = num(body.manufacturer_id);
  const r = await api(id ? `/api/medicines/${id}` : '/api/medicines', { method: id ? 'PUT' : 'POST', body });
  if (!r.ok) return formErr('mf-err', r.status === 403 ? 'You do not have permission to edit the catalogue.' : r.msg);
  closeModal(); showToast(r.data.message); S.meds = null; renderPage();
}

/* Safety & interactions */
PAGES.safety = async () => {
  const meds = await loadMeds();
  const opts = (sel) => `<option value="">Select medicine…</option>` + meds.map(m => `<option value="${m.medicine_id}" ${String(sel) === String(m.medicine_id) ? 'selected' : ''}>#${m.medicine_id} — ${esc(m.brand_name)} (${esc(m.generic_name)})</option>`).join('');
  return `<div class="space-y-6">
    <div class="hud-card hud-brackets p-5 sm:p-6">
      <div class="mb-1">${heading('Medicine safety profile')}</div>
      <p class="text-sm text-steelGray mb-4">Side effects, contraindications, recalls and source references for one medicine.</p>
      <form onsubmit="runSafety(event)" class="flex flex-col sm:flex-row gap-3 max-w-3xl">
        <select id="safety-sel" class="field flex-1" required>${opts(S.safetyId)}</select>
        <button class="btn-crimson px-6 py-2.5 rounded-sm font-display font-bold tracking-wider uppercase text-sm text-white">Check safety</button></form></div>
    <div id="safety-out"></div>
    <div class="hud-card hud-brackets p-5 sm:p-6">
      <div class="mb-1">${heading('Interaction checker', 'bioAmber')}</div>
      <p class="text-sm text-steelGray mb-4">Compare two medicines against documented ingredient interactions.</p>
      <form onsubmit="runInteraction(event)" class="grid grid-cols-1 md:grid-cols-[1fr_1fr_auto] gap-3">
        <select id="int-a" class="field" required>${opts('')}</select><select id="int-b" class="field" required>${opts('')}</select>
        <button class="btn-crimson px-6 py-2.5 rounded-sm font-display font-bold tracking-wider uppercase text-sm text-white">Check</button></form>
      <div id="int-out" class="mt-5"></div></div></div>`;
};
AFTER.safety = () => { if (S.safetyId) loadSafety(S.safetyId); };
function runSafety(e) { e.preventDefault(); S.safetyId = $('safety-sel').value; loadSafety(S.safetyId); }

async function loadSafety(id) {
  const out = $('safety-out'); out.innerHTML = loading;
  const [s, refs, rec] = await Promise.all([api(`/api/medicines/${id}/safety`), api(`/api/medicines/${id}/references`), api(`/api/medicines/${id}/recalls`)]);
  if (!$('safety-out')) return;
  if (!s.ok) { out.innerHTML = note(s.msg, 'bad'); return; }
  const { medicine, side_effects: se, contraindications: ci } = s.data.data;
  const recalls = rec.ok ? rec.data.data : [];
  const active = recalls.filter(r => r.status === 'ACTIVE');
  out.innerHTML = `<div class="hud-card hud-brackets p-6 space-y-6">
    <div class="border-b border-borderSubtle pb-4"><div class="font-mono text-xs text-crimson-bright tracking-widest">SAFETY DOSSIER // ID #${medicine.medicine_id}</div>
      <h3 class="font-display text-2xl sm:text-3xl font-bold text-white mt-1">${esc(medicine.brand_name)}</h3></div>
    ${active.length ? note(`${active.length} active recall${active.length > 1 ? 's' : ''} affect this medicine: ${active.map(a => a.recall_reference_code).join(', ')}.`, 'bad') : ''}
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
      <div class="p-4 bg-obsidian/90 border border-borderSubtle rounded-sm"><div class="font-mono text-xs text-bioAmber uppercase tracking-wider mb-3">Side effects (${se.length})</div>
        ${se.length ? se.map(x => `<div class="py-2 border-b border-borderSubtle/60 last:border-0 text-sm"><div class="flex flex-wrap items-center gap-2">${esc(x.adverse_reaction)} ${badge(x.severity, sevTone(x.severity))} ${x.requires_medical_attention ? badge('SEEK CARE', 'bad') : ''}</div>
          ${x.frequency ? `<div class="font-mono text-[11px] text-steelGray mt-0.5">Frequency: ${esc(x.frequency)}</div>` : ''}</div>`).join('') : '<div class="text-xs text-steelGray">No side effects recorded.</div>'}</div>
      <div class="p-4 bg-obsidian/90 border border-borderSubtle rounded-sm"><div class="font-mono text-xs text-crimson-bright uppercase tracking-wider mb-3">Contraindications (${ci.length})</div>
        ${ci.length ? ci.map(x => `<div class="py-2 border-b border-borderSubtle/60 last:border-0 text-sm"><div class="flex flex-wrap items-center gap-2">${esc(x.condition_name)} ${badge(x.type, x.type === 'ABSOLUTE' ? 'bad' : 'warn')}</div>
          ${x.clinical_rationale ? `<div class="text-xs text-steelGray mt-1">${esc(x.clinical_rationale)}</div>` : ''}</div>`).join('') : '<div class="text-xs text-steelGray">No contraindications recorded.</div>'}</div></div>
    <div class="p-4 bg-obsidian/90 border border-borderSubtle rounded-sm"><div class="font-mono text-xs text-sky-400 uppercase tracking-wider mb-3">Source references</div>
      ${refs.ok && refs.data.data.length ? refs.data.data.map(x => `<div class="text-xs py-1.5">${x.url ? `<a href="${esc(x.url)}" target="_blank" rel="noopener noreferrer" class="text-sky-400 hover:underline">${esc(x.source_name)}</a>` : esc(x.source_name)}
        <span class="text-steelGray">— ${esc(x.publication_title || x.source_type || '')}</span> ${badge(x.verification_status || 'UNVERIFIED')}</div>`).join('') : '<div class="text-xs text-steelGray">No references on file.</div>'}</div></div>`;
}

async function runInteraction(e) {
  e.preventDefault();
  const a = $('int-a').value, b = $('int-b').value, out = $('int-out');
  if (a === b) { out.innerHTML = note('Choose two different medicines.', 'warn'); return; }
  out.innerHTML = loading;
  const r = await api(`/api/medicines/${a}/interactions/${b}`);
  if (!r.ok) { out.innerHTML = note(r.msg, 'bad'); return; }
  const list = r.data.data;
  out.innerHTML = !list.length ? note(r.data.message, 'ok') : list.map(i => `
    <div class="p-4 mb-3 bg-obsidian border border-borderSubtle rounded-sm text-sm space-y-1.5">
      <div class="flex flex-wrap items-center gap-2 font-semibold">${esc(i.ingredient_1)} ⇄ ${esc(i.ingredient_2)} ${badge(i.severity, sevTone(i.severity))}</div>
      ${i.clinical_effect ? `<div><span class="text-steelGray">Effect:</span> ${esc(i.clinical_effect)}</div>` : ''}
      ${i.mechanism ? `<div><span class="text-steelGray">Mechanism:</span> ${esc(i.mechanism)}</div>` : ''}
      ${i.management_advice ? `<div class="text-bioAmber"><span class="text-steelGray">Management:</span> ${esc(i.management_advice)}</div>` : ''}
      ${i.source_name ? `<div class="font-mono text-[11px] text-steelGray">Source: ${i.url ? `<a href="${esc(i.url)}" target="_blank" rel="noopener noreferrer" class="text-sky-400 hover:underline">${esc(i.source_name)}</a>` : esc(i.source_name)}</div>` : ''}
    </div>`).join('');
}

/* Recalls */
PAGES.recalls = async () => {
  const r = await api('/api/recalls' + (S.recallFilter !== 'ALL' ? `?status=${S.recallFilter}` : ''));
  if (!r.ok) return note(r.msg, 'bad');
  const rows = r.data.data, active = rows.filter(x => x.status === 'ACTIVE').length;
  return `<div class="space-y-6">
    ${active ? `<div class="hud-card p-5 border-crimson bg-crimson/[0.08] flex items-center gap-3.5">
      <div class="w-10 h-10 shrink-0 rounded-sm bg-crimson/20 border border-crimson flex items-center justify-center text-crimson-bright font-bold text-lg hazard-pulse">!</div>
      <div><div class="font-mono text-xs font-bold text-crimson-bright tracking-widest uppercase">${active} active recall${active > 1 ? 's' : ''}</div>
      <p class="text-sm mt-1">Quarantine affected batches immediately. Open a record to see the lots involved.</p></div></div>` : ''}
    <div class="hud-card hud-brackets p-5 sm:p-6 space-y-5">
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">${heading('Recall records')}
        <div class="flex flex-wrap gap-1.5 font-mono text-[11px]">${RECALL_FILTERS.map(f => `<button onclick="S.recallFilter='${f}';renderPage()" class="px-2.5 py-1 rounded-sm border ${S.recallFilter === f ? 'bg-crimson text-white border-crimson-bright font-bold' : 'bg-obsidian text-steelGray border-borderSubtle hover:text-white'}">${f}</button>`).join('')}</div></div>
      ${table(['Reference', 'Authority', 'Class', 'Status', 'Announced', 'Source'], rows.length ? rows.map(x => `
        <tr onclick="openRecall(${x.recall_id})" class="hover:bg-white/[0.03] cursor-pointer">
          <td class="py-4 px-3 font-mono font-bold">${esc(x.recall_reference_code)}</td><td class="py-4 px-3">${esc(x.issuing_authority)}</td>
          <td class="py-4 px-3 font-mono text-xs text-bioAmber">${esc(x.recall_class)}</td><td class="py-4 px-3">${badge(x.status)}</td>
          <td class="py-4 px-3 font-mono text-xs text-steelGray">${fmtDate(x.announcement_date)}</td><td class="py-4 px-3 text-xs text-steelGray">${esc(x.source_name || '—')}</td></tr>`).join('') : empty('No recall records for this filter.', 6))}</div></div>`;
};

async function openRecall(id) {
  openModal('RECALL FILE', loading);
  const r = await api(`/api/recalls/${id}`);
  if (!r.ok) { $('modal-body').innerHTML = note(r.msg, 'bad'); return; }
  const { recall: c, affected_medicines: am } = r.data.data;
  $('modal-code').textContent = c.recall_reference_code;
  $('modal-body').innerHTML = `
    <div class="flex flex-wrap items-center justify-between gap-3 border-b border-borderSubtle pb-4"><div>
      <div class="font-mono text-xs text-crimson-bright">${esc(c.issuing_authority)}</div><div class="font-mono text-bioAmber text-sm mt-1">${esc(c.recall_class)}</div></div>${badge(c.status)}</div>
    ${kv('Reason', esc(c.recall_reason))}${kv('Action required', esc(c.action_required))}
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">${kv('Announced', fmtDate(c.announcement_date))}
      ${kv('Source', c.reference_url ? `<a href="${esc(c.reference_url)}" target="_blank" rel="noopener noreferrer" class="text-sky-400 hover:underline">${esc(c.source_name || c.reference_url)}</a>` : esc(c.source_name))}</div>
    <div><div class="font-mono text-[10px] text-steelGray uppercase tracking-wider mb-2">Affected medicines (${am.length})</div>
      ${am.length ? am.map(x => `<div class="p-3 mb-2 bg-obsidian border border-borderSubtle rounded-sm text-xs flex flex-wrap justify-between gap-2">
        <div><span class="font-semibold text-sm">${esc(x.brand_name)}</span> <span class="text-steelGray">${esc(x.generic_name)}</span>
          ${x.affected_lot_description ? `<div class="text-steelGray mt-1">${esc(x.affected_lot_description)}</div>` : ''}</div>
        <div class="text-right font-mono">${x.batch_number ? `${esc(x.batch_number)}<div class="mt-1">${badge(x.batch_status)}</div>` : '<span class="text-steelGray">No batch linked</span>'}</div></div>`).join('') : '<div class="text-xs text-steelGray">No medicines linked.</div>'}</div>`;
}

/* Batches */
PAGES.batches = async () => {
  const days = S.expDays;
  const url = days ? `/api/batches/expiring?days=${encodeURIComponent(days)}` : '/api/batches' + (S.batchFilter !== 'ALL' ? `?status=${S.batchFilter}` : '');
  const [r, sum] = await Promise.all([api(url), api('/api/batches/summary')]);
  const sm = sum.ok ? sum.data.data : null;
  const stat = (l, v, c = '') => `<div class="hud-card p-4"><div class="font-mono text-[10px] text-steelGray uppercase tracking-wider">${l}</div><div class="font-display text-3xl font-bold mt-1 ${c}">${sm ? num(v) : '—'}</div></div>`;
  const rows = r.ok ? r.data.data : [];
  return `<div class="space-y-5">
    <div class="grid grid-cols-2 lg:grid-cols-5 gap-3">${sm ? stat('Total', sm.total_batches) + stat('Valid', sm.valid_batches, 'text-bioEmerald') + stat('Expiring 30d', sm.expiring_within_30_days, 'text-bioAmber') + stat('Recalled', sm.recalled_batches, 'text-crimson-bright') + stat('Quarantined', sm.quarantined_batches, 'text-bioAmber') : ''}</div>
    <div class="hud-card hud-brackets p-5 sm:p-6 space-y-5">
      <div class="flex flex-col lg:flex-row lg:items-center justify-between gap-4">${heading('Batch management')}
        <div class="flex flex-wrap items-center gap-1.5 font-mono text-[11px]">
          ${BATCH_FILTERS.map(f => `<button onclick="S.expDays='';S.batchFilter='${f}';renderPage()" class="px-2.5 py-1 rounded-sm border ${!days && S.batchFilter === f ? 'bg-crimson text-white border-crimson-bright font-bold' : 'bg-obsidian text-steelGray border-borderSubtle hover:text-white'}">${f.replace('_', ' ')}</button>`).join('')}
          <form onsubmit="event.preventDefault();S.expDays=$('exp-days').value;renderPage()" class="flex items-center gap-1.5 ml-1">
            <input id="exp-days" type="number" min="1" max="365" value="${esc(days)}" placeholder="days" class="field !w-20 !py-1 font-mono text-xs" aria-label="Expiring within days">
            <button class="btn-ghost px-2.5 py-1 rounded-sm ${days ? '!border-crimson !text-white' : ''}">EXPIRING ≤ DAYS</button></form></div></div>
      ${!r.ok ? note(r.msg, 'bad') : table(['ID', 'Medicine', 'Batch number', 'Expiry', 'Qty', 'Status', days ? 'Days left' : 'Date check'], rows.length ? rows.map(b => `
        <tr onclick="openBatch(${b.batch_id})" class="hover:bg-white/[0.03] cursor-pointer">
          <td class="py-3.5 px-3 font-mono text-xs text-steelGray">${b.batch_id}</td>
          <td class="py-3.5 px-3">${esc(b.brand_name)} <span class="text-steelGray text-xs">${esc(b.generic_name)}</span></td>
          <td class="py-3.5 px-3 font-mono font-semibold">${esc(b.batch_number)}</td><td class="py-3.5 px-3 font-mono text-xs text-steelGray">${fmtDate(b.expiry_date)}</td>
          <td class="py-3.5 px-3 font-mono text-xs">${esc(b.initial_quantity)}</td><td class="py-3.5 px-3">${badge(b.status)}</td>
          <td class="py-3.5 px-3 font-mono text-[11px] ${b.date_assessment === 'EXPIRED_BY_DATE' ? 'text-crimson-bright' : b.date_assessment === 'EXPIRING_WITHIN_30_DAYS' ? 'text-bioAmber' : 'text-steelGray'}">${days ? esc(b.days_until_expiry) : esc(String(b.date_assessment || '').replace(/_/g, ' '))}</td></tr>`).join('') : empty('No batches match this filter.', 7))}
    </div></div>`;
};

async function openBatch(id) {
  openModal('BATCH FILE', loading);
  const r = await api(`/api/batches/${id}`);
  if (!r.ok) { $('modal-body').innerHTML = note(r.msg, 'bad'); return; }
  const b = r.data.data, d = num(b.days_until_expiry);
  $('modal-code').textContent = b.batch_number;
  $('modal-body').innerHTML = `
    <div class="flex flex-wrap items-start justify-between gap-3 border-b border-borderSubtle pb-4"><div>
      <h2 class="font-display text-2xl font-bold text-white">${esc(b.brand_name)}</h2>
      <p class="text-sm text-steelGray">${esc(b.generic_name)} — ${esc(b.strength)} · ${esc(b.dosage_form)}</p></div>${badge(b.status)}</div>
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
      ${kv('Batch number', esc(b.batch_number), 'font-mono')}${kv('Initial quantity', esc(b.initial_quantity))}
      ${kv('Manufactured', fmtDate(b.manufacturing_date))}${kv('Expiry', fmtDate(b.expiry_date))}
      ${kv('Days until expiry', d < 0 ? `<span class="text-crimson-bright">Expired ${-d} days ago</span>` : d <= 30 ? `<span class="text-bioAmber">${d} days</span>` : `${d} days`)}${kv('Registered', fmtDT(b.created_at))}</div>`;
  $('modal-footer').insertAdjacentHTML('afterbegin', `<button onclick="closeModal(); openMedicine(${b.medicine_id})" class="btn-ghost px-3.5 py-1.5 text-xs font-mono rounded-sm">VIEW MEDICINE</button>`);
}

/* Admin */
PAGES.admin = async () => {
  const r = await api('/api/auth/admin/users');
  if (!r.ok) return note(r.status === 403 ? 'You need the USER_MANAGE permission to view this page.' : r.msg, 'bad');
  const users = r.data.users, pending = users.filter(u => u.account_status === 'PENDING').length;
  const btn = (u, st, label, cls) => `<button onclick="setUserStatus(${u.user_id}, '${st}')" class="font-mono text-xs hover:underline ${cls}">${label}</button>`;
  return `<div class="hud-card hud-brackets p-5 sm:p-6 space-y-5">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4"><div>${heading('Staff accounts')}
      <p class="text-sm text-steelGray mt-1">${pending ? `${pending} registration${pending > 1 ? 's' : ''} waiting for approval.` : 'No registrations waiting.'}</p></div>
      <button onclick="renderPage()" class="btn-crimson px-4 py-2 rounded-sm font-display font-bold text-xs tracking-widest uppercase text-white self-start">Refresh</button></div>
    ${table(['Name', 'Username', 'Email', 'Role', 'Status', 'Last login', '>Actions'], users.map(u => {
      const staff = STAFF_ROLES.includes(u.role), me = u.user_id === S.user.user_id;
      const acts = !staff || me ? '<span class="text-steelGray/50 font-mono text-xs">—</span>'
        : [u.account_status !== 'APPROVED' ? btn(u, 'APPROVED', 'Approve', 'text-bioEmerald') : '', u.account_status !== 'REJECTED' ? btn(u, 'REJECTED', u.account_status === 'APPROVED' ? 'Revoke' : 'Reject', 'text-sky-400 hover:text-crimson-bright') : ''].join(' <span class="text-steelGray/40">|</span> ');
      return `<tr class="hover:bg-white/[0.02]"><td class="py-3.5 px-3 font-medium">${esc(u.full_name)}</td><td class="py-3.5 px-3 font-mono text-xs text-steelGray">${esc(u.username)}</td>
        <td class="py-3.5 px-3 text-steelGray">${esc(u.email)}</td><td class="py-3.5 px-3">${badge(u.role, STATUS_TONE[u.role] || 'mute')}</td>
        <td class="py-3.5 px-3">${badge(u.account_status)}</td><td class="py-3.5 px-3 font-mono text-[11px] text-steelGray">${fmtDT(u.last_login_at)}</td>
        <td class="py-3.5 px-3 text-right whitespace-nowrap">${acts}</td></tr>`; }).join(''))}</div>`;
};
async function setUserStatus(id, status) {
  const r = await api(`/api/auth/admin/users/${id}/status`, { method: 'PATCH', body: { status } });
  showToast(r.ok ? r.data.message : r.msg, !r.ok); if (r.ok) renderPage();
}

/* Profile */
PAGES.profile = async () => {
  const r = await api('/api/auth/me'); if (r.ok) S.user = { ...S.user, ...r.data.user };
  const u = S.user;
  return `<div class="max-w-3xl hud-card hud-brackets p-6 sm:p-8">
    <div class="flex flex-col sm:flex-row sm:items-center gap-5 border-b border-borderSubtle pb-6">
      <div class="w-16 h-16 rounded-sm bg-crimson flex items-center justify-center font-display font-bold text-3xl text-white shadow-[0_0_20px_rgba(200,30,43,0.45)]">${esc((u.full_name || u.username)[0].toUpperCase())}</div>
      <div><div class="font-mono text-xs text-crimson-bright tracking-widest uppercase">${esc(u.role)}</div>
        <h2 class="font-display text-2xl sm:text-3xl font-bold text-white">${esc(u.full_name)}</h2><p class="font-mono text-xs text-steelGray mt-1">${esc(u.email)}</p></div></div>
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 mt-6">${kv('Username', esc(u.username), 'font-mono')}${kv('Role', badge(u.role))}
      ${kv('Account status', badge(u.account_status || 'APPROVED'))}${kv('User ID', '#' + esc(u.user_id), 'font-mono')}</div></div>`;
};

/* ---------- Boot ---------- */
window.addEventListener('DOMContentLoaded', async () => {
  const r = await api('/api/auth/me');
  if (r.ok && r.data.authenticated) { enterApp(r.data.user); checkHealth(); }
  else $('auth-view').classList.remove('hidden');
});
