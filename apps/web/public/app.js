import { renderDocumentIntake } from './document-intake.js';
import { renderDepartmentOperations } from './department-operations.js';
import { openVetDrugOperationalWorkspace } from './vet-drug-operational.js';
import { openRegistrationBatchMemo, renderRegistrationMemoCenter, openTradeCoordinationSheet, openRegulatoryReportBuilder, renderRegulatoryReportsPage, openImportPlanAnalyticsDashboard, openModuleReportForKey, moduleReportAvailable } from './legacy-parity.js';
import { renderDrugLegacyWorkspace, renderTradeLegacyWorkspace } from './legacy-workspaces-v16.js';
const API = '/api/v1';
const modules = [
    { key: 'guided_services', labelLo: 'ບໍລິການແບບມີຂັ້ນຕອນ', labelEn: 'Guided Services', path: '/guided-services', icon: '🧭', priority: true, fields: [] },
    { key: 'my_work', labelLo: 'ວຽກຂອງຂ້ອຍ', labelEn: 'My Work', path: '/my-work', icon: '✅', priority: true, fields: [] },
    { key: 'provincial_reporting', labelLo: 'ລາຍງານແຂວງ / ປະຈຳເດືອນ', labelEn: 'Provincial / Monthly Reporting', path: '/reporting/submissions', icon: '📊', priority: true, fields: [] },
    { key: 'department_operations', labelLo: 'ວຽກປະຈຳເດືອນ / ງົບປະມານ', labelEn: 'Monthly Work & Budget', path: '/department-operations', icon: '📅', priority: true, fields: [] },
    { key: 'admin_center', labelLo: 'ຈັດການລະບົບ', labelEn: 'Admin Center', path: '/admin/overview', icon: '⚙️', priority: true, fields: [] },
    { key: 'document_intake', labelLo: 'ຮັບເອກະສານ / ກວດຄຳຂໍ', labelEn: 'Dossier Intake & Review', path: '/document-intake', icon: '📄', priority: true, fields: [] },
    { key: 'drug_registrations', labelLo: 'ທະບຽນຢາສັດ', labelEn: 'Veterinary Drug Registration', path: '/drug-registrations', icon: '💊', priority: true, drill: true, fields: ['registrationNo', 'tradeName', 'genericName', 'category', 'registrationStatus', 'expiryDate'] },
    { key: 'trade_workspace', labelLo: 'ນຳເຂົ້າ · ສົ່ງອອກ · ສົ່ງຜ່ານ', labelEn: 'Import · Export · Transit', path: '/trade-workspace', icon: '🚚', priority: true, fields: [] },
    { key: 'regulatory_reports', labelLo: 'ສູນລາຍງານ', labelEn: 'Central Reports', path: '/legacy-parity/reports', icon: '📈', priority: true, fields: [] },
    { key: 'veterinary_devices', labelLo: 'ອຸປະກອນສັດຕະວະແພດ', labelEn: 'Veterinary Devices', path: '/veterinary-devices', icon: '🩺', priority: true, drill: true, navHidden: true, fields: ['deviceName', 'brand', 'model', 'deviceCategory', 'registrationNo', 'authorizationStatus'] },
    { key: 'import_plans', labelLo: 'ແຜນການຄ້າປະຈຳປີ', labelEn: 'Annual Trade Plans', path: '/import-plans', icon: '📅', priority: true, drill: true, navHidden: true, fields: ['planNo', 'planYear', 'applicationDate', 'approvalNo', 'status'] },
    { key: 'import_plan_items', labelLo: 'ລາຍການໃນແຜນນຳເຂົ້າ', labelEn: 'Annual Plan Items', path: '/import-plan-items', icon: '📦', priority: true, navHidden: true, fields: ['planId', 'itemNo', 'itemType', 'itemName', 'registrationNo', 'plannedQuantity', 'unitCode'] },
    { key: 'import_applications', labelLo: 'ຄຳຮ້ອງນຳເຂົ້າ', labelEn: 'Import Applications', path: '/import-applications', icon: '📝', priority: true, drill: true, navHidden: true, fields: ['applicationNo', 'applicationDate', 'borderCheckpoint', 'invoiceNo', 'permitNo', 'status'] },
    { key: 'import_application_items', labelLo: 'ລາຍການໃນຄຳຮ້ອງນຳເຂົ້າ', labelEn: 'Import Application Items', path: '/import-application-items', icon: '🚚', priority: true, navHidden: true, fields: ['applicationId', 'itemNo', 'itemType', 'itemName', 'registrationNo', 'requestedQuantity', 'unitCode', 'eligibilityStatus'] },
    { key: 'export_applications', labelLo: 'ຄຳຮ້ອງສົ່ງອອກ', labelEn: 'Export Applications', path: '/export-applications', icon: '📦', priority: true, drill: true, navHidden: true, fields: ['caseNo', 'destinationCountry', 'serviceType', 'status'] },
    { key: 'animuse', labelLo: 'ANIMUSE / AMR', labelEn: 'ANIMUSE / AMR', path: '/animuse/summary', icon: '📊', priority: true, navHidden: true, fields: [] },
    { key: 'companies', labelLo: 'ບໍລິສັດ / ຜູ້ປະກອບການ', labelEn: 'Companies & Operators', path: '/companies', icon: '🏢', drill: true, fields: ['legalNameLo', 'legalNameEn', 'enterpriseNo', 'phone', 'status'] },
    { key: 'products', labelLo: 'Product Master', labelEn: 'Product Master', path: '/products', icon: '🧬', fields: ['tradeName', 'genericName', 'productCode', 'lifecycleStatus'] },
    { key: 'inspections', labelLo: 'ການກວດກາ', labelEn: 'Inspections', path: '/inspections', icon: '🔎', fields: ['inspectionNo', 'triggerType', 'priority', 'status'] },
    { key: 'laboratory_samples', labelLo: 'ຫ້ອງວິໄຈ / ຕົວຢ່າງ', labelEn: 'Laboratory Samples', path: '/laboratory/samples', icon: '🧪', fields: ['sampleNo', 'sampleType', 'sampleStatus', 'receivedAt'] },
    { key: 'disease_cases', labelLo: 'ເຝົ້າລະວັງພະຍາດ', labelEn: 'Disease Cases', path: '/disease-cases', icon: '🦠', fields: ['caseNo', 'caseClassification', 'reportedAt', 'status'] },
    { key: 'trade_shipments', labelLo: 'ຂົນສົ່ງ / ຜ່ານດ່ານ', labelEn: 'Shipments & Border', path: '/trade/shipments', icon: '🚛', fields: ['shipmentNo', 'expectedArrivalAt', 'actualArrivalAt', 'status'] },
    { key: 'gis_layers', labelLo: 'ແຜນທີ່ GIS', labelEn: 'GIS Layers', path: '/gis/layers', icon: '🗺️', fields: ['layerCode', 'nameLo', 'sourceDomain', 'status'] }
];
let current = modules[0];
let temporaryWorkspaceReturnKey = null;
let lang = 'lo';
let editingDrugId = null;
let editingCompanyId = null;
let companySiteContext = null;
let companyRegistrationCompanyId = null;
let bulkFilePayload = null;
let publicBrowsing = false;
let activeServiceDraftId = null;
let pendingServiceCode = null;
let draftViewStepIndex = 0;
let currentUserRoles = [];
let currentUserMustChangePassword = false;
let adminTab = 'overview';
let reportingTab = 'inbox';
let reportingSelectedId = null;
let reportingConfigCache = null;
let platformPublicSettings = {};
let deferredInstallPrompt = null;
let waitingServiceWorker = null;
const $ = (s) => document.querySelector(s);
const tokenKey = 'lvsp_access_token';
function token() { return localStorage.getItem(tokenKey) || ''; }
function t(m) { return lang === 'lo' ? m.labelLo : m.labelEn; }
function val(o, k) { return o?.[k] ?? o?.[k.replace(/[A-Z]/g, m => '_' + m.toLowerCase())] ?? ''; }
function pretty(k) { return k.replace(/([A-Z])/g, ' $1').replaceAll('_', ' ').replace(/^./, x => x.toUpperCase()); }
function esc(v) { return String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }
function fmtDate(v) { if (!v)
    return '—'; const s = String(v).slice(0, 10); const p = s.split('-'); return p.length === 3 ? `${p[2]}/${p[1]}/${p[0]}` : s; }
function idOf(row) { return String(row.id || row.partyId || ''); }
async function api(path, opts = {}) {
    const h = { 'content-type': 'application/json', ...(opts.headers || {}) };
    if (token())
        h.authorization = 'Bearer ' + token();
    const res = await fetch(API + path, { ...opts, headers: h });
    const data = await res.json();
    if (res.status === 401 && path != '/auth/login') {
        showLogin();
        throw new Error(lang === 'lo' ? 'ກະລຸນາເຂົ້າລະບົບ' : 'Please sign in');
    }
    if (!res.ok)
        throw new Error(data?.error?.message || `HTTP ${res.status}`);
    return data;
}
async function apiPublic(path) { const res = await fetch(API + path, { headers: { 'content-type': 'application/json' } }); const data = await res.json(); if (!res.ok)
    throw new Error(data?.error?.message || `HTTP ${res.status}`); return data; }
function showCustomPage(show = true) { $('#data-panel').classList.toggle('hidden', show); $('#custom-page').classList.toggle('hidden', !show); $('#stats').classList.toggle('hidden', show); if (!show)
    $('#custom-page').innerHTML = ''; }
function authenticated() { return !!token(); }
function isAdminClient() { return currentUserRoles.some(r => ['SYSTEM_ADMIN', 'SECURITY_ADMIN'].includes(r)); }
function canReviewReportingClient() { return currentUserRoles.some(r => ['SYSTEM_ADMIN', 'SECURITY_ADMIN', 'TECHNICAL_REVIEWER', 'MANAGEMENT_VIEWER'].includes(r)); }
function featureEnabled(code, def = true) { return platformPublicSettings[code] === undefined ? def : platformPublicSettings[code] !== false; }
function moduleByKey(key) { return modules.find(x => x.key === key) || null; }
function applyRequestedModule() {
    const requested = new URLSearchParams(location.search).get('module');
    const module = requested ? moduleByKey(requested) : null;
    if (module && (module.key !== 'admin_center' || isAdminClient()))
        current = module;
}
function restoreTemporaryWorkspace(reload = false) { if (!temporaryWorkspaceReturnKey)
    return; const m = moduleByKey(temporaryWorkspaceReturnKey); temporaryWorkspaceReturnKey = null; if (m) {
    current = m;
    renderNav();
    if (reload)
        loadModule();
} }
async function openWorkspaceCreate(moduleKey) { const m = moduleByKey(moduleKey); if (!m)
    return toast('Workspace module not found', true); temporaryWorkspaceReturnKey = current.key; current = m; try {
    await openCreate();
}
catch (e) {
    restoreTemporaryWorkspace(false);
    toast(e.message, true);
} }
async function openWorkspaceBulk(kind) { const key = kind === 'plan' ? 'import_plans' : 'import_applications', m = moduleByKey(key); if (!m)
    return toast('Bulk module not found', true); temporaryWorkspaceReturnKey = current.key; current = m; try {
    await openBulk();
}
catch (e) {
    restoreTemporaryWorkspace(false);
    toast(e.message, true);
} }
function renderNav() {
    const visible = (!authenticated() && publicBrowsing)
        ? modules.filter(m => m.key === 'guided_services')
        : modules.filter(m => !m.navHidden && (m.key !== 'admin_center' || isAdminClient()));
    $('#nav').innerHTML = visible.map(m => `<button class="nav-item ${m.key === current.key ? 'active' : ''} ${m.priority ? 'priority' : ''}" data-key="${m.key}"><span>${m.icon}</span><span>${esc(t(m))}</span></button>`).join('');
    $('#logout-btn').textContent = authenticated() ? 'Logout' : 'Login';
    document.querySelectorAll('.nav-item').forEach(el => el.addEventListener('click', () => { current = modules.find(x => x.key === el.dataset.key); renderNav(); loadModule(); }));
}
async function loadStats() {
    try {
        const r = await api('/meta');
        const c = r.data.counts || {};
        const stats = [['ຄຳຂໍນຳເຂົ້າ', 'Import Apps', c.import_applications || 0, '📝'], ['ທະບຽນຢາ', 'Drug Reg.', c.drug_registrations || 0, '💊'], ['ອຸປະກອນ', 'Devices', c.veterinary_devices || 0, '🩺'], ['ແຜນປະຈຳປີ', 'Annual Plans', c.import_plans || 0, '📅'], ['ບໍລິສັດ', 'Companies', c.companies || 0, '🏢']];
        $('#stats').innerHTML = stats.map(x => `<div class="stat-card"><div class="stat-icon">${x[3]}</div><div><strong>${x[2]}</strong><span>${lang === 'lo' ? x[0] : x[1]}</span></div></div>`).join('');
        $('#storage-mode').textContent = `${r.data.storageMode || ''} / ${r.data.authMode || ''}`;
        const sl = $('#side-storage-label');
        if (sl)
            sl.textContent = r.data.storageMode === 'postgres' ? 'Neon PostgreSQL Staging' : 'Local Development Mode';
    }
    catch (e) {
        console.error(e);
    }
}
function renderRows(rows) {
    $('#record-count').textContent = `${rows.length} ${lang === 'lo' ? 'ລາຍການ' : 'records'}`;
    $('#table-head').innerHTML = '<tr>' + current.fields.map(f => `<th>${esc(pretty(f))}</th>`).join('') + '<th>ID</th></tr>';
    $('#table-body').innerHTML = rows.length ? rows.map((row) => `<tr class="${current.drill ? 'clickable-row' : ''}" data-id="${esc(idOf(row))}">` + current.fields.map(f => `<td>${esc(val(row, f))}</td>`).join('') + `<td><code>${esc(idOf(row).slice(0, 8))}</code></td></tr>`).join('') : `<tr><td colspan="${current.fields.length + 1}" class="empty">${lang === 'lo' ? 'ຍັງບໍ່ມີຂໍ້ມູນ' : 'No records yet'}</td></tr>`;
    bindRowClicks();
}
function bindRowClicks() { if (!current.drill)
    return; document.querySelectorAll('#table-body tr[data-id]').forEach(tr => tr.addEventListener('click', () => openDetail(tr.dataset.id || ''))); }
