// LVSP v1.3 Veterinary Drug Registration operational workspace UI.
// Six-section staff workspace over migration 000800. No new sidebar module.
// @ts-nocheck
const API = '/api/v1';
const TOKEN_KEY = 'lvsp_access_token';
let state = { profileId: null, reference: null, applications: [], current: null, me: null, tab: 'application' };
function esc(v) { return String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }
function fmtDate(v) { if (!v)
    return '—'; const s = String(v).slice(0, 10), p = s.split('-'); return p.length === 3 ? `${p[2]}/${p[1]}/${p[0]}` : s; }
function fmtDateTime(v) { if (!v)
    return '—'; try {
    return new Date(v).toLocaleString();
}
catch {
    return String(v);
} }
function shortId(v) { const s = String(v || ''); return s ? s.slice(0, 8) : '—'; }
function token() { return localStorage.getItem(TOKEN_KEY) || ''; }
async function opApi(path, opts = {}) {
    const h = { 'content-type': 'application/json', ...(opts.headers || {}) };
    if (token())
        h.authorization = 'Bearer ' + token();
    const r = await fetch(API + path, { ...opts, headers: h });
    let b = {};
    try {
        b = await r.json();
    }
    catch { }
    if (!r.ok)
        throw new Error(b?.error?.message || `HTTP ${r.status}`);
    return b;
}
function roles() { return state.me?.roles || []; }
function canReview() { return roles().some((r) => ['SYSTEM_ADMIN', 'SECURITY_ADMIN', 'TECHNICAL_REVIEWER', 'APPROVING_AUTHORITY'].includes(r)); }
function canApprove() { return roles().some((r) => ['SYSTEM_ADMIN', 'APPROVING_AUTHORITY'].includes(r)); }
function statusClass(v) { return 'vdo-status ' + String(v || '').toLowerCase().replaceAll('_', '-'); }
function toast(message, bad = false) { let x = document.querySelector('#vdo-toast'); if (!x) {
    x = document.createElement('div');
    x.id = 'vdo-toast';
    document.body.appendChild(x);
} x.textContent = message; x.className = bad ? 'bad' : 'ok'; x.style.display = 'block'; setTimeout(() => x.style.display = 'none', 3500); }
function ensureStyle() {
    if (document.querySelector('#vdo-style'))
        return;
    const st = document.createElement('style');
    st.id = 'vdo-style';
    st.textContent = `
#vdo-dialog{width:min(1240px,96vw);height:min(900px,94vh);padding:0;border:0;border-radius:18px;box-shadow:0 22px 80px #0005;background:#f6f8fb;color:#172033}
#vdo-dialog::backdrop{background:#0b1325aa;backdrop-filter:blur(3px)}
.vdo-shell{display:flex;flex-direction:column;height:100%}.vdo-head{background:#10233e;color:white;padding:16px 20px;display:flex;align-items:center;gap:14px}.vdo-head-main{min-width:0;flex:1}.vdo-head h2{margin:0;font-size:20px}.vdo-head small{opacity:.78}.vdo-head button,.vdo-toolbar button,.vdo-btn{border:1px solid #ccd5e0;border-radius:9px;padding:8px 12px;background:white;cursor:pointer;font:inherit}.vdo-head button{background:#ffffff18;color:white;border-color:#ffffff33}.vdo-btn.primary{background:#1769aa;color:white;border-color:#1769aa}.vdo-btn.warn{background:#fff4dd;border-color:#e5b35c}.vdo-btn.danger{background:#fff0f0;border-color:#e6a3a3;color:#a52626}.vdo-btn:disabled{opacity:.45;cursor:not-allowed}
.vdo-toolbar{padding:10px 16px;background:white;border-bottom:1px solid #dfe5ed;display:flex;gap:10px;align-items:center;flex-wrap:wrap}.vdo-toolbar select{min-width:280px;max-width:520px;padding:8px;border:1px solid #ccd5e0;border-radius:8px}.vdo-tabs{display:flex;gap:2px;overflow:auto;background:white;padding:0 12px;border-bottom:1px solid #dfe5ed}.vdo-tab{white-space:nowrap;border:0;background:transparent;padding:11px 14px;cursor:pointer;border-bottom:3px solid transparent}.vdo-tab.active{border-bottom-color:#1769aa;color:#1769aa;font-weight:700}.vdo-body{padding:16px;overflow:auto;flex:1}.vdo-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.vdo-grid.three{grid-template-columns:repeat(3,minmax(0,1fr))}.vdo-card{background:white;border:1px solid #dde4ed;border-radius:12px;padding:14px;box-shadow:0 1px 2px #00000008}.vdo-card h3,.vdo-card h4{margin:0 0 10px}.vdo-card.wide{grid-column:1/-1}.vdo-kv{display:grid;grid-template-columns:170px 1fr;gap:5px 12px;font-size:14px}.vdo-kv b{color:#5b6676;font-weight:600}.vdo-status{display:inline-block;border-radius:999px;padding:4px 9px;background:#eef2f6;font-size:12px;font-weight:700}.vdo-status.registered,.vdo-status.approved,.vdo-status.accepted,.vdo-status.pass{background:#e3f5e9;color:#176a38}.vdo-status.rejected,.vdo-status.fail,.vdo-status.cancelled{background:#fde7e7;color:#9a2424}.vdo-status.correction-requested,.vdo-status.needs-correction{background:#fff2d8;color:#8c5c00}.vdo-form{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.vdo-form .full{grid-column:1/-1}.vdo-form label{font-size:12px;color:#5c6877;display:flex;flex-direction:column;gap:4px}.vdo-form input,.vdo-form select,.vdo-form textarea{width:100%;box-sizing:border-box;border:1px solid #cdd6e1;border-radius:8px;padding:8px;font:inherit;background:white}.vdo-form textarea{min-height:70px;resize:vertical}.vdo-actions{display:flex;flex-wrap:wrap;gap:8px;margin-top:12px}.vdo-table-wrap{overflow:auto}.vdo-table{width:100%;border-collapse:collapse;font-size:13px}.vdo-table th,.vdo-table td{padding:8px;border-bottom:1px solid #e4e9ef;text-align:left;vertical-align:top}.vdo-table th{background:#f7f9fb;position:sticky;top:0}.vdo-note{padding:10px;border-radius:9px;background:#fff8e7;border:1px solid #ead39d;font-size:13px}.vdo-muted{color:#6d7785;font-size:13px}.vdo-empty{text-align:center;padding:42px 18px;color:#667386}.vdo-section-title{display:flex;justify-content:space-between;align-items:center;gap:10px;margin-bottom:10px}.vdo-pres{border-left:4px solid #9cb6cf}.vdo-history{font-size:12px}.vdo-pill-row{display:flex;gap:7px;flex-wrap:wrap}.vdo-code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12px}
#vdo-toast{display:none;position:fixed;z-index:100000;right:22px;bottom:22px;padding:11px 15px;border-radius:9px;color:white;box-shadow:0 4px 24px #0004}#vdo-toast.ok{background:#176a38}#vdo-toast.bad{background:#a62c2c}
@media(max-width:800px){.vdo-grid,.vdo-grid.three,.vdo-form{grid-template-columns:1fr}.vdo-kv{grid-template-columns:1fr}.vdo-toolbar select{min-width:180px}.vdo-card.wide,.vdo-form .full{grid-column:1}}
`;
    document.head.appendChild(st);
}
function dialog() { let d = document.querySelector('#vdo-dialog'); if (!d) {
    d = document.createElement('dialog');
    d.id = 'vdo-dialog';
    document.body.appendChild(d);
} return d; }
const tabDefs = [
    ['application', '1. ຄຳຮ້ອງ / Application'], ['parties', '2. ພາກສ່ວນ / Parties'], ['presentations', '3. ຂະໜາດ / Presentations'],
    ['dossier', '4. ເອກະສານ / Dossier'], ['review', '5. ກວດທົບ / Review'], ['decision', '6. ຕັດສິນ & ປະຫວັດ / Decision']
];
function shell() {
    const d = dialog();
    const p = state.reference?.profile || {};
    d.innerHTML = `<div class="vdo-shell"><div class="vdo-head"><div class="vdo-head-main"><h2>🗂 ແຟ້ມພິຈາລະນາຂຶ້ນທະບຽນຢາ</h2><small>${esc(p.tradeName || '')} ${p.registrationNo ? '· ' + esc(p.registrationNo) : ''} · Operational Dossier v1.3</small></div><button id="vdo-close">✕ ປິດ</button></div><div class="vdo-toolbar"><label>Application: <select id="vdo-app-select"></select></label><button id="vdo-new">＋ ຄຳຮ້ອງໃໝ່</button><button id="vdo-refresh">↻ Refresh</button><span id="vdo-current-status"></span></div><div class="vdo-tabs" id="vdo-tabs"></div><div class="vdo-body" id="vdo-body"></div></div>`;
    d.querySelector('#vdo-close').onclick = () => d.close();
    d.querySelector('#vdo-refresh').onclick = () => reloadCurrent();
    d.querySelector('#vdo-new').onclick = () => showCreate();
    renderSelector();
    renderTabs();
    renderBody();
}
function renderSelector() { const s = document.querySelector('#vdo-app-select'); if (!s)
    return; s.innerHTML = `<option value="">— Select operational application —</option>` + state.applications.map((a) => `<option value="${esc(a.applicationId)}" ${state.current?.application?.id === a.applicationId ? 'selected' : ''}>${esc(a.applicationNo || 'Draft ' + shortId(a.applicationId))} · ${esc(a.currentStatus)} · ${fmtDate(a.applicationDate)}</option>`).join(''); s.onchange = async () => { if (!s.value) {
    state.current = null;
    renderTabs();
    renderBody();
    return;
} await loadOne(s.value); }; const x = document.querySelector('#vdo-current-status'); if (x)
    x.innerHTML = state.current ? `<span class="${statusClass(state.current.application.currentStatus)}">${esc(state.current.application.currentStatus)}</span>` : ''; }
