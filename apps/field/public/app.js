const API = '/api/v1';
const tokenKey = 'lvsp_access_token';
const key = 'lvsp-field-queue-v1';
const form = document.querySelector('#field-form');
const queue = document.querySelector('#queue');
const syncBtn = document.querySelector('#sync-btn');
const state = document.querySelector('#network-state');
const authState = document.querySelector('#auth-state');
const installBtn = document.querySelector('#install-btn');
let installPrompt = null;
function token() { return localStorage.getItem(tokenKey) || ''; }
function drafts() { try {
    return JSON.parse(localStorage.getItem(key) || '[]');
}
catch {
    return [];
} }
function save(ds) { localStorage.setItem(key, JSON.stringify(ds)); render(); }
function esc(v) { return String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }
function parseGps(v) { const m = String(v || '').match(/^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/); if (!m)
    return { latitude: null, longitude: null }; return { latitude: Number(m[1]), longitude: Number(m[2]) }; }
function render() { const ds = drafts(); const pending = ds.filter(d => d.syncStatus !== 'SYNCED'); document.querySelector('#pending-count').textContent = String(pending.length); queue.innerHTML = ds.length ? ds.map(d => `<article class="${d.syncStatus.toLowerCase()}"><div class="row"><b>${esc(d.facility || 'No facility')}</b><span>${esc(d.syncStatus)}</span></div><p>${esc(d.finding)}</p><small>${esc(d.captureType)} · ${esc(d.gps || 'No GPS')} · ${new Date(d.createdAt).toLocaleString()}</small>${d.lastError ? `<em>${esc(d.lastError)}</em>` : ''}<button class="remove" data-id="${esc(d.id)}" type="button">Remove</button></article>`).join('') : '<p class="empty">No offline records</p>'; document.querySelectorAll('.remove').forEach(b => b.addEventListener('click', () => save(ds.filter(x => x.id !== b.dataset.id)))); }
function updateNetwork() { const on = navigator.onLine; state.textContent = on ? 'Online' : 'Offline'; state.className = on ? 'status online' : 'status offline'; syncBtn.disabled = !on; }
async function api(path, body) { const t = token(); if (!t)
    throw new Error('Please sign in to LVSP Staff first'); const r = await fetch(API + path, { method: 'POST', headers: { 'content-type': 'application/json', 'authorization': 'Bearer ' + t }, body: JSON.stringify(body) }); let data = {}; try {
    data = await r.json();
}
catch { } if (!r.ok)
    throw new Error(data?.error?.message || `HTTP ${r.status}`); return data; }
async function sync() { const ds = drafts(); const pending = ds.filter(d => d.syncStatus !== 'SYNCED'); if (!pending.length)
    return; syncBtn.disabled = true; syncBtn.textContent = 'Syncing…'; try {
    await api('/field-captures/sync', { items: pending.map(d => ({ localCaptureId: d.id, captureType: d.captureType, facility: d.facility, finding: d.finding, gps: d.gps, latitude: d.latitude, longitude: d.longitude, capturedAt: d.createdAt, payload: { finding: d.finding, gps: d.gps } })) });
    const ids = new Set(pending.map(x => x.id));
    save(ds.map(d => ids.has(d.id) ? { ...d, syncStatus: 'SYNCED', lastError: undefined } : d));
    document.querySelector('#message').textContent = `Synced ${pending.length} record(s) to LVSP staging queue.`;
}
catch (e) {
    const ids = new Set(pending.map(x => x.id));
    save(ds.map(d => ids.has(d.id) ? { ...d, syncStatus: 'ERROR', lastError: e.message } : d));
    document.querySelector('#message').textContent = e.message;
}
finally {
    syncBtn.textContent = 'Sync now';
    syncBtn.disabled = !navigator.onLine;
} }
form.addEventListener('submit', e => { e.preventDefault(); const fd = new FormData(form); const gps = String(fd.get('gps') || ''); const pos = parseGps(gps); const d = { id: crypto.randomUUID(), captureType: String(fd.get('captureType') || 'INSPECTION_NOTE'), facility: String(fd.get('facility') || ''), finding: String(fd.get('finding') || ''), gps, latitude: pos.latitude, longitude: pos.longitude, createdAt: new Date().toISOString(), syncStatus: 'PENDING' }; save([d, ...drafts()]); form.reset(); });
document.querySelector('#gps').onclick = () => navigator.geolocation?.getCurrentPosition(p => { document.querySelector('[name=gps]').value = `${p.coords.latitude.toFixed(6)},${p.coords.longitude.toFixed(6)}`; }, () => { document.querySelector('#message').textContent = 'GPS permission unavailable'; });
syncBtn.onclick = () => sync();
window.addEventListener('online', () => { updateNetwork(); if (token())
    sync().catch(() => { }); });
window.addEventListener('offline', updateNetwork);
window.addEventListener('beforeinstallprompt', (e) => { e.preventDefault(); installPrompt = e; installBtn.hidden = false; });
installBtn.onclick = async () => { if (installPrompt) {
    installPrompt.prompt();
    await installPrompt.userChoice;
    installPrompt = null;
    installBtn.hidden = true;
} };
if ('serviceWorker' in navigator)
    navigator.serviceWorker.register('/field/sw.js').catch(console.error);
authState.innerHTML = token() ? '<b>Signed in session detected</b> · sync is available' : '<b>Not signed in</b> · <a href="/" target="_blank">Open LVSP Staff and sign in first</a>';
updateNetwork();
render();