async function loadAnimuse() {
    $('#page-title').textContent = 'ANIMUSE / AMR';
    $('#page-subtitle').textContent = lang === 'lo' ? 'ສະຫຼຸບການນຳເຂົ້າ ແລະ ກຸ່ມສານຕ້ານເຊື້ອ' : 'Import and antimicrobial summary';
    $('#record-count').textContent = 'ANIMUSE / AMR';
    $('#table-head').innerHTML = '<tr><th>Type / Kind</th><th>Items</th><th>Cleared Qty</th><th>Value USD</th><th>Gross kg</th></tr>';
    try {
        const r = await api('/animuse/summary');
        const rows = r.data.importSummary || [];
        $('#table-body').innerHTML = rows.length ? rows.map((x) => `<tr><td>${esc(x.kind)}</td><td>${esc(x.itemCount)}</td><td>${esc(x.clearedQuantity)}</td><td>${esc(x.valueUsd)}</td><td>${esc(x.grossWeightKg)}</td></tr>`).join('') : '<tr><td colspan="5" class="empty">No import summary</td></tr>';
    }
    catch (e) {
        $('#table-body').innerHTML = `<tr><td colspan="5" class="error">${esc(e.message)}</td></tr>`;
    }
}
async function loadModule() {
    if (current.key === 'guided_services') {
        showCustomPage(true);
        return renderGuidedServices();
    }
    if (current.key === 'my_work') {
        showCustomPage(true);
        return renderMyWork();
    }
    if (current.key === 'document_intake') {
        $('#page-title').textContent = lang === 'lo' ? 'ຮັບເອກະສານ / ກວດຄຳຂໍ' : 'Dossier Intake & Review';
        $('#page-subtitle').textContent = '';
        showCustomPage(true);
        return renderDocumentIntake({ root: $('#custom-page'), api, lang, token });
    }
    if (current.key === 'department_operations') {
        $('#page-title').textContent = lang === 'lo' ? 'ວຽກປະຈຳເດືອນ / ງົບປະມານ' : 'Monthly Work & Budget';
        $('#page-subtitle').textContent = lang === 'lo' ? 'ແຜນວຽກ, ຜົນປະຕິບັດ ແລະ ງົບປະມານພາຍໃນພະແນກ' : 'Department plans, results and budget';
        showCustomPage(true);
        return renderDepartmentOperations({ root: $('#custom-page'), api, lang });
    }
    if (current.key === 'provincial_reporting') {
        showCustomPage(true);
        return renderProvincialReporting();
    }
    if (current.key === 'admin_center') {
        showCustomPage(true);
        return renderAdminCenter(adminTab);
    }
    if (current.key === 'drug_registrations') {
        showCustomPage(true);
        return renderDrugLegacyWorkspace({ root: $('#custom-page'), lang, api, openDrug: (id) => openDrugDetail(id), createDrug: () => { editingDrugId = null; openCreate(); }, openDossier: (id, h) => openVetDrugOperationalWorkspace(id, h || {}), openMemoCenter: () => renderRegistrationMemoCenter(), openReport: (source) => openRegulatoryReportBuilder(source, 'all') });
    }
    if (current.key === 'trade_workspace') {
        showCustomPage(true);
        return renderTradeLegacyWorkspace({ root: $('#custom-page'), lang, api, openPlan: (id) => openPlanDetail(id), openApplication: (id) => openImportDetail(id), createPlan: () => openWorkspaceCreate('import_plans'), createApplication: () => openWorkspaceCreate('import_applications'), openBulk: (kind) => openWorkspaceBulk(kind), openReport: (source) => openRegulatoryReportBuilder(source, 'all') });
    }
    if (current.key === 'regulatory_reports') {
        showCustomPage(true);
        return renderRegulatoryReportsPage();
    }
    showCustomPage(false);
    configureBulkToolbar();
    if (current.key === 'animuse')
        return loadAnimuse();
    $('#page-title').textContent = t(current);
    $('#page-subtitle').textContent = current.priority ? (lang === 'lo' ? 'Priority Veterinary Products • ຂໍ້ມູນຈາກ Neon PostgreSQL' : 'Priority Veterinary Products • Neon PostgreSQL') : (lang === 'lo' ? 'ຂໍ້ມູນຈາກ LVSP API' : 'Data from LVSP API');
    $('#table-body').innerHTML = `<tr><td colspan="${current.fields.length + 1}" class="empty">Loading…</td></tr>`;
    try {
        const r = await api(current.path);
        const rows = r.data || [];
        $('#record-count').textContent = `${r.meta?.total ?? rows.length} ${lang === 'lo' ? 'ລາຍການ' : 'records'}`;
        renderRows(rows);
    }
    catch (e) {
        $('#table-body').innerHTML = `<tr><td colspan="${current.fields.length + 1}" class="error">${esc(e.message)}</td></tr>`;
    }
}
function defaultReportingMonth() { const d = new Date(); d.setDate(1); d.setMonth(d.getMonth() - 1); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`; }
function reportingMonthParts() { const raw = document.querySelector('#reporting-month')?.value || defaultReportingMonth(); const [y, m] = raw.split('-').map(Number); return { year: y, month: m, value: raw }; }
function reportingSpeciesOptions() { return [['BUFFALO', 'ຄວາຍ / Buffalo'], ['CATTLE', 'ງົວ / Cattle'], ['PIG', 'ໝູ / Pig'], ['GOAT_SHEEP', 'ແກະ/ແບ້ / Sheep-Goat'], ['POULTRY', 'ສັດປີກ / Poultry'], ['DOG', 'ໝາ / Dog'], ['CAT', 'ແມວ / Cat'], ['HORSE', 'ມ້າ / Horse'], ['AQUATIC', 'ສັດນ້ຳ / Aquatic'], ['OTHER', 'ອື່ນໆ / Other']]; }
function reportStatusClass(s) { return 'rpt-status ' + String(s || '').toLowerCase().replaceAll('_', '-'); }
function reportingTabsHtml() { const tabs = [['inbox', '📥 ຮັບລາຍງານ / Inbox'], ['entry', '✍️ ບັນທຶກຂໍ້ມູນ / Data Entry'], ['summary', '📊 ສັງລວມເດືອນ / Monthly Summary']]; if (isAdminClient())
    tabs.push(['assignments', '👥 ແບ່ງວຽກ / Assignments']); return `<div class="reporting-tabs">${tabs.map(x => `<button class="reporting-tab ${reportingTab === x[0] ? 'active' : ''}" data-tab="${x[0]}">${x[1]}</button>`).join('')}</div>`; }
function bindReportingTabs() { document.querySelectorAll('.reporting-tab').forEach(b => b.addEventListener('click', () => { reportingTab = b.dataset.tab || 'inbox'; renderProvincialReporting(reportingTab); })); }
async function getReportingConfig() { if (reportingConfigCache)
    return reportingConfigCache; const r = await api('/reporting/config'); reportingConfigCache = r.data; return reportingConfigCache; }
function provinceOptions(rows) { return rows.map((p) => `<option value="${esc(p.provinceCode)}">${esc(lang === 'lo' ? p.nameLo : (p.nameEn || p.nameLo))} · ${esc(p.regionNameLo || p.regionCode || '')}</option>`).join(''); }
function reportingShell(title, body = '<div class="reporting-loading">Loading…</div>') { $('#page-title').textContent = lang === 'lo' ? 'ລາຍງານແຂວງ ແລະ ສັງລວມສະຖິຕິ' : 'Provincial Reporting & Consolidation'; $('#page-subtitle').textContent = lang === 'lo' ? 'ຮັບລາຍງານ → ບັນທຶກສະເພາະຕົວຊີ້ວັດ → ກວດຢືນຢັນ → ສັງລວມເດືອນ/ປີ' : 'Receive → enter required indicators → verify → consolidate monthly/annually'; $('#custom-page').innerHTML = `<div class="reporting-shell"><div class="reporting-hero"><div><span>PROVINCIAL VETERINARY REPORTING</span><h2>${esc(title)}</h2><p>${lang === 'lo' ? 'ໜຶ່ງ Module ດຽວສຳລັບບົດລາຍງານ Word/PDF/Scan/Excel ຈາກແຂວງ. ບັນທຶກພຽງຂໍ້ມູນທີ່ DVS ຕ້ອງການ.' : 'One module for provincial Word/PDF/Scan/Excel reports; capture only the indicators DVS needs.'}</p></div><label class="reporting-month"><span>${lang === 'lo' ? 'ເດືອນສັງລວມ' : 'Consolidation month'}</span><input id="reporting-month" type="month" value="${defaultReportingMonth()}"></label></div>${reportingTabsHtml()}<div id="reporting-content">${body}</div></div>`; bindReportingTabs(); const mi = document.querySelector('#reporting-month'); mi?.addEventListener('change', () => renderProvincialReporting(reportingTab)); }
async function renderProvincialReporting(tab = 'inbox') { if (!featureEnabled('REPORTING_MODULE_ENABLED', true)) {
    current = modules.find(x => x.key === 'my_work');
    renderNav();
    return loadModule();
} reportingTab = tab; reportingShell(lang === 'lo' ? 'ລະບົບຮັບລາຍງານ ແລະ ສັງລວມແຫ່ງຊາດ' : 'Provincial Reporting & National Consolidation'); try {
    if (tab === 'entry')
        await renderReportingEntry();
    else if (tab === 'summary')
        await renderReportingSummary();
    else if (tab === 'assignments')
        await renderReportingAssignments();
    else
        await renderReportingInbox();
}
catch (e) {
    $('#reporting-content').innerHTML = `<div class="error-card">${esc(e.message)}</div>`;
} }
async function renderReportingInbox() {
    const cfg = await getReportingConfig();
    const { year, month } = reportingMonthParts();
    const r = await api(`/reporting/dashboard?year=${year}&month=${month}`);
    const d = r.data || {}, s = d.summary || {}, rows = d.submissions || [];
    const missing = (s.provinceCoverage || []).filter((x) => Number(x.receivedCount || 0) === 0);
    $('#reporting-content').innerHTML = `<div class="reporting-kpis"><div><b>${esc(s.receivedProvinces || 0)}/${esc(s.totalProvinces || 0)}</b><span>${lang === 'lo' ? 'ແຂວງທີ່ສົ່ງ' : 'Provinces received'}</span></div><div><b>${esc(s.verifiedProvinces || 0)}</b><span>${lang === 'lo' ? 'ກວດຢືນຢັນແລ້ວ' : 'Verified'}</span></div><div><b>${esc(rows.length)}</b><span>${lang === 'lo' ? 'ບົດໃນເດືອນ' : 'Reports in month'}</span></div><div><b>${esc(missing.length)}</b><span>${lang === 'lo' ? 'ຍັງບໍ່ສົ່ງ' : 'Not received'}</span></div></div>
<div class="reporting-grid"><section class="reporting-card"><div class="rpt-card-head"><div><h3>+ ${lang === 'lo' ? 'ລົງທະບຽນບົດລາຍງານທີ່ໄດ້ຮັບ' : 'Register incoming report'}</h3><small>${lang === 'lo' ? 'Word / PDF / Scan / Excel — ເກັບຊື່/ເລກອ້າງອີງຂອງໄຟລ໌; binary attachment ຈະເຊື່ອມ object storage ໃນຂັ້ນ online.' : 'Word / PDF / Scan / Excel — record the source file/reference; binary attachments will use object storage at online deployment.'}</small></div></div><form id="reporting-new-form" class="reporting-form"><label><span>${lang === 'lo' ? 'ແຂວງ' : 'Province'}</span><select name="provinceCode" required><option value="">—</option>${provinceOptions(cfg.provinces || [])}</select></label><label><span>${lang === 'lo' ? 'ປະເພດລາຍງານ' : 'Report type'}</span><select name="reportType"><option value="WEEKLY">Weekly / ອາທິດ</option><option value="MONTHLY">Monthly / ເດືອນ</option><option value="QUARTERLY">Quarterly</option><option value="SEMI_ANNUAL">6 Months</option><option value="ANNUAL">Annual</option><option value="AD_HOC">Ad hoc</option></select></label><label><span>${lang === 'lo' ? 'ແຕ່ວັນທີ' : 'Period start'}</span><input name="periodStart" type="date" required></label><label><span>${lang === 'lo' ? 'ຫາວັນທີ' : 'Period end'}</span><input name="periodEnd" type="date" required></label><label><span>${lang === 'lo' ? 'ຊື່ໄຟລ໌ຕົ້ນສະບັບ' : 'Source filename'}</span><input name="sourceFilename" placeholder="Salavan_week4_July_2026.pdf"></label><label><span>${lang === 'lo' ? 'ຮັບຜ່ານ' : 'Received via'}</span><select name="sourceChannel"><option>DOCUMENT</option><option>EMAIL</option><option>PAPER</option><option>WHATSAPP</option><option>MESSAGING</option><option>DIRECT_ENTRY</option><option>OTHER</option></select></label><label class="span2"><span>${lang === 'lo' ? 'ເລກ/ລິ້ງ/ບ່ອນເກັບຕົ້ນສະບັບ' : 'Source reference / location'}</span><input name="sourceReference" placeholder="Incoming ref., Drive/OneDrive link, filing no. ..."></label><label class="span2"><span>${lang === 'lo' ? 'ໝາຍເຫດ' : 'Note'}</span><textarea name="summaryNote" rows="2"></textarea></label><label class="rpt-check span2"><input type="checkbox" name="includeInConsolidation" checked> ${lang === 'lo' ? 'ໃຫ້ລວມເຂົ້າການສັງລວມເມື່ອກວດຢືນຢັນ' : 'Include in consolidation once verified'}</label><div class="span2"><button class="primary" type="submit">${lang === 'lo' ? 'ຮັບບົດລາຍງານ' : 'Register report'}</button></div></form></section>
<section class="reporting-card"><h3>${lang === 'lo' ? 'ແຂວງທີ່ຍັງບໍ່ສົ່ງໃນເດືອນນີ້' : 'Not yet received this month'}</h3><div class="province-chips">${missing.map((x) => `<span>${esc(x.nameLo || x.nameEn)}</span>`).join('') || `<span class="ok-chip">${lang === 'lo' ? 'ຮັບຄົບຕາມຂອບເຂດ' : 'Complete for assigned scope'}</span>`}</div></section></div>
<section class="reporting-card"><div class="rpt-card-head"><h3>${lang === 'lo' ? 'ບົດລາຍງານທີ່ຮັບແລ້ວ' : 'Received reports'}</h3><small>${lang === 'lo' ? 'ກົດແຖວເພື່ອປ້ອນສະເພາະຂໍ້ມູນທີ່ຕ້ອງການ' : 'Click a row to enter only required data'}</small></div><div class="table-wrap"><table class="reporting-table"><thead><tr><th>Province</th><th>Period</th><th>Type</th><th>Source</th><th>Indicators</th><th>Trade</th><th>Status</th><th>Consolidate</th></tr></thead><tbody>${rows.map((x) => `<tr class="rpt-open" data-id="${esc(x.id)}"><td><b>${esc(x.provinceNameLo || x.provinceNameEn)}</b><small>${esc(x.regionNameLo || x.regionCode || '')}</small></td><td>${fmtDate(x.periodStart)} – ${fmtDate(x.periodEnd)}</td><td>${esc(x.reportType)}</td><td>${esc(x.sourceFilename || x.sourceReference || x.sourceChannel || '—')}</td><td>${esc(x.indicatorCount || 0)}</td><td>${esc(x.tradeCount || 0)}</td><td><span class="${reportStatusClass(x.status)}">${esc(x.status)}</span></td><td>${x.includeInConsolidation ? '✓' : '—'}</td></tr>`).join('') || `<tr><td colspan="8" class="empty">${lang === 'lo' ? 'ຍັງບໍ່ມີບົດລາຍງານ' : 'No reports registered'}</td></tr>`}</tbody></table></div></section>`;
    const form = document.querySelector('#reporting-new-form');
    const setMonthDates = () => { const { year, month } = reportingMonthParts(); const start = `${year}-${String(month).padStart(2, '0')}-01`; const end = `${year}-${String(month).padStart(2, '0')}-${String(new Date(year, month, 0).getDate()).padStart(2, '0')}`; form.elements.namedItem('periodStart').value = start; form.elements.namedItem('periodEnd').value = end; };
    setMonthDates();
    form.addEventListener('submit', async (ev) => { ev.preventDefault(); const fd = new FormData(form); const data = Object.fromEntries(fd.entries()); data.includeInConsolidation = form.elements.namedItem('includeInConsolidation').checked; try {
        const rr = await api('/reporting/submissions', { method: 'POST', body: JSON.stringify(data) });
        reportingSelectedId = rr.data.id;
        reportingTab = 'entry';
        toast(lang === 'lo' ? 'ລົງທະບຽນບົດລາຍງານແລ້ວ' : 'Report registered');
        renderProvincialReporting('entry');
    }
    catch (e) {
        toast(e.message, true);
    } });
    document.querySelectorAll('.rpt-open').forEach(tr => tr.addEventListener('click', () => { reportingSelectedId = tr.dataset.id || null; reportingTab = 'entry'; renderProvincialReporting('entry'); }));
}
function indicatorRowsHtml(rows) { return rows.map((x) => `<tr><td>${esc(x.sectionCode)}</td><td>${esc(x.metricNameLo || x.metricNameEn || x.metricCode)}</td><td>${esc(x.speciesCode)}</td><td><b>${esc(x.valueNumeric)}</b> ${esc(x.unitCode || '')}</td><td>${esc(x.sourceNote || '')}</td></tr>`).join('') || '<tr><td colspan="5" class="empty">No indicator values yet</td></tr>'; }
function tradeRowsHtml(rows) { return rows.map((x) => `<tr><td>${esc(x.movementType)}</td><td>${esc(x.commodityClass)}</td><td>${esc(x.itemName || x.speciesCode || '')}</td><td>${esc(x.checkpointIn || x.checkpointOut || '')}</td><td>${esc(x.quantity ?? '')} ${esc(x.unitCode || '')}</td><td>${esc(x.weightTon ?? '')}</td><td>${esc(x.valueAmount ?? '')} ${esc(x.currencyCode || '')}</td><td>${esc(x.originText || '')} → ${esc(x.destinationText || '')}</td></tr>`).join('') || '<tr><td colspan="8" class="empty">No trade statistics yet</td></tr>'; }
function reportingEntryActions(status) { const out = []; if (status === 'RECEIVED')
    out.push(`<button class="ghost rpt-status-action" data-status="DATA_ENTRY">Start data entry</button>`); if (status === 'DATA_ENTRY')
    out.push(`<button class="primary rpt-status-action" data-status="READY_FOR_REVIEW">${lang === 'lo' ? 'ສົ່ງກວດ' : 'Send for review'}</button>`); if (status === 'READY_FOR_REVIEW') {
    out.push(`<button class="ghost rpt-status-action" data-status="DATA_ENTRY">${lang === 'lo' ? 'ສົ່ງກັບແກ້' : 'Return to entry'}</button>`);
    if (canReviewReportingClient())
        out.push(`<button class="primary rpt-status-action" data-status="VERIFIED">✓ ${lang === 'lo' ? 'ກວດຢືນຢັນ' : 'Verify'}</button>`);
} if (status === 'VERIFIED' && isAdminClient())
    out.push(`<button class="ghost rpt-status-action" data-status="SUPERSEDED">${lang === 'lo' ? 'ເຮັດໃຫ້ສະບັບນີ້ເປັນເກົ່າ' : 'Supersede'}</button>`); return out.join(''); }
async function renderReportingEntry() {
    const cfg = await getReportingConfig();
    if (!reportingSelectedId) {
        const { year, month } = reportingMonthParts();
        const r = await api(`/reporting/submissions?year=${year}&month=${month}`);
        const rows = r.data || [];
        $('#reporting-content').innerHTML = `<section class="reporting-card"><h3>${lang === 'lo' ? 'ເລືອກບົດລາຍງານເພື່ອບັນທຶກ' : 'Choose a report for data entry'}</h3><div class="rpt-select-list">${rows.map((x) => `<button class="rpt-select" data-id="${esc(x.id)}"><b>${esc(x.provinceNameLo)}</b><span>${fmtDate(x.periodStart)} – ${fmtDate(x.periodEnd)} · ${esc(x.reportType)}</span><em class="${reportStatusClass(x.status)}">${esc(x.status)}</em></button>`).join('') || '<p>No reports for this month.</p>'}</div></section>`;
        document.querySelectorAll('.rpt-select').forEach(b => b.addEventListener('click', () => { reportingSelectedId = b.dataset.id || null; renderProvincialReporting('entry'); }));
        return;
    }
    const r = await api(`/reporting/submissions/${encodeURIComponent(reportingSelectedId)}`);
    const d = r.data, rep = d.report || {}, locked = rep.status === 'VERIFIED' || rep.status === 'SUPERSEDED';
    const species = reportingSpeciesOptions();
    $('#reporting-content').innerHTML = `<div class="rpt-entry-head"><button id="rpt-back" class="ghost">← Inbox</button><div><h3>${esc(rep.provinceNameLo || rep.provinceNameEn)} · ${esc(rep.reportType)}</h3><p>${fmtDate(rep.periodStart)} – ${fmtDate(rep.periodEnd)} · ${esc(rep.sourceFilename || rep.sourceReference || rep.sourceChannel || '')}</p></div><span class="${reportStatusClass(rep.status)}">${esc(rep.status)}</span><div class="rpt-head-actions">${reportingEntryActions(rep.status)}</div></div>
<div class="reporting-grid"><section class="reporting-card"><h3>1. ${lang === 'lo' ? 'ຕົວຊີ້ວັດສັດຕະວະແພດ' : 'Veterinary indicators'}</h3><p class="rpt-help">${lang === 'lo' ? 'ອີງຕາມ Excel ເກົ່າ: ສັກຢາ, ປິ່ນປົວ/ຕາຍ, ກວດກາຂ້າສັດ. ປ້ອນພຽງຕົວເລກທີ່ມີໃນບົດຕົ້ນສະບັບ.' : 'From the legacy Excel: vaccination, treatment/deaths, slaughter inspection. Enter only values supported by the source report.'}</p>${locked ? '' : `<form id="rpt-indicator-form" class="reporting-form compact"><label><span>Section</span><select name="section"><option value="VACCINATION">Vaccination / ສັກຢາ</option><option value="TREATMENT">Treatment / ປິ່ນປົວ</option><option value="SLAUGHTER_INSPECTION">Slaughter inspection / ກວດກາຂ້າສັດ</option></select></label><label><span>Species</span><select name="speciesCode">${species.map(x => `<option value="${x[0]}">${x[1]}</option>`).join('')}</select></label><div id="rpt-metric-fields" class="span2 metric-fields"></div><label class="span2"><span>Source note / ໝາຍເຫດ</span><input name="sourceNote" placeholder="Page/table/remark from source report"></label><div class="span2"><button class="primary" type="submit">Save indicators</button></div></form>`}<div class="table-wrap"><table class="reporting-table"><thead><tr><th>Section</th><th>Metric</th><th>Species</th><th>Value</th><th>Source note</th></tr></thead><tbody>${indicatorRowsHtml(d.indicators || [])}</tbody></table></div></section>
<section class="reporting-card"><h3>2. ${lang === 'lo' ? 'ນຳເຂົ້າ / ສົ່ງອອກ / ສົ່ງຜ່ານ' : 'Import / Export / Transit'}</h3><p class="rpt-help">${lang === 'lo' ? 'ຮອງຮັບຕາຕະລາງ Excel ສັດເປັນ, ໄຂ່, ຜະລິດຕະພັນສັດ, ຜົນພອຍໄດ້, ດ່ານ, ຕົ້ນທາງ-ປາຍທາງ.' : 'Covers legacy Excel live animals, eggs, animal products, by-products, checkpoints, origin/destination.'}</p>${locked ? '' : `<form id="rpt-trade-form" class="reporting-form compact"><label><span>Movement</span><select name="movementType"><option>IMPORT</option><option>EXPORT</option><option>TRANSIT</option><option>DOMESTIC_MOVEMENT</option></select></label><label><span>Class</span><select name="commodityClass"><option>LIVE_ANIMAL</option><option>ANIMAL_PRODUCT</option><option>EGG</option><option>ANIMAL_BYPRODUCT</option><option>AQUATIC_ANIMAL</option><option>OTHER</option></select></label><label><span>Purpose</span><select name="purposeCode"><option value="">—</option><option>CONSUMPTION</option><option>BREEDING</option><option>OTHER</option></select></label><label><span>Species</span><select name="speciesCode"><option value="">—</option>${species.map(x => `<option value="${x[0]}">${x[1]}</option>`).join('')}</select></label><label class="span2"><span>Item / Product</span><input name="itemName"></label><label><span>Checkpoint in</span><input name="checkpointIn"></label><label><span>Checkpoint out</span><input name="checkpointOut"></label><label><span>Origin</span><input name="originText"></label><label><span>Destination</span><input name="destinationText"></label><label><span>Quantity</span><input name="quantity" type="number" min="0" step="any"></label><label><span>Unit</span><input name="unitCode" placeholder="HEAD / TON / KG / EGG"></label><label><span>Weight (ton)</span><input name="weightTon" type="number" min="0" step="any"></label><label><span>Value</span><input name="valueAmount" type="number" min="0" step="any"></label><label><span>Currency</span><select name="currencyCode"><option>USD</option><option>LAK</option><option>THB</option><option>CNY</option><option>VND</option></select></label><label><span>Transport</span><input name="transportMode"></label><label class="span2"><span>Company / operator</span><input name="companyName"></label><div class="span2"><button class="primary" type="submit">Add trade row</button></div></form>`}<div class="table-wrap"><table class="reporting-table"><thead><tr><th>Move</th><th>Class</th><th>Item</th><th>Checkpoint</th><th>Qty</th><th>Ton</th><th>Value</th><th>Origin → Dest.</th></tr></thead><tbody>${tradeRowsHtml(d.tradeStats || [])}</tbody></table></div></section></div>
<section class="reporting-card"><h3>3. ${lang === 'lo' ? 'ກິດຈະກຳ / ບັນຫາ / ແຜນຕໍ່ໄປ' : 'Activities / issues / next-period plan'}</h3>${locked ? '' : `<form id="rpt-note-form" class="reporting-form compact"><label><span>Type</span><select name="noteType"><option>ACTIVITY</option><option>ISSUE</option><option>RISK</option><option>PLAN</option><option>OTHER</option></select></label><label><span>Category</span><input name="categoryCode" placeholder="DISEASE / INSPECTION / TRAINING ..."></label><label class="span2"><span>Description</span><textarea name="description" rows="3" required></textarea></label><label class="rpt-check span2"><input name="isNextPeriodPlan" type="checkbox"> ${lang === 'lo' ? 'ແຜນສຳລັບໄລຍະຕໍ່ໄປ' : 'Next-period plan'}</label><div class="span2"><button class="primary" type="submit">Add note</button></div></form>`}<div class="rpt-notes">${(d.notes || []).map((x) => `<article><b>${esc(x.noteType)} · ${esc(x.categoryCode || '')}</b><p>${esc(x.description)}</p>${x.isNextPeriodPlan ? '<em>Next period plan</em>' : ''}</article>`).join('') || '<p class="empty">No activity notes yet</p>'}</div></section>`;
    document.querySelector('#rpt-back')?.addEventListener('click', () => { reportingTab = 'inbox'; renderProvincialReporting('inbox'); });
    document.querySelectorAll('.rpt-status-action').forEach(b => b.addEventListener('click', async () => { try {
        await api(`/reporting/submissions/${encodeURIComponent(reportingSelectedId || '')}/status`, { method: 'POST', body: JSON.stringify({ status: b.dataset.status }) });
        toast('Status updated');
        renderProvincialReporting('entry');
    }
    catch (e) {
        toast(e.message, true);
    } }));
    const metricBox = document.querySelector('#rpt-metric-fields');
    const indForm = document.querySelector('#rpt-indicator-form');
    if (indForm && metricBox) {
        const draw = () => { const section = indForm.elements.namedItem('section').value; if (section === 'VACCINATION')
            metricBox.innerHTML = '<label><span>Population / ຝູງສັດ</span><input name="population" type="number" min="0" step="1"></label><label><span>Vaccinated / ສັກໄດ້</span><input name="vaccinated" type="number" min="0" step="1"></label>';
        else if (section === 'TREATMENT')
            metricBox.innerHTML = '<label><span>Treated / ປິ່ນປົວ</span><input name="treated" type="number" min="0" step="1"></label><label><span>Deaths / ຕາຍ</span><input name="deaths" type="number" min="0" step="1"></label>';
        else
            metricBox.innerHTML = '<label><span>Inspected / slaughtered</span><input name="inspected" type="number" min="0" step="1"></label>'; };
        draw();
        indForm.elements.namedItem('section').addEventListener('change', draw);
        indForm.addEventListener('submit', async (ev) => { ev.preventDefault(); const fd = new FormData(indForm); const section = String(fd.get('section')), speciesCode = String(fd.get('speciesCode')), sourceNote = String(fd.get('sourceNote') || ''); const rows = []; const push = (metricCode, key) => { const raw = fd.get(key); if (raw !== null && String(raw).trim() !== '')
            rows.push({ metricCode, speciesCode, valueNumeric: Number(raw), unitCode: 'HEAD', sourceNote }); }; if (section === 'VACCINATION') {
            push('VACCINATION.POPULATION', 'population');
            push('VACCINATION.VACCINATED', 'vaccinated');
        }
        else if (section === 'TREATMENT') {
            push('TREATMENT.TREATED', 'treated');
            push('TREATMENT.DEATHS', 'deaths');
        }
        else
            push('SLAUGHTER.INSPECTED', 'inspected'); if (!rows.length)
            return toast(lang === 'lo' ? 'ປ້ອນຢ່າງໜ້ອຍ 1 ຕົວເລກ' : 'Enter at least one value', true); try {
            await api(`/reporting/submissions/${encodeURIComponent(reportingSelectedId || '')}/indicators`, { method: 'POST', body: JSON.stringify({ rows }) });
            toast('Indicators saved');
            renderProvincialReporting('entry');
        }
        catch (e) {
            toast(e.message, true);
        } });
    }
    const tf = document.querySelector('#rpt-trade-form');
    tf?.addEventListener('submit', async (ev) => { ev.preventDefault(); const data = Object.fromEntries(new FormData(tf).entries()); try {
        await api(`/reporting/submissions/${encodeURIComponent(reportingSelectedId || '')}/trade-stats`, { method: 'POST', body: JSON.stringify(data) });
        toast('Trade row saved');
        renderProvincialReporting('entry');
    }
    catch (e) {
        toast(e.message, true);
    } });
    const nf = document.querySelector('#rpt-note-form');
    nf?.addEventListener('submit', async (ev) => { ev.preventDefault(); const data = Object.fromEntries(new FormData(nf).entries()); data.isNextPeriodPlan = nf.elements.namedItem('isNextPeriodPlan').checked; try {
        await api(`/reporting/submissions/${encodeURIComponent(reportingSelectedId || '')}/notes`, { method: 'POST', body: JSON.stringify(data) });
        toast('Note saved');
        renderProvincialReporting('entry');
    }
    catch (e) {
        toast(e.message, true);
    } });
}
async function renderReportingSummary() { const { year, month } = reportingMonthParts(); const r = await api(`/reporting/monthly-summary?year=${year}&month=${month}`); const s = r.data || {}; $('#reporting-content').innerHTML = `<div class="reporting-kpis"><div><b>${esc(s.receivedProvinces || 0)}/${esc(s.totalProvinces || 0)}</b><span>Received</span></div><div><b>${esc(s.verifiedProvinces || 0)}</b><span>Verified</span></div><div><b>${esc((s.indicators || []).length)}</b><span>Indicator groups</span></div><div><b>${esc((s.trade || []).length)}</b><span>Trade groups</span></div></div><div class="reporting-grid"><section class="reporting-card"><div class="rpt-card-head"><h3>${lang === 'lo' ? 'ຮ່າງບົດສະຫຼຸບອັດຕະໂນມັດ' : 'Automatic monthly draft'}</h3><div><button id="rpt-copy-summary" class="ghost">Copy</button><button id="rpt-print-summary" class="ghost">Print</button></div></div><textarea id="rpt-narrative" class="reporting-narrative">${esc(s.suggestedNarrativeLo || '')}</textarea><p class="rpt-help">${lang === 'lo' ? 'ນີ້ເປັນ Draft ຈາກຂໍ້ມູນ VERIFIED ເທົ່ານັ້ນ. ພະນັກງານຕ້ອງກວດ/ແກ້ກ່ອນສົ່ງເປັນທາງການ.' : 'Draft uses VERIFIED data only. Staff must review/edit before official submission.'}</p></section><section class="reporting-card"><h3>${lang === 'lo' ? 'ຄວາມຄົບຖ້ວນການລາຍງານ' : 'Reporting completeness'}</h3><div class="coverage-list">${(s.provinceCoverage || []).map((x) => `<div><span>${esc(x.nameLo || x.nameEn)}</span><b>${Number(x.receivedCount) > 0 ? '✓ Received' : '○ Missing'}</b><em>${Number(x.verifiedCount) > 0 ? 'VERIFIED ' + esc(x.consolidationSource || '') : 'Not verified'}</em></div>`).join('')}</div></section></div><section class="reporting-card"><h3>${lang === 'lo' ? 'ຕົວເລກສັງລວມສັດຕະວະແພດ' : 'Consolidated veterinary indicators'}</h3><div class="table-wrap"><table class="reporting-table"><thead><tr><th>Section</th><th>Metric</th><th>Species</th><th>Value</th><th>Unit</th></tr></thead><tbody>${(s.indicators || []).map((x) => `<tr><td>${esc(x.sectionCode)}</td><td>${esc(x.nameLo || x.nameEn || x.metricCode)}</td><td>${esc(x.speciesCode)}</td><td><b>${esc(x.valueNumeric)}</b></td><td>${esc(x.unitCode || '')}</td></tr>`).join('') || '<tr><td colspan="5" class="empty">No verified indicator data yet</td></tr>'}</tbody></table></div></section><section class="reporting-card"><h3>${lang === 'lo' ? 'ນຳເຂົ້າ / ສົ່ງອອກ / ສົ່ງຜ່ານ' : 'Trade consolidation'}</h3><div class="table-wrap"><table class="reporting-table"><thead><tr><th>Movement</th><th>Class</th><th>Rows</th><th>Quantity</th><th>Ton</th><th>Value</th></tr></thead><tbody>${(s.trade || []).map((x) => `<tr><td>${esc(x.movementType)}</td><td>${esc(x.commodityClass)}</td><td>${esc(x.rowCount)}</td><td>${esc(x.quantity)}</td><td>${esc(x.weightTon)}</td><td>${esc(x.valueAmount)} ${esc(x.currencyCode)}</td></tr>`).join('') || '<tr><td colspan="6" class="empty">No verified trade data yet</td></tr>'}</tbody></table></div></section>`; document.querySelector('#rpt-copy-summary')?.addEventListener('click', async () => { const text = document.querySelector('#rpt-narrative').value; try {
    await navigator.clipboard.writeText(text);
    toast('Copied');
}
catch {
    toast('Copy unavailable', true);
} }); document.querySelector('#rpt-print-summary')?.addEventListener('click', () => { const text = document.querySelector('#rpt-narrative').value; const indicatorRows = (s.indicators || []).map((x) => `<tr><td>${esc(x.nameLo || x.nameEn || x.metricCode)}</td><td>${esc(x.speciesCode)}</td><td>${esc(x.valueNumeric)} ${esc(x.unitCode || '')}</td></tr>`).join(''); setPrint(`<section class="print-page monthly-report-page"><h1>ບົດສະຫຼຸບຂໍ້ມູນສັດຕະວະແພດ ປະຈຳເດືອນ ${month}/${year}</h1><p>${esc(text).replaceAll('\n', '<br>')}</p><h2>ຕາຕະລາງສັງລວມ</h2><table class="permit-table"><thead><tr><th>ຕົວຊີ້ວັດ</th><th>ປະເພດສັດ</th><th>ຈຳນວນ</th></tr></thead><tbody>${indicatorRows || '<tr><td colspan="3">No verified data</td></tr>'}</tbody></table><p class="rpt-print-note">Draft generated from VERIFIED LVSP provincial reporting data. Review required before official issuance.</p></section>`); }); }
async function renderReportingAssignments() { if (!isAdminClient())
    return renderReportingInbox(); const cfg = await api('/reporting/config'); reportingConfigCache = cfg.data; const d = cfg.data || {}; $('#reporting-content').innerHTML = `<section class="reporting-card"><h3>${lang === 'lo' ? 'ແບ່ງພາກຮັບຜິດຊອບ' : 'Regional work allocation'}</h3><p class="rpt-help">${lang === 'lo' ? 'ການແບ່ງ ເໜືອ–ກາງ–ໃຕ້ ໃນໜ້ານີ້ເປັນການແບ່ງວຽກພາຍໃນ ປັບໄດ້ ແລະບໍ່ແທນຂໍ້ມູນເຂດປົກຄອງທາງການ.' : 'North/Central/South here is editable internal work allocation; it does not replace official administrative geography.'}</p><div class="region-cards">${(d.regions || []).map((rg) => { const provinces = (d.provinces || []).filter((p) => p.regionCode === rg.regionCode); const assigns = (d.assignments || []).filter((a) => a.regionCode === rg.regionCode); return `<article><h4>${esc(rg.nameLo || rg.nameEn)} <small>${esc(rg.regionCode)}</small></h4><div class="province-chips">${provinces.map((p) => `<span>${esc(p.nameLo)}</span>`).join('')}</div><div class="rpt-assign-list">${assigns.map((a) => `<div><b>${esc(a.staffSubject)}</b><span>${esc(a.assignmentRole)}</span></div>`).join('') || '<em>No staff assigned</em>'}</div><form class="rpt-assign-form" data-region="${esc(rg.regionCode)}"><input name="staffSubject" placeholder="username / user subject" required><select name="assignmentRole"><option>DATA_ENTRY</option><option>REVIEWER</option><option>MANAGER</option></select><button class="primary" type="submit">Assign</button></form></article>`; }).join('')}</div></section>`; document.querySelectorAll('.rpt-assign-form').forEach(f => f.addEventListener('submit', async (ev) => { ev.preventDefault(); const form = f; const data = Object.fromEntries(new FormData(form).entries()); try {
    await api(`/reporting/regions/${encodeURIComponent(form.dataset.region || '')}/assignment`, { method: 'PUT', body: JSON.stringify(data) });
    reportingConfigCache = null;
    toast('Assignment saved');
    renderProvincialReporting('assignments');
}
catch (e) {
    toast(e.message, true);
} })); }
function settingValue(x) { const v = x?.valueJson; return v === undefined || v === null ? '' : v; }
async function loadPublicSettings() {
    try {
        const r = await apiPublic('/public/platform-settings');
        const settings = r.data || [];
        platformPublicSettings = Object.fromEntries(settings.map((x) => [x.settingCode, settingValue(x)]));
        renderNav();
        const banner = settings.find((x) => x.settingCode === 'MAINTENANCE_BANNER');
        const text = String(settingValue(banner) || '').trim();
        const el = $('#maintenance-banner');
        if (el) {
            el.textContent = text;
            el.classList.toggle('hidden', !text);
        }
        const field = settings.find((x) => x.settingCode === 'FIELD_PWA_ENABLED');
        const link = $('#field-app-link');
        if (link && field)
            link.classList.toggle('hidden', settingValue(field) === false);
    }
    catch { }
}
function updateNetworkState() { const el = $('#network-state'); if (!el)
    return; const on = navigator.onLine; el.textContent = on ? (lang === 'lo' ? 'Online' : 'Online') : (lang === 'lo' ? 'Offline' : 'Offline'); el.classList.toggle('online', on); el.classList.toggle('offline', !on); }
function initPwa() {
    updateNetworkState();
    window.addEventListener('online', updateNetworkState);
    window.addEventListener('offline', updateNetworkState);
    window.addEventListener('beforeinstallprompt', (e) => { e.preventDefault(); deferredInstallPrompt = e; $('#install-btn')?.classList.remove('hidden'); });
    window.addEventListener('appinstalled', () => { $('#install-btn')?.classList.add('hidden'); deferredInstallPrompt = null; toast(lang === 'lo' ? 'ຕິດຕັ້ງ LVSP App ສຳເລັດ' : 'LVSP App installed'); });
    if ('serviceWorker' in navigator) {
        navigator.serviceWorker.register('/sw.js').then(reg => { if (reg.waiting) {
            waitingServiceWorker = reg.waiting;
            $('#update-btn')?.classList.remove('hidden');
        } reg.addEventListener('updatefound', () => { const w = reg.installing; if (!w)
            return; w.addEventListener('statechange', () => { if (w.state === 'installed' && navigator.serviceWorker.controller) {
            waitingServiceWorker = w;
            $('#update-btn')?.classList.remove('hidden');
        } }); }); }).catch(console.error);
    }
}
async function installPwa() { if (!deferredInstallPrompt) {
    toast(lang === 'lo' ? 'ໃຊ້ເມນູ Chrome/Edge → Install app ຖ້າປຸ່ມບໍ່ຂຶ້ນ' : 'Use Chrome/Edge menu → Install app if the prompt is unavailable');
    return;
} deferredInstallPrompt.prompt(); await deferredInstallPrompt.userChoice; deferredInstallPrompt = null; $('#install-btn')?.classList.add('hidden'); }
function applyPwaUpdate() { if (waitingServiceWorker) {
    waitingServiceWorker.postMessage({ type: 'SKIP_WAITING' });
    navigator.serviceWorker.addEventListener('controllerchange', () => location.reload(), { once: true });
}
else
    location.reload(); }
function adminTabsHtml() { const tabs = [['overview', 'Overview / ພາບລວມ'], ['services', 'Services'], ['modules', 'Modules / Roadmap'], ['users', 'Users & Roles'], ['access', 'National Access'], ['settings', 'Settings'], ['field', 'Field Sync'], ['audit', 'Audit']]; return `<div class="admin-tabs">${tabs.map(x => `<button class="admin-tab ${adminTab === x[0] ? 'active' : ''}" data-tab="${x[0]}">${x[1]}</button>`).join('')}</div>`; }
function bindAdminTabs() { document.querySelectorAll('.admin-tab').forEach(b => b.addEventListener('click', () => { adminTab = b.dataset.tab || 'overview'; renderAdminCenter(adminTab); })); }
async function renderAdminCenter(tab = 'overview') {
    if (!isAdminClient()) {
        current = modules.find(x => x.key === 'my_work');
        renderNav();
        return loadModule();
    }
    adminTab = tab;
    $('#page-title').textContent = lang === 'lo' ? 'ສູນຈັດການລະບົບ' : 'LVSP Admin Center';
    $('#page-subtitle').textContent = lang === 'lo' ? 'ຄຸ້ມຄອງ configuration ສູນກາງ — ບໍ່ເກັບ secret ໃນໜ້ານີ້' : 'Central non-secret configuration, users, services, PWA and audit';
    const root = $('#custom-page');
    root.innerHTML = `<div class="admin-shell"><div class="admin-hero"><div><span class="admin-kicker">CENTRAL ADMINISTRATION</span><h2>${lang === 'lo' ? 'ຄຸ້ມຄອງ LVSP ຈາກສູນກາງ' : 'Manage LVSP centrally'}</h2><p>${lang === 'lo' ? 'ປັບຄ່າທີ່ອະນຸຍາດ, ກວດ users/roles, services, field sync ແລະ audit. ການປ່ຽນ code/database ຍັງຜ່ານ deployment.' : 'Configure safe settings and review users, services, field sync and audit. Code/database changes still go through controlled deployment.'}</p></div><div class="admin-hero-actions"><button class="ghost" id="admin-install">⬇ Install Staff App</button><a class="ghost link-btn" href="/field/" target="_blank">📱 Open Field App</a></div></div>${adminTabsHtml()}<div id="admin-content" class="admin-card">Loading…</div></div>`;
    bindAdminTabs();
    $('#admin-install').onclick = () => installPwa();
    try {
        if (tab === 'overview')
            await renderAdminOverview();
        else if (tab === 'services')
            await renderAdminServices();
        else if (tab === 'modules')
            await renderAdminModules();
        else if (tab === 'users')
            await renderAdminUsers();
        else if (tab === 'access')
            await renderAdminAccess();
        else if (tab === 'settings')
            await renderAdminSettings();
        else if (tab === 'field')
            await renderAdminField();
        else
            await renderAdminAudit();
    }
    catch (e) {
        $('#admin-content').innerHTML = `<div class="error">${esc(e.message)}</div>`;
    }
}
async function renderAdminOverview() { const r = await api('/admin/overview'); const d = r.data || {}, c = d.counts || {}; $('#admin-content').innerHTML = `<h3>${lang === 'lo' ? 'ພາບລວມລະບົບ' : 'Platform overview'}</h3><div class="admin-stat-grid"><div class="admin-stat"><b>${esc(c.users || 0)}</b><span>Users</span></div><div class="admin-stat"><b>${esc(c.roles || 0)}</b><span>Roles</span></div><div class="admin-stat"><b>${esc(c.activeServices || 0)}</b><span>Active Services</span></div><div class="admin-stat"><b>${esc(c.workflows || 0)}</b><span>Workflows</span></div><div class="admin-stat"><b>${esc(c.openTasks || 0)}</b><span>Open Tasks</span></div><div class="admin-stat"><b>${esc(c.fieldCaptures || 0)}</b><span>Field Captures</span></div></div><div class="admin-pwa-box"><div><b>Release</b><code>${esc(d.releaseVersion || '')}</code><small> · ${esc(d.runtime?.mode || '')} / ${esc(d.authMode || '')}</small></div><div><b>${lang === 'lo' ? 'ການອັບເດດ' : 'Central updates'}</b><span>${lang === 'lo' ? 'ເມື່ອ deploy version ໃໝ່ ຜູ້ໃຊ້ Web/PWA ຈະຮັບ update ຈາກ server ສູນກາງ.' : 'New deployments are delivered centrally to Web/PWA users; no per-PC patching.'}</span></div></div><p class="admin-note">${lang === 'lo' ? 'ຂັ້ນ Production ຍັງຕ້ອງປ່ຽນ Local Auth ໄປ OIDC/SSO, HTTPS/domain, object storage, backup/security/UAT.' : 'Production still requires OIDC/SSO, HTTPS/domain, object storage and security/UAT gates.'}</p>`; }
async function renderAdminServices() { const r = await api('/admin/services'); const rows = r.data || []; $('#admin-content').innerHTML = `<h3>Digital Services (${rows.length})</h3><p class="admin-note">${lang === 'lo' ? 'Admin ປິດ/ເປີດ service ແລະ Public browse ໄດ້. ການແກ້ steps/requirements ແບບ Service Builder ຈະຕໍ່ຍອດຈາກຖານນີ້.' : 'Admins can activate services and public browsing. A fuller visual Service Builder can extend this foundation.'}</p><div class="detail-table-wrap"><table class="admin-table"><thead><tr><th>Service</th><th>Domain</th><th>Version</th><th>Guide</th><th>Active</th><th>Public</th><th>Public Guide</th></tr></thead><tbody>${rows.map((x) => `<tr><td class="admin-service-name"><b>${esc(lang === 'lo' ? (x.nameLo || x.nameEn) : (x.nameEn || x.nameLo))}</b><small>${esc(x.serviceCode)} · ${esc(x.launchModuleKey || '')}</small></td><td>${esc(x.domainCode)}</td><td>${esc(x.versionNo || '—')} ${esc(x.versionStatus || '')}</td><td>${esc(x.guideStatus || '—')}</td><td><input type="checkbox" class="admin-service-toggle" data-code="${esc(x.serviceCode)}" data-key="isActive" ${x.isActive ? 'checked' : ''}></td><td><input type="checkbox" class="admin-service-toggle" data-code="${esc(x.serviceCode)}" data-key="isPublic" ${x.isPublic ? 'checked' : ''}></td><td><input type="checkbox" class="admin-service-toggle" data-code="${esc(x.serviceCode)}" data-key="allowPublicBrowse" ${x.allowPublicBrowse ? 'checked' : ''}></td></tr>`).join('')}</tbody></table></div>`; document.querySelectorAll('.admin-service-toggle').forEach(el => el.addEventListener('change', async () => { const x = el; try {
    await api(`/admin/services/${encodeURIComponent(x.dataset.code || '')}`, { method: 'PATCH', body: JSON.stringify({ [x.dataset.key || '']: x.checked }) });
    toast(lang === 'lo' ? 'ອັບເດດ Service ແລ້ວ' : 'Service updated');
}
catch (e) {
    x.checked = !x.checked;
    toast(e.message, true);
} })); }
async function renderAdminModules() {
    const r = await api('/admin/modules');
    const rows = r.data || [];
    $('#admin-content').innerHTML = `<h3>${lang === 'lo' ? 'Modules ແລະ ແຜນພັດທະນາ' : 'Modules & Roadmap'} (${rows.length})</h3><p class="admin-note">${lang === 'lo' ? 'ລາຍການນີ້ເປັນສິ່ງທີ່ Public Homepage ຈະສະແດງ. ACTIVE = ໃຊ້ແລ້ວ, IN_DEVELOPMENT = ກຳລັງສ້າງ, PLANNED = ວາງແຜນ.' : 'This catalog drives the public platform roadmap. ACTIVE = available, IN_DEVELOPMENT = being built, PLANNED = roadmap.'}</p><div class="detail-table-wrap"><table class="admin-table"><thead><tr><th>Module</th><th>Status</th><th>Public</th><th>Login</th><th>Public data</th></tr></thead><tbody>${rows.map((x) => `<tr><td><b>${esc(lang === 'lo' ? (x.nameLo || x.nameEn) : (x.nameEn || x.nameLo))}</b><br><code>${esc(x.moduleCode)}</code></td><td><select class="admin-module-status" data-code="${esc(x.moduleCode)}"><option ${x.deliveryStatus === 'ACTIVE' ? 'selected' : ''}>ACTIVE</option><option ${x.deliveryStatus === 'IN_DEVELOPMENT' ? 'selected' : ''}>IN_DEVELOPMENT</option><option ${x.deliveryStatus === 'PLANNED' ? 'selected' : ''}>PLANNED</option><option ${x.deliveryStatus === 'PAUSED' ? 'selected' : ''}>PAUSED</option></select></td><td><input type="checkbox" class="admin-module-toggle" data-key="publicVisible" data-code="${esc(x.moduleCode)}" ${x.publicVisible ? 'checked' : ''}></td><td><input type="checkbox" class="admin-module-toggle" data-key="loginRequired" data-code="${esc(x.moduleCode)}" ${x.loginRequired ? 'checked' : ''}></td><td>${esc(x.publicDataMode || 'CATALOG_ONLY')}</td></tr>`).join('')}</tbody></table></div>`;
    const save = async (code, patch) => { try {
        await api(`/admin/modules/${encodeURIComponent(code)}`, { method: 'PATCH', body: JSON.stringify(patch) });
        toast(lang === 'lo' ? 'ອັບເດດ Module ແລ້ວ' : 'Module updated');
    }
    catch (e) {
        toast(e.message, true);
        await renderAdminModules();
    } };
    document.querySelectorAll('.admin-module-status').forEach(el => el.addEventListener('change', () => save(el.dataset.code || '', { deliveryStatus: el.value })));
    document.querySelectorAll('.admin-module-toggle').forEach(el => el.addEventListener('change', () => { const x = el; save(x.dataset.code || '', { [x.dataset.key || '']: x.checked }); }));
}
async function renderAdminUsers() {
    const [u, r] = await Promise.all([api('/admin/users'), api('/admin/roles')]);
    const users = u.data || [], roles = r.data || [];
    $('#admin-content').innerHTML = `<h3>${lang === 'lo' ? 'ຜູ້ໃຊ້ ແລະ Roles' : 'Users & Roles'}</h3><p class="admin-note">${lang === 'lo' ? 'ພະນັກງານພາຍໃນບໍ່ສະໝັກເອງ. Admin ສ້າງ account ແລະໃຫ້ Temporary Password; ຜູ້ໃຊ້ຕ້ອງປ່ຽນ password ຄັ້ງທຳອິດ.' : 'Internal staff accounts are provisioned by administrators with a temporary password that must be changed at first sign-in.'}</p>
 <div class="admin-setting-grid"><div class="admin-setting"><label>+ ${lang === 'lo' ? 'ສ້າງ Account ພະນັກງານ' : 'Create staff account'}</label><input id="new-user-name" placeholder="Username"><input id="new-user-email" placeholder="Email (optional)"><input id="new-user-password" type="password" minlength="12" placeholder="Temporary password (12+)"><select id="new-user-role"><option value="">${lang === 'lo' ? '-- ເລືອກ Role ຫຼືໄປກຳນົດທີ່ National Access --' : '-- Choose role or assign later in National Access --'}</option>${roles.map((x) => `<option value="${esc(x.code)}">${esc(x.code)} · ${esc(lang === 'lo' ? (x.nameLo || x.nameEn) : (x.nameEn || x.nameLo))}</option>`).join('')}</select><div class="admin-setting-foot"><button class="primary" id="create-staff-user">${lang === 'lo' ? 'ສ້າງ Account' : 'Create account'}</button></div></div></div>
 <div class="detail-table-wrap"><table class="admin-table"><thead><tr><th>User</th><th>Email</th><th>Status</th><th>Roles / Scope</th><th>Last login</th></tr></thead><tbody>${users.map((x) => `<tr><td><b>${esc(x.username || x.id)}</b><br><code>${esc(String(x.id || '').slice(0, 12))}</code></td><td>${esc(x.email || '—')}</td><td>${esc(x.status || '')}</td><td><div class="admin-role-chips">${(x.assignments || []).map((a) => `<span>${esc(a.roleCode || '')} · ${esc(a.scopeName || a.scopeType || 'GLOBAL/UNSCOPED')}</span>`).join('') || (x.roles || []).map((z) => `<span>${esc(z.code || z)}</span>`).join('') || '—'}</div></td><td>${fmtDate(x.lastLoginAt)}</td></tr>`).join('') || '<tr><td colspan="5">No users</td></tr>'}</tbody></table></div><h3 style="margin-top:18px">Role Catalog</h3><div class="admin-role-chips">${roles.map((x) => `<span><b>${esc(x.code)}</b> · ${esc(x.permissionCount || 0)} permissions</span>`).join('')}</div>`;
    $('#create-staff-user').addEventListener('click', async () => { const username = ($('#new-user-name').value || '').trim(), email = ($('#new-user-email').value || '').trim(), password = ($('#new-user-password').value || ''), role = ($('#new-user-role').value || ''); if (!username || password.length < 12)
        return toast(lang === 'lo' ? 'ກະລຸນາໃສ່ username ແລະ temporary password 12+ ຕົວ' : 'Username and 12+ character temporary password are required', true); try {
        await api('/admin/users', { method: 'POST', body: JSON.stringify({ username, email: email || null, password, mustChangePassword: true, roles: role ? [role] : [] }) });
        toast(lang === 'lo' ? 'ສ້າງ Account ແລ້ວ' : 'Account created');
        await renderAdminUsers();
    }
    catch (e) {
        toast(e.message, true);
    } });
}
async function renderAdminAccess() {
    const [f, u, r, m] = await Promise.all([api('/admin/access-foundation'), api('/admin/users'), api('/admin/roles'), api('/admin/access-matrix')]);
    const d = f.data || {}, users = u.data || [], roles = r.data || [], matrix = m.data || [], orgs = d.organizations || [], units = d.adminUnits || [], facilities = d.facilities || [], scopes = d.scopes || [];
    const unitLabel = (x) => `${x.unitTypeCode || ''} · ${lang === 'lo' ? (x.nameLo || x.nameEn) : (x.nameEn || x.nameLo)}`;
    $('#admin-content').innerHTML = `<h3>${lang === 'lo' ? 'ສິດເຂົ້າໃຊ້ລະດັບປະເທດ' : 'National Access Foundation'}</h3><p class="admin-note">User + Role + Organization + Province/District + Checkpoint. ${lang === 'lo' ? 'ການກຳນົດ scope ນີ້ເປັນຖານສຳລັບການບັງຄັບສິດລາຍ module ໃນຂັ້ນຕໍ່ໄປ.' : 'These scopes are the controlled foundation for module-by-module geographic enforcement.'}</p>
 <div class="admin-stat-grid"><div class="admin-stat"><b>${orgs.length}</b><span>Organizations</span></div><div class="admin-stat"><b>${units.length}</b><span>Admin Units</span></div><div class="admin-stat"><b>${facilities.length}</b><span>Facilities / Checkpoints</span></div><div class="admin-stat"><b>${scopes.length}</b><span>Access Scopes</span></div><div class="admin-stat"><b>${matrix.length}</b><span>Scoped Assignments</span></div></div>
 <div class="admin-setting-grid">
  <div class="admin-setting"><label>1. ${lang === 'lo' ? 'ສ້າງ Organization' : 'Create organization'}</label><input id="org-code" placeholder="Organization code"><select id="org-type"><option>CENTRAL</option><option>PROVINCE_OFFICE</option><option>DISTRICT_OFFICE</option><option>CHECKPOINT</option><option>OTHER</option></select><input id="org-name-lo" placeholder="ຊື່ພາສາລາວ"><input id="org-name-en" placeholder="English name"><select id="org-unit"><option value="">-- Admin unit (optional) --</option>${units.map((x) => `<option value="${esc(x.id)}">${esc(unitLabel(x))}</option>`).join('')}</select><select id="org-parent"><option value="">-- Parent organization (optional) --</option>${orgs.map((x) => `<option value="${esc(x.id)}">${esc(x.organizationCode || '')} · ${esc(lang === 'lo' ? (x.nameLo || x.nameEn) : (x.nameEn || x.nameLo))}</option>`).join('')}</select><div class="admin-setting-foot"><button class="primary" id="org-create">Create</button></div></div>
  <div class="admin-setting"><label>2. ${lang === 'lo' ? 'ສ້າງ Access Scope' : 'Create access scope'}</label><input id="scope-name" placeholder="Scope name, e.g. Vientiane Capital"><select id="scope-type"><option>GLOBAL</option><option>CENTRAL</option><option>PROVINCE</option><option>DISTRICT</option><option>CHECKPOINT</option><option>ORGANIZATION</option><option>DOMAIN</option><option>CUSTOM</option></select><select id="scope-unit"><option value="">-- Province/District admin unit --</option>${units.map((x) => `<option value="${esc(x.id)}">${esc(unitLabel(x))}</option>`).join('')}</select><select id="scope-org"><option value="">-- Organization --</option>${orgs.map((x) => `<option value="${esc(x.id)}">${esc(x.organizationCode || '')} · ${esc(lang === 'lo' ? (x.nameLo || x.nameEn) : (x.nameEn || x.nameLo))}</option>`).join('')}</select><select id="scope-facility"><option value="">-- Checkpoint / Facility --</option>${facilities.map((x) => `<option value="${esc(x.id)}">${esc(x.facilityNo || '')} · ${esc(lang === 'lo' ? (x.nameLo || x.nameEn) : (x.nameEn || x.nameLo))}</option>`).join('')}</select><input id="scope-domain" placeholder="Domain code (optional)"><div class="admin-setting-foot"><button class="primary" id="scope-create">Create</button></div></div>
  <div class="admin-setting"><label>3. ${lang === 'lo' ? 'ມອບ Role + Scope ໃຫ້ຜູ້ໃຊ້' : 'Assign Role + Scope'}</label><select id="assign-user">${users.map((x) => `<option value="${esc(x.id)}">${esc(x.username || x.id)}</option>`).join('')}</select><select id="assign-role">${roles.map((x) => `<option value="${esc(x.code)}">${esc(x.code)}</option>`).join('')}</select><select id="assign-scope"><option value="">GLOBAL / UNSCOPED</option>${scopes.map((x) => `<option value="${esc(x.id)}">${esc(x.scopeName || x.scopeType || x.id)} · ${esc(x.scopeType || '')}</option>`).join('')}</select><div class="admin-setting-foot"><button class="primary" id="assign-create">Assign</button></div></div>
 </div>
 <h3>${lang === 'lo' ? 'ຕາຕະລາງສິດປັດຈຸບັນ' : 'Current access matrix'}</h3><div class="detail-table-wrap"><table class="admin-table"><thead><tr><th>User</th><th>Role</th><th>Scope</th><th>Organization / Area / Checkpoint</th><th></th></tr></thead><tbody>${matrix.map((x) => `<tr><td><b>${esc(x.username || '')}</b></td><td>${esc(x.roleCode || '')}</td><td>${esc(x.scopeType || 'GLOBAL/UNSCOPED')}<br><small>${esc(x.scopeName || '')}</small></td><td>${esc(x.organizationNameLo || x.adminUnitNameLo || x.facilityNameLo || x.domainCode || '—')}</td><td><button class="ghost assignment-remove" data-id="${esc(x.assignmentId || '')}">${lang === 'lo' ? 'ປິດສິດ' : 'Deactivate'}</button></td></tr>`).join('') || '<tr><td colspan="5">No scoped assignments yet</td></tr>'}</tbody></table></div>
 <div class="pilot-notice">⚠ ${lang === 'lo' ? 'ການແບ່ງອຳນາດອອກໃບອະນຸຍາດ Central/Province/District ຍັງບໍ່ຖືກ hard-code. ຕ້ອງຢືນຢັນ Delegation Matrix ທາງກົດໝາຍກ່ອນ.' : 'Central/Province/District legal issuing authority is intentionally not hard-coded until the formal delegation matrix is approved.'}</div>`;
    $('#org-create').addEventListener('click', async () => { try {
        await api('/admin/organizations', { method: 'POST', body: JSON.stringify({ organizationCode: ($('#org-code').value || '').trim() || null, organizationType: ($('#org-type').value || 'OTHER'), nameLo: ($('#org-name-lo').value || '').trim(), nameEn: ($('#org-name-en').value || '').trim() || null, adminUnitId: ($('#org-unit').value || null), parentId: ($('#org-parent').value || null) }) });
        toast('Organization created');
        await renderAdminAccess();
    }
    catch (e) {
        toast(e.message, true);
    } });
    $('#scope-create').addEventListener('click', async () => { try {
        await api('/admin/access-scopes', { method: 'POST', body: JSON.stringify({ scopeName: ($('#scope-name').value || '').trim() || null, scopeType: ($('#scope-type').value || 'CUSTOM'), adminUnitId: ($('#scope-unit').value || null), organizationId: ($('#scope-org').value || null), facilityId: ($('#scope-facility').value || null), domainCode: ($('#scope-domain').value || '').trim() || null }) });
        toast('Access scope created');
        await renderAdminAccess();
    }
    catch (e) {
        toast(e.message, true);
    } });
    $('#assign-create').addEventListener('click', async () => { const uid = ($('#assign-user').value || ''), roleCode = ($('#assign-role').value || ''), accessScopeId = ($('#assign-scope').value || null); try {
        await api(`/admin/users/${encodeURIComponent(uid)}/assignments`, { method: 'POST', body: JSON.stringify({ roleCode, accessScopeId }) });
        toast('Role + scope assigned');
        await renderAdminAccess();
    }
    catch (e) {
        toast(e.message, true);
    } });
    document.querySelectorAll('.assignment-remove').forEach(b => b.addEventListener('click', async () => { const id = b.dataset.id || ''; if (!id)
        return; try {
        await api(`/admin/user-assignments/${encodeURIComponent(id)}`, { method: 'PATCH', body: JSON.stringify({ status: 'INACTIVE' }) });
        toast('Assignment deactivated');
        await renderAdminAccess();
    }
    catch (e) {
        toast(e.message, true);
    } }));
}
async function renderAdminSettings() { const r = await api('/admin/settings'); const rows = r.data || []; $('#admin-content').innerHTML = `<h3>Platform Settings</h3><p class="admin-note">${lang === 'lo' ? 'ໜ້ານີ້ຈົ່ງເກັບແຕ່ configuration ທີ່ບໍ່ແມ່ນ secret. Password/API key/database URL ຫ້າມເກັບຢູ່ນີ້.' : 'Only non-secret configuration belongs here. Passwords, API keys and database URLs must remain in deployment secret management.'}</p><div class="admin-setting-grid">${rows.map((x) => { const v = settingValue(x); const control = x.valueType === 'BOOLEAN' ? `<label class="admin-switch"><input type="checkbox" class="admin-setting-input" data-code="${esc(x.settingCode)}" data-type="BOOLEAN" ${v === true ? 'checked' : ''}> Enabled</label>` : `<input class="admin-setting-input" data-code="${esc(x.settingCode)}" data-type="${esc(x.valueType)}" type="${x.valueType === 'NUMBER' ? 'number' : 'text'}" value="${esc(typeof v === 'string' ? v : JSON.stringify(v))}">`; return `<div class="admin-setting"><label>${esc(lang === 'lo' ? (x.nameLo || x.nameEn) : (x.nameEn || x.nameLo))}</label><small>${esc(x.categoryCode)} · ${esc(x.settingCode)}</small>${control}<div class="admin-setting-foot"><button class="ghost admin-setting-save" data-code="${esc(x.settingCode)}">Save</button></div></div>`; }).join('')}</div>`; document.querySelectorAll('.admin-setting-save').forEach(b => b.addEventListener('click', async () => { const code = b.dataset.code || ''; const inp = document.querySelector(`.admin-setting-input[data-code="${CSS.escape(code)}"]`); let value = inp.dataset.type === 'BOOLEAN' ? inp.checked : inp.dataset.type === 'NUMBER' ? Number(inp.value) : inp.value; try {
    await api(`/admin/settings/${encodeURIComponent(code)}`, { method: 'PATCH', body: JSON.stringify({ value }) });
    toast('Setting saved');
    await loadPublicSettings();
}
catch (e) {
    toast(e.message, true);
} })); }
async function renderAdminField() { const r = await api('/admin/field-captures'); const rows = r.data || []; $('#admin-content').innerHTML = `<h3>Offline Field Sync (${rows.length})</h3><p class="admin-note">${lang === 'lo' ? 'Field App ເກັບຮ່າງ offline ແລ້ວ sync ເຂົ້າ staging queue. ຂໍ້ມູນນີ້ຍັງບໍ່ແມ່ນ official Finding ຈົນກວ່າຈະ review/link ເຂົ້າ Inspection Case.' : 'Field App syncs offline drafts into a staging queue. They are not official Findings until reviewed and linked to an Inspection Case.'}</p><div class="detail-table-wrap"><table class="admin-table"><thead><tr><th>Received</th><th>Facility</th><th>Capture</th><th>GPS</th><th>Subject</th><th>Status</th></tr></thead><tbody>${rows.map((x) => `<tr><td>${fmtDate(x.receivedAt)}</td><td>${esc(x.facilityText || x.facility || '—')}</td><td>${esc(x.payload?.finding || x.finding || x.captureType || '')}</td><td>${esc(x.latitude ?? '')} ${x.longitude !== undefined && x.longitude !== null ? ', ' + esc(x.longitude) : ''}</td><td><code>${esc(x.submittedBySubject || '')}</code></td><td><span class="field-status">${esc(x.syncStatus || '')}</span></td></tr>`).join('') || '<tr><td colspan="6">No field captures</td></tr>'}</tbody></table></div>`; }
async function renderAdminAudit() { const r = await api('/admin/audit'); const rows = (r.data || []).slice(0, 200); $('#admin-content').innerHTML = `<h3>Audit Log</h3><div class="detail-table-wrap"><table class="admin-table"><thead><tr><th>Time</th><th>Action</th><th>Resource</th><th>Actor</th></tr></thead><tbody>${rows.map((x) => `<tr><td>${esc(String(x.occurredAt || '').replace('T', ' ').slice(0, 19))}</td><td>${esc(x.actionCode || '')}</td><td>${esc(x.resourceType || '')} ${esc(String(x.resourceId || '').slice(0, 8))}</td><td>${esc(x.actorUserId || x.metadata?.actorUserId || 'system')}</td></tr>`).join('') || '<tr><td colspan="4">No audit events</td></tr>'}</tbody></table></div>`; }
function guideText(x, loKey, enKey) { return lang === 'lo' ? (x?.[loKey] || x?.[enKey] || '') : (x?.[enKey] || x?.[loKey] || ''); }
function serviceName(s) { return guideText(s, 'nameLo', 'nameEn') || s.serviceCode || ''; }
function serviceStatusBadge(s) { const st = s.guideStatus || s.status || 'PILOT'; return `<span class="guide-badge ${String(st).toLowerCase()}">${esc(st)}</span>`; }
async function renderGuidedServices() {
    $('#page-title').textContent = lang === 'lo' ? 'ສູນບໍລິການແບບມີຂັ້ນຕອນ' : 'Guided Digital Services';
    $('#page-subtitle').textContent = lang === 'lo' ? 'ເລືອກວຽກທີ່ຕ້ອງການ — LVSP ຈະພາໄປທີລະຂັ້ນ' : 'Choose what you need to do — LVSP guides you step by step';
    const root = $('#custom-page');
    root.innerHTML = `<div class="guide-hero"><div><span class="guide-kicker">LVSP DIGITAL SERVICES</span><h2>${lang === 'lo' ? 'ຂ້ອຍຕ້ອງການ…' : 'I want to…'}</h2><p>${lang === 'lo' ? 'ເລືອກບໍລິການ, ກວດສິ່ງທີ່ຕ້ອງກະກຽມ, ເຮັດຕາມຂັ້ນຕອນ, ບັນທຶກ Draft ແລະ ຕິດຕາມສະຖານະ.' : 'Choose a service, prepare requirements, follow each step, save a draft and track progress.'}</p></div><div class="guide-hero-state">${authenticated() ? '🔐 ' + (lang === 'lo' ? 'ເຂົ້າລະບົບແລ້ວ' : 'Signed in') : '🌐 ' + (lang === 'lo' ? 'ກຳລັງເບິ່ງແບບສາທາລະນະ' : 'Public browsing')}</div></div><div class="service-card-grid" id="service-card-grid"><div class="guide-loading">Loading…</div></div>${authenticated() ? '<div class="draft-strip" id="draft-strip"></div>' : ''}`;
    try {
        const r = authenticated() && !publicBrowsing ? await api('/guided-services') : await apiPublic('/public/service-catalog');
        const rows = r.data || [];
        $('#service-card-grid').innerHTML = rows.map((x) => `<article class="service-card"><div class="service-card-top"><span class="service-icon">${esc(x.icon || '🧭')}</span>${serviceStatusBadge(x)}</div><div class="service-code">${esc(x.serviceCode)}</div><h3>${esc(serviceName(x))}</h3><p>${esc(guideText(x, 'overviewLo', 'overviewEn') || x.description || '')}</p><div class="service-meta"><span>${esc(x.stepCount || 0)} ${lang === 'lo' ? 'ຂັ້ນ' : 'steps'}</span><span>${esc(x.requirementCount || 0)} ${lang === 'lo' ? 'ລາຍການກະກຽມ' : 'requirements'}</span></div><button class="primary service-view" data-code="${esc(x.serviceCode)}">${lang === 'lo' ? 'ເບິ່ງຂັ້ນຕອນ →' : 'View guide →'}</button></article>`).join('') || `<div class="empty-box">${lang === 'lo' ? 'ຍັງບໍ່ມີບໍລິການທີ່ເປີດໃຊ້' : 'No guided services configured'}</div>`;
        document.querySelectorAll('.service-view').forEach(b => b.addEventListener('click', () => openServiceGuide(b.dataset.code || '')));
        if (authenticated()) {
            const d = await api('/service-drafts');
            const drafts = d.data || [];
            const strip = $('#draft-strip');
            strip.innerHTML = drafts.length ? `<div class="draft-strip-head"><b>${lang === 'lo' ? 'ຮ່າງຂອງຂ້ອຍ' : 'My drafts'}</b><button class="ghost" id="all-drafts-btn">${lang === 'lo' ? 'ເບິ່ງວຽກຂອງຂ້ອຍ' : 'Open My Work'}</button></div><div class="draft-mini-list">${drafts.slice(0, 4).map((x) => `<button class="draft-mini" data-id="${esc(x.id)}"><span>${esc(x.icon || '📝')}</span><span><b>${esc(lang === 'lo' ? (x.serviceNameLo || x.serviceCodeSnapshot) : (x.serviceNameEn || x.serviceCodeSnapshot))}</b><small>${esc(x.completedSteps || 0)}/${esc(x.totalSteps || 0)} · ${esc(x.status)}</small></span></button>`).join('')}</div>` : '';
            document.querySelectorAll('.draft-mini').forEach(b => b.addEventListener('click', () => renderServiceDraft(b.dataset.id || '')));
            const all = document.querySelector('#all-drafts-btn');
            if (all)
                all.addEventListener('click', () => { current = modules.find(x => x.key === 'my_work'); renderNav(); loadModule(); });
        }
    }
    catch (e) {
        root.innerHTML = `<div class="error-card">${esc(e.message)}</div>`;
    }
}
async function openServiceGuide(code) {
    try {
        const r = authenticated() && !publicBrowsing ? await api(`/guided-services/${encodeURIComponent(code)}`) : await apiPublic(`/public/services/${encodeURIComponent(code)}`);
        const g = r.data, s = g.service || {}, steps = g.steps || [], reqs = g.requirements || [], outs = g.outputs || [];
        const root = $('#custom-page');
        $('#page-title').textContent = serviceName(s);
        $('#page-subtitle').textContent = `${s.serviceCode || code} · ${lang === 'lo' ? 'ຄູ່ມືກ່ອນເລີ່ມ' : 'Service guide'}`;
        root.innerHTML = `<div class="guide-toolbar"><button class="ghost" id="guide-back">← ${lang === 'lo' ? 'ກັບຄືນລາຍການ' : 'All services'}</button>${serviceStatusBadge(s)}</div><article class="guide-detail"><header><div class="service-icon large">${esc(s.icon || '🧭')}</div><div><div class="service-code">${esc(s.serviceCode || code)}</div><h2>${esc(serviceName(s))}</h2><p>${esc(guideText(s, 'overviewLo', 'overviewEn'))}</p></div></header><div class="guide-info-grid"><section><h3>✓ ${lang === 'lo' ? 'ໃຜ/ເງື່ອນໄຂກ່ອນເລີ່ມ' : 'Eligibility / before starting'}</h3><p>${esc(guideText(s, 'eligibilityLo', 'eligibilityEn') || '—')}</p></section><section><h3>📂 ${lang === 'lo' ? 'ກະກຽມຫຍັງ' : 'What to prepare'}</h3><p>${esc(guideText(s, 'preparationLo', 'preparationEn') || '—')}</p></section><section><h3>⚙️ ${lang === 'lo' ? 'ຫຼັງຈາກຍື່ນ' : 'After submission'}</h3><p>${esc(guideText(s, 'processingLo', 'processingEn') || '—')}</p></section></div><section class="guide-section"><h3>${lang === 'lo' ? 'ລາຍການທີ່ຕ້ອງກະກຽມ' : 'Preparation checklist'}</h3><div class="requirement-list">${reqs.map((x) => `<div class="requirement-item"><span>${x.isRequired ? '●' : '○'}</span><div><b>${esc(guideText(x, 'nameLo', 'nameEn'))}</b><small>${esc(guideText(x, 'descriptionLo', 'descriptionEn') || x.requirementType || '')}</small></div><em>${x.isRequired ? (lang === 'lo' ? 'ຈຳເປັນ' : 'Required') : (lang === 'lo' ? 'ຕາມກໍລະນີ' : 'If applicable')}</em></div>`).join('') || '—'}</div></section><section class="guide-section"><h3>${lang === 'lo' ? 'ຂັ້ນຕອນ' : 'Steps'}</h3><div class="service-step-list">${steps.map((x, i) => `<div class="service-step"><span class="step-num">${i + 1}</span><div><b>${esc(guideText(x, 'nameLo', 'nameEn'))}</b><small>${esc(guideText(x, 'descriptionLo', 'descriptionEn'))}</small></div><span class="step-type">${esc(x.stepType || '')}</span></div>`).join('')}</div></section><section class="guide-section outputs"><h3>${lang === 'lo' ? 'ຜົນທີ່ຈະໄດ້' : 'Expected output'}</h3>${outs.map((x) => `<div>📄 <b>${esc(guideText(x, 'nameLo', 'nameEn'))}</b> <span>${esc(x.outputType || '')}</span></div>`).join('') || '—'}</section>${s.configurationNoticeLo || s.configurationNoticeEn ? `<div class="pilot-notice">⚠ ${esc(guideText(s, 'configurationNoticeLo', 'configurationNoticeEn'))}</div>` : ''}<div class="guide-cta"><button class="primary" id="start-service">${authenticated() ? (lang === 'lo' ? 'ເລີ່ມຄຳຮ້ອງ / ສ້າງ Draft' : 'Start / create draft') : (lang === 'lo' ? 'ເຂົ້າລະບົບເພື່ອເລີ່ມ' : 'Sign in to start')}</button></div></article>`;
        $('#guide-back').onclick = () => renderGuidedServices();
        $('#start-service').onclick = () => startGuidedService(code);
    }
    catch (e) {
        toast(e.message, true);
    }
}
async function startGuidedService(code) {
    if (!authenticated()) {
        pendingServiceCode = code;
        showLogin();
        return;
    }
    publicBrowsing = false;
    try {
        const r = await api('/service-drafts', { method: 'POST', body: JSON.stringify({ serviceCode: code }) });
        await renderServiceDraft(r.data.draft.id);
    }
    catch (e) {
        toast(e.message, true);
    }
}
function requirementStatusLabel(st) { return { PENDING: lang === 'lo' ? 'ຍັງບໍ່ກວດ' : 'Pending', READY: lang === 'lo' ? 'ພ້ອມ' : 'Ready', NOT_APPLICABLE: 'N/A', MISSING: lang === 'lo' ? 'ຂາດ' : 'Missing' }[st] || st; }
function vetDrugReviewReqStatus(q) {
    const s = String(q?.status || q?.requirementStatus || q?.currentStatus || q?.verificationStatus || 'PENDING').toUpperCase();
    if (['READY', 'PRESENT', 'RECEIVED', 'ACCEPTED', 'COMPLETED'].includes(s))
        return 'READY';
    if (['MISSING', 'REJECTED'].includes(s))
        return 'MISSING';
    if (['NOT_APPLICABLE', 'N/A', 'WAIVED'].includes(s))
        return 'NOT_APPLICABLE';
    return 'PENDING';
}
function vetDrugReviewReqLabel(q) {
    return lang === 'lo' ? (q?.nameLo || q?.requirementNameLo || q?.requirementLabelLo || q?.labelLo || q?.nameEn || q?.requirementLabel || q?.requirementCode || '') : (q?.nameEn || q?.requirementNameEn || q?.requirementLabelEn || q?.labelEn || q?.nameLo || q?.requirementLabel || q?.requirementCode || '');
}
async function renderVetDrugReviewDraft(id, d, reqs, steps) {
    const root = $('#custom-page');
    const qs = (reqs || []).map((q) => ({ ...q, _reviewStatus: vetDrugReviewReqStatus(q) }));
    const ready = qs.filter((q) => q._reviewStatus === 'READY').length;
    const pending = qs.filter((q) => q._reviewStatus === 'PENDING').length;
    const missing = qs.filter((q) => q._reviewStatus === 'MISSING').length;
    const na = qs.filter((q) => q._reviewStatus === 'NOT_APPLICABLE').length;
    $('#page-title').textContent = lang === 'lo' ? (d.serviceNameLo || 'ກວດຄຳຮ້ອງຂຶ້ນທະບຽນຢາ') : (d.serviceNameEn || 'Veterinary Drug Application Review');
    $('#page-subtitle').textContent = `${d.serviceCodeSnapshot || 'VM-1003'} · ${lang === 'lo' ? 'ກວດຄວາມຄົບຖ້ວນ — ບໍ່ປ້ອນຂໍ້ມູນຊ້ຳ' : 'Completeness review — no duplicate data entry'}`;
    const rows = qs.length ? qs.map((q, i) => { const st = q._reviewStatus; const badge = st === 'READY' ? (lang === 'lo' ? '✓ ມີ/ພ້ອມ' : '✓ Present') : st === 'MISSING' ? (lang === 'lo' ? '✕ ຂາດ' : '✕ Missing') : st === 'NOT_APPLICABLE' ? 'N/A' : (lang === 'lo' ? '○ ຍັງກວດ' : '○ To check'); return `<tr><td>${i + 1}</td><td><b>${esc(vetDrugReviewReqLabel(q))}</b></td><td>${esc(badge)}</td></tr>`; }).join('') : `<tr><td colspan="3">${lang === 'lo' ? 'ຍັງບໍ່ມີ checklist' : 'No checklist configured'}</td></tr>`;
    root.innerHTML = `<div class="wizard-main" style="min-height:auto"><div class="wizard-head"><div class="guide-badge pilot">REVIEW DESK</div><h2>${lang === 'lo' ? 'ກວດເອກະສານ ແລະ ຂໍ້ມູນຄຳຮ້ອງ' : 'Application & dossier review'}</h2><p>${lang === 'lo' ? 'ກວດສິ່ງທີ່ຜູ້ປະກອບການຍື່ນມາ. ຂໍ້ມູນຫຼັກບໍ່ຕ້ອງປ້ອນຊ້ຳເປັນ 8 ຂັ້ນ.' : 'Review operator-submitted data and evidence. Core data is not re-entered as an 8-step wizard.'}</p></div><div style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px"><div class="wizard-box"><b>${ready}</b><small style="display:block">${lang === 'lo' ? 'ມີ/ພ້ອມ' : 'Present'}</small></div><div class="wizard-box"><b>${pending}</b><small style="display:block">${lang === 'lo' ? 'ຍັງກວດ' : 'To check'}</small></div><div class="wizard-box"><b>${missing}</b><small style="display:block">${lang === 'lo' ? 'ຂາດ/ຕ້ອງທວງ' : 'Missing'}</small></div><div class="wizard-box"><b>${na}</b><small style="display:block">N/A</small></div></div><div class="wizard-box"><h3>${lang === 'lo' ? 'Checklist ເອກະສານ/ຂໍ້ກຳນົດ' : 'Document / requirement checklist'}</h3><div style="overflow:auto"><table class="data-table" style="width:100%"><thead><tr><th>#</th><th>${lang === 'lo' ? 'ລາຍການກວດ' : 'Requirement'}</th><th>${lang === 'lo' ? 'ສະຖານະ' : 'Status'}</th></tr></thead><tbody>${rows}</tbody></table></div></div><div class="wizard-box guidance-box"><h3>${lang === 'lo' ? 'ວິທີເຮັດວຽກ' : 'Working method'}</h3><p>${lang === 'lo' ? 'ເປີດຂໍ້ມູນຢາ → ກວດ dossier/ເອກະສານ → ເບິ່ງວ່າຄົບຫຼືຂາດ → ຖ້າຂາດໃຫ້ທວງຂໍນຳຜູ້ປະກອບການ.' : 'Open the drug record → review dossier/evidence → identify missing items → request correction from the operator.'}</p></div><div class="wizard-actions"><button class="ghost" id="review-back">← ${lang === 'lo' ? 'ກັບ' : 'Back'}</button><button class="ghost" id="review-copy-request" ${missing + pending === 0 ? 'disabled' : ''}>📋 ${lang === 'lo' ? 'ລາຍການທວງຂໍ' : 'Copy request list'}</button><button class="primary" id="review-open-drug">💊 ${lang === 'lo' ? 'ໄປຂຶ້ນທະບຽນຢາ / ແຟ້ມພິຈາລະນາ' : 'Open Drug Registration / Dossier'}</button></div></div>`;
    const b = document.querySelector('#review-back');
    if (b)
        b.onclick = () => renderGuidedServices();
    const o = document.querySelector('#review-open-drug');
    if (o)
        o.onclick = () => { const m = modules.find((z) => z.key === 'drug_registrations'); if (!m) {
            toast('Drug Registration module not found', true);
            return;
        } current = m; renderNav(); loadModule(); };
    const c = document.querySelector('#review-copy-request');
    if (c)
        c.onclick = async () => { const ask = qs.filter((q) => ['MISSING', 'PENDING'].includes(q._reviewStatus)); const title = lang === 'lo' ? 'ລາຍການຂໍໃຫ້ຜູ້ປະກອບການສົ່ງ/ແກ້ໄຂເພີ່ມ:' : 'Please provide/correct the following items:'; const text = [title, ...ask.map((q, i) => `${i + 1}. ${vetDrugReviewReqLabel(q)}`)].join('\n'); try {
            await navigator.clipboard.writeText(text);
            toast(lang === 'lo' ? 'ຄັດລອກລາຍການແລ້ວ' : 'Request list copied');
        }
        catch {
            toast(text);
        } };
}
async function renderServiceDraft(id) {
    if (!authenticated()) {
        showLogin();
        return;
    }
    publicBrowsing = false;
    activeServiceDraftId = id;
    try {
        const r = await api(`/service-drafts/${encodeURIComponent(id)}`);
        const d = r.data.draft || {}, steps = r.data.steps || [], reqs = r.data.requirements || [];
        if (String(d.serviceCodeSnapshot || '') === 'VM-1003')
            return renderVetDrugReviewDraft(id, d, reqs, steps);
        const incomplete = steps.findIndex((x) => x.status !== 'COMPLETED');
        if (incomplete >= 0)
            draftViewStepIndex = incomplete;
        else
            draftViewStepIndex = Math.max(0, steps.length - 1);
        const x = steps[draftViewStepIndex] || {};
        const done = steps.filter((z) => z.status === 'COMPLETED').length;
        const pct = steps.length ? Math.round(done / steps.length * 100) : 0;
        $('#page-title').textContent = lang === 'lo' ? (d.serviceNameLo || d.serviceCodeSnapshot || 'Guided Service') : (d.serviceNameEn || d.serviceCodeSnapshot || 'Guided Service');
        $('#page-subtitle').textContent = `${d.serviceCodeSnapshot || ''} · ${d.status || ''}`;
        const root = $('#custom-page');
        root.innerHTML = `<div class="wizard-shell"><aside class="wizard-steps"><button class="ghost" id="wizard-exit">← ${lang === 'lo' ? 'ບໍລິການ' : 'Services'}</button><div class="wizard-progress"><div><b>${done}/${steps.length}</b><span>${pct}%</span></div><div class="progress-track"><i style="width:${pct}%"></i></div></div>${steps.map((z, i) => `<button class="wizard-step ${i === draftViewStepIndex ? 'active' : ''} ${z.status === 'COMPLETED' ? 'done' : ''}" data-i="${i}"><span>${z.status === 'COMPLETED' ? '✓' : i + 1}</span><div><b>${esc(guideText(z, 'nameLo', 'nameEn'))}</b><small>${esc(z.status)}</small></div></button>`).join('')}</aside><section class="wizard-main"><div class="wizard-head"><span class="step-type">${esc(x.stepType || '')}</span><h2>${esc(guideText(x, 'nameLo', 'nameEn'))}</h2><p>${esc(guideText(x, 'descriptionLo', 'descriptionEn') || '')}</p></div>${String(x.stepType || '').toUpperCase() === 'DOCUMENTS' || String(x.stepType || '').toUpperCase() === 'REVIEW' ? `<div class="wizard-box"><h3>${lang === 'lo' ? 'Checklist ເອກະສານ/ຂໍ້ມູນ' : 'Requirement checklist'}</h3><div class="wizard-reqs">${reqs.map((q) => `<label><input type="checkbox" class="draft-req" data-code="${esc(q.requirementCode)}" ${q.status === 'READY' ? 'checked' : ''}><span><b>${esc(guideText(q, 'nameLo', 'nameEn'))}</b><small>${esc(guideText(q, 'descriptionLo', 'descriptionEn') || q.requirementType || '')} · ${esc(requirementStatusLabel(q.status))}</small></span>${q.isRequired ? '<em>Required</em>' : ''}</label>`).join('')}</div></div>` : ''}<div class="wizard-box guidance-box"><h3>💡 ${lang === 'lo' ? 'ຄຳແນະນຳໃນຂັ້ນນີ້' : 'Step notes'}</h3><textarea id="step-note" placeholder="${lang === 'lo' ? 'ບັນທຶກຂໍ້ມູນ/ໝາຍເຫດຊົ່ວຄາວ…' : 'Save a note for this step…'}">${esc(x.stepPayload?.note || '')}</textarea></div>${d.status === 'GUIDE_COMPLETED' || d.status === 'DOMAIN_DRAFT_CREATED' ? `<div class="guide-complete"><b>✓ ${lang === 'lo' ? 'ສຳເລັດຄູ່ມືຂັ້ນຕອນ' : 'Guided preparation complete'}</b><p>${lang === 'lo' ? 'ສາມາດໄປຕໍ່ທີ່ແບບຟອມລາຍລະອຽດ. ຫຼັງບັນທຶກ LVSP ຈະເຊື່ອມ Draft ນີ້ກັບ record ຈິງ.' : 'Continue to the detailed form. LVSP will link this guided draft to the created domain record.'}</p><button class="primary" id="launch-domain">${lang === 'lo' ? 'ໄປແບບຟອມລາຍລະອຽດ →' : 'Continue to detailed form →'}</button></div>` : ''}<div class="wizard-actions"><button class="ghost" id="wizard-prev" ${draftViewStepIndex <= 0 ? 'disabled' : ''}>← ${lang === 'lo' ? 'ກ່ອນໜ້າ' : 'Previous'}</button><button class="primary" id="wizard-next">${x.status === 'COMPLETED' ? (lang === 'lo' ? 'ໄປຂັ້ນຕໍ່ໄປ' : 'Next step') : (lang === 'lo' ? 'ບັນທຶກ ແລະ ສຳເລັດຂັ້ນນີ້' : 'Save & complete step')}</button></div></section></div>`;
        $('#wizard-exit').onclick = () => renderGuidedServices();
        document.querySelectorAll('.wizard-step').forEach(b => b.addEventListener('click', () => { draftViewStepIndex = Number(b.dataset.i || 0); renderServiceDraft(id); }));
        $('#wizard-prev').onclick = () => { draftViewStepIndex = Math.max(0, draftViewStepIndex - 1); renderServiceDraft(id); };
        $('#wizard-next').onclick = async () => { if (x.status === 'COMPLETED') {
            draftViewStepIndex = Math.min(steps.length - 1, draftViewStepIndex + 1);
            return renderServiceDraft(id);
        } const requirements = {}; document.querySelectorAll('.draft-req').forEach((q) => requirements[q.dataset.code] = q.checked ? 'READY' : 'PENDING'); try {
            await api(`/service-drafts/${encodeURIComponent(id)}`, { method: 'PATCH', body: JSON.stringify({ stepCode: x.stepCode, completed: true, payload: { note: $('#step-note')?.value || '' }, requirements }) });
            await renderServiceDraft(id);
        }
        catch (e) {
            toast(e.message, true);
        } };
        const launch = document.querySelector('#launch-domain');
        if (launch)
            launch.onclick = () => launchGuidedDomain(d.launchModuleKey, id);
    }
    catch (e) {
        toast(e.message, true);
    }
}
function launchGuidedDomain(moduleKey, draftId) { const m = modules.find(x => x.key === moduleKey); if (!m) {
    toast('Detailed module is not configured', true);
    return;
} activeServiceDraftId = draftId; current = m; renderNav(); loadModule().then(() => openCreate()); }
async function renderMyWork() {
    $('#page-title').textContent = lang === 'lo' ? 'ວຽກຂອງຂ້ອຍ' : 'My Work';
    $('#page-subtitle').textContent = lang === 'lo' ? 'Work Queue • Draft • ວຽກລໍຖ້າດຳເນີນ' : 'Task queue • drafts • pending work';
    const root = $('#custom-page');
    if (!authenticated()) {
        root.innerHTML = `<div class="empty-box">${lang === 'lo' ? 'ກະລຸນາ Login ເພື່ອເບິ່ງວຽກ' : 'Sign in to view your work'}</div>`;
        return;
    }
    try {
        const [wr, dr] = await Promise.all([api('/my-work'), api('/service-drafts')]);
        const w = wr.data || {}, drafts = dr.data || [];
        root.innerHTML = `<div class="work-hero"><div><span class="guide-kicker">TASK-CENTRIC WORKSPACE</span><h2>${lang === 'lo' ? 'ສິ່ງທີ່ຕ້ອງເຮັດ' : 'What needs attention'}</h2></div><button class="primary" id="new-service-work">+ ${lang === 'lo' ? 'ເລີ່ມບໍລິການ' : 'Start service'}</button></div><div class="work-queue-grid">${(w.domainQueues || []).filter((x) => String(x.queueType) !== 'PROVINCIAL_REPORT').map((x) => `<div class="work-queue-card"><small>${esc(x.queueType)}</small><b>${esc(x.itemCount)}</b><span>${esc(x.status)}</span></div>`).join('') || '<div class="empty-box">No domain queue items</div>'}</div><section class="work-section"><h3>${lang === 'lo' ? 'ຮ່າງບໍລິການ / ຄຳຮ້ອງທີ່ກຳລັງເຮັດ' : 'Guided drafts in progress'}</h3><div class="work-draft-list">${drafts.map((x) => `<button class="work-draft" data-id="${esc(x.id)}"><span class="service-icon">${esc(x.icon || '📝')}</span><span class="work-draft-main"><b>${esc(lang === 'lo' ? (x.serviceNameLo || x.serviceCodeSnapshot) : (x.serviceNameEn || x.serviceCodeSnapshot))}</b><small>${esc(x.serviceCodeSnapshot)} · ${esc(x.status)}</small><i><em style="width:${x.totalSteps ? Math.round((x.completedSteps || 0) / x.totalSteps * 100) : 0}%"></em></i></span><strong>${String(x.serviceCodeSnapshot || '') === 'VM-1003' ? 'REVIEW' : esc(x.completedSteps || 0) + '/' + esc(x.totalSteps || 0)}</strong></button>`).join('') || '<div class="empty-box">No drafts</div>'}</div></section><section class="work-section"><h3>${lang === 'lo' ? 'Workflow Tasks' : 'Workflow Tasks'}</h3>${(w.tasks || []).length ? `<div class="detail-table-wrap"><table><thead><tr><th>Step</th><th>Entity</th><th>Status</th><th>Priority</th><th>Due</th></tr></thead><tbody>${w.tasks.map((x) => `<tr><td>${esc(lang === 'lo' ? (x.stepNameLo || x.stepCode) : (x.stepNameEn || x.stepCode))}</td><td>${esc(x.businessEntityType)} ${esc(x.businessEntityId || '')}</td><td>${esc(x.status)}</td><td>${esc(x.priority || '')}</td><td>${fmtDate(x.dueAt)}</td></tr>`).join('')}</tbody></table></div>` : `<div class="empty-box">${lang === 'lo' ? 'ຍັງບໍ່ມີ Workflow task ທີ່ມອບໝາຍ' : 'No assigned workflow tasks yet'}</div>`}</section>`;
        $('#new-service-work').onclick = () => { current = modules.find(x => x.key === 'guided_services'); renderNav(); loadModule(); };
        document.querySelectorAll('.work-draft').forEach(b => b.addEventListener('click', () => renderServiceDraft(b.dataset.id || '')));
    }
    catch (e) {
        root.innerHTML = `<div class="error-card">${esc(e.message)}</div>`;
    }
}
async function options(path, label) { try {
    const r = await api(path);
    return (r.data || []).map((x) => `<option value="${esc(x.id)}">${esc(label(x))}</option>`).join('');
}
catch {
    return '';
} }
async function planItemOptions() {
    try {
        const [ir, pr] = await Promise.all([api('/import-plan-items'), api('/import-plans')]);
        const plans = new Map((pr.data || []).map((x) => [String(x.id), x]));
        return (ir.data || []).map((x) => { const p = plans.get(String(x.planId)) || {}; return `<option value="${esc(x.id)}" data-plan="${esc(x.planId || '')}">${esc(p.planNo || 'Plan')} (${esc(p.planYear || '')}) — ${esc(x.itemName || '')} — ${esc(x.plannedQuantity || '')} ${esc(x.unitCode || '')}</option>`; }).join('');
    }
    catch {
        return '';
    }
}
function bindPlanItemFilter() {
    const plan = document.querySelector('[name="planId"]');
    const item = document.querySelector('[name="planItemId"]');
    if (!item)
        return;
    const refresh = () => { const pid = plan?.value || ''; Array.from(item.options).forEach((o) => { if (!o.value)
        return; const match = !pid || o.dataset.plan === pid; o.disabled = !match; o.hidden = !match; }); if (item.value && item.selectedOptions[0]?.disabled)
        item.value = ''; };
    plan?.addEventListener('change', refresh);
    refresh();
}
function bindPlanTrackingControls() {
    const mode = document.querySelector('[name="lineMode"]');
    const basis = document.querySelector('[name="trackingBasis"]');
    const unit = document.querySelector('[name="unitCode"]');
    const qty = document.querySelector('[name="plannedQuantity"]');
    const count = document.querySelector('[name="plannedItemCount"]');
    if (!mode || !basis)
        return;
    const sync = () => { const summary = mode.value === 'SUMMARY_GROUP'; if (summary) {
        if (['QUANTITY', 'QUANTITY_VALUE'].includes(basis.value))
            basis.value = 'COUNT_VALUE';
        if (unit && !unit.value)
            unit.value = 'ລາຍການ';
        if (count && !count.value && qty && Number(qty.value) > 0)
            count.value = String(Math.trunc(Number(qty.value)));
    }
    else if (basis.value === 'COUNT_VALUE') {
        basis.value = 'QUANTITY_VALUE';
    } };
    mode.addEventListener('change', sync);
    sync();
}
async function companySiteOptions(companyId = '') { try {
    const r = await api('/company-sites' + (companyId ? '?companyId=' + encodeURIComponent(companyId) : ''));
    return (r.data || []).map((x) => `<option value="${esc(x.facilityId)}" data-company="${esc(x.companyId)}">${esc(x.legalNameLo || x.legalNameEn || 'Company')} — ${esc(x.siteRoleNameLo || x.siteRoleNameEn || x.siteRoleCode)} — ${esc(x.addressTextLo || x.addressTextEn || x.facilityNameLo || '')}</option>`).join('');
}
catch {
    return '';
} }
const companySiteRoles = [['REGISTERED_OFFICE', 'ທີ່ຢູ່ຈົດທະບຽນ / Registered office'], ['HEAD_OFFICE', 'ສຳນັກງານໃຫຍ່ / Head office'], ['BUSINESS_SITE', 'ສະຖານທີ່ທຸລະກິດ / Business site'], ['BRANCH_OFFICE', 'ສາຂາ / Branch'], ['REGISTRATION_HOLDER_OFFICE', 'ສຳນັກງານຜູ້ຖືທະບຽນ / Registration holder office'], ['IMPORTER_OFFICE', 'ສຳນັກງານຜູ້ນຳເຂົ້າ / Importer office'], ['MANUFACTURING_SITE', 'ໂຮງງານ / Manufacturing site'], ['WAREHOUSE', 'ສາງ / Warehouse'], ['DISTRIBUTION_SITE', 'ສະຖານທີ່ຈັດຈຳໜ່າຍ / Distribution site'], ['OTHER', 'ອື່ນໆ / Other']];
function siteRoleOptions(selected = '') { return companySiteRoles.map(x => `<option value="${x[0]}" ${selected === x[0] ? 'selected' : ''}>${x[1]}</option>`).join(''); }
async function companyRoleOptions(selected = []) { try {
    const r = await api('/company-role-types');
    const sel = new Set((selected || []).map(String));
    return (r.data || []).map((x) => `<option value="${esc(x.code)}" ${sel.has(String(x.code)) ? 'selected' : ''}>${esc(x.nameLo || x.nameEn || x.code)} (${esc(x.code)})</option>`).join('');
}
catch {
    return '';
} }
const itemTypes = `<option value="MEDICINE">ຢາ / Medicine</option><option value="VACCINE">ວັກຊີນ / Vaccine</option><option value="BIOLOGICAL">ຊີວະພັນ / Biological</option><option value="VETERINARY_DEVICE">ອຸປະກອນ / Veterinary Device</option><option value="DIAGNOSTIC_KIT">Diagnostic Kit</option><option value="OTHER_VETERINARY_PRODUCT">Other Veterinary Product</option>`;
function compositionText(list) { return (list || []).map((c) => [c.ingredientName, c.ingredientRole, c.quantityText, c.unitText, c.equivalenceText].map(x => x || '').join(' | ')).join('\n'); }
function presentationRow(i, p = {}) { return `<div class="presentation-row" data-i="${i}"><div class="presentation-grid"><label><span>Sub code</span><input class="p-sub" value="${esc(p.subCode || String(i + 1).padStart(2, '0'))}"></label><label><span>Strength</span><input class="p-strength" value="${esc(p.strengthText || '')}" placeholder="e.g. 112.5 mg"></label><label><span>Basis</span><input class="p-basis" value="${esc(p.basisText || '')}" placeholder="1 tablet / 1 mL / 1 dose"></label><label><span>Packaging *</span><input class="p-pack" value="${esc(p.packDescription || '')}" placeholder="e.g. 100 mL/bottle" required></label><label><span>Target / size-specific use</span><input class="p-target" value="${esc(p.targetText || '')}"></label><label><span>Total weight/content</span><input class="p-total" value="${esc(p.totalWeightText || '')}"></label><label><span>Kit?</span><select class="p-kit"><option value="false" ${p.isKit ? '' : 'selected'}>No</option><option value="true" ${p.isKit ? 'selected' : ''}>Yes</option></select></label><label><span>Container</span><input class="p-container" value="${esc(p.containerType || '')}" placeholder="Bottle / vial / box"></label></div><label class="wide4"><span>Composition for this presentation</span><textarea class="p-composition composition-text" placeholder="Ingredient | role | quantity | unit | equivalence">${esc(compositionText(p.composition || []))}</textarea></label><button type="button" class="ghost p-remove">Remove presentation</button></div>`; }
function bindPresentations() { let n = document.querySelectorAll('.presentation-row').length; const box = document.querySelector('#presentation-list'); document.querySelector('#add-presentation')?.addEventListener('click', () => { box.insertAdjacentHTML('beforeend', presentationRow(n++)); bindPresentationRemove(); }); bindPresentationRemove(); }
function bindPresentationRemove() { document.querySelectorAll('.p-remove').forEach(b => { b.onclick = () => { if (document.querySelectorAll('.presentation-row').length > 1)
    b.closest('.presentation-row').remove(); }; }); }