function renderTabs() { const t = document.querySelector('#vdo-tabs'); if (!t)
    return; t.innerHTML = tabDefs.map(([k, l]) => `<button class="vdo-tab ${state.tab === k ? 'active' : ''}" data-tab="${k}" ${!state.current ? 'disabled' : ''}>${l}</button>`).join(''); t.querySelectorAll('.vdo-tab').forEach((b) => b.onclick = () => { state.tab = b.dataset.tab; renderTabs(); renderBody(); }); }
function renderBody() { const b = document.querySelector('#vdo-body'); if (!b)
    return; if (!state.current) {
    b.innerHTML = emptyStart();
    bindCreateInline();
    return;
} if (state.tab === 'application')
    renderApplication(b);
else if (state.tab === 'parties')
    renderParties(b);
else if (state.tab === 'presentations')
    renderPresentations(b);
else if (state.tab === 'dossier')
    renderDossier(b);
else if (state.tab === 'review')
    renderReview(b);
else
    renderDecision(b); }
function emptyStart() { const p = state.reference?.profile || {}; return `<div class="vdo-grid"><div class="vdo-card wide"><h3>${esc(p.tradeName || 'Veterinary Drug')}</h3><div class="vdo-kv"><b>Generic name</b><span>${esc(p.genericName || '—')}</span><b>Current profile registration</b><span>${esc(p.registrationNo || '—')}</span><b>Product ID</b><span class="vdo-code">${esc(p.productId || '—')}</span><b>Operational applications</b><span>${state.applications.length}</span></div></div><div class="vdo-card wide"><h3>ເລີ່ມຄຳຮ້ອງ Operational Application</h3><p class="vdo-muted">000800 ສ້າງ lifecycle ແຍກຈາກ Product Registry. ຄຳຮ້ອງໃໝ່ຈະເຊື່ອມ profile ເກົ່າ ແລະ copy snapshot ຂອງ parties/packages ໂດຍບໍ່ແກ້ຂໍ້ມູນທະບຽນເກົ່າ.</p>${createFormHtml()}</div></div>`; }
function createFormHtml() { const today = new Date().toISOString().slice(0, 10); const rt = String(state.reference?.profile?.registrationType || 'IMPORT').toUpperCase(); return `<form id="vdo-create-form" class="vdo-form"><label>Application No. (optional)<input name="applicationNo" placeholder="ປ່ອຍວ່າງໄດ້"></label><label>Application Date<input type="date" name="applicationDate" value="${today}"></label><label>Application Kind<select name="applicationKind"><option>NEW</option><option>RENEWAL</option><option>VARIATION</option><option>TRANSFER</option><option>LEGACY_MIGRATION</option></select></label><label>Registration Type<select name="registrationType">${['IMPORT', 'DOMESTIC', 'REPACK'].map(x => `<option ${x === rt ? 'selected' : ''}>${x}</option>`).join('')}</select></label><label class="full"><span><input style="width:auto" type="checkbox" name="includeAllPresentations" checked> ນຳຂະໜາດບັນຈຸປັດຈຸບັນເຂົ້າຄຳຮ້ອງທັງໝົດ</span></label><label class="full">Notes<textarea name="notes"></textarea></label><div class="full"><button class="vdo-btn primary" type="submit">ສ້າງ Operational Application</button></div></form>`; }
function bindCreateInline() { const f = document.querySelector('#vdo-create-form'); if (!f)
    return; f.onsubmit = async (e) => { e.preventDefault(); try {
    const fd = new FormData(f);
    const body = { regulatoryProfileId: state.profileId, applicationNo: fd.get('applicationNo'), applicationDate: fd.get('applicationDate'), applicationKind: fd.get('applicationKind'), registrationType: fd.get('registrationType'), includeAllPresentations: !!fd.get('includeAllPresentations'), notes: fd.get('notes') };
    const r = await opApi('/veterinary-drug-applications', { method: 'POST', body: JSON.stringify(body) });
    state.current = r.data;
    await reloadList();
    state.tab = 'application';
    renderSelector();
    renderTabs();
    renderBody();
    toast('ສ້າງຄຳຮ້ອງແລ້ວ');
}
catch (e) {
    toast(e.message, true);
} }; }
function showCreate() { state.current = null; state.tab = 'application'; renderSelector(); renderTabs(); renderBody(); }
function renderApplication(b) {
    const d = state.current, a = d.application, w = d.workspace || {}, trans = d.allowedTransitions || [];
    b.innerHTML = `<div class="vdo-grid"><div class="vdo-card"><div class="vdo-section-title"><h3>Application Identity</h3><span class="${statusClass(a.currentStatus)}">${esc(a.currentStatus)}</span></div><div class="vdo-kv"><b>Application No.</b><span>${esc(a.applicationNo || 'Draft ' + shortId(a.id))}</span><b>Application Date</b><span>${fmtDate(a.applicationDate)}</span><b>Kind</b><span>${esc(a.applicationKind)}</span><b>Registration Type</b><span>${esc(a.registrationType)}</span><b>Configuration</b><span>${esc(a.configurationStatus)}</span><b>Correction Round</b><span>${esc(a.correctionRound)}</span></div></div><div class="vdo-card"><h3>Product / Existing Profile</h3><div class="vdo-kv"><b>Trade name</b><span>${esc(w.tradeName || state.reference?.profile?.tradeName || '—')}</span><b>Generic name</b><span>${esc(w.genericName || state.reference?.profile?.genericName || '—')}</span><b>Profile Reg. No.</b><span>${esc(w.profileRegistrationNo || '—')}</span><b>DLF No.</b><span>${esc(w.dlfNo || '—')}</span><b>Issue → Expiry</b><span>${fmtDate(w.issueDate)} → ${fmtDate(w.expiryDate)}</span></div></div><div class="vdo-card wide"><h3>Lifecycle Commands</h3><div class="vdo-note">Status ປ່ຽນຜ່ານ <span class="vdo-code">transition_veterinary_drug_application()</span> ເທົ່ານັ້ນ. ປຸ່ມອະນຸມັດ/ປະຕິເສດ/REGISTER ຖືກຈຳກັດຕາມ role.</div><label style="display:block;margin-top:10px;font-size:12px;color:#5c6877">Comment / ໝາຍເຫດ<textarea id="vdo-transition-comment" style="width:100%;box-sizing:border-box;margin-top:4px;border:1px solid #cdd6e1;border-radius:8px;padding:8px;min-height:60px"></textarea></label><div class="vdo-actions">${trans.length ? trans.map((x) => transitionButton(x)).join('') : '<span class="vdo-muted">No command available from this status.</span>'}</div></div><div class="vdo-card wide"><h3>Timeline</h3><div class="vdo-grid three"><div><b>Submitted</b><br>${fmtDateTime(a.submittedAt)}</div><div><b>Screening</b><br>${fmtDateTime(a.screeningStartedAt)}</div><div><b>Technical review</b><br>${fmtDateTime(a.technicalReviewStartedAt)}</div><div><b>Recommended</b><br>${fmtDateTime(a.recommendedAt)}</div><div><b>Decided</b><br>${fmtDateTime(a.decidedAt)}</div><div><b>Registered</b><br>${fmtDateTime(a.registeredAt)}</div></div></div></div>`;
    b.querySelectorAll('.vdo-transition').forEach((btn) => btn.onclick = () => doTransition(btn.dataset.action));
}
function transitionButton(x) { const a = String(x.actionCode), high = ['APPROVE', 'REJECT', 'REGISTER'].includes(a), review = ['RETURN_TO_DRAFT', 'START_SCREENING', 'START_TECHNICAL_REVIEW', 'REQUEST_CORRECTION', 'RECOMMEND_APPROVAL', 'RECOMMEND_REJECTION'].includes(a); if (high && !canApprove())
    return ''; if (review && !canReview())
    return ''; const label = { SUBMIT: 'ສົ່ງຄຳຮ້ອງ / Submit', RETURN_TO_DRAFT: 'ສົ່ງຄືນ Draft', START_SCREENING: 'ເລີ່ມ Screening', REQUEST_CORRECTION: 'ຂໍແກ້ໄຂ', RESUBMIT: 'ສົ່ງຄືນ / Resubmit', START_TECHNICAL_REVIEW: 'ເລີ່ມ Technical Review', RECOMMEND_APPROVAL: 'ແນະນຳອະນຸມັດ', RECOMMEND_REJECTION: 'ແນະນຳປະຕິເສດ', APPROVE: '✅ APPROVE', REJECT: '⛔ REJECT', REGISTER: '🪪 REGISTER', CANCEL: 'Cancel' }; return `<button class="vdo-btn vdo-transition ${a === 'REJECT' || a === 'CANCEL' ? 'danger' : high ? 'primary' : ''}" data-action="${esc(a)}">${esc(label[a] || a)} → ${esc(x.toStatus)}</button>`; }