function readPresentations() { return Array.from(document.querySelectorAll('.presentation-row')).map((el) => ({ id: el.dataset.id || undefined, subCode: el.querySelector('.p-sub').value.trim(), strengthText: el.querySelector('.p-strength').value.trim(), basisText: el.querySelector('.p-basis').value.trim(), packDescription: el.querySelector('.p-pack').value.trim(), targetText: el.querySelector('.p-target').value.trim(), totalWeightText: el.querySelector('.p-total').value.trim(), isKit: el.querySelector('.p-kit').value === 'true', containerType: el.querySelector('.p-container').value.trim(), composition: el.querySelector('.p-composition').value.split(/\n+/).map(x => x.trim()).filter(Boolean).map((line, j) => { const p = line.split('|').map(x => x.trim()); return { sequenceNo: j + 1, ingredientName: p[0] || '', ingredientRole: (p[1] || 'ACTIVE').toUpperCase(), quantityText: p[2] || '', unitText: p[3] || '', equivalenceText: p[4] || '' }; }) })); }
function fileToBase64(file) { return new Promise((resolve, reject) => { const r = new FileReader(); r.onload = () => resolve(String(r.result).split(',')[1] || ''); r.onerror = reject; r.readAsDataURL(file); }); }
function exportItemRow(i, speciesOptsHtml, unitOptsHtml, p = {}) { return `<div class="export-item-row" data-i="${i}"><div class="presentation-grid"><label><span>Commodity Class / ປະເພດສິນຄ້າ *</span><select class="ei-class" required><option value="">— Select —</option><option value="LIVE_ANIMAL" ${p.commodityClass === 'LIVE_ANIMAL' ? 'selected' : ''}>Live Animal / ສັດມີຊີວິດ</option><option value="ANIMAL_PRODUCT" ${p.commodityClass === 'ANIMAL_PRODUCT' ? 'selected' : ''}>Animal Product / ຜະລິດຕະພັນສັດ</option><option value="EGG" ${p.commodityClass === 'EGG' ? 'selected' : ''}>Egg / ໄຂ່</option><option value="ANIMAL_BYPRODUCT" ${p.commodityClass === 'ANIMAL_BYPRODUCT' ? 'selected' : ''}>Animal By-product</option><option value="AQUATIC_ANIMAL" ${p.commodityClass === 'AQUATIC_ANIMAL' ? 'selected' : ''}>Aquatic Animal / ສັດນ້ຳ</option><option value="OTHER" ${p.commodityClass === 'OTHER' ? 'selected' : ''}>Other / ອື່ນໆ</option></select></label><label><span>Species / ຊະນິດພັນ</span><select class="ei-species"><option value="">— / —</option>${speciesOptsHtml}</select></label><label><span>Item / ຊື່ສິນຄ້າ *</span><input class="ei-desc" value="${esc(p.itemDescription || '')}" required></label><label><span>Quantity / ຈຳນວນ</span><input class="ei-qty" type="number" step="0.001" value="${esc(p.quantity ?? '')}"></label><label><span>Unit / ຫົວໜ່ວຍ</span><select class="ei-unit"><option value="">— / —</option>${unitOptsHtml}</select></label><label><span>HS/AHTN code</span><input class="ei-hs" value="${esc(p.hsAhtnCode || '')}"></label></div><button type="button" class="ghost ei-remove">Remove item / ລຶບ</button></div>`; }
function bindExportItems(speciesOptsHtml, unitOptsHtml) { let n = document.querySelectorAll('.export-item-row').length; const box = document.querySelector('#export-item-list'); document.querySelector('#add-export-item')?.addEventListener('click', () => { box.insertAdjacentHTML('beforeend', exportItemRow(n++, speciesOptsHtml, unitOptsHtml)); bindExportItemRemove(); }); bindExportItemRemove(); }
function bindExportItemRemove() { document.querySelectorAll('.ei-remove').forEach(b => { b.onclick = () => { if (document.querySelectorAll('.export-item-row').length > 1)
    b.closest('.export-item-row').remove(); }; }); }
function readExportItems() { return Array.from(document.querySelectorAll('.export-item-row')).map((el) => ({ commodityClass: el.querySelector('.ei-class').value, speciesId: el.querySelector('.ei-species').value || null, itemDescription: el.querySelector('.ei-desc').value.trim(), quantity: el.querySelector('.ei-qty').value || null, unitId: el.querySelector('.ei-unit').value || null, hsAhtnCode: el.querySelector('.ei-hs').value.trim() || null })).filter((x) => x.itemDescription); }
function fillForm(profile) { const form = $('#create-form'); Object.entries(profile || {}).forEach(([k, v]) => { const e = form.elements.namedItem(k); if (e && v !== null && v !== undefined)
    e.value = String(v).slice(0, e.type === 'date' ? 10 : 100000); }); }
let vetDrugReferenceCache = null;
async function vetDrugReferenceData() { if (vetDrugReferenceCache)
    return vetDrugReferenceCache; try {
    const r = await api('/veterinary-drug-reference-data');
    vetDrugReferenceCache = r.data || {};
}
catch {
    vetDrugReferenceCache = { categories: [], dosageGroups: [], dosageForms: [], distributions: [], routes: [], atcvet: [], registrationTypes: [] };
} return vetDrugReferenceCache; }
function refValue(x) { return String(x?.valueText ?? x?.code ?? ''); }
function refLabel(x) { return String((lang === 'lo' ? (x?.nameLo || x?.valueText) : (x?.nameEn || x?.valueText)) || x?.code || ''); }
function controlledOptions(list, selected, placeholder = '— ເລືອກ / Select —') {
    const sel = String(selected ?? '');
    const vals = new Set((list || []).map(refValue));
    let h = `<option value="">${esc(placeholder)}</option>`;
    if (sel && !vals.has(sel))
        h += `<option value="${esc(sel)}" selected>⚠ Legacy / ຄ່າເດີມ — ${esc(sel)}</option>`;
    h += (list || []).map((x) => `<option value="${esc(refValue(x))}" ${sel === refValue(x) ? 'selected' : ''}>${esc(refLabel(x))}</option>`).join('');
    return h;
}
function categoryCode(ref, value) { const x = (ref?.categories || []).find((z) => refValue(z) === String(value || '')); return x?.code || ''; }
function dosageFormOptions(ref, group, selected) { const list = (ref?.dosageForms || []).filter((x) => !group || String(x.parentCode || '') === String(group)); return controlledOptions(list, selected, '— ເລືອກ Dosage Form —'); }
function atcvetOptions(ref, category, selected) { const cc = categoryCode(ref, category); let list = ref?.atcvet || []; if (cc) {
    const relevant = list.filter((x) => Array.isArray(x?.metadata?.categoryCodes) && x.metadata.categoryCodes.includes(cc));
    if (relevant.length)
        list = relevant;
} return controlledOptions(list, selected, '— ເລືອກ ATCvet —'); }
function isoExpiry(issue, years) { if (!issue || !years || years === 'NONE')
    return ''; const m = String(issue).slice(0, 10).match(/^(\d{4})-(\d{2})-(\d{2})$/); if (!m)
    return ''; const y = Number(m[1]) + Number(years), mo = Number(m[2]), d = Number(m[3]); const last = new Date(Date.UTC(y, mo, 0)).getUTCDate(); return `${y}-${String(mo).padStart(2, '0')}-${String(Math.min(d, last)).padStart(2, '0')}`; }