async function doTransition(action) { if (!confirm(`Execute ${action}?`))
    return; try {
    const comment = document.querySelector('#vdo-transition-comment')?.value || '';
    const r = await opApi(`/veterinary-drug-applications/${state.current.application.id}/transition`, { method: 'POST', body: JSON.stringify({ actionCode: action, comment }) });
    state.current = r.data;
    await reloadList();
    renderSelector();
    renderBody();
    toast(`${action} ສຳເລັດ`);
}
catch (e) {
    toast(e.message, true);
} }
function companyOptions(selected = '') { return `<option value="">— Snapshot / no Company Master —</option>` + (state.reference?.companies || []).map((c) => `<option value="${esc(c.partyId)}" ${String(selected) === String(c.partyId) ? 'selected' : ''}>${esc(c.legalNameLo || c.legalNameEn)}${c.enterpriseNo ? ' · ' + esc(c.enterpriseNo) : ''}</option>`).join(''); }
function siteOptions(companyId, selected = '') { return `<option value="">— No specific site —</option>` + (state.reference?.companySites || []).filter((s) => String(s.companyId) === String(companyId)).map((s) => `<option value="${esc(s.facilityId)}" ${String(selected) === String(s.facilityId) ? 'selected' : ''}>${esc(s.siteRoleCode)} · ${esc(s.facilityNameLo || s.facilityNameEn || '')} · ${esc(s.addressTextLo || s.addressTextEn || '')}</option>`).join(''); }
function renderParties(b) {
    const ps = state.current.parties || [];
    b.innerHTML = `<div class="vdo-grid"><div class="vdo-card wide"><div class="vdo-section-title"><h3>Parties & Regulatory Snapshots</h3><span class="vdo-muted">Company Master link + frozen snapshot text</span></div><div class="vdo-table-wrap"><table class="vdo-table"><thead><tr><th>Role</th><th>Company / Name snapshot</th><th>Site / Address snapshot</th><th>Status</th><th></th></tr></thead><tbody>${ps.length ? ps.map((p) => `<tr><td><b>${esc(p.roleCode)}</b>${p.isPrimary ? ' ⭐' : ''}</td><td>${esc(p.companyNameLo || p.companyNameEn || p.nameSnapshot || '—')}<br><small>${esc(p.nameSnapshot || '')}</small></td><td>${esc(p.facilityNameLo || p.facilityNameEn || '')}<br><small>${esc(p.addressSnapshot || p.facilityAddressLo || p.facilityAddressEn || '—')}</small></td><td><span class="${statusClass(p.status)}">${esc(p.status)}</span></td><td>${p.status === 'ACTIVE' ? `<button class="vdo-btn vdo-party-sup" data-id="${esc(p.id)}">Supersede</button>` : ''}</td></tr>`).join('') : '<tr><td colspan="5">No parties</td></tr>'}</tbody></table></div></div><div class="vdo-card wide"><h3>＋ Add / Replace Party</h3><form id="vdo-party-form" class="vdo-form"><label>Role<select name="roleCode"><option>APPLICANT</option><option>REGISTRATION_HOLDER</option><option>MAH</option><option>IMPORTER</option><option>MANUFACTURER</option><option>DISTRIBUTOR</option><option>AUTHORIZED_REPRESENTATIVE</option><option>OTHER</option></select></label><label>Company Master<select id="vdo-party-company" name="partyId">${companyOptions()}</select></label><label>Company Site<select id="vdo-party-site" name="facilityId"><option value="">— Select company first —</option></select></label><label>Country snapshot<input name="countrySnapshot"></label><label>Name snapshot<input id="vdo-party-name" name="nameSnapshot" placeholder="Required if no Company Master"></label><label>Address snapshot<input id="vdo-party-address" name="addressSnapshot"></label><label class="full">Contact snapshot<input name="contactSnapshot"></label><label><span><input style="width:auto" type="checkbox" name="isPrimary" checked> Primary role record</span></label><div class="full"><button class="vdo-btn primary">Save party snapshot</button></div></form></div></div>`;
    const company = b.querySelector('#vdo-party-company'), site = b.querySelector('#vdo-party-site'), name = b.querySelector('#vdo-party-name'), address = b.querySelector('#vdo-party-address');
    company.onchange = () => { site.innerHTML = siteOptions(company.value); const c = (state.reference.companies || []).find((x) => x.partyId === company.value); if (c && !name.value)
        name.value = c.legalNameLo || c.legalNameEn || ''; };
    site.onchange = () => { const s = (state.reference.companySites || []).find((x) => x.facilityId === site.value && x.companyId === company.value); if (s && !address.value)
        address.value = s.addressTextLo || s.addressTextEn || ''; };
    b.querySelector('#vdo-party-form').onsubmit = async (e) => { e.preventDefault(); const fd = new FormData(e.currentTarget); const o = Object.fromEntries(fd.entries()); o.isPrimary = !!fd.get('isPrimary'); try {
        const r = await opApi(`/veterinary-drug-applications/${state.current.application.id}/parties`, { method: 'POST', body: JSON.stringify(o) });
        state.current = r.data;
        renderBody();
        toast('Party saved');
    }
    catch (er) {
        toast(er.message, true);
    } };
    b.querySelectorAll('.vdo-party-sup').forEach((x) => x.onclick = async () => { if (!confirm('Supersede this party snapshot?'))
        return; try {
        const r = await opApi(`/veterinary-drug-applications/${state.current.application.id}/parties/${x.dataset.id}`, { method: 'PATCH', body: JSON.stringify({ status: 'SUPERSEDED' }) });
        state.current = r.data;
        renderBody();
    }
    catch (er) {
        toast(er.message, true);
    } });
}
function packageLabel(p) { return [p.subCode, p.packageCode, p.packDescription, p.packSize && p.unitCode ? `${p.packSize} ${p.unitCode}` : null].filter(Boolean).join(' · ') || shortId(p.id); }
function renderPresentations(b) {
    const ps = state.current.presentations || [], used = new Set(ps.map((x) => x.packageId)), available = (state.reference?.packages || []).filter((x) => !used.has(x.id));
    b.innerHTML = `<div class="vdo-grid">${ps.map((p) => `<div class="vdo-card vdo-pres"><div class="vdo-section-title"><h3>#${esc(p.sequenceNo)} ${esc(p.requestedSubCode || '')}</h3><span class="${statusClass(p.status)}">${esc(p.status)}</span></div><div class="vdo-kv"><b>Package</b><span>${esc(p.packageCode || '—')}</span><b>Description</b><span>${esc(p.packDescription || '—')}</span><b>Container</b><span>${esc(p.containerType || '—')}</span><b>Current size</b><span>${esc(p.packSize || '')} ${esc(p.unitCode || '')}</span></div><form class="vdo-form vdo-pres-form" data-id="${esc(p.id)}" style="margin-top:10px"><label>Sub code<input name="requestedSubCode" value="${esc(p.requestedSubCode || '')}"></label><label>Proposed Reg. Package No.<input name="proposedRegistrationPackageNo" value="${esc(p.proposedRegistrationPackageNo || '')}"></label><label>Status<select name="status">${['DRAFT', 'SUBMITTED', 'APPROVED', 'REGISTERED', 'SUPERSEDED', 'CANCELLED'].map(s => `<option ${s === p.status ? 'selected' : ''}>${s}</option>`).join('')}</select></label><label><span><input style="width:auto" type="checkbox" name="separateCertificate" ${p.separateCertificate ? 'checked' : ''}> Separate certificate</span><span><input style="width:auto" type="checkbox" name="separateQr" ${p.separateQr ? 'checked' : ''}> Separate QR</span></label><label class="full">Notes<textarea name="notes">${esc(p.notes || '')}</textarea></label><div class="full"><button class="vdo-btn">Save presentation</button></div></form></div>`).join('')}<div class="vdo-card wide"><h3>＋ Add Existing Product Package</h3>${available.length ? `<form id="vdo-pres-add" class="vdo-form"><label class="full">Package<select name="packageId">${available.map((p) => `<option value="${esc(p.id)}">${esc(packageLabel(p))}</option>`).join('')}</select></label><div class="full"><button class="vdo-btn primary">Add presentation</button></div></form>` : '<p class="vdo-muted">All active product packages are already included.</p>'}</div></div>`;
    b.querySelectorAll('.vdo-pres-form').forEach((f) => f.onsubmit = async (e) => { e.preventDefault(); const fd = new FormData(f); const o = Object.fromEntries(fd.entries()); o.separateCertificate = !!fd.get('separateCertificate'); o.separateQr = !!fd.get('separateQr'); try {
        const r = await opApi(`/veterinary-drug-applications/${state.current.application.id}/presentations/${f.dataset.id}`, { method: 'PATCH', body: JSON.stringify(o) });
        state.current = r.data;
        renderBody();
        toast('Presentation saved');
    }
    catch (er) {
        toast(er.message, true);
    } });
    const add = b.querySelector('#vdo-pres-add');
    if (add)
        add.onsubmit = async (e) => { e.preventDefault(); const o = Object.fromEntries(new FormData(add).entries()); try {
            const r = await opApi(`/veterinary-drug-applications/${state.current.application.id}/presentations`, { method: 'POST', body: JSON.stringify(o) });
            state.current = r.data;
            renderBody();
            toast('Presentation added');
        }
        catch (er) {
            toast(er.message, true);
        } };
}
function docOptions(selected = '') { return `<option value="">— Metadata only / no linked file —</option>` + (state.reference?.documents || []).map((d) => `<option value="${esc(d.id)}" ${String(selected) === String(d.id) ? 'selected' : ''}>${esc(d.documentType)} · ${esc(d.title || d.originalFilename || shortId(d.id))}</option>`).join(''); }
function renderDossier(b) {
    const ds = state.current.documents || [];
    const statuses = ['PENDING', 'RECEIVED', 'ACCEPTED', 'REJECTED', 'WAIVED', 'NOT_APPLICABLE'];
    b.innerHTML = `<div class="vdo-grid"><div class="vdo-card wide"><div class="vdo-section-title"><h3>Dossier Checklist / Evidence</h3><span class="vdo-muted">Mandatory status is configuration-driven; default = PENDING_LEGAL_VERIFICATION</span></div><div class="vdo-table-wrap"><table class="vdo-table"><thead><tr><th>Code / Label</th><th>Document</th><th>Required?</th><th>Verification</th><th>Notes</th><th></th></tr></thead><tbody>${ds.length ? ds.map((d) => `<tr><td><b>${esc(d.requirementCode)}</b><br>${esc(d.requirementLabel || '')}<br><small>${esc(d.requirementSource)}</small></td><td>${esc(d.documentTitle || d.originalFilename || '—')}</td><td>${d.isRequired ? 'Yes' : 'No'}</td><td><select class="vdo-doc-status" data-id="${esc(d.id)}" ${canReview() ? '' : 'disabled'}>${statuses.map(s => `<option ${s === d.verificationStatus ? 'selected' : ''}>${s}</option>`).join('')}</select></td><td>${esc(d.notes || '')}</td><td>${canReview() ? `<button class="vdo-btn vdo-doc-save" data-id="${esc(d.id)}">Save</button>` : ''}</td></tr>`).join('') : '<tr><td colspan="6">No dossier requirement rows yet.</td></tr>'}</tbody></table></div></div><div class="vdo-card wide"><h3>＋ Add Dossier Requirement / Evidence Link</h3><div class="vdo-note">Requirement ທີ່ເພີ່ມໃໝ່ບໍ່ຖືກອ້າງວ່າເປັນຂໍ້ບັງຄັບທາງກົດໝາຍ. ຖ້າຍັງບໍ່ກວດຢືນຢັນ ໃຫ້ຮັກສາ <b>PENDING_LEGAL_VERIFICATION</b>.</div><form id="vdo-doc-form" class="vdo-form" style="margin-top:10px"><label>Requirement Code<input name="requirementCode" required placeholder="e.g. CPP / GMP / COA / LABEL"></label><label>Label<input name="requirementLabel"></label><label class="full">Existing LVSP Document<select name="documentId">${docOptions()}</select></label><label><span><input style="width:auto" type="checkbox" name="isRequired"> Required (only if verified)</span></label><label>Requirement Source<input name="requirementSource" value="PENDING_LEGAL_VERIFICATION"></label><label class="full">Legal reference (optional)<input name="legalReference"></label><label class="full">Notes<textarea name="notes"></textarea></label><div class="full"><button class="vdo-btn primary">Add dossier row</button></div></form></div></div>`;
    b.querySelector('#vdo-doc-form').onsubmit = async (e) => { e.preventDefault(); const fd = new FormData(e.currentTarget), o = Object.fromEntries(fd.entries()); o.isRequired = !!fd.get('isRequired'); try {
        const r = await opApi(`/veterinary-drug-applications/${state.current.application.id}/documents`, { method: 'POST', body: JSON.stringify(o) });
        state.current = r.data;
        renderBody();
        toast('Dossier row added');
    }
    catch (er) {
        toast(er.message, true);
    } };
    b.querySelectorAll('.vdo-doc-save').forEach((x) => x.onclick = async () => { const sel = b.querySelector(`.vdo-doc-status[data-id="${x.dataset.id}"]`); try {
        const r = await opApi(`/veterinary-drug-applications/${state.current.application.id}/documents/${x.dataset.id}`, { method: 'PATCH', body: JSON.stringify({ verificationStatus: sel.value }) });
        state.current = r.data;
        renderBody();
        toast('Verification updated');
    }
    catch (er) {
        toast(er.message, true);
    } });
}
function renderReview(b) {
    const rs = state.current.reviews || [];
    b.innerHTML = `<div class="vdo-grid"><div class="vdo-card wide"><h3>Screening / Technical Review Records</h3><div class="vdo-table-wrap"><table class="vdo-table"><thead><tr><th>Type</th><th>Round</th><th>Outcome</th><th>Findings</th><th>Recommendation</th><th>Completed</th></tr></thead><tbody>${rs.length ? rs.map((r) => `<tr><td>${esc(r.reviewType)}</td><td>${esc(r.reviewRound)}</td><td><span class="${statusClass(r.outcome)}">${esc(r.outcome)}</span></td><td>${esc(r.findings || '—')}</td><td>${esc(r.recommendation || '—')}</td><td>${fmtDateTime(r.completedAt)}</td></tr>`).join('') : '<tr><td colspan="6">No review records.</td></tr>'}</tbody></table></div></div>${canReview() ? `<div class="vdo-card wide"><h3>＋ Record Review</h3><form id="vdo-review-form" class="vdo-form"><label>Review Type<select name="reviewType"><option>SCREENING</option><option>TECHNICAL</option><option>QUALITY</option><option>SAFETY</option><option>EFFICACY</option><option>LABEL</option><option>DOSSIER</option><option>FINAL</option></select></label><label>Outcome<select name="outcome"><option>PENDING</option><option>PASS</option><option>FAIL</option><option>NEEDS_CORRECTION</option><option>RECOMMEND_APPROVAL</option><option>RECOMMEND_REJECTION</option></select></label><label class="full">Findings<textarea name="findings"></textarea></label><label class="full">Recommendation<textarea name="recommendation"></textarea></label><label class="full">Internal notes<textarea name="internalNotes"></textarea></label><div class="full"><button class="vdo-btn primary">Save immutable review record</button></div></form></div>` : `<div class="vdo-card wide vdo-note">Your role is read-only for technical review records.</div>`}</div>`;
    const f = b.querySelector('#vdo-review-form');
    if (f)
        f.onsubmit = async (e) => { e.preventDefault(); const o = Object.fromEntries(new FormData(f).entries()); try {
            const r = await opApi(`/veterinary-drug-applications/${state.current.application.id}/reviews`, { method: 'POST', body: JSON.stringify(o) });
            state.current = r.data;
            renderBody();
            toast('Review record saved');
        }
        catch (er) {
            toast(er.message, true);
        } };
}
function renderDecision(b) {
    const d = state.current, link = d.registrationLink, prs = d.presentationRegistrations || [], certs = d.presentationCertificates || [], acts = d.actions || [];
    b.innerHTML = `<div class="vdo-grid"><div class="vdo-card"><h3>Official Registration Link</h3>${link ? `<div class="vdo-kv"><b>Registration No.</b><span>${esc(link.registrationNo)}</span><b>Status</b><span>${esc(link.registrationStatus)}</span><b>Issue / Expiry</b><span>${fmtDate(link.issueDate)} → ${fmtDate(link.expiryDate)}</span><b>Linked</b><span>${fmtDateTime(link.linkedAt)}</span></div>` : `<p class="vdo-muted">Not linked yet. Approval is not the same object as Registration.</p>`}${!link && canApprove() && state.current.application.currentStatus === 'APPROVED' ? `<form id="vdo-reg-link" class="vdo-form"><label class="full">Existing official registration for this product<select name="registrationId"><option value="">— Select —</option>${(state.reference?.registrations || []).map((r) => `<option value="${esc(r.id)}">${esc(r.registrationNo)} · ${esc(r.status)} · ${fmtDate(r.issueDate)}</option>`).join('')}</select></label><label class="full">Notes<input name="notes"></label><div class="full"><button class="vdo-btn primary">Link registration + active packages</button></div></form>` : ''}</div><div class="vdo-card"><h3>Presentation Registration Links</h3>${prs.length ? prs.map((x) => `<div style="margin:7px 0"><b>${esc(x.registrationPackageNo || x.registrationNo || 'Linked')}</b><br><small>${esc(x.packageId)}</small></div>`).join('') : '<p class="vdo-muted">No presentation registration links.</p>'}</div><div class="vdo-card wide"><h3>Certificates / QR</h3>${certs.length ? `<div class="vdo-table-wrap"><table class="vdo-table"><thead><tr><th>Presentation</th><th>Certificate No.</th><th>Status</th><th>Issued</th><th>Verification</th></tr></thead><tbody>${certs.map((c) => `<tr><td>#${esc(c.sequenceNo)}</td><td>${esc(c.certificateNo)}</td><td>${esc(c.certificateStatus)}</td><td>${fmtDateTime(c.issuedAt)}</td><td class="vdo-code">${esc(c.verificationToken || '—')}</td></tr>`).join('')}</tbody></table></div>` : '<div class="vdo-note">Certificate generation/QR issuance is intentionally separate from Application approval. This workspace is ready to link presentation-specific certificates when the certificate/QR phase is connected.</div>'}</div><div class="vdo-card wide"><h3>Immutable Action History</h3><div class="vdo-table-wrap"><table class="vdo-table vdo-history"><thead><tr><th>Time</th><th>Action</th><th>From → To</th><th>Actor</th><th>Comment</th></tr></thead><tbody>${acts.length ? acts.map((a) => `<tr><td>${fmtDateTime(a.performedAt)}</td><td><b>${esc(a.actionCode)}</b></td><td>${esc(a.fromStatus || '—')} → ${esc(a.toStatus || '—')}</td><td class="vdo-code">${esc(a.actorUserId || 'system/demo')}</td><td>${esc(a.comment || '')}</td></tr>`).join('') : '<tr><td colspan="5">No lifecycle actions yet.</td></tr>'}</tbody></table></div></div></div>`;
    const f = b.querySelector('#vdo-reg-link');
    if (f)
        f.onsubmit = async (e) => { e.preventDefault(); const o = Object.fromEntries(new FormData(f).entries()); if (!o.registrationId) {
            toast('Select an official registration', true);
            return;
        } if (!confirm('Link this official registration and active packages?'))
            return; try {
            const r = await opApi(`/veterinary-drug-applications/${state.current.application.id}/registration-link`, { method: 'POST', body: JSON.stringify(o) });
            state.current = r.data;
            renderBody();
            toast('Official registration linked');
        }
        catch (er) {
            toast(er.message, true);
        } };
}
async function reloadList() { const r = await opApi(`/veterinary-drug-applications?regulatoryProfileId=${encodeURIComponent(state.profileId)}`); state.applications = r.data || []; }
async function loadOne(id) { try {
    const r = await opApi(`/veterinary-drug-applications/${encodeURIComponent(id)}`);
    state.current = r.data;
    renderSelector();
    renderTabs();
    renderBody();
}
catch (e) {
    toast(e.message, true);
} }
async function reloadCurrent() { try {
    await reloadList();
    if (state.current?.application?.id)
        await loadOne(state.current.application.id);
    else {
        renderSelector();
        renderBody();
    }
    toast('Refreshed');
}
catch (e) {
    toast(e.message, true);
} }
export async function openVetDrugOperationalWorkspace(regulatoryProfileId, profileHint = {}) {
    ensureStyle();
    state = { profileId: regulatoryProfileId, reference: null, applications: [], current: null, me: null, tab: 'application' };
    const d = dialog();
    d.innerHTML = '<div class="vdo-empty">Loading operational dossier…</div>';
    d.showModal();
    try {
        const [ref, apps, me] = await Promise.all([opApi(`/veterinary-drug-applications/reference?regulatoryProfileId=${encodeURIComponent(regulatoryProfileId)}`), opApi(`/veterinary-drug-applications?regulatoryProfileId=${encodeURIComponent(regulatoryProfileId)}`), opApi('/auth/me').catch(() => ({ data: { roles: [] } }))]);
        state.reference = ref.data || { profile: profileHint };
        state.applications = apps.data || [];
        state.me = me.data || { roles: [] };
        if (!state.reference.profile)
            state.reference.profile = profileHint;
        if (state.applications.length) {
            const newest = state.applications[0];
            const one = await opApi(`/veterinary-drug-applications/${encodeURIComponent(newest.applicationId)}`);
            state.current = one.data;
        }
        shell();
    }
    catch (e) {
        d.innerHTML = `<div class="vdo-empty"><h3>Unable to open Operational Dossier</h3><p>${esc(e.message)}</p><button class="vdo-btn" id="vdo-fail-close">Close</button></div>`;
        d.querySelector('#vdo-fail-close').onclick = () => d.close();
    }
}