function syncDrugValidity() { const form = $('#create-form'); const d = form.elements.namedItem('dlfDate'); const issue = form.elements.namedItem('issueDate'); const yrs = form.elements.namedItem('validYears'); const exp = form.elements.namedItem('expiryDate'); if (!issue || !yrs || !exp)
    return; if (d?.value)
    issue.value = d.value; exp.value = isoExpiry(issue.value, yrs.value); }
async function refreshRegistrationNumberPreview() { const form = $('#create-form'); const type = form.elements.namedItem('registrationType'); const no = form.elements.namedItem('registrationNo'); const src = form.elements.namedItem('registrationNumberSource'); if (!type || !no || !src || editingDrugId)
    return; try {
    const r = await api(`/drug-registrations/next-number?registrationType=${encodeURIComponent(type.value)}`);
    no.value = r.data?.registrationNo || '';
    src.value = 'AUTO';
    no.readOnly = true;
}
catch (e) {
    toast('Registration number preview: ' + e.message, true);
} }
function bindDrugRegulatoryControls(ref, preset) {
    const form = $('#create-form');
    const group = form.elements.namedItem('dosageGroup');
    const dose = form.elements.namedItem('dosageForm');
    const cat = form.elements.namedItem('category');
    const atc = form.elements.namedItem('atcvet');
    const type = form.elements.namedItem('registrationType');
    const reg = form.elements.namedItem('registrationNo');
    const src = form.elements.namedItem('registrationNumberSource');
    group?.addEventListener('change', () => { if (dose)
        dose.innerHTML = dosageFormOptions(ref, group.value, ''); });
    cat?.addEventListener('change', () => { if (atc)
        atc.innerHTML = atcvetOptions(ref, cat.value, ''); });
    type?.addEventListener('change', () => { if (!editingDrugId)
        refreshRegistrationNumberPreview(); });
    form.elements.namedItem('dlfDate')?.addEventListener('change', syncDrugValidity);
    form.elements.namedItem('validYears')?.addEventListener('change', syncDrugValidity);
    document.querySelector('#registration-no-toggle')?.addEventListener('click', () => { if (!reg || !src)
        return; if (reg.readOnly) {
        reg.readOnly = false;
        reg.focus();
        src.value = 'MANUAL';
        document.querySelector('#registration-no-toggle').textContent = '🔒 Lock / ລັອກ';
    }
    else {
        reg.readOnly = true;
        document.querySelector('#registration-no-toggle').textContent = '✏️ Manual edit / ແກ້ເອງ';
    } });
    if (preset) {
        if (src && !src.value)
            src.value = preset.registrationNumberSource || 'LEGACY';
        syncDrugValidity();
    }
    else
        refreshRegistrationNumberPreview();
}
async function openCreate(preset = null) {
    editingDrugId = preset?.profile?.id || null;
    $('#modal-title').textContent = (editingDrugId ? (lang === 'lo' ? 'ແກ້ໄຂ ' : 'Edit ') : (lang === 'lo' ? 'ເພີ່ມ ' : 'Create ')) + t(current);
    const companyOpts = await options('/companies', x => x.legalNameLo || x.legalNameEn || x.id);
    const siteOpts = await companySiteOptions();
    const countryOpts = await options('/countries', x => `${x.iso2Code || ''} — ${x.nameLo || x.nameEn || ''}`);
    const productOpts = await options('/products', x => x.tradeName || x.genericName || x.id);
    const deviceOpts = await options('/veterinary-devices', x => [x.deviceName, x.brand, x.model].filter(Boolean).join(' — ') || x.id);
    const planOpts = await options('/import-plans', x => `${x.planNo} (${x.planYear})`);
    const planItemOpts = await planItemOptions();
    const appOpts = await options('/import-applications', x => `${x.applicationNo} — ${x.applicationDate || ''}`);
    const companyRoleOpts = await companyRoleOptions((preset?.roles || []).map((x) => x.code));
    const drugRef = current.key === 'drug_registrations' ? await vetDrugReferenceData() : null;
    if (current.key === 'drug_registrations') {
        const ps = preset?.presentations?.length ? preset.presentations : [{}];
        $('#form-fields').innerHTML = `
   <div class="form-section-title">1. ຂໍ້ມູນຢາ / Product Core</div>
   <label><span>Trade Name *</span><input name="tradeName" required></label><label><span>Generic Name / INN summary</span><input name="genericName"></label>
   <label><span>Registration Type</span><select name="registrationType">${controlledOptions((drugRef?.registrationTypes || []).map((x) => ({ ...x, valueText: x.code })), preset?.profile?.registrationType || 'IMPORT')}</select></label><label><span>Category *</span><select name="category" required>${controlledOptions(drugRef?.categories || [], preset?.profile?.category)}</select></label>
   <label><span>Dosage Group *</span><select name="dosageGroup" required>${controlledOptions(drugRef?.dosageGroups || [], preset?.profile?.dosageGroup)}</select></label><label><span>Dosage Form *</span><select name="dosageForm" required>${dosageFormOptions(drugRef, preset?.profile?.dosageGroup, preset?.profile?.dosageForm)}</select></label><label><span>ATCvet</span><select name="atcvet">${atcvetOptions(drugRef, preset?.profile?.category, preset?.profile?.atcvet)}</select></label><label><span>Distribution / Supply Classification</span><select name="distributionClassification">${controlledOptions(drugRef?.distributions || [], preset?.profile?.distributionClassification)}</select></label>
   <div class="section-help">Controlled values reuse the proven legacy registry. Dosage Form depends on Dosage Group; ATCvet is filtered by Category. Historical values are preserved as “Legacy” instead of being deleted.</div>
   <label class="wide"><span>Active Ingredient(s)</span><textarea name="activeIngredients"></textarea></label><label><span>Target Species</span><input name="targetSpecies"></label><label><span>Route / Method of Administration</span><select name="route">${controlledOptions(drugRef?.routes || [], preset?.profile?.route)}</select></label>
   <label><span>Shelf life</span><input name="shelfLife"></label><label><span>Storage</span><input name="storageConditions"></label><label class="wide"><span>Indications</span><textarea name="indications"></textarea></label><label class="wide"><span>Dosage & Administration</span><textarea name="dosageAdministration"></textarea></label>
   <div class="form-section-title">2. Withdrawal Period</div><label><span>Meat</span><input name="withdrawalMeat"></label><label><span>Milk</span><input name="withdrawalMilk"></label><label><span>Eggs</span><input name="withdrawalEggs"></label><label><span>Honey</span><input name="withdrawalHoney"></label><label><span>Aquatic</span><input name="withdrawalAquatic"></label>
   <div class="form-section-title">3. Legal Company + Physical Site / ນິຕິບຸກຄົນ + ສະຖານທີ່</div><div class="section-help">1 ບໍລິສັດ = 1 Company Master. ສຳນັກງານ, ໂຮງງານ, ສາງ ແລະ ສາຂາ ເປັນ Site/Facility ແຍກພາຍໃຕ້ບໍລິສັດດຽວ.</div><label><span>Registration Holder Company</span><select name="holderCompanyId"><option value="">—</option>${companyOpts}</select></label><label><span>Holder Office / Site</span><select name="holderSiteId"><option value="">— Select site —</option>${siteOpts}</select></label><label><span>Importer Company</span><select name="importerCompanyId"><option value="">—</option>${companyOpts}</select></label><label><span>Importer Office / Site</span><select name="importerSiteId"><option value="">— Select site —</option>${siteOpts}</select></label><label><span>Manufacturer Company</span><select name="manufacturerCompanyId"><option value="">—</option>${companyOpts}</select></label><label><span>Manufacturing Site / Factory</span><select name="manufacturerSiteId"><option value="">— Select site —</option>${siteOpts}</select></label><label><span>Distributor Company</span><select name="distributorCompanyId"><option value="">—</option>${companyOpts}</select></label><label><span>Distribution Site</span><select name="distributorSiteId"><option value="">— Select site —</option>${siteOpts}</select></label><div class="form-section-title">3A. Regulatory snapshot / Legacy fallback</div><div class="section-help">ເກັບຂໍ້ຄວາມຕາມເອກະສານທີ່ອະນຸມັດ; ໃຊ້ເປັນ fallback ຖ້າບໍ່ມີ Company/Site master.</div><label><span>Manufacturer Name Snapshot</span><input name="manufacturerName"></label><label><span>Manufacturer Country</span><input name="manufacturerCountry"></label><label class="wide"><span>Manufacturer Address Snapshot</span><input name="manufacturerAddress"></label><label><span>Distributor Name Snapshot</span><input name="distributorName"></label><label><span>Distributor Country</span><input name="distributorCountry"></label>
   <div class="form-section-title">4. Applicant / Business</div><label><span>Applicant Name</span><input name="applicantName"></label><label><span>Nationality</span><input name="applicantNationality"></label><label><span>ID/Passport No.</span><input name="applicantIdNo"></label><label><span>Business Licence No.</span><input name="businessLicenseNo"></label><label><span>Business Licence Date</span><input name="businessLicenseDate" type="date"></label>
   <div class="form-section-title">5. Regulatory Information / ການອອກທະບຽນ</div><div class="section-help">DLF No. + DLF Date ແມ່ນຂໍ້ມູນຫຼັງອະນຸມັດ/ລົງນາມ. DLF Date ເປັນ Issue Date ແລະ Expiry Date ຄຳນວນອັດຕະໂນມັດຈາກ Valid Years.</div><label><span>Application No.</span><input name="applicationNo"></label><label><span>Application Date</span><input name="applicationDate" type="date"></label><label><span>Registration No.</span><div class="inline-regno"><input name="registrationNo" readonly><input type="hidden" name="registrationNumberSource" value="${esc(preset?.profile?.registrationNumberSource || (editingDrugId ? 'LEGACY' : 'AUTO'))}"><button type="button" class="ghost" id="registration-no-toggle">✏️ Manual edit / ແກ້ເອງ</button></div><small>Auto: ຢສ-[F/L/R]-YYYYMM-NNNN · manual override is preserved in the audit trail.</small></label><label><span>Status</span><select name="registrationStatus"><option>DRAFT</option><option>SUBMITTED</option><option>UNDER_REVIEW</option><option>ACTIVE</option><option>SUSPENDED</option><option>EXPIRED</option></select></label><label><span>DLF No. / ເລກທີກົມ</span><input name="dlfNo"></label><label><span>DLF Date / ວັນທີອະນຸມັດ-ລົງນາມ</span><input name="dlfDate" type="date"></label><label><span>Issue Date / ວັນອອກ</span><input name="issueDate" type="date" readonly></label><label><span>Valid Years / ອາຍຸທະບຽນ</span><select name="validYears"><option value="">— Select —</option><option value="NONE">No fixed expiry / ບໍ່ກຳນົດ</option><option value="2">2 years</option><option value="3">3 years</option><option value="4">4 years</option><option value="5">5 years</option><option value="6">6 years</option></select></label><label><span>Expiry Date / ວັນໝົດອາຍຸ</span><input name="expiryDate" type="date" readonly></label><label><span>GMP Reference</span><input name="gmpReference"></label><label><span>CPP Reference</span><input name="cppReference"></label><label class="wide"><span>Contraindications</span><textarea name="contraindications"></textarea></label><label class="wide"><span>Warnings</span><textarea name="warnings"></textarea></label><label class="wide"><span>Notes</span><textarea name="notes"></textarea></label>
   <div class="form-section-title">6. Packaging / Presentations — 1 ຂະໜາດ = 1 ເລກທະບຽນຍ່ອຍ = 1 ໃບທະບຽນ</div><div class="section-help">ຮັກສາ Sub code ຄົງທີ່; ການແກ້ໄຂຈະສ້າງ package version ໃໝ່ ແທນການລຶບປະຫວັດ.</div><div id="presentation-list" class="wide">${ps.map((p, i) => presentationRow(i, p)).join('')}</div><button type="button" id="add-presentation" class="ghost wide">+ Add Presentation / ເພີ່ມຂະໜາດ</button>`;
        bindPresentations();
        if (preset?.profile)
            fillForm(preset.profile);
        bindDrugRegulatoryControls(drugRef, preset?.profile || null);
    }
    else if (current.key === 'companies') {
        editingCompanyId = preset?.company?.id || null;
        companySiteContext = null;
        companyRegistrationCompanyId = null;
        $('#modal-title').textContent = (editingCompanyId ? 'ແກ້ໄຂບໍລິສັດ / Edit Company' : 'ເພີ່ມບໍລິສັດ / Add Company');
        $('#form-fields').innerHTML = `<div class="form-section-title">Company Master / ຂໍ້ມູນນິຕິບຸກຄົນ</div><div class="section-help">ບໍລິສັດ 1 ແຫ່ງ = 1 Master Record. ຢ່າສ້າງຊ້ຳເພາະມີຫຼາຍທີ່ຢູ່; ໃຫ້ເພີ່ມ Site/Facility ຫຼັງບັນທຶກ.</div><label><span>ຊື່ນິຕິບຸກຄົນ (ລາວ) *</span><input name="legalNameLo" required></label><label><span>Legal Name (English)</span><input name="legalNameEn"></label><label><span>Enterprise / Business No.</span><input name="enterpriseNo"></label><label><span>Tax No.</span><input name="taxNo"></label><label><span>Country</span><select name="countryId"><option value="">— Select —</option>${countryOpts}</select></label><label><span>Registration Date</span><input name="registrationDate" type="date"></label><label><span>Phone (general)</span><input name="phone"></label><label><span>Email (general)</span><input name="email" type="email"></label><label><span>Website</span><input name="website"></label><label><span>Status</span><select name="status"><option>ACTIVE</option><option>INACTIVE</option><option>SUSPENDED</option></select></label><label class="wide"><span>Company Roles / ບົດບາດ (ກົດ Command/Ctrl ເພື່ອເລືອກຫຼາຍ)</span><select name="roleCodes" multiple size="6">${companyRoleOpts}</select></label>`;
        if (preset?.company)
            fillForm(preset.company);
    }
    else if (current.key === 'veterinary_devices')
        $('#form-fields').innerHTML = `<div class="form-section-title">Veterinary Device / Equipment Master</div><label><span>Device Name *</span><input name="deviceName" required></label><label><span>Device Code</span><input name="deviceCode"></label><label><span>Brand</span><input name="brand"></label><label><span>Model</span><input name="model"></label><label><span>Category</span><input name="deviceCategory"></label><label><span>Status</span><select name="authorizationStatus"><option>DRAFT</option><option>UNDER_REVIEW</option><option>AUTHORIZED</option><option>ACTIVE</option><option>SUSPENDED</option></select></label><label class="wide"><span>Intended Use</span><textarea name="intendedUse"></textarea></label><label><span>Manufacturer</span><input name="manufacturerName"></label><label><span>Country</span><input name="manufacturerCountry"></label><label><span>Importer</span><select name="importerCompanyId"><option value="">—</option>${companyOpts}</select></label><label><span>Registration / Authorization No.</span><input name="registrationNo"></label><label class="wide"><span>Technical Specification</span><textarea name="technicalSpecification"></textarea></label><label class="wide"><span>Instructions for Use</span><textarea name="instructionsForUse"></textarea></label>`;
    else if (current.key === 'import_plans')
        $('#form-fields').innerHTML = `<div class="form-section-title">Annual Trade Plan — Plan vs Actual Ready</div><div class="section-help">Specific product: track Quantity/Value. Category/Summary plan such as “20 ລາຍການ”: use COUNT_VALUE so LVSP never subtracts bottles/boxes/items from an item count.</div><label><span>Plan No. *</span><input name="planNo" required></label><label><span>Year *</span><input name="planYear" type="number" value="${new Date().getFullYear()}" required></label><label><span>Company *</span><select name="companyId" required><option value="">— Select —</option>${companyOpts}</select></label><label><span>Office / Site used for this plan</span><select name="companySiteId"><option value="">— Select site —</option>${siteOpts}</select></label><label><span>Work Area *</span><select name="serviceType" required><option value="VET_DRUG_DEVICE">Veterinary Drugs & Devices</option><option value="ANIMAL_FEED" disabled>Animal Feed & Ingredients — DVS scope unconfirmed</option><option value="ANIMAL_PRODUCT" disabled>Animal Products — shared/confirm responsibility</option></select></label><label><span>Movement Type *</span><select name="movementType" required><option>IMPORT</option><option>EXPORT</option><option>TRANSIT</option></select></label><label><span>Application Date</span><input name="applicationDate" type="date"></label><label><span>Approval No.</span><input name="approvalNo"></label><label><span>Status</span><select name="status"><option>DRAFT</option><option>SUBMITTED</option><option>APPROVED</option></select></label><div class="form-section-title">First Plan Item</div><label><span>Line Mode</span><select name="lineMode"><option value="ITEM">Specific Item</option><option value="SUMMARY_GROUP">Category / Summary Group</option></select></label><label><span>Tracking Basis</span><select name="trackingBasis"><option value="QUANTITY_VALUE">Quantity + Value</option><option value="QUANTITY">Quantity only</option><option value="VALUE">Value only</option><option value="COUNT_VALUE">Item Count + Value</option><option value="REFERENCE_ONLY">Reference only</option></select></label><label><span>Item Type</span><select name="itemType">${itemTypes}</select></label><label><span>Item / Category Name</span><input name="itemName"></label><label><span>Product</span><select name="productId"><option value="">—</option>${productOpts}</select></label><label><span>Device</span><select name="deviceId"><option value="">—</option>${deviceOpts}</select></label><label><span>Planned Qty</span><input name="plannedQuantity" type="number" step="0.001"></label><label><span>Unit</span><input name="unitCode"></label><label><span>Planned Item Count</span><input name="plannedItemCount" type="number" min="0"></label><label><span>Planned Value USD</span><input name="plannedValue" type="number" step="0.01"></label><label><span>Category Code</span><input name="categoryCode" placeholder="e.g. VET_DEVICE"></label>`;
    else if (current.key === 'import_plan_items')
        $('#form-fields').innerHTML = `<div class="form-section-title">Annual Plan Item — Safe Tracking</div><div class="section-help">Do not use QUANTITY for a mixed-unit category plan. Example: “20 ລາຍການ” should use COUNT_VALUE; specific “5,000 bottles” can use QUANTITY_VALUE.</div><label><span>Annual Plan *</span><select name="planId" required><option value="">— Select —</option>${planOpts}</select></label><label><span>Item No. *</span><input name="itemNo" type="number" min="1" required></label><label><span>Line Mode</span><select name="lineMode"><option value="ITEM">Specific Item</option><option value="SUMMARY_GROUP">Category / Summary Group</option></select></label><label><span>Tracking Basis *</span><select name="trackingBasis"><option value="QUANTITY_VALUE">Quantity + Value</option><option value="QUANTITY">Quantity only</option><option value="VALUE">Value only</option><option value="COUNT_VALUE">Item Count + Value</option><option value="REFERENCE_ONLY">Reference only</option></select></label><label><span>Category Code</span><input name="categoryCode"></label><label><span>Item Type *</span><select name="itemType">${itemTypes}</select></label><label><span>Item / Category Name *</span><input name="itemName" required></label><label><span>Registered Product</span><select name="productId"><option value="">—</option>${productOpts}</select></label><label><span>Veterinary Device</span><select name="deviceId"><option value="">—</option>${deviceOpts}</select></label><label><span>Registration No.</span><input name="registrationNo"></label><label><span>Package</span><input name="packageDescription"></label><label><span>Planned Qty</span><input name="plannedQuantity" type="number" step="0.001" value="0"></label><label><span>Unit</span><input name="unitCode"></label><label><span>Planned Item Count</span><input name="plannedItemCount" type="number" min="0"></label><label><span>Planned Value USD</span><input name="plannedValue" type="number" step="0.01"></label><label><span>Currency</span><input name="currencyCode" value="USD"></label>`;
    else if (current.key === 'import_applications')
        $('#form-fields').innerHTML = `<div class="form-section-title">Import / Export / Transit Application — ຄຳຮ້ອງດຽວຮອງຮັບ mixed items</div><label><span>Movement Type *</span><select name="importType" required><option>IMPORT</option><option>EXPORT</option><option>TRANSIT</option></select></label><label><span>Application No. *</span><input name="applicationNo" required></label><label><span>Application Date *</span><input name="applicationDate" type="date" required></label><label><span>Company *</span><select name="companyId" required><option value="">— Select —</option>${companyOpts}</select></label><label><span>Office / Site submitting application</span><select name="companySiteId"><option value="">— Select site —</option>${siteOpts}</select></label><label><span>Annual Plan</span><select name="planId"><option value="">—</option>${planOpts}</select></label><div class="form-section-title">Movement / Route</div><label><span>Origin Country</span><input name="originCountry"></label><label><span>Destination Country</span><input name="destinationCountry"></label><label><span>Entry Checkpoint</span><input name="borderCheckpoint"></label><label><span>Exit Checkpoint</span><input name="checkpointOut"></label><label><span>Transport Mode</span><input name="transportMode"></label><label><span>Purpose</span><input name="purpose"></label><div class="form-section-title">Decision / Permit / Clearance</div><label><span>Status</span><select name="status"><option>DRAFT</option><option>SUBMITTED</option><option>SCREENING</option><option>UNDER_REVIEW</option><option>APPROVED</option><option>CLEARED</option><option>CLOSED</option><option>REJECTED</option><option>CANCELLED</option></select></label><label><span>Decision No.</span><input name="decisionNo"></label><label><span>Decision Date</span><input name="decisionDate" type="date"></label><label><span>Permit No.</span><input name="permitNo"></label><label><span>Valid From</span><input name="validFrom" type="date"></label><label><span>Permit Valid To</span><input name="permitValidTo" type="date"></label><label><span>Cleared Date</span><input name="clearedDate" type="date"></label><label><span>Signed By</span><input name="signedBy"></label><label><span>Invoice No.</span><input name="invoiceNo"></label><label><span>Invoice Date</span><input name="invoiceDate" type="date"></label><div class="form-section-title">First Item (medicine / vaccine / device may coexist)</div><label><span>Plan Item / ອ້າງອີງແຜນ</span><select name="planItemId"><option value="">— Auto/Manual Link —</option>${planItemOpts}</select></label><label><span>Item Type</span><select name="itemType">${itemTypes}</select></label><label><span>Item Name</span><input name="itemName"></label><label><span>Registered Product</span><select name="productId"><option value="">—</option>${productOpts}</select></label><label><span>Veterinary Device</span><select name="deviceId"><option value="">—</option>${deviceOpts}</select></label><label><span>Requested Qty</span><input name="requestedQuantity" type="number" step="0.001"></label><label><span>Approved Qty</span><input name="approvedQuantity" type="number" step="0.001"></label><label><span>Cleared / Actual Qty</span><input name="clearedQuantity" type="number" step="0.001"></label><label><span>Unit</span><input name="unitCode"></label><label><span>Item Value USD</span><input name="itemValue" type="number" step="0.01"></label>`;
    else if (current.key === 'import_application_items')
        $('#form-fields').innerHTML = `<div class="form-section-title">Import Item — Link to Annual Plan</div><label><span>Import Application *</span><select name="applicationId" required><option value="">— Select —</option>${appOpts}</select></label><label><span>Plan Item / ລາຍການແຜນ</span><select name="planItemId"><option value="">— Select / Auto match —</option>${planItemOpts}</select></label><label><span>Item No. *</span><input name="itemNo" type="number" min="1" required></label><label><span>Item Type *</span><select name="itemType">${itemTypes}</select></label><label><span>Item Name *</span><input name="itemName" required></label><label><span>Registered Product</span><select name="productId"><option value="">—</option>${productOpts}</select></label><label><span>Veterinary Device</span><select name="deviceId"><option value="">—</option>${deviceOpts}</select></label><label><span>Registration No.</span><input name="registrationNo"></label><label><span>Package</span><input name="packageDescription"></label><label><span>Requested Qty *</span><input name="requestedQuantity" type="number" step="0.001" required></label><label><span>Approved Qty</span><input name="approvedQuantity" type="number" step="0.001"></label><label><span>Cleared / Actual Qty</span><input name="clearedQuantity" type="number" step="0.001"></label><label><span>Unit</span><input name="unitCode"></label><label><span>Item Value USD</span><input name="itemValue" type="number" step="0.01"></label><label><span>Antimicrobial?</span><select name="antimicrobial"><option value="false">No</option><option value="true">Yes</option></select></label><label><span>Active substance kg</span><input name="activeSubstanceKg" type="number" step="0.000001"></label>`;
    else if (current.key === 'export_applications') {
        const speciesOptsHtml = await options('/species', (x) => x.nameLo || x.nameEn || x.code);
        const unitOptsHtml = await options('/units', (x) => x.nameLo || x.nameEn || x.code);
        $('#form-fields').innerHTML = `<div class="form-section-title">${lang === 'lo' ? 'ຄຳຮ້ອງສົ່ງອອກ' : 'Export Application'}</div><label><span>Company / ບໍລິສັດ *</span><select name="companyId" required><option value="">— Select —</option>${companyOpts}</select></label><label><span>Work Area / ປະເພດບໍລິການ *</span><select name="serviceType" required><option value="ANIMAL_FEED">Animal Feed &amp; Ingredients / ອາຫານສັດ</option><option value="ANIMAL_PRODUCT">Animal Products / ຜະລິດຕະພັນສັດ</option><option value="LIVE_ANIMAL">Live Animals / ສັດມີຊີວິດ</option><option value="PET_MOVEMENT">Pet Movement / ການເຄື່ອນຍ້າຍສັດລ້ຽງ</option></select></label><label><span>Destination Country / ປະເທດປາຍທາງ *</span><select name="destinationCountryId" required><option value="">— Select —</option>${countryOpts}</select></label><label><span>Intended Shipment From</span><input name="shipmentFrom" type="date"></label><label><span>Intended Shipment To</span><input name="shipmentTo" type="date"></label><label class="wide"><span>Notes</span><textarea name="notes"></textarea></label><div class="form-section-title">${lang === 'lo' ? 'ລາຍການສິນຄ້າ' : 'Items'}</div><div id="export-item-list" class="wide">${exportItemRow(0, speciesOptsHtml, unitOptsHtml)}</div><button type="button" id="add-export-item" class="ghost wide">+ ${lang === 'lo' ? 'ເພີ່ມລາຍການ' : 'Add Item'}</button>`;
        bindExportItems(speciesOptsHtml, unitOptsHtml);
    }
    else
        $('#form-fields').innerHTML = current.fields.map((f, i) => `<label><span>${esc(pretty(f))}</span><input name="${esc(f)}" ${i === 0 ? 'required' : ''}></label>`).join('');
    bindCompanySiteFilters();
    bindPlanItemFilter();
    bindPlanTrackingControls();
    $('#create-modal').showModal();
}
function contactValue(site, type) { return (site?.contacts || []).find((x) => String(x.contactType || '').toUpperCase() === type)?.contactValue || ''; }
function bindCompanySiteFilters() {
    const pairs = [['holderCompanyId', 'holderSiteId'], ['importerCompanyId', 'importerSiteId'], ['manufacturerCompanyId', 'manufacturerSiteId'], ['distributorCompanyId', 'distributorSiteId'], ['companyId', 'companySiteId']];
    for (const [companyName, siteName] of pairs) {
        const c = document.querySelector(`[name="${companyName}"]`);
        const st = document.querySelector(`[name="${siteName}"]`);
        if (!c || !st)
            continue;
        const refresh = () => { const company = c.value; Array.from(st.options).forEach((o) => { if (!o.value)
            return; const match = !company || o.dataset.company === company; o.disabled = !match; o.hidden = !match; }); if (st.value && st.selectedOptions[0]?.disabled)
            st.value = ''; };
        c.addEventListener('change', refresh);
        refresh();
    }
}
async function openCompanySiteForm(companyId, site = null) {
    editingDrugId = null;
    editingCompanyId = null;
    companyRegistrationCompanyId = null;
    companySiteContext = { companyId, siteId: site?.id || undefined };
    $('#modal-title').textContent = site ? 'ແກ້ໄຂສະຖານທີ່ / Edit Site' : 'ເພີ່ມທີ່ຢູ່/ສະຖານທີ່ / Add Site';
    $('#form-fields').innerHTML = `<div class="form-section-title">Physical Site / Facility</div><div class="section-help">ສຳນັກງານ, ໂຮງງານ, ສາງ, ສາຂາ ແມ່ນ Site ພາຍໃຕ້ Company Master ດຽວ. ຢ່າສ້າງ Company ຊ້ຳເພາະທີ່ຢູ່ຕ່າງກັນ.</div><label><span>Site Role *</span><select name="siteRoleCode" required>${siteRoleOptions(site?.siteRoleCode || 'BUSINESS_SITE')}</select></label><label><span>Facility/Site No.</span><input name="facilityNo" value="${esc(site?.facilityNo || '')}"></label><label><span>Site Name (Lao)</span><input name="nameLo" value="${esc(site?.nameLo || site?.facilityNameLo || '')}"></label><label><span>Site Name (English)</span><input name="nameEn" value="${esc(site?.nameEn || site?.facilityNameEn || '')}"></label><label class="wide"><span>Address (Lao) *</span><textarea name="addressTextLo" required>${esc(site?.addressTextLo || '')}</textarea></label><label class="wide"><span>Address (English)</span><textarea name="addressTextEn">${esc(site?.addressTextEn || '')}</textarea></label><label><span>Phone</span><input name="phone" value="${esc(contactValue(site, 'PHONE'))}"></label><label><span>Email</span><input name="email" type="email" value="${esc(contactValue(site, 'EMAIL'))}"></label><label><span>Website</span><input name="website" value="${esc(contactValue(site, 'WEBSITE'))}"></label><label><span>Fax</span><input name="fax" value="${esc(contactValue(site, 'FAX'))}"></label><label><span>Primary for this role?</span><select name="isPrimary"><option value="false" ${site?.isPrimary ? '' : 'selected'}>No</option><option value="true" ${site?.isPrimary ? 'selected' : ''}>Yes</option></select></label><label><span>Status</span><select name="status"><option value="ACTIVE" ${site?.status === 'INACTIVE' ? '' : 'selected'}>ACTIVE</option><option value="INACTIVE" ${site?.status === 'INACTIVE' ? 'selected' : ''}>INACTIVE</option></select></label><label><span>Valid From</span><input name="validFrom" type="date" value="${esc(String(site?.validFrom || '').slice(0, 10))}"></label><label><span>Valid To</span><input name="validTo" type="date" value="${esc(String(site?.validTo || '').slice(0, 10))}"></label><label class="wide"><span>Notes</span><textarea name="notes">${esc(site?.notes || '')}</textarea></label>`;
    $('#create-modal').showModal();
}
async function openCompanyRegistrationForm(companyId) {
    editingDrugId = null;
    editingCompanyId = null;
    companySiteContext = null;
    companyRegistrationCompanyId = companyId;
    const siteOpts = await companySiteOptions(companyId);
    $('#modal-title').textContent = 'ເພີ່ມໃບອະນຸຍາດ/ທະບຽນບໍລິສັດ';
    $('#form-fields').innerHTML = `<div class="form-section-title">Company Licence / External Registration</div><label><span>Type *</span><select name="registrationType"><option>BUSINESS_LICENSE</option><option>IMPORTER_LICENSE</option><option>MANUFACTURER_LICENSE</option><option>GMP_CERTIFICATE</option><option>DISTRIBUTOR_LICENSE</option><option>OTHER</option></select></label><label><span>Registration / Licence No. *</span><input name="registrationNo" required></label><label><span>Related Site (optional)</span><select name="facilityId"><option value="">— Company level —</option>${siteOpts}</select></label><label><span>Issuing Authority</span><input name="issuingAuthority"></label><label><span>Issue Date</span><input name="issueDate" type="date"></label><label><span>Expiry Date</span><input name="expiryDate" type="date"></label><label><span>Status</span><select name="status"><option>ACTIVE</option><option>EXPIRED</option><option>SUSPENDED</option><option>REVOKED</option></select></label><label class="wide"><span>Notes</span><textarea name="notes"></textarea></label>`;
    $('#create-modal').showModal();
}
function cleaned(body) { const x = {}; for (const [k, v] of Object.entries(body)) {
    if (v === '')
        continue;
    if (v === 'true')
        x[k] = true;
    else if (v === 'false')
        x[k] = false;
    else
        x[k] = v;
} return x; }
async function submitForm(ev) {
    ev.preventDefault();
    const form = ev.target;
    const fd = new FormData(form);
    const selectedRoleCodes = fd.getAll('roleCodes').map(String);
    const b = cleaned(Object.fromEntries(fd.entries()));
    delete b.roleCodes;
    let createdTargetId = null;
    let createdTargetResource = null;
    try {
        if (companySiteContext) {
            const ctx = { ...companySiteContext };
            if (ctx.siteId)
                await api(`/company-sites/${encodeURIComponent(ctx.siteId)}`, { method: 'PATCH', body: JSON.stringify(b) });
            else
                await api(`/companies/${encodeURIComponent(ctx.companyId)}/sites`, { method: 'POST', body: JSON.stringify(b) });
            companySiteContext = null;
            $('#create-modal').close();
            form.reset();
            await Promise.all([loadModule(), loadStats()]);
            toast('ບັນທຶກສະຖານທີ່ສຳເລັດ');
            return openCompanyDetail(ctx.companyId);
        }
        if (companyRegistrationCompanyId) {
            const cid = companyRegistrationCompanyId;
            await api(`/companies/${encodeURIComponent(cid)}/registrations`, { method: 'POST', body: JSON.stringify(b) });
            companyRegistrationCompanyId = null;
            $('#create-modal').close();
            form.reset();
            toast('ບັນທຶກໃບອະນຸຍາດສຳເລັດ');
            return openCompanyDetail(cid);
        }
        if (current.key === 'companies') {
            let cid = editingCompanyId;
            if (cid)
                await api(`/companies/${encodeURIComponent(cid)}`, { method: 'PATCH', body: JSON.stringify(b) });
            else {
                const cr = await api('/companies', { method: 'POST', body: JSON.stringify(b) });
                cid = cr.data.id;
            }
            if (cid)
                await api(`/companies/${encodeURIComponent(cid)}/roles`, { method: 'PUT', body: JSON.stringify({ roleCodes: selectedRoleCodes }) });
            editingCompanyId = null;
        }
        else if (current.key === 'drug_registrations') {
            if (b.validYears === 'NONE') {
                b.validYears = null;
                b.expiryDate = null;
            }
            else if (b.validYears !== undefined)
                b.validYears = Number(b.validYears);
            syncDrugValidity();
            const vf = new FormData(form);
            if (vf.get('issueDate'))
                b.issueDate = String(vf.get('issueDate'));
            if (vf.get('expiryDate'))
                b.expiryDate = String(vf.get('expiryDate'));
            const presentations = readPresentations();
            if (!presentations.length || presentations.some(p => !p.packDescription))
                throw new Error('Please enter at least one packaging/presentation');
            if (editingDrugId)
                await api(`/drug-registrations/${encodeURIComponent(editingDrugId)}/complete`, { method: 'PATCH', body: JSON.stringify({ profile: b, presentations }) });
            else {
                const cr = await api('/drug-registrations/complete', { method: 'POST', body: JSON.stringify({ profile: b, presentations }) });
                createdTargetId = cr.data?.registration?.id || null;
                createdTargetResource = 'drug_registration';
            }
        }
        else if (current.key === 'import_plans') {
            const first = { itemType: b.itemType, itemName: b.itemName, productId: b.productId, deviceId: b.deviceId, lineMode: b.lineMode || 'ITEM', trackingBasis: b.trackingBasis || 'QUANTITY_VALUE', categoryCode: b.categoryCode || null, plannedItemCount: b.plannedItemCount !== undefined ? Number(b.plannedItemCount) : null, plannedQuantity: Number(b.plannedQuantity || 0), plannedValue: b.plannedValue !== undefined ? Number(b.plannedValue) : null, unitCode: b.unitCode };
            for (const k of ['itemType', 'itemName', 'productId', 'deviceId', 'lineMode', 'trackingBasis', 'categoryCode', 'plannedItemCount', 'plannedQuantity', 'plannedValue', 'unitCode'])
                delete b[k];
            const planProfile = { movementType: String(b.movementType || 'IMPORT').toUpperCase(), serviceType: String(b.serviceType || 'VET_DRUG_DEVICE').toUpperCase() };
            delete b.movementType;
            delete b.serviceType;
            b.planYear = Number(b.planYear);
            const r = await api('/import-plans', { method: 'POST', body: JSON.stringify(b) });
            await api(`/import-plans/${encodeURIComponent(r.data.id)}/profile`, { method: 'PUT', body: JSON.stringify(planProfile) });
            createdTargetId = r.data.id;
            createdTargetResource = 'import_plan';
            if (first.itemName) {
                const ir = await api('/import-plan-items', { method: 'POST', body: JSON.stringify({ itemType: first.itemType, itemName: first.itemName, productId: first.productId, deviceId: first.deviceId, lineMode: first.lineMode, plannedItemCount: first.plannedItemCount, plannedQuantity: first.plannedQuantity, plannedValue: first.plannedValue, unitCode: first.unitCode, planId: r.data.id, itemNo: 1 }) });
                await api(`/legacy-parity/import-plan-item-profile/${encodeURIComponent(ir.data.id)}`, { method: 'PUT', body: JSON.stringify({ lineMode: first.lineMode, trackingBasis: first.trackingBasis, scopeType: first.lineMode === 'SUMMARY_GROUP' ? 'CATEGORY' : 'ITEM', categoryCode: first.categoryCode, plannedItemCount: first.plannedItemCount, plannedValueUsd: first.plannedValue }) });
            }
        }
        else if (current.key === 'import_applications') {
            const first = { planItemId: b.planItemId || null, itemType: b.itemType, itemName: b.itemName, productId: b.productId, deviceId: b.deviceId, requestedQuantity: Number(b.requestedQuantity || 0), approvedQuantity: b.approvedQuantity !== undefined ? Number(b.approvedQuantity) : null, clearedQuantity: b.clearedQuantity !== undefined ? Number(b.clearedQuantity) : null, unitCode: b.unitCode, itemValue: b.itemValue !== undefined ? Number(b.itemValue) : null };
            for (const k of ['planItemId', 'itemType', 'itemName', 'productId', 'deviceId', 'requestedQuantity', 'approvedQuantity', 'clearedQuantity', 'unitCode', 'itemValue'])
                delete b[k];
            const r = await api('/import-applications', { method: 'POST', body: JSON.stringify(b) });
            createdTargetId = r.data.id;
            createdTargetResource = 'import_application';
            if (first.itemName)
                await api('/import-application-items', { method: 'POST', body: JSON.stringify({ ...first, applicationId: r.data.id, itemNo: 1 }) });
        }
        else if (current.key === 'import_plan_items') {
            const profile = { lineMode: b.lineMode || 'ITEM', trackingBasis: b.trackingBasis || 'QUANTITY_VALUE', scopeType: (b.lineMode || 'ITEM') === 'SUMMARY_GROUP' ? 'CATEGORY' : 'ITEM', categoryCode: b.categoryCode || null, plannedItemCount: b.plannedItemCount !== undefined ? Number(b.plannedItemCount) : null, plannedValueUsd: b.plannedValue !== undefined ? Number(b.plannedValue) : null };
            delete b.trackingBasis;
            delete b.categoryCode;
            for (const k of ['itemNo', 'plannedQuantity', 'plannedValue', 'plannedItemCount'])
                if (b[k] !== undefined)
                    b[k] = Number(b[k]);
            const ir = await api('/import-plan-items', { method: 'POST', body: JSON.stringify(b) });
            await api(`/legacy-parity/import-plan-item-profile/${encodeURIComponent(ir.data.id)}`, { method: 'PUT', body: JSON.stringify(profile) });
        }
        else if (current.key === 'export_applications') {
            const exportItems = readExportItems();
            if (!exportItems.length)
                throw new Error(lang === 'lo' ? 'ກະລຸນາເພີ່ມຢ່າງໜ້ອຍ 1 ລາຍການ' : 'Please add at least one item');
            const er = await api('/export-applications', { method: 'POST', body: JSON.stringify({ ...b, items: exportItems }) });
            createdTargetId = er.data?.application?.id || null;
            createdTargetResource = 'export_application';
            toast((lang === 'lo' ? 'ຍື່ນຄຳຮ້ອງສຳເລັດ — ເລກອ້າງອີງພາຍໃນ: ' : 'Submitted — internal reference: ') + (er.data?.application?.caseNo || ''));
        }
        else {
            for (const k of ['itemNo', 'plannedQuantity', 'plannedValue', 'plannedItemCount', 'requestedQuantity', 'approvedQuantity', 'clearedQuantity', 'itemValue', 'activeSubstanceKg'])
                if (b[k] !== undefined)
                    b[k] = Number(b[k]);
            await api(current.path, { method: 'POST', body: JSON.stringify(b) });
        }
        if (activeServiceDraftId && createdTargetId && createdTargetResource) {
            try {
                await api(`/service-drafts/${encodeURIComponent(activeServiceDraftId)}/link`, { method: 'POST', body: JSON.stringify({ targetResource: createdTargetResource, targetId: createdTargetId }) });
                toast(lang === 'lo' ? 'ບັນທຶກ ແລະ ເຊື່ອມ Guided Draft ສຳເລັດ' : 'Saved and linked to guided draft');
            }
            catch (e) {
                toast('Saved, but draft link failed: ' + e.message, true);
            }
            activeServiceDraftId = null;
        }
        $('#create-modal').close();
        form.reset();
        editingDrugId = null;
        editingCompanyId = null;
        companySiteContext = null;
        companyRegistrationCompanyId = null;
        if (temporaryWorkspaceReturnKey) {
            const m = moduleByKey(temporaryWorkspaceReturnKey);
            temporaryWorkspaceReturnKey = null;
            if (m) {
                current = m;
                renderNav();
            }
        }
        await Promise.all([loadModule(), loadStats()]);
        if (!createdTargetId || !createdTargetResource)
            toast(lang === 'lo' ? 'ບັນທຶກສຳເລັດ' : 'Saved');
    }
    catch (e) {
        toast(e.message, true);
    }
}
function detailRow(k, v) { return `<div class="detail-row"><div class="detail-key">${esc(k)}</div><div class="detail-value">${v || '—'}</div></div>`; }
function closeDetail() { $('#detail-modal').close(); $('#detail-body').innerHTML = ''; $('#detail-actions').innerHTML = ''; }
async function openDetail(id) {
    try {
        if (current.key === 'companies')
            return openCompanyDetail(id);
        if (current.key === 'drug_registrations')
            return openDrugDetail(id);
        if (current.key === 'import_applications')
            return openImportDetail(id);
        if (current.key === 'import_plans')
            return openPlanDetail(id);
        if (current.key === 'export_applications')
            return openExportDetail(id);
        const r = await api(`${current.path}/${encodeURIComponent(id)}`);
        const x = r.data || {};
        $('#detail-title').textContent = t(current);
        $('#detail-subtitle').textContent = id;
        $('#detail-body').innerHTML = '<div class="detail-section"><h3>Record</h3>' + Object.entries(x).filter(([, v]) => v !== null && v !== '').map(([k, v]) => detailRow(pretty(k), esc(v))).join('') + '</div>';
        $('#detail-actions').innerHTML = '<button class="ghost" id="detail-close-bottom">Close</button>';
        $('#detail-modal').showModal();
        $('#detail-close-bottom').onclick = closeDetail;
    }
    catch (e) {
        toast(e.message, true);
    }
}
async function openCompanyDetail(id) {
    const [r, dups] = await Promise.all([api(`/companies/${encodeURIComponent(id)}/complete`), api('/company-duplicate-candidates').catch(() => ({ data: [] }))]);
    const d = r.data, c = d.company || {}, sites = d.sites || [], regs = d.registrations || [], roles = d.roles || [], aliases = d.aliases || [], rel = d.related || {};
    const relatedDup = (dups.data || []).filter((x) => String(x.companyA?.id) === id || String(x.companyB?.id) === id);
    $('#detail-title').textContent = c.legalNameLo || c.legalNameEn || 'Company';
    $('#detail-subtitle').textContent = [c.legalNameEn, c.enterpriseNo].filter(Boolean).join(' · ');
    const siteCards = sites.map((x) => { const contacts = (x.contacts || []).map((z) => `${esc(z.contactType)}: ${esc(z.contactValue)}`).join(' · '); return `<div class="company-site-card"><div class="company-site-head"><div><b>${esc(x.siteRoleNameLo || x.siteRoleNameEn || x.siteRoleCode)}</b>${x.isPrimary ? '<span class="site-primary">Primary</span>' : ''}</div><button class="mini-action company-site-edit" data-site="${esc(x.id)}">✏️ ແກ້ໄຂ</button></div><div>${esc(x.nameLo || x.facilityNameLo || x.nameEn || '')}</div><div class="company-site-address">${esc(x.addressTextLo || x.addressTextEn || '—')}</div>${contacts ? `<div class="company-site-contact">${contacts}</div>` : ''}<div class="company-site-meta">${esc(x.facilityNo || '')} ${x.validFrom ? `· ${fmtDate(x.validFrom)}` : ''}${x.validTo ? ` → ${fmtDate(x.validTo)}` : ''} · ${esc(x.status || '')}</div></div>`; }).join('');
    const regRows = regs.map((x) => `<tr><td>${esc(x.registrationType)}</td><td><b>${esc(x.registrationNo)}</b></td><td>${esc(x.issuingAuthority)}</td><td>${fmtDate(x.issueDate)}</td><td>${fmtDate(x.expiryDate)}</td><td>${esc(x.status)}</td></tr>`).join('');
    const dupHtml = relatedDup.length ? `<div class="detail-section duplicate-review"><h3>⚠ Potential Duplicate Review / ກວດຄືນລາຍການອາດຊ້ຳ</h3><div class="duplicate-note">LVSP ບໍ່ລວມບໍລິສັດອັດຕະໂນມັດ. ລາຍການນີ້ຕ້ອງໃຫ້ພະນັກງານກວດຊື່, ເລກນິຕິບຸກຄົນ/ໃບທຸລະກິດ ແລະ ປະຫວັດກ່ອນລວມ.</div>${relatedDup.map((x) => { const other = String(x.companyA?.id) === id ? x.companyB : x.companyA; return `<div class="duplicate-candidate"><b>${esc(other?.legalNameLo || other?.legalNameEn || '')}</b> <span>${esc((x.reasons || []).join(', '))}</span></div>`; }).join('')}</div>` : '';
    $('#detail-body').innerHTML = `<div class="company-master-rule"><b>Single Source of Truth:</b> 1 legal company = 1 Company Master; many offices/factories/warehouses = many Sites/Facilities under that company.</div><div class="detail-section"><h3>ນິຕິບຸກຄົນ / Legal Entity</h3>${detailRow('Legal Name (Lao)', esc(c.legalNameLo))}${detailRow('Legal Name (English)', esc(c.legalNameEn))}${detailRow('Enterprise / Business No.', esc(c.enterpriseNo))}${detailRow('Tax No.', esc(c.taxNo))}${detailRow('General Phone', esc(c.phone))}${detailRow('General Email', esc(c.email))}${detailRow('Website', esc(c.website))}${detailRow('Registration Date', fmtDate(c.registrationDate))}${detailRow('Status', `<span class="status-pill">${esc(c.status)}</span>`)}</div><div class="detail-section"><h3>ບົດບາດ / Roles</h3><div class="company-role-list">${roles.length ? roles.map((x) => `<span>${esc(x.nameLo || x.nameEn || x.code)}</span>`).join('') : '—'}</div></div><div class="detail-section"><h3>ທີ່ຢູ່ / Sites & Facilities (${sites.length})</h3><div class="company-site-list">${siteCards || '<div class="empty-box">ຍັງບໍ່ມີ Site/Address — ກົດ “+ ເພີ່ມທີ່ຢູ່/ສະຖານທີ່”</div>'}</div></div><div class="detail-section"><h3>ໃບອະນຸຍາດ / External Registrations</h3><div class="detail-table-wrap"><table><thead><tr><th>Type</th><th>No.</th><th>Authority</th><th>Issue</th><th>Expiry</th><th>Status</th></tr></thead><tbody>${regRows || '<tr><td colspan="6">—</td></tr>'}</tbody></table></div></div><div class="detail-section"><h3>ການນຳໃຊ້ໃນ LVSP</h3>${detailRow('Registration holder products', esc(rel.holderProducts || 0))}${detailRow('Importer products', esc(rel.importerProducts || 0))}${detailRow('Manufacturer products', esc(rel.manufacturerProducts || 0))}${detailRow('Import applications', esc(rel.importApplications || 0))}${detailRow('Annual import plans', esc(rel.importPlans || 0))}${aliases.length ? detailRow('Aliases / Legacy names', aliases.map((x) => esc(x.aliasName)).join('<br>')) : ''}</div>${dupHtml}`;
    $('#detail-actions').innerHTML = '<button class="ghost" id="company-add-reg">📄 + ໃບອະນຸຍາດ</button><button class="ghost" id="company-add-site">📍 + ເພີ່ມທີ່ຢູ່/ສະຖານທີ່</button><button class="primary" id="company-edit">✏️ ແກ້ໄຂບໍລິສັດ</button>';
    $('#detail-modal').showModal();
    $('#company-edit').onclick = () => { closeDetail(); editingCompanyId = id; openCreate({ company: c, roles }); };
    $('#company-add-site').onclick = () => { closeDetail(); openCompanySiteForm(id); };
    $('#company-add-reg').onclick = () => { closeDetail(); openCompanyRegistrationForm(id); };
    document.querySelectorAll('.company-site-edit').forEach(b => b.addEventListener('click', e => { const sid = e.currentTarget.dataset.site; const site = sites.find((x) => String(x.id) === String(sid)); closeDetail(); openCompanySiteForm(id, site); }));
}
async function openDrugDetail(id) {
    const r = await api(`/drug-registrations/${encodeURIComponent(id)}/complete`);
    const d = r.data, p = d.profile, ps = d.presentations || [];
    $('#detail-title').textContent = p.tradeName || 'Drug Registration';
    $('#detail-subtitle').textContent = p.registrationNo || id;
    const wd = [['ຊີ້ນ / Meat', p.withdrawalMeat], ['ນົມ / Milk', p.withdrawalMilk], ['ໄຂ່ / Eggs', p.withdrawalEggs], ['ນ້ຳເຜິ້ງ / Honey', p.withdrawalHoney], ['ສັດນ້ຳ / Aquatic', p.withdrawalAquatic]].filter(([, v]) => v).map(([k, v]) => `${k}: ${esc(v)}`).join('<br>') || '—';
    const pres = ps.map((x, i) => `<div class="presentation-card"><div class="presentation-card-head"><div><b>${esc(x.subCode || String(i + 1))}</b> <span>${esc((p.registrationNo || '') + (ps.length > 1 ? '-' + (x.subCode || String(i + 1)) : ''))}</span></div><button class="mini-action pres-print" data-i="${i}">🖨 ພິມໃບທະບຽນ</button></div>${detailRow('Strength', esc(x.strengthText))}${detailRow('Packaging', esc(x.packDescription))}${detailRow('Target', esc(x.targetText))}${detailRow('Composition', (x.composition || []).map((c) => `${esc(c.ingredientName)} ${esc(c.quantityText)} ${esc(c.unitText)}${c.equivalenceText ? ' (' + esc(c.equivalenceText) + ')' : ''}`).join('<br>') || '—')}</div>`).join('');
    $('#detail-body').innerHTML = `<div class="detail-section"><h3>ການລະບຸຜະລິດຕະພັນ</h3>${detailRow('Registration Type', esc(p.registrationType))}${detailRow('Generic Name', esc(p.genericName))}${detailRow('Category', esc(p.category))}${detailRow('Dosage Group / Form', esc([p.dosageGroup, p.dosageForm].filter(Boolean).join(' · ')))}${detailRow('ATCvet', esc(p.atcvet))}${detailRow('Distribution', esc(p.distributionClassification))}${detailRow('Shelf life', esc(p.shelfLife))}${detailRow('Storage', esc(p.storageConditions))}</div><div class="detail-section"><h3>ຂະໜາດການຫຸ້ມຫໍ່ & ສ່ວນປະກອບ <small>(${ps.length} ຂະໜາດ · 1 ຂະໜາດ = 1 ໃບທະບຽນ)</small></h3>${pres || '—'}</div><div class="detail-section"><h3>ຂໍ້ມູນທາງຄລີນິກ & ຄວາມປອດໄພ</h3>${detailRow('Target Species', esc(p.targetSpecies))}${detailRow('Withdrawal Period', wd)}${detailRow('Indications', esc(p.indications))}${detailRow('Dosage & Administration', esc(p.dosageAdministration))}${detailRow('Route', esc(p.route))}${detailRow('Contraindications', esc(p.contraindications))}${detailRow('Warnings', esc(p.warnings))}</div><div class="detail-section"><h3>ນິຕິບຸກຄົນ, ສະຖານທີ່ & ການອອກທະບຽນ</h3>${detailRow('Registration Holder', esc(p.holderCompanyName))}${detailRow('Holder Office / Site', esc(p.holderAddress))}${detailRow('Importer', esc(p.importerCompanyName))}${detailRow('Importer Office / Site', esc(p.importerAddress))}${detailRow('Manufacturer', esc(p.manufacturerCompanyName || p.manufacturerName))}${detailRow('Manufacturer Country', esc(p.manufacturerCountry))}${detailRow('Manufacturing Site', esc(p.manufacturerSiteAddress || p.manufacturerAddress))}${detailRow('Distributor', esc(p.distributorCompanyName || p.distributorName))}${detailRow('Distribution Site', esc(p.distributorSiteAddress || p.distributorAddress))}${detailRow('Applicant', esc(p.applicantName))}${detailRow('Application No.', esc(p.applicationNo))}${detailRow('DLF No.', esc(p.dlfNo))}${detailRow('Issue / Expiry', `${fmtDate(p.issueDate)} → ${fmtDate(p.expiryDate)}`)}${detailRow('Status', `<span class="status-pill">${esc(p.registrationStatus)}</span>`)}</div>`;
    $('#detail-actions').innerHTML = `<button class="ghost" id="drug-operational">🗂 ແຟ້ມພິຈາລະນາ</button><button class="ghost" id="drug-memo">📄 ໃບກິດສຳພັນ</button>${ps.length > 1 ? `<button class="ghost" id="drug-print-all">🖨 ພິມທຸກຂະໜາດ (${ps.length})</button>` : `<button class="ghost" id="drug-print-one">🖨 ພິມໃບທະບຽນ</button>`}<button class="primary" id="drug-edit">✏️ ແກ້ໄຂ</button>`;
    $('#detail-modal').showModal();
    document.querySelectorAll('.pres-print').forEach(b => b.addEventListener('click', e => printDrugCertificate(id, Number(e.currentTarget.dataset.i))));
    $('#drug-operational').onclick = () => openVetDrugOperationalWorkspace(id, p);
    $('#drug-edit').onclick = async () => { closeDetail(); editingDrugId = id; await openCreate(d); };
    $('#drug-memo').onclick = () => openRegistrationBatchMemo(id);
    if (ps.length > 1)
        $('#drug-print-all').onclick = () => printDrugCertificate(id, null);
    else
        $('#drug-print-one').onclick = () => printDrugCertificate(id, 0);
}
async function openImportDetail(id) {
    const r = await api(`/import-applications/${encodeURIComponent(id)}/complete`);
    const a = r.data.application, items = r.data.items || [];
    $('#detail-title').textContent = `${a.applicationNo || ''} ${a.permitNo ? '· ' + a.permitNo : ''}`;
    $('#detail-subtitle').textContent = lang === 'lo' ? 'Import / Export / Transit — ຄຳຮ້ອງ / ໃບອະນຸຍາດ' : 'Import / Export / Transit application / permit';
    const rows = items.map((x) => `<tr><td>${esc(x.itemNo)}</td><td>${esc(x.legacyKind || x.itemType)}</td><td>${esc(x.itemName)}</td><td>${esc(x.registrationNo)}</td><td>${esc(x.packageDescription)}</td><td>${esc(x.requestedQuantity || 0)} ${esc(x.unitCode)}</td><td>${esc(x.approvedQuantity || '—')}</td><td>${esc(x.clearedPacks || x.clearedQuantity || '—')}</td><td>${esc(x.itemValue)}</td><td>${esc(x.eligibilityStatus || '')}</td></tr>`).join('');
    $('#detail-body').innerHTML = `<div class="detail-section"><h3>ຂໍ້ມູນຄຳຮ້ອງ / Permit</h3>${detailRow('Movement Type', `<span class="status-pill">${esc(a.importType || 'IMPORT')}</span>`)}${detailRow('Company', esc(a.legalNameLo || a.legalNameEn))}${detailRow('Company Office / Site', esc(a.companySiteAddressLo || a.companySiteAddressEn || a.companySiteNameLo || ''))}${detailRow('Application Date', fmtDate(a.applicationDate))}${detailRow('Decision', `${esc(a.decisionNo || '—')} · ${fmtDate(a.decisionDate)}`)}${detailRow('Permit No.', esc(a.permitNo))}${detailRow('Validity', `${fmtDate(a.validFrom || a.applicationDate)} → ${fmtDate(a.permitValidTo)}`)}${detailRow('Origin → Destination', `${esc(a.originCountry || '—')} → ${esc(a.destinationCountry || '—')}`)}${detailRow('Checkpoint', `${esc(a.borderCheckpoint || '—')}${a.checkpointOut ? ' → ' + esc(a.checkpointOut) : ''}`)}${detailRow('Transport', esc(a.transportMode || a.transportInformation))}${detailRow('Purpose', esc(a.purpose))}${detailRow('Cleared Date', fmtDate(a.clearedDate))}${detailRow('Signed by', esc(a.signedBy))}${detailRow('Status', `<span class="status-pill">${esc(a.status)}</span>`)}</div><div class="detail-section"><h3>ລາຍການ (${items.length})</h3><div class="detail-table-wrap"><table><thead><tr><th>#</th><th>Type</th><th>Name</th><th>Reg No.</th><th>Pack</th><th>Requested</th><th>Approved</th><th>Cleared</th><th>USD</th><th>Eligibility</th></tr></thead><tbody>${rows}</tbody></table></div></div>`;
    $('#detail-actions').innerHTML = '<button class="ghost" id="trade-coordination">📋 ໃບກິດສຳພັນ / ກວດເອກະສານ</button><button class="ghost" id="permit-print">🖨 ພິມໃບອະນຸຍາດ / Notification Letter</button>';
    $('#detail-modal').showModal();
    $('#trade-coordination').onclick = () => openTradeCoordinationSheet(id);
    $('#permit-print').onclick = () => printImportPermit(id);
}
async function openPlanDetail(id) {
    const [r, ar] = await Promise.all([api(`/import-plans/${encodeURIComponent(id)}/complete`), api(`/legacy-parity/reports/import-analytics?planId=${encodeURIComponent(id)}`)]);
    const a = r.data.plan, items = r.data.items || [], tracking = ar.data?.planTracking || [], summary = ar.data?.summary || {};
    $('#detail-title').textContent = a.planNo || 'Annual Plan';
    $('#detail-subtitle').textContent = `${a.planYear || ''} · ${a.legalNameLo || a.legalNameEn || ''}`;
    const n = (v, d = 0) => v === null || v === undefined || v === '' ? '—' : Number(v).toLocaleString(undefined, { maximumFractionDigits: d });
    const money = (v) => v === null || v === undefined || v === '' ? '—' : '$' + Number(v).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    const planDisplay = (x) => x.trackingBasis === 'COUNT_VALUE' ? `${n(x.plannedItemCount)} ${lang === 'lo' ? 'ລາຍການ' : 'items'}${x.plannedValueUsd !== null && x.plannedValueUsd !== undefined ? ' · ' + money(x.plannedValueUsd) : ''}` : x.trackingBasis === 'VALUE' ? money(x.plannedValueUsd) : x.trackingBasis === 'REFERENCE_ONLY' ? (lang === 'lo' ? 'ອ້າງອີງ / ບໍ່ຫັກຍອດ' : 'Reference only') : `${n(x.plannedQuantity, 3)} ${esc(x.unitCode || '')}${x.trackingBasis === 'QUANTITY_VALUE' && x.plannedValueUsd !== null && x.plannedValueUsd !== undefined ? ' · ' + money(x.plannedValueUsd) : ''}`;
    const actualDisplay = (x) => x.trackingBasis === 'COUNT_VALUE' ? `${n(x.actualItemCount)} ${lang === 'lo' ? 'ລາຍການ' : 'items'} · ${money(x.actualClearedValueUsd)}` : x.trackingBasis === 'VALUE' ? money(x.actualClearedValueUsd) : x.trackingBasis === 'REFERENCE_ONLY' ? `${n(x.importCount)} ${lang === 'lo' ? 'ຄັ້ງ' : 'times'}` : `${n(x.actualClearedQuantity, 3)} ${esc(x.unitCode || '')}${x.trackingBasis === 'QUANTITY_VALUE' ? ' · ' + money(x.actualClearedValueUsd) : ''}`;
    const remainingDisplay = (x) => x.trackingBasis === 'COUNT_VALUE' ? `${n(x.remainingItemCount)} ${lang === 'lo' ? 'ລາຍການ' : 'items'}${x.remainingValueUsd !== null && x.remainingValueUsd !== undefined ? ' · ' + money(x.remainingValueUsd) : ''}` : x.trackingBasis === 'VALUE' ? money(x.remainingValueUsd) : x.trackingBasis === 'REFERENCE_ONLY' ? '—' : `${n(x.remainingQuantity, 3)} ${esc(x.unitCode || '')}${x.trackingBasis === 'QUANTITY_VALUE' && x.remainingValueUsd !== null && x.remainingValueUsd !== undefined ? ' · ' + money(x.remainingValueUsd) : ''}`;
    const statusLabel = (x) => String(x.trackingStatus || '').replaceAll('_', ' ');
    const approvedDisplay = (x) => x.trackingBasis === 'COUNT_VALUE' ? `${n(x.approvedItemCount)} ${lang === 'lo' ? 'ລາຍການ' : 'items'} · ${money(x.approvedValueUsd)}` : x.trackingBasis === 'VALUE' ? money(x.approvedValueUsd) : x.trackingBasis === 'REFERENCE_ONLY' ? `${n(x.approvalCount)} ${lang === 'lo' ? 'ຄັ້ງອະນຸມັດ' : 'approvals'}` : `${n(x.approvedQuantity, 3)} ${esc(x.unitCode || '')}${x.trackingBasis === 'QUANTITY_VALUE' ? ' · ' + money(x.approvedValueUsd) : ''}`;
    const trackingRows = tracking.map((x) => `<tr><td>${esc(x.itemNo)}</td><td><b>${esc(x.itemName)}</b><div class="muted">${esc(x.registrationNo || x.categoryCode || '')}</div></td><td>${esc(x.trackingBasis || '')}</td><td>${planDisplay(x)}</td><td>${approvedDisplay(x)}</td><td>${actualDisplay(x)}</td><td>${remainingDisplay(x)}</td><td>${n(x.approvalCount)} / ${n(x.importCount)}</td><td><span class="status-pill">${esc(statusLabel(x))}</span>${Number(x.unitMismatchCount || 0) > 0 ? `<div class="muted">⚠ ${n(x.unitMismatchCount)} unit mismatch</div>` : ''}</td></tr>`).join('');
    const rawRows = items.map((x) => `<tr><td>${esc(x.itemNo)}</td><td>${esc(x.itemType)}</td><td>${esc(x.itemName)}</td><td>${esc(x.registrationNo)}</td><td>${esc(x.lineMode || 'ITEM')}</td><td>${esc(x.packageDescription)}</td><td>${esc(x.plannedQuantity)} ${esc(x.unitCode)}</td><td>${esc(x.plannedItemCount || '—')}</td><td>${money(x.plannedValue)}</td></tr>`).join('');
    const warn = Number(summary.unitMismatchPlanCount || 0) > 0 ? `<div class="notice warning">⚠ ${lang === 'lo' ? 'ພົບລາຍການຫົວໜ່ວຍບໍ່ກົງກັນ:' : 'Unit mismatches:'} ${n(summary.unitMismatchPlanCount)}. ${lang === 'lo' ? 'ລະບົບບໍ່ນຳຈຳນວນທີ່ຫົວໜ່ວຍຕ່າງກັນມາຫັກກັນ.' : 'Incompatible quantities are not subtracted.'}</div>` : '';
    $('#detail-body').innerHTML = `<div class="detail-section"><h3>${lang === 'lo' ? 'ແຜນການຄ້າປະຈຳປີ' : 'Annual Trade Plan'}</h3>${detailRow('Company', esc(a.legalNameLo || a.legalNameEn))}${detailRow('Company Office / Site', esc(a.companySiteAddressLo || a.companySiteAddressEn || a.companySiteNameLo || ''))}${detailRow('Work Area', esc(a.serviceType || 'VET_DRUG_DEVICE'))}${detailRow('Movement', esc(a.movementType || 'IMPORT'))}${detailRow('Year', esc(a.planYear))}${detailRow('Application Date', fmtDate(a.applicationDate))}${detailRow('Approval No.', esc(a.approvalNo))}${detailRow('Status', esc(a.status))}</div>${warn}<div class="detail-section"><h3>📊 ${lang === 'lo' ? 'Plan vs Actual — ແຜນ / ອະນຸມັດ / ນຳເຂົ້າຈິງ' : 'Plan vs Approved vs Actual'}</h3><p class="muted">${lang === 'lo' ? 'ລະບົບແຍກ Quantity / Value / Item Count. ຕົວຢ່າງ “20 ລາຍການ” ຈະບໍ່ນຳໄປຫັກກັບ 3,933 ຂວດ/ກ່ອງ/ອັນ.' : 'Quantity, value and item-count plans are tracked separately; mixed units are never subtracted.'}</p><div class="detail-table-wrap"><table><thead><tr><th>#</th><th>${lang === 'lo' ? 'ລາຍການ' : 'Item'}</th><th>Tracking</th><th>${lang === 'lo' ? 'ແຜນ' : 'Plan'}</th><th>${lang === 'lo' ? 'ອະນຸມັດ' : 'Approved'}</th><th>${lang === 'lo' ? 'ນຳເຂົ້າຈິງ' : 'Actual'}</th><th>${lang === 'lo' ? 'ຍອດເຫຼືອ' : 'Remaining'}</th><th>${lang === 'lo' ? 'ອະນຸມັດ / ນຳເຂົ້າ' : 'Approvals / Imports'}</th><th>Status</th></tr></thead><tbody>${trackingRows || `<tr><td colspan="9" class="empty">${lang === 'lo' ? 'ຍັງບໍ່ມີລາຍການແຜນ' : 'No plan items'}</td></tr>`}</tbody></table></div></div><details class="detail-section"><summary><b>${lang === 'lo' ? 'ເບິ່ງຂໍ້ມູນແຜນດິບ' : 'Raw Plan Data'} (${items.length})</b></summary><div class="detail-table-wrap" style="margin-top:10px"><table><thead><tr><th>#</th><th>Type</th><th>Name</th><th>Reg No.</th><th>Mode</th><th>Pack</th><th>Qty</th><th>Item Count</th><th>Value</th></tr></thead><tbody>${rawRows}</tbody></table></div></details>`;
    $('#detail-actions').innerHTML = `<button class="ghost" id="plan-analytics-full">📈 ${lang === 'lo' ? 'ເປີດ Import Analytics' : 'Open Import Analytics'}</button><button class="ghost" id="detail-close-bottom">Close</button>`;
    $('#detail-modal').showModal();
    $('#plan-analytics-full').onclick = () => openImportPlanAnalyticsDashboard();
    $('#detail-close-bottom').onclick = closeDetail;
}
async function openExportDetail(id) {
    const r = await api(`/export-applications/${encodeURIComponent(id)}/complete`);
    const a = r.data.application, items = r.data.items || [];
    $('#detail-title').textContent = a.caseNo || 'Export Application';
    $('#detail-subtitle').textContent = lang === 'lo' ? 'ຄຳຮ້ອງສົ່ງອອກ (ເລກອ້າງອີງພາຍໃນ)' : 'Export application (internal reference number)';
    const rows = items.map((x) => `<tr><td>${esc(x.itemNo)}</td><td>${esc(x.commodityClass)}</td><td>${esc(x.itemDescription)}</td><td>${esc(x.speciesNameLo || x.speciesNameEn || '—')}</td><td>${esc(x.quantity ?? '—')} ${esc(x.unitCode || '')}</td><td>${esc(x.hsAhtnCode || '—')}</td></tr>`).join('');
    $('#detail-body').innerHTML = `<div class="detail-section"><h3>${lang === 'lo' ? 'ຂໍ້ມູນຄຳຮ້ອງ' : 'Application'}</h3>${detailRow('Reference No. (internal)', esc(a.caseNo))}${detailRow('Company', esc(a.legalNameLo || a.legalNameEn))}${detailRow('Work Area', esc(a.serviceType))}${detailRow('Destination Country', esc(a.destinationCountryNameLo || a.destinationCountryNameEn || '—'))}${detailRow('Shipment Window', `${fmtDate(a.intendedShipmentFrom)} → ${fmtDate(a.intendedShipmentTo)}`)}${detailRow('Status', `<span class="status-pill">${esc(a.caseStatus)}</span>`)}${detailRow('Submitted', fmtDate(a.submittedAt))}${detailRow('Notes', esc(a.detailNotes))}</div><div class="detail-section"><h3>${lang === 'lo' ? 'ລາຍການ' : 'Items'} (${items.length})</h3><div class="detail-table-wrap"><table><thead><tr><th>#</th><th>Class</th><th>Item</th><th>Species</th><th>Qty</th><th>HS/AHTN</th></tr></thead><tbody>${rows}</tbody></table></div></div><div class="notice">${lang === 'lo' ? 'ໝາຍເຫດ: ເລກອ້າງອີງນີ້ເປັນເລກອ້າງອີງພາຍໃນລະບົບ, ບໍ່ແມ່ນເລກໃບຢັ້ງຢືນ/ໃບອະນຸຍາດທາງການ.' : 'Note: this reference number is an internal system identifier, not an official certificate or permit number.'}</div>`;
    $('#detail-actions').innerHTML = '<button class="ghost" id="detail-close-bottom">Close</button>';
    $('#detail-modal').showModal();
    $('#detail-close-bottom').onclick = closeDetail;
}
function setPrint(html) {
    const pa = $('#print-area');
    if (pa.parentElement !== document.body)
        document.body.appendChild(pa);
    pa.innerHTML = html;
    const imgs = [...pa.querySelectorAll('img')];
    const waits = imgs.map(img => img.complete ? Promise.resolve() : new Promise(resolve => { let done = false; const finish = () => { if (done)
        return; done = true; resolve(); }; img.addEventListener('load', finish, { once: true }); img.addEventListener('error', finish, { once: true }); setTimeout(finish, 1000); }));
    Promise.all(waits).then(async () => { try {
        await document.fonts?.ready;
    }
    catch { } setTimeout(() => window.print(), 120); });
}
function certNo(p, x, i, total) { const base = p.registrationNo || ''; return total > 1 ? `${base}-${x.subCode || String(i + 1).padStart(2, '0')}` : base; }
function certComposition(x) { return (x.composition || []).map((c) => `${esc(c.ingredientName)}${c.quantityText ? ` <b>${esc(c.quantityText)} ${esc(c.unitText)}</b>` : ''}${c.equivalenceText ? ` (${esc(c.equivalenceText)})` : ''}`).join('<br>') || '—'; }
function certLegacyRow(label, value) { return `<div class="legacy-cert-label">${esc(label)}</div><div class="legacy-cert-colon">:</div><div class="legacy-cert-value">${value || '—'}</div>`; }
function legacyParty(name, address) { const n = esc(name || ''); const a = esc(address || ''); return `${n ? `<b>${n}</b>` : ''}${a ? `<span class="legacy-cert-address">${a}</span>` : ''}` || '—'; }
function withdrawalText(p) { return [[`ຊີ້ນ`, p.withdrawalMeat], [`ນົມ`, p.withdrawalMilk], [`ໄຂ່`, p.withdrawalEggs], [`ສັດນ້ຳ`, p.withdrawalAquatic]].filter((x) => x[1]).map((x) => `${x[0]}: ${esc(x[1])}`).join(' · '); }
function buildDrugCertPage(p, x, i, total) {
    const registration = certNo(p, x, i, total);
    const legal1 = '- ອີງຕາມ ກົດໝາຍ ວ່າດ້ວຍການລ້ຽງສັດ ແລະ ການສັດຕະວະແພດ (ສະບັບປັບປຸງ) ສະບັບ ເລກທີ 08/ສພຊ, ລົງວັນທີ 11 ພະຈິກ 2016;';
    const legal2 = '- ອີງຕາມ ດຳລັດ ວ່າດ້ວຍຢາສັດຕະວະແພດ, ເລກທີ 199-ລບ, ລົງວັນທີ 13 ມີນາ 2020;';
    const holder = p.holderCompanyName || p.importerCompanyName || '';
    const holderAddr = p.holderAddress || p.importerAddress || '';
    const mfg = [p.manufacturerCompanyName || p.manufacturerName, p.manufacturerCountry].filter(Boolean).join(', ');
    const validYears = p.validYears || '3';
    const validText = p.expiryDate ? `ໃບທະບຽນຢາສັດຕະວະແພດສະບັບນີ້ ມີອາຍຸການນຳໃຊ້ ${esc(validYears)} ປີ ນັບແຕ່ມື້ລົງລາຍເຊັນ.` : 'ໃບທະບຽນຢາສັດຕະວະແພດສະບັບນີ້ ມີຜົນນຳໃຊ້ນັບແຕ່ມື້ລົງລາຍເຊັນ.';
    const notes = [
        'ວິສາຫະກິດເຈົ້າຂອງທະບຽນ ຕ້ອງຍື່ນຄຳຮ້ອງຂໍຕໍ່ອາຍຸກ່ອນວັນໝົດອາຍຸຕາມກຳນົດ; ໃບທະບຽນອາດຖືກລະງັບ, ຖອນ ຫຼື ຍົກເລີກຕາມກົດໝາຍ.',
        'ວິສາຫະກິດເຈົ້າຂອງທະບຽນ ຕ້ອງຮັບຜິດຊອບຕໍ່ຄຸນນະພາບ, ຄວາມປອດໄພ ແລະ ປະສິດທິຜົນຂອງຜະລິດຕະພັນ.',
        'ການນຳເຂົ້າ, ຈຳໜ່າຍ ແລະ ນຳໃຊ້ ຕ້ອງປະຕິບັດຕາມເງື່ອນໄຂທີ່ໄດ້ອະນຸມັດໃນເອກະສານຂຶ້ນທະບຽນ.',
        'ຫ້າມດັດແກ້, ຕໍ່ເຕີມ ຫຼື ລົບລ້າງ ຂໍ້ຄວາມໃນໃບທະບຽນໂດຍພາລະການ.'
    ];
    return `<section class="print-page legacy-cert">
   <div class="legacy-cert-frame"></div>
   <img class="cert-corner tl" src="/img_corner.jpg"><img class="cert-corner tr" src="/img_corner.jpg">
   <img class="cert-corner bl" src="/img_corner.jpg"><img class="cert-corner br" src="/img_corner.jpg">
   <img class="legacy-cert-wm" src="/img_watermark.jpg">
   <div class="legacy-cert-body">
     <div class="legacy-cert-main">
       <img class="legacy-cert-emblem" src="/img_emblem.jpg">
       <div class="legacy-cert-country">ສາທາລະນະລັດ ປະຊາທິປະໄຕ ປະຊາຊົນລາວ</div>
       <div class="legacy-cert-motto">ສັນຕິພາບ ເອກະລາດ ປະຊາທິປະໄຕ ເອກະພາບ ວັດທະນາຖາວອນ</div>
       <div class="legacy-cert-refrow">
         <div class="legacy-cert-org">ກະຊວງກະສິກຳ ແລະ ສິ່ງແວດລ້ອມ<br>ກົມລ້ຽງສັດ ແລະ ການປະມົງ</div>
         <div class="legacy-cert-refno">ເລກທີ : <span>${esc(p.dlfNo || '')}</span> / ກລປ<br>ນະຄອນຫຼວງວຽງຈັນ, ວັນທີ : <span>${fmtDate(p.dlfDate || p.issueDate)}</span></div>
       </div>
       <div class="legacy-cert-title">ໃບທະບຽນຢາສັດຕະວະແພດ</div>
       <div class="legacy-cert-regno">ເລກທະບຽນ : ${esc(registration)}</div>
       <div class="legacy-cert-legal"><div>${legal1}</div><div>${legal2}</div></div>
       <div class="legacy-cert-intro">ກົມລ້ຽງສັດ ແລະ ການປະມົງ ໄດ້ອອກໃບທະບຽນຢາສັດຕະວະແພດ ໃຫ້ແກ່:</div>
       <div class="legacy-cert-grid">
         ${certLegacyRow('ຊື່ທາງການຄ້າ', `<b>${esc(p.tradeName)}</b>${p.genericName && p.genericName !== p.tradeName ? ` (${esc(p.genericName)})` : ''}`)}
         ${certLegacyRow('ປະເພດຢາ', esc(p.category))}
         ${certLegacyRow('ຮູບແບບຢາ', esc(p.dosageForm))}
         ${certLegacyRow('ຄວາມແຮງ', `<b>${esc(x.strengthText)}</b>`)}
         ${certLegacyRow('ສ່ວນປະກອບ', `<b>ສ່ວນປະກອບຫຼັກ:</b> ${certComposition(x)}`)}
         ${certLegacyRow('ເປົ້າໝາຍການນຳໃຊ້', `${esc(p.indications)}${p.targetSpecies ? `<br><span class="legacy-muted">ສັດເປົ້າໝາຍ: ${esc(p.targetSpecies)}</span>` : ''}`)}
         ${certLegacyRow('ຂະໜາດບັນຈຸ', esc(x.packDescription))}
         ${withdrawalText(p) ? certLegacyRow('ໄລຍະການຢຸດຢາ', withdrawalText(p)) : ''}
         ${certLegacyRow('ອາຍຸ/ການເກັບຮັກສາ', esc([p.shelfLife, p.storageConditions].filter(Boolean).join(' · ')))}
         ${certLegacyRow('ຜູ້ຖືທະບຽນ', legacyParty(holder, holderAddr))}
         ${certLegacyRow('ຜູ້ຜະລິດ', legacyParty(mfg, p.manufacturerSiteAddress || p.manufacturerAddress || ''))}
       </div>
       <div class="legacy-cert-valid">${validText}</div>
       <div class="legacy-cert-sign"><div class="legacy-cert-sign-role">ຫົວໜ້າກົມ</div></div>
     </div>
     <div class="legacy-cert-spacer"></div>
     <div class="legacy-cert-notes"><b>ໝາຍເຫດ:</b>${notes.map((n, idx) => `<div><b>${idx + 1}.</b> ${n}</div>`).join('')}</div>
   </div>
 </section>`;
}
async function printDrugCertificate(id, presIdx) { try {
    const r = await api(`/drug-registrations/${encodeURIComponent(id)}/complete`);
    const p = r.data.profile, ps = r.data.presentations || [];
    const html = presIdx === null ? ps.map((x, i) => buildDrugCertPage(p, x, i, ps.length)).join('') : buildDrugCertPage(p, ps[presIdx] || {}, presIdx, ps.length);
    setPrint(html);
}
catch (e) {
    toast(e.message, true);
} }
async function printDrugMemo(id) { try {
    const r = await api(`/drug-registrations/${encodeURIComponent(id)}/complete`);
    const p = r.data.profile, ps = r.data.presentations || [];
    const regRows = ps.length > 1 ? ps.map((x, i) => `<div>${esc(certNo(p, x, i, ps.length))} · ${esc(x.strengthText)} · ${esc(x.packDescription)}</div>`).join('') : esc(p.registrationNo);
    setPrint(`<section class="print-page memo-page"><img class="memo-emblem" src="/img_emblem.jpg"><div class="memo-country">ສາທາລະນະລັດ ປະຊາທິປະໄຕ ປະຊາຊົນລາວ</div><div class="memo-motto">ສັນຕິພາບ ເອກະລາດ ປະຊາທິປະໄຕ ເອກະພາບ ວັດທະນາຖາວອນ</div><div class="memo-head"><div>ກົມລ້ຽງສັດ ແລະ ການປະມົງ<br>ພະແນກສັດຕະວະແພດ</div><div>ເລກທີ: ................../ກລປ<br>ນະຄອນຫຼວງ, ....../....../......</div></div><h1>ໃບກິດສຳພັນພາຍໃນ</h1><p><b>ຮຽນ:</b> ..................................................................................</p><p><b>ເລື່ອງ:</b> ສະເໜີຂໍອະນຸມັດຂຶ້ນທະບຽນຢາສັດຕະວະແພດ</p><p>ສະເໜີຂໍອະນຸມັດຂຶ້ນທະບຽນຢາສັດຕະວະແພດ ຈຳນວນ <b>1</b> ລາຍການ ດັ່ງນີ້:</p><table class="memo-table"><thead><tr><th>ລ/ດ</th><th>ຊື່ຜະລິດຕະພັນ</th><th>ເລກທະບຽນ</th><th>ປະເພດຢາ</th></tr></thead><tbody><tr><td>1</td><td><b>${esc(p.tradeName)}</b><br>${esc(p.genericName)}</td><td>${regRows}</td><td>${esc(p.category)}</td></tr></tbody></table><div class="memo-signs"><div>ພະນັກງານຄົ້ນຄວ້າ<br><br><br>............................</div><div>ຫົວໜ້າຂະແໜງ<br><br><br>............................</div><div>ຫົວໜ້າພະແນກ<br><br><br>............................</div></div><div class="memo-comments">ຄຳເຫັນ ຮອງຫົວໜ້າກົມຜູ້ຊີ້ນຳ:<br><br>........................................................................................................................<br><br>........................................................................................................................</div></section>`);
}
catch (e) {
    toast(e.message, true);
} }
function printPermitStandalone(html) {
    const frame = document.createElement('iframe');
    frame.setAttribute('aria-hidden', 'true');
    frame.style.position = 'fixed';
    frame.style.right = '0';
    frame.style.bottom = '0';
    frame.style.width = '1px';
    frame.style.height = '1px';
    frame.style.opacity = '0';
    frame.style.border = '0';
    frame.style.pointerEvents = 'none';
    document.body.appendChild(frame);
    const doc = frame.contentDocument, win = frame.contentWindow;
    if (!doc || !win) {
        frame.remove();
        throw new Error('Unable to prepare print document');
    }
    const css = `@page{size:A4 portrait;margin:0}html,body{margin:0;padding:0;background:#fff;color:#172033;font-family:"Noto Sans Lao","Phetsarath OT",Arial,sans-serif}.permit-page{box-sizing:border-box;width:210mm;min-height:277mm;padding:12mm 14mm;background:#fff}.permit-emblem{display:block;width:20mm;height:auto;margin:0 auto 1mm}.permit-country{text-align:center;font-size:13pt;font-weight:800}.permit-motto{text-align:center;font-size:10pt}.permit-head{display:flex;justify-content:space-between;gap:10mm;margin-top:7mm;font-size:10pt;line-height:1.5}.permit-head>div:last-child{text-align:right}.permit-page h1{text-align:center;font-size:16pt;margin:7mm 0 5mm}.permit-page p{font-size:10.5pt;line-height:1.55}.permit-checks{border:1px solid #52667f;padding:3mm;text-align:center;margin:3mm 0;font-size:10pt}.permit-table{border-collapse:collapse;width:100%;font-size:9pt;table-layout:auto}.permit-table th,.permit-table td{border:1px solid #3b4b63;padding:2mm;white-space:normal;vertical-align:top;overflow-wrap:anywhere}.permit-table th{background:#eef4f1;color:#16213a}.permit-sign{display:flex;justify-content:space-between;gap:12mm;margin-top:8mm;font-size:10pt}.permit-sign>div:last-child{text-align:center;min-width:60mm}`;
    doc.open();
    doc.write(`<!doctype html><html><head><meta charset="utf-8"><base href="${location.origin}/"><title>LVSP Notification Letter</title><style>${css}</style></head><body>${html}</body></html>`);
    doc.close();
    const run = async () => { try {
        await doc.fonts?.ready;
    }
    catch { } const imgs = [...doc.images]; await Promise.all(imgs.map(img => img.complete ? Promise.resolve() : new Promise(resolve => { const done = () => resolve(); img.addEventListener('load', done, { once: true }); img.addEventListener('error', done, { once: true }); setTimeout(done, 1200); }))); setTimeout(() => { win.focus(); win.print(); setTimeout(() => frame.remove(), 2500); }, 180); };
    if (doc.readyState === 'complete')
        void run();
    else
        frame.addEventListener('load', () => void run(), { once: true });
}
async function printImportPermit(id) { try {
    const r = await api(`/import-applications/${encodeURIComponent(id)}/complete`);
    const a = r.data.application, items = r.data.items || [], movement = String(a.importType || 'IMPORT').toUpperCase(), ck = (x) => movement === x ? '☑' : '□';
    const rows = items.map((x) => `<tr><td>${esc(x.itemNo)}</td><td>${esc(x.itemName)}</td><td>${esc(x.packageDescription)}</td><td>${esc(x.approvedQuantity || x.requestedQuantity || x.clearedPacks || 0)}</td><td>${esc(x.unitCode)}</td><td>${esc(x.itemValue || '')}</td><td>${esc(x.registrationNo || x.eligibilityStatus || '')}</td></tr>`).join('');
    printPermitStandalone(`<section class="permit-page"><img class="permit-emblem" src="/img_emblem.jpg"><div class="permit-country">ສາທາລະນະລັດ ປະຊາທິປະໄຕ ປະຊາຊົນລາວ</div><div class="permit-motto">ສັນຕິພາບ ເອກະລາດ ປະຊາທິປະໄຕ ເອກະພາບ ວັດທະນາຖາວອນ</div><div class="permit-head"><div>ກະຊວງກະສິກຳ ແລະ ສິ່ງແວດລ້ອມ<br>ກົມລ້ຽງສັດ ແລະ ການປະມົງ</div><div>Ref No: ${esc(a.permitNo || a.decisionNo || '................')}</div></div><h1>ໃບແຈ້ງອະນຸຍາດ / NOTIFICATION LETTER</h1><div class="permit-checks">${ck('IMPORT')} ນຳເຂົ້າ (IMPORT) &nbsp;&nbsp; ${ck('EXPORT')} ສົ່ງອອກ (EXPORT) &nbsp;&nbsp; ${ck('TRANSIT')} ສົ່ງຜ່ານ (TRANSIT)</div><p><b>Company:</b> ${esc(a.legalNameLo || a.legalNameEn)}${a.companySiteAddressLo || a.companySiteAddressEn ? `<br><b>Office/Site:</b> ${esc(a.companySiteAddressLo || a.companySiteAddressEn)}` : ''}<br><b>Origin → Destination:</b> ${esc(a.originCountry || '—')} → ${esc(a.destinationCountry || '—')} &nbsp; <b>Checkpoint:</b> ${esc(a.borderCheckpoint || '—')}${a.checkpointOut ? ' → ' + esc(a.checkpointOut) : ''}</p><table class="permit-table"><thead><tr><th>#</th><th>Description</th><th>Pack</th><th>Qty</th><th>Unit</th><th>USD</th><th>Reg/Status</th></tr></thead><tbody>${rows}</tbody></table><p><b>Purpose:</b> ${esc(a.purpose)}</p><div class="permit-sign"><div>Validity: ${fmtDate(a.validFrom || a.applicationDate)} — ${fmtDate(a.permitValidTo)}</div><div><b>Approved by:</b><br><br><br>${esc(a.signedBy || '................................')}</div></div></section>`);
}
catch (e) {
    toast(e.message, true);
} }
function configureBulkToolbar() {
    const tb = $('#template-btn');
    const bb = $('#bulk-btn');
    const isPlan = current.key === 'import_plans';
    const isApp = current.key === 'import_applications';
    tb.classList.toggle('hidden', !(isPlan || isApp));
    bb.classList.toggle('hidden', !(isPlan || isApp));
    if (isPlan)
        tb.href = '/templates/Annual_Import_Plan_Template.xlsx';
    if (isApp)
        tb.href = '/templates/Import_Application_Items_Template.xlsx';
    const toolbar = document.querySelector('.panel-head .toolbar');
    let memoBtn = document.querySelector('#drug-memo-center-btn');
    if (toolbar && !memoBtn) {
        memoBtn = document.createElement('button');
        memoBtn.id = 'drug-memo-center-btn';
        memoBtn.className = 'ghost hidden';
        memoBtn.textContent = '📄 ໃບກິດສຳພັນ';
        const create = $('#create-btn');
        toolbar.insertBefore(memoBtn, create);
        memoBtn.onclick = () => { showCustomPage(true); renderRegistrationMemoCenter(); };
    }
    if (memoBtn)
        memoBtn.classList.toggle('hidden', current.key !== 'drug_registrations');
    let reportBtn = document.querySelector('#module-report-btn');
    if (toolbar && !reportBtn) {
        reportBtn = document.createElement('button');
        reportBtn.id = 'module-report-btn';
        reportBtn.className = 'ghost hidden';
        reportBtn.textContent = '📊 ' + (lang === 'lo' ? 'ລາຍງານ Module' : 'Module Report');
        const create = $('#create-btn');
        toolbar.insertBefore(reportBtn, create);
        reportBtn.onclick = () => openModuleReportForKey(current.key);
    }
    if (reportBtn) {
        const ownReport = moduleReportAvailable(current.key) && !['drug_registrations', 'trade_workspace', 'regulatory_reports'].includes(current.key);
        reportBtn.classList.toggle('hidden', !ownReport);
    }
}
async function openBulk() { const isPlan = current.key === 'import_plans'; const r = await api(isPlan ? '/import-plans' : '/import-applications'); const sel = $('#bulk-parent'); sel.innerHTML = '<option value="">— Select —</option>' + (r.data || []).map((x) => `<option value="${esc(x.id)}">${esc(isPlan ? `${x.planNo} (${x.planYear})` : `${x.applicationNo} ${x.applicationDate || ''}`)}</option>`).join(''); $('#bulk-parent-label').textContent = isPlan ? 'Annual Plan / ແຜນປະຈຳປີ' : 'Import Application / ຄຳຮ້ອງ'; $('#bulk-file').value = ''; $('#bulk-summary').innerHTML = ''; $('#bulk-preview-body').innerHTML = ''; $('#bulk-commit').disabled = true; bulkFilePayload = null; $('#bulk-modal').showModal(); }
async function previewBulk() { const f = $('#bulk-file').files?.[0]; const parent = $('#bulk-parent').value; if (!parent || !f)
    return toast('Select plan/application and Excel file', true); const dataBase64 = await fileToBase64(f); bulkFilePayload = { filename: f.name, dataBase64, target: current.key === 'import_plans' ? 'plan' : 'application', parentId: parent }; try {
    const r = await api('/bulk-import/preview', { method: 'POST', body: JSON.stringify(bulkFilePayload) });
    const d = r.data;
    $('#bulk-summary').innerHTML = `<b>${d.summary.total}</b> rows · <span class="bulk-ok">Valid ${d.summary.valid}</span> · <span class="bulk-warn">Warnings ${d.summary.warnings}</span> · <span class="bulk-error">Errors ${d.summary.errors}</span>`;
    $('#bulk-preview-body').innerHTML = d.rows.map((x) => `<tr><td>${x.rowNo}</td><td>${esc(x.itemType)}</td><td>${esc(x.itemName)}</td><td>${esc(x.registrationNo)}</td><td>${esc(x.packageDescription)}</td><td>${esc(x.quantity)} ${esc(x.unitCode)}</td><td class="${x.validationStatus === 'VALID' ? 'bulk-ok' : x.validationStatus === 'WARNING' ? 'bulk-warn' : 'bulk-error'}">${esc(x.validationStatus)}</td><td>${esc([...(x.errors || []), ...(x.warnings || [])].join('; ') || x.eligibilityMessage || '')}</td></tr>`).join('');
    $('#bulk-commit').disabled = d.summary.errors > 0;
}
catch (e) {
    toast(e.message, true);
} }
async function commitBulk() { if (!bulkFilePayload)
    return; try {
    const r = await api('/bulk-import/commit', { method: 'POST', body: JSON.stringify(bulkFilePayload) });
    toast(`Imported ${r.data.created} rows to Neon`);
    $('#bulk-modal').close();
    if (temporaryWorkspaceReturnKey) {
        const m = moduleByKey(temporaryWorkspaceReturnKey);
        temporaryWorkspaceReturnKey = null;
        if (m) {
            current = m;
            renderNav();
        }
    }
    await Promise.all([loadModule(), loadStats()]);
}
catch (e) {
    toast(e.message, true);
} }
function toast(text, bad = false) { const e = $('#toast'); e.textContent = text; e.className = 'toast show ' + (bad ? 'bad' : ''); setTimeout(() => e.className = 'toast', 3500); }
function showLogin() { const d = $('#login-modal'); if (!d.open)
    d.showModal(); }
function showPasswordChange() { const d = $('#password-modal'); if (!d.open)
    d.showModal(); }
async function renderPublicOverview() {
    publicBrowsing = true;
    currentUserRoles = [];
    showCustomPage(true);
    renderNav();
    $('#page-title').textContent = lang === 'lo' ? 'ພາບລວມ LVSP' : 'LVSP Public Portal';
    $('#page-subtitle').textContent = lang === 'lo' ? 'ຄົ້ນຫາຂໍ້ມູນ, ເອກະສານ, ທະບຽນ ແລະເບິ່ງທຸກ Module ຂອງ LVSP' : 'Search public records, documents and services across LVSP';
    try {
        const [ov, mc] = await Promise.all([apiPublic('/public/overview'), apiPublic('/public/module-catalog')]);
        const st = ov.data || {}, catalog = mc.data || [];
        const statusText = (x) => { const s = String(x.deliveryStatus || x.status || 'PLANNED'); if (lang === 'lo')
            return s === 'ACTIVE' ? 'ເປີດໃຊ້ງານ' : s === 'IN_DEVELOPMENT' ? 'ກຳລັງພັດທະນາ' : s === 'PLANNED' ? 'ວາງແຜນ' : s === 'APPROVED' ? 'ອະນຸມັດ' : s === 'CLEARED' ? 'ຜ່ານດ່ານ' : s === 'COMPLETED' ? 'ສຳເລັດ' : s; return s.replaceAll('_', ' '); };
        const publicModeText = (x) => x.publicDataMode === 'READ_ONLY' ? (lang === 'lo' ? 'Public ເບິ່ງໄດ້ຢ່າງດຽວ' : 'Public read-only') : (lang === 'lo' ? 'Public ເບິ່ງພາບລວມ' : 'Public overview');
        const moduleCards = catalog.map((x) => `<article class="service-card public-module-card" role="button" tabindex="0" data-public-module="${esc(x.moduleCode || '')}"><div class="service-card-top"><span class="service-icon">${esc(x.icon || '🧩')}</span><span class="guide-badge ${esc(String(x.deliveryStatus || '').toLowerCase())}">${esc(statusText(x))}</span></div><div class="service-code">${esc(x.moduleCode || '')}</div><h3>${esc(lang === 'lo' ? (x.nameLo || x.nameEn) : (x.nameEn || x.nameLo))}</h3><p>${esc(lang === 'lo' ? (x.descriptionLo || x.descriptionEn) : (x.descriptionEn || x.descriptionLo))}</p><div class="service-meta"><span>${x.loginRequired ? '🔐 ' + (lang === 'lo' ? 'Login ເພື່ອເຮັດວຽກ' : 'Login for operations') : '🌐 Public'}</span><span>${x.publicDataMode === 'READ_ONLY' ? '👁 ' + publicModeText(x) : 'ℹ️ ' + publicModeText(x)}</span></div><div class="public-module-open">${lang === 'lo' ? 'ເບິ່ງລາຍລະອຽດ →' : 'View details →'}</div></article>`).join('');
        $('#custom-page').innerHTML = `<section class="workspace-shell public-portal-shell">
     <section class="public-search-hero"><div class="public-search-hero-copy"><div class="eyebrow">LVSP · PUBLIC INFORMATION PORTAL</div><h2>${lang === 'lo' ? 'ຄົ້ນຫາຂໍ້ມູນສັດຕະວະແພດ' : 'Search Veterinary Services Information'}</h2><p>${lang === 'lo' ? 'ບໍ່ຈຳເປັນເລື່ອນເບິ່ງລາຍການທັງໝົດ. ພິມສິ່ງທີ່ຕ້ອງການຄົ້ນຫາ ເຊັ່ນ ເລກທະບຽນ, ເລກໃບອະນຸຍາດ, ເລກທີ່ເອກະສານ, ຊື່ຢາ, ຊື່ເອກະສານ ຫຼື ຊື່ໜ້າວຽກ.' : 'Type what you want to find: registration number, permit/document number, medicine name, document name, or service/module.'}</p></div><button class="ghost" id="public-login-btn">🔐 ${lang === 'lo' ? 'ເຂົ້າລະບົບພະນັກງານ' : 'Staff sign in'}</button>
       <form class="public-global-search" id="public-search-form"><span class="public-search-icon">⌕</span><input id="public-global-search-input" autocomplete="off" placeholder="${lang === 'lo' ? 'ຄົ້ນຫາ: ເລກທະບຽນ, ເລກອະນຸຍາດ, ຊື່ຢາ, ຊື່ເອກະສານ...' : 'Search: registration no., permit no., medicine, document, service...'}"><button class="primary" type="submit">${lang === 'lo' ? 'ຄົ້ນຫາ' : 'Search'}</button></form>
       <p class="public-search-scope">${lang === 'lo' ? 'ວຽກນຳເຂົ້າ · ສົ່ງອອກ · ສົ່ງຜ່ານ ແມ່ນຢູ່ໃນ LVSP ເຊັ່ນດຽວກັບທະບຽນຢາ ແລະ Module ອື່ນ. Module ທີ່ກຳລັງສ້າງກໍຍັງສະແດງໃນລາຍການບໍລິການ; ຂໍ້ມູນພາຍໃນຕ້ອງ Login.' : 'Import, export and transit are part of LVSP alongside drug registration and other services. modules currently being built remain visible in the service catalog; internal operational data requires login.'}</p>
       <div class="public-search-hints"><span>${lang === 'lo' ? 'ຕົວຢ່າງ:' : 'Examples:'}</span><button type="button" data-search-example="ທະບຽນຢາສັດ">${lang === 'lo' ? 'ທະບຽນຢາສັດ' : 'Drug registration'}</button><button type="button" data-search-example="Import Notification Letter">Import Permit</button><button type="button" data-search-example="Transit Permit">Transit Permit</button><button type="button" data-search-example="Farm Registration">${lang === 'lo' ? 'ຂຶ້ນທະບຽນຟາມ' : 'Farm Registration'}</button></div>
     </section>
     <div class="stats public-portal-stats"><div class="stat-card"><div><strong>${esc(st.activeDrugRegistrations || 0)}</strong><span>${lang === 'lo' ? 'ທະບຽນຢາທີ່ເປີດໃຊ້' : 'Active drug registrations'}</span></div></div><div class="stat-card"><div><strong>${esc(st.activeCompanies || 0)}</strong><span>${lang === 'lo' ? 'ບໍລິສັດທີ່ໃຊ້ງານ' : 'Active companies'}</span></div></div><div class="stat-card"><div><strong>${esc(st.completedTradeRecords || 0)}</strong><span>${lang === 'lo' ? 'ເອກະສານການຄ້າສຳເລັດ' : 'Completed trade records'}</span></div></div><div class="stat-card"><div><strong>${esc(catalog.length)}</strong><span>${lang === 'lo' ? 'Modules ຂອງ LVSP' : 'LVSP modules'}</span></div></div></div>
     <section class="panel public-search-results-panel" id="public-search-results" hidden><div class="panel-head"><div><b id="public-search-results-title">${lang === 'lo' ? 'ຜົນການຄົ້ນຫາ' : 'Search results'}</b><span id="public-search-results-meta"></span></div><button class="ghost" id="public-search-clear">${lang === 'lo' ? 'ລ້າງ' : 'Clear'}</button></div><div id="public-search-results-body" class="public-search-results-list"></div></section>
     <section class="guide-section public-services-section"><div class="panel-head"><div><b>${lang === 'lo' ? 'ພາບລວມ Modules ທັງໝົດ' : 'All Module Overview'}</b><span>${lang === 'lo' ? 'ເບິ່ງທັງ Module ທີ່ເປີດໃຊ້, ກຳລັງພັດທະນາ ແລະວາງແຜນ' : 'Active, in-development and planned work areas are all visible'}</span></div></div><div class="service-card-grid">${moduleCards || '<div class="empty-box">No module catalog</div>'}</div></section>
     <section class="panel public-module-detail-panel" id="public-module-detail" hidden><div class="panel-head"><div><b id="public-module-detail-title"></b><span id="public-module-detail-code"></span></div><button class="ghost" id="public-module-detail-close">×</button></div><div id="public-module-detail-body"></div></section>
   </section>`;
        const openModule = (code) => { const x = catalog.find((m) => String(m.moduleCode) === code); if (!x)
            return; const name = lang === 'lo' ? (x.nameLo || x.nameEn) : (x.nameEn || x.nameLo), desc = lang === 'lo' ? (x.descriptionLo || x.descriptionEn) : (x.descriptionEn || x.descriptionLo); $('#public-module-detail-title').textContent = name || code; $('#public-module-detail-code').textContent = `${code} · ${statusText(x)}`; const extra = code === 'VET_DRUG_REGISTRATION' ? (lang === 'lo' ? 'ຂໍ້ມູນທະບຽນຢາບໍ່ສະແດງເປັນຕາຕະລາງທັງໝົດອີກແລ້ວ. ໃຫ້ຄົ້ນຫາຈາກຊ່ອງຄົ້ນຫາດ້ານເທິງດ້ວຍເລກທະບຽນ, ຊື່ຢາ ຫຼື INN.' : 'The full drug registry is no longer dumped on the homepage. Search by registration number, medicine name or INN above.') : code === 'VET_DRUG_TRADE' ? (lang === 'lo' ? `ຄົ້ນຫາໃບອະນຸຍາດ/Notification Letter ທີ່ສຳເລັດແລ້ວດ້ວຍເລກ Application, Decision ຫຼື Permit. ຈຳນວນລາຍການສຳເລັດປັດຈຸບັນ: ${st.completedTradeRecords || 0}.` : `Search completed permit/notification records by application, decision or permit number. Current completed records: ${st.completedTradeRecords || 0}.`) : (x.deliveryStatus === 'PLANNED' || x.deliveryStatus === 'IN_DEVELOPMENT') ? (lang === 'lo' ? 'Module ນີ້ຢູ່ໃນແຜນ LVSP ແລ້ວ. Public ເບິ່ງສະຖານະ ແລະເປົ້າໝາຍໄດ້; ການປະຕິບັດງານຈະເປີດຫຼັງພັດທະນາສຳເລັດ.' : 'This module is on the LVSP roadmap. Its status and purpose are public; operational functions will open when ready.') : (lang === 'lo' ? 'Public ເບິ່ງຂໍ້ມູນທີ່ອະນຸຍາດໄດ້; ການປ່ອນ, ແກ້ ແລະອະນຸມັດຕ້ອງ Login.' : 'Public information is viewable; creating, editing and approval require an authorized login.'); $('#public-module-detail-body').innerHTML = `<div class="public-module-detail-grid"><div><b>${lang === 'lo' ? 'ລາຍລະອຽດ' : 'Description'}</b><p>${esc(desc || '—')}</p></div><div><b>${lang === 'lo' ? 'ສະຖານະ' : 'Status'}</b><p>${esc(statusText(x))}</p></div><div><b>${lang === 'lo' ? 'ສິດເຂົ້າໃຊ້' : 'Access'}</b><p>${x.loginRequired ? (lang === 'lo' ? '🔐 Login ສຳລັບວຽກພາຍໃນ' : '🔐 Login required for internal operations') : '🌐 Public'}</p></div><div><b>Public</b><p>${esc(publicModeText(x))}</p></div></div><div class="public-module-note">${esc(extra)}</div>${x.loginRequired ? `<button class="primary" id="public-module-login">${lang === 'lo' ? 'ເຂົ້າລະບົບພະນັກງານ' : 'Staff sign in'}</button>` : ''}`; const p = $('#public-module-detail'); p.hidden = false; p.scrollIntoView({ behavior: 'smooth', block: 'start' }); const b = document.querySelector('#public-module-login'); if (b)
            b.onclick = () => showLogin(); };
        const typeIcon = (kind) => kind === 'DRUG_REGISTRATION' ? '💊' : kind === 'TRADE_DOCUMENT' ? '📄' : '🧩';
        const renderResults = (list, query) => { const panel = $('#public-search-results'), body = $('#public-search-results-body'); panel.hidden = false; $('#public-search-results-meta').textContent = `${list.length} ${lang === 'lo' ? 'ຜົນສຳລັບ' : 'results for'} “${query}”`; body.innerHTML = list.length ? list.map((x, i) => `<article class="public-search-result ${x.kind === 'MODULE' ? 'is-module' : ''}" ${x.kind === 'MODULE' ? `data-search-module="${esc(x.meta?.moduleCode || x.referenceNo || '')}" role="button" tabindex="0"` : ''}><div class="public-search-result-icon">${typeIcon(x.kind)}</div><div class="public-search-result-main"><div class="public-search-result-type">${esc(lang === 'lo' ? (x.typeLabelLo || x.typeLabelEn) : (x.typeLabelEn || x.typeLabelLo))}</div><h3>${esc(lang === 'lo' ? (x.titleLo || x.titleEn) : (x.titleEn || x.titleLo))}</h3><div class="public-search-result-ref">${esc(x.referenceNo || '')}</div>${x.subtitleLo || x.subtitleEn ? `<p>${esc(lang === 'lo' ? (x.subtitleLo || x.subtitleEn) : (x.subtitleEn || x.subtitleLo))}</p>` : ''}<div class="public-search-result-meta"><span class="guide-badge ${esc(String(x.status || '').toLowerCase())}">${esc(statusText(x))}</span>${x.issueDate ? `<span>${lang === 'lo' ? 'ວັນທີ' : 'Date'}: ${fmtDate(x.issueDate)}</span>` : ''}${x.validTo ? `<span>${lang === 'lo' ? 'ໃຊ້ໄດ້ເຖິງ' : 'Valid to'}: ${fmtDate(x.validTo)}</span>` : ''}${x.kind === 'MODULE' ? `<span class="public-search-open">${lang === 'lo' ? 'ເບິ່ງ Module →' : 'View module →'}</span>` : ''}</div></div></article>`).join('') : `<div class="public-search-empty"><div>⌕</div><b>${lang === 'lo' ? 'ບໍ່ພົບຂໍ້ມູນ' : 'No public result found'}</b><p>${lang === 'lo' ? 'ລອງກວດເລກທີ່ ຫຼືພິມຄຳຄົ້ນຫາໃຫ້ສັ້ນລົງ.' : 'Check the number or try a shorter search phrase.'}</p></div>`; document.querySelectorAll('[data-search-module]').forEach(el => { const go = () => openModule(el.dataset.searchModule || ''); el.addEventListener('click', go); el.addEventListener('keydown', (ev) => { if (ev.key === 'Enter' || ev.key === ' ') {
            ev.preventDefault();
            go();
        } }); }); panel.scrollIntoView({ behavior: 'smooth', block: 'start' }); };
        const doSearch = async (raw) => { const q = String(raw || '').trim(); const input = $('#public-global-search-input'); input.value = q; if (q.length < 2) {
            toast(lang === 'lo' ? 'ກະລຸນາພິມຢ່າງໜ້ອຍ 2 ຕົວອັກສອນ' : 'Enter at least 2 characters', true);
            input.focus();
            return;
        } const body = $('#public-search-results-body'); $('#public-search-results').hidden = false; $('#public-search-results-meta').textContent = lang === 'lo' ? 'ກຳລັງຄົ້ນຫາ...' : 'Searching...'; body.innerHTML = `<div class="public-search-loading">${lang === 'lo' ? 'ກຳລັງຄົ້ນຫາຂໍ້ມູນ Public...' : 'Searching public information...'}</div>`; try {
            const r = await apiPublic('/public/search?q=' + encodeURIComponent(q) + '&limit=60');
            renderResults(r.data || [], q);
        }
        catch (e) {
            body.innerHTML = `<div class="error">${esc(e.message)}</div>`;
        } };
        document.querySelectorAll('.public-module-card').forEach(el => { el.addEventListener('click', () => openModule(el.dataset.publicModule || '')); el.addEventListener('keydown', (ev) => { if (ev.key === 'Enter' || ev.key === ' ') {
            ev.preventDefault();
            openModule(el.dataset.publicModule || '');
        } }); });
        $('#public-module-detail-close').addEventListener('click', () => { $('#public-module-detail').hidden = true; });
        $('#public-login-btn').addEventListener('click', () => showLogin());
        $('#public-search-form').addEventListener('submit', (ev) => { ev.preventDefault(); void doSearch($('#public-global-search-input').value); });
        $('#public-search-clear').addEventListener('click', () => { $('#public-search-results').hidden = true; $('#public-global-search-input').value = ''; $('#public-global-search-input').focus(); });
        document.querySelectorAll('[data-search-example]').forEach(el => el.addEventListener('click', () => void doSearch(el.dataset.searchExample || '')));
    }
    catch (e) {
        $('#custom-page').innerHTML = `<div class="error">${esc(e.message)}</div>`;
    }
}
async function login(ev) {
    ev.preventDefault();
    const f = ev.target;
    const data = Object.fromEntries(new FormData(f).entries());
    try {
        const r = await api('/auth/login', { method: 'POST', body: JSON.stringify(data) });
        localStorage.setItem(tokenKey, r.data.token);
        currentUserRoles = r.data.user.roles || [];
        currentUserMustChangePassword = Boolean(r.data.user.mustChangePassword);
        publicBrowsing = false;
        applyRequestedModule();
        $('#login-modal').close();
        $('#user-badge').textContent = r.data.user.username || r.data.user.id;
        renderNav();
        if (currentUserMustChangePassword) {
            showPasswordChange();
            return;
        }
        await Promise.all([loadStats(), loadModule()]);
        if (pendingServiceCode) {
            const code = pendingServiceCode;
            pendingServiceCode = null;
            await startGuidedService(code);
        }
    }
    catch (e) {
        $('#login-error').textContent = e.message;
    }
}
async function changePassword(ev) {
    ev.preventDefault();
    const f = ev.target;
    const data = Object.fromEntries(new FormData(f).entries());
    const err = $('#password-error');
    if (String(data.newPassword || '') !== String(data.confirmPassword || '')) {
        err.textContent = lang === 'lo' ? 'ລະຫັດໃໝ່ບໍ່ກົງກັນ' : 'New passwords do not match';
        return;
    }
    try {
        const r = await api('/auth/change-password', { method: 'POST', body: JSON.stringify({ currentPassword: data.currentPassword, newPassword: data.newPassword }) });
        localStorage.setItem(tokenKey, r.data.token);
        currentUserMustChangePassword = false;
        err.textContent = '';
        $('#password-modal').close();
        await Promise.all([loadStats(), loadModule()]);
    }
    catch (e) {
        err.textContent = e.message;
    }
}
async function initAuth() {
    if (!token()) {
        currentUserRoles = [];
        currentUserMustChangePassword = false;
        publicBrowsing = true;
        await renderPublicOverview();
        const requested = new URLSearchParams(location.search).get('module');
        if (requested && moduleByKey(requested))
            showLogin();
        return;
    }
    try {
        const r = await api('/auth/me');
        currentUserRoles = r.data.roles || [];
        currentUserMustChangePassword = Boolean(r.data.mustChangePassword);
        $('#user-badge').textContent = r.data.username || r.data.id;
        renderNav();
        if (currentUserMustChangePassword)
            showPasswordChange();
    }
    catch {
        localStorage.removeItem(tokenKey);
        currentUserRoles = [];
        currentUserMustChangePassword = false;
        publicBrowsing = true;
        await renderPublicOverview();
    }
}
function bind() {
    $('#install-btn').addEventListener('click', () => installPwa());
    $('#update-btn').addEventListener('click', () => applyPwaUpdate());
    $('#create-btn').addEventListener('click', () => { editingDrugId = null; editingCompanyId = null; companySiteContext = null; companyRegistrationCompanyId = null; openCreate(); });
    $('#bulk-btn').addEventListener('click', () => openBulk());
    $('#bulk-close').addEventListener('click', () => { $('#bulk-modal').close(); restoreTemporaryWorkspace(false); });
    $('#bulk-preview').addEventListener('click', () => previewBulk());
    $('#bulk-commit').addEventListener('click', () => commitBulk());
    $('#create-form').addEventListener('submit', submitForm);
    $('#cancel-btn').addEventListener('click', () => { editingDrugId = null; editingCompanyId = null; companySiteContext = null; companyRegistrationCompanyId = null; $('#create-modal').close(); restoreTemporaryWorkspace(true); });
    $('#detail-close').addEventListener('click', closeDetail);
    $('#lang-btn').addEventListener('click', () => { lang = lang === 'lo' ? 'en' : 'lo'; $('#lang-btn').textContent = lang === 'lo' ? 'EN' : 'ລາວ'; renderNav(); if (publicBrowsing && !authenticated())
        renderPublicOverview();
    else
        loadModule(); if (authenticated())
        loadStats(); });
    $('#login-form').addEventListener('submit', login);
    $('#password-form').addEventListener('submit', changePassword);
    $('#browse-services-btn').addEventListener('click', () => { publicBrowsing = true; pendingServiceCode = null; $('#login-modal').close(); current = modules.find(x => x.key === 'guided_services'); renderNav(); loadModule(); });
    $('#browse-public-btn').addEventListener('click', () => { $('#login-modal').close(); renderPublicOverview(); });
    $('#logout-btn').addEventListener('click', () => { localStorage.removeItem(tokenKey); currentUserRoles = []; currentUserMustChangePassword = false; publicBrowsing = true; renderPublicOverview(); showLogin(); });
    $('#search').addEventListener('input', async (e) => { if (['animuse', 'guided_services', 'my_work', 'provincial_reporting', 'admin_center'].includes(current.key))
        return; const q = e.target.value; try {
        const r = await api(current.path + '?q=' + encodeURIComponent(q));
        renderRows(r.data || []);
    }
    catch { } });
}
initPwa();
loadPublicSettings();
renderNav();
bind();
initAuth().then(() => { if (!authenticated())
    return; applyRequestedModule(); renderNav(); if (authenticated())
    loadStats(); if (!currentUserMustChangePassword)
    loadModule(); });
