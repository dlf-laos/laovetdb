// @ts-nocheck
import { presentationToAmu } from './amu-presentation.js';
const E = v => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const format = v => v == null ? '—' : Number(v).toLocaleString(undefined, { maximumFractionDigits: 6 });
export async function renderAmuWorkspace(ctx) {
    const title = document.querySelector('#page-title');
    if (title)
        title.textContent = 'ANIMUSE';
    const root = ctx.root;
    let year = String(new Date().getFullYear()), records = [], summary = {}, reference = {}, editing = null;
    let form = { sourceRef: '', lineRef: '', productName: '', companyName: '', arrivalDate: new Date().toISOString().slice(0, 10), movementType: 'IMPORT', registrationBasis: 'NOT_LINKED', packCount: '', packSize: '', packUnit: 'ml', evidence: '', components: [] };
    const label = (lo, en) => ctx.lang === 'lo' ? lo : en;
    const option = (items, value) => items.map(v => `<option value="${E(v)}" ${v === value ? 'selected' : ''}>${E(v)}</option>`).join('');
    const notify = e => { const box = root.querySelector('#amu-message'); if (box)
        box.textContent = String(e.message || e); };
    async function load() { const r = await ctx.api('/animuse/ledger?year=' + encodeURIComponent(year)); records = r.data.records; summary = r.data.summary; reference = (await ctx.api('/animuse/ledger/reference')).data; }
    function blank() { editing = null; form = { sourceRef: '', lineRef: '', productName: '', companyName: '', arrivalDate: new Date().toISOString().slice(0, 10), movementType: 'IMPORT', registrationBasis: 'NOT_LINKED', packCount: '', packSize: '', packUnit: 'ml', evidence: '', components: [] }; }
    const field = (key, lo, en, type = 'text') => `<label>${label(lo, en)}<input name="${key}" type="${type}" value="${E(form[key])}" ${type === 'number' ? 'min="0" step="any"' : ''}></label>`;
    function components() { return form.components.map((c, i) => `<fieldset data-component="${i}" style="border:1px solid #cbded5;border-radius:10px;padding:12px;margin:12px 0"><legend>${label('ສານອອກລິດ', 'Active ingredient')} ${i + 1}</legend><div class="amu-grid">${[['name', 'ຊື່ສານ / INN', 'text'], ['strength', 'ຄວາມແຮງ / Strength', 'number'], ['evidence', 'ຫຼັກຖານສະຫຼາກ/ໜ້າເອກະສານ / Evidence', 'text']].map(([key, title, type]) => `<label>${title}<input data-key="${key}" type="${type}" value="${E(c[key])}" ${type === 'number' ? 'min="0" step="any"' : ''}></label>`).join('')}<label>WOAH class<select data-key="classCode"><option value="">— ${label('ລໍຖ້າຈັດກຸ່ມ', 'Unmapped')} —</option>${option(reference.classes || [], c.classCode)}</select></label><label>${label('ຫົວໜ່ວຍຄວາມແຮງ', 'Strength unit')}<select data-key="mode">${option(reference.modes || [], c.mode)}</select></label><label>${label('ພື້ນຖານນ້ຳໜັກ', 'Mass basis')}<select data-key="massBasis"><option value="">— Select —</option>${option(['LABEL_COMPOUND', 'ACTIVE_MOIETY'], c.massBasis)}</select></label></div><details><summary>${label('IU, ການແປງສານ ແລະ ການຍົກເວັ້ນ', 'IU, moiety conversion and exclusions')}</summary><div class="amu-grid">${[['iuPerMg', 'IU per mg'], ['activeEntityFactor', 'Active entity factor (0–1)'], ['conversionEvidence', 'Conversion reference'], ['exclusionReason', 'Exclusion reason / reference']].map(([key, title]) => `<label>${title}<input data-key="${key}" value="${E(c[key])}"></label>`).join('')}<label><input type="checkbox" data-key="excluded" ${c.excluded ? 'checked' : ''}> ${label('ຍົກເວັ້ນຈາກຍອດລາຍງານ (ຕ້ອງມີເຫດຜົນ)', 'Exclude from reporting (reason required)')}</label></div></details><button type="button" data-remove="${i}">${label('ເອົາສານນີ້ອອກ', 'Remove ingredient')}</button></fieldset>`).join(''); }
    function draw() {
        root.innerHTML = `<style>.amu-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:12px}.amu-grid label{display:flex;flex-direction:column;gap:5px}.amu-grid input,.amu-grid select{min-height:40px;padding:8px;max-width:100%}.amu-box{background:white;border:1px solid #d5e2dc;padding:18px;border-radius:14px;margin:14px 0}.amu-table{overflow:auto}.amu-table table{width:100%;border-collapse:collapse}.amu-table td,.amu-table th{padding:9px;border-bottom:1px solid #d5e2dc;text-align:left}.amu-box button{padding:8px 12px;margin:4px;cursor:pointer}.amu-warning{background:#fff2d8;padding:12px;border-radius:10px;line-height:1.6}.amu-stats{display:flex;gap:22px;flex-wrap:wrap}.amu-stats b{font-size:22px;display:block}</style>
 <section class="amu-box"><p><a href="/?module=drug_registrations">💊 ${label('ທະບຽນຢາ', 'Drug registration')}</a> · <a href="/?module=trade_workspace">🚚 ${label('ນຳເຂົ້າ · ສົ່ງອອກ', 'Trade workspace')}</a></p><h2>ANIMUSE · ${label('ປະລິມານຢາຈາກການນຳເຂົ້າຈິງ', 'Actual antimicrobial movements')}</h2><p>${label('ເຊື່ອມທະບຽນ → ຂະໜາດບັນຈຸ → ປະລິມານຜ່ານດ່ານ → kg ຂອງແຕ່ລະສານ. ສະຖານະທະບຽນບໍ່ແມ່ນການຢືນຢັນການນຳເຂົ້າ.', 'Registry → exact presentation → actual cleared quantity → kg per active ingredient. Registry linkage does not authorize importation.')}</p><div class="amu-warning">${label('ນັບສະເພາະລາຍການທີ່ກວດຢືນຢັນແລ້ວ. ບໍ່ນັບແຜນ/ຈຳນວນທີ່ຂໍ. ຂາດຂໍ້ມູນ = ລໍຖ້າກວດ, ບໍ່ແມ່ນ 0. ລາຍງານນີ້ບໍ່ແມ່ນຫຼັກຖານວ່າໃຊ້ຢາໃນສັດແລ້ວ.', 'Only reviewed records count. Planned or requested quantities never count. Missing data remain pending, not zero. This is an import-supply report, not evidence of administration to animals.')}</div><p><label>${label('ປີ', 'Year')} <input id="amu-year" type="number" min="2000" max="2200" value="${E(year)}"></label><button id="amu-refresh">${label('ສະແດງ', 'Refresh')}</button><button id="amu-csv">CSV</button><button id="amu-new">+ ${label('ບັນທຶກຜ່ານດ່ານຈິງ', 'Actual movement')}</button></p><div class="amu-stats"><div><b>${format(summary.importKg)}</b>Import kg</div><div><b>${format(summary.reExportKg)}</b>Re-export kg</div><div><b>${format(summary.netImportKg)}</b>${label('ສຸດທິ kg (ກ່ອນກວດ stock)', 'Net kg (before stock reconciliation)')}</div><div><b>${summary.pending || 0}</b>${label('ລໍຖ້າກວດ', 'Pending')}</div></div>${summary.warning ? '<p class="amu-warning">' + E(summary.warning) + '</p>' : ''}<p>${label('ສົ່ງອອກ ແລະ ຜ່ານແດນແຍກຕ່າງຫາກ. ບໍ່ລວມຍອດຂາຍຊ້ຳກັບຍອດນຳເຂົ້າ.', 'Exports and transit are separate. Sales are not added to imports.')}</p><div class="amu-table"><table><thead><tr><th>WOAH class</th><th>Import kg</th></tr></thead><tbody>${Object.entries(summary.byClass || {}).map(([k, v]) => `<tr><td>${E(k)}</td><td>${format(v)}</td></tr>`).join('') || '<tr><td colspan="2">—</td></tr>'}</tbody></table></div></section>
 <section class="amu-box"><h3>${label('ຍອດນຳເຂົ້າຕາມການເຊື່ອມທະບຽນ', 'Imports by registry linkage')}</h3>${Object.entries(summary.byRegistration || {}).map(([k, v]) => `<p>${E(k)}: <b>${format(v)} kg</b></p>`).join('') || '—'}<p>${label('ລາຍການທີ່ຂາດຂໍ້ມູນຢູ່ໃນຍອດລໍຖ້າກວດຂ້າງເທິງ.', 'Incomplete records remain in the pending count above.')}</p></section>
 <div id="amu-message" role="status" style="color:#a63621;white-space:pre-wrap"></div>
 <section class="amu-box"><h3>${editing ? label('ດັດແກ້: ຈະກັບເປັນລໍຖ້າກວດ', 'Edit: returns to draft') : label('ບັນທຶກລາຍການໃໝ່', 'New movement')}</h3><form id="amu-form"><div class="amu-grid">${field('sourceRef', 'ເລກເອກະສານຜ່ານດ່ານ *', 'Clearance document *')}${field('lineRef', 'ເລກແຖວໃນເອກະສານ *', 'Source line *')}${field('arrivalDate', 'ວັນທີຜ່ານດ່ານຈິງ *', 'Actual movement date *', 'date')}<label>${label('ປະເພດ', 'Movement')}<select name="movementType">${option(['IMPORT', 'RE_EXPORT', 'EXPORT', 'TRANSIT'], form.movementType)}</select></label>${field('companyName', 'ບໍລິສັດ', 'Company')}<label>${label('ສະຖານະທະບຽນ', 'Registry linkage')}<select name="registrationBasis">${option(['NOT_LINKED', 'UNREGISTERED', 'REGISTERED'], form.registrationBasis)}</select></label></div><details><summary>${label('ເລືອກລາຍການຈາກວຽກນຳເຂົ້າ', 'Link an existing trade item')}</summary><input id="amu-trade-q" placeholder="Permit / Product"><button id="amu-trade-find" type="button">${label('ຄົ້ນຫາ', 'Search')}</button><select id="amu-trade"><option value="">—</option></select><p>${label('ດຶງສະເພາະຈຳນວນຜ່ານດ່ານທີ່ມີການບັນທຶກ. ຕ້ອງກວດກັບຫຼັກຖານຈິງ.', 'Only recorded clearance quantities are suggested. Verify them against the actual clearance evidence.')}</p></details><details open><summary>${label('ຄົ້ນຫາຢາທີ່ຂຶ້ນທະບຽນ', 'Find a registered presentation')}</summary><input id="amu-reg-q" placeholder="${label('ຊື່ຢາ ຫຼື ເລກທະບຽນ', 'Product or registration number')}"><button id="amu-find" type="button">${label('ຄົ້ນຫາ', 'Search')}</button><select id="amu-package"><option value="">—</option></select><pre id="amu-reg-info" style="white-space:pre-wrap">${E(form.registrationNo || '')}</pre></details><div class="amu-grid">${field('productName', 'ຊື່ຢາ *', 'Product name *')}${field('packCount', 'ຈຳນວນຫີບຫໍ່ຈິງ', 'Actual packs', 'number')}${field('packSize', 'ປະລິມານຕໍ່ 1 ຫີບຫໍ່', 'Content per pack', 'number')}<label>${label('ຫົວໜ່ວຍບັນຈຸ', 'Pack unit')}<select name="packUnit">${option(['ml', 'g', 'unit'], form.packUnit)}</select></label>${field('evidence', 'ເອກະສານ/ໜ້າທີ່ຢືນຢັນຈຳນວນຈິງ *', 'Actual quantity evidence *')}${field('route', 'ວິທີໃຊ້', 'Route')}${field('animalGroup', 'ກຸ່ມສັດ', 'Animal group')}${field('useType', 'ຈຸດປະສົງໃຊ້', 'Use type')}</div><p>${label('kg active = kg ຂອງສານອອກລິດລວມຂອງແຖວນີ້, ບໍ່ແມ່ນນ້ຳໜັກລວມສິນຄ້າ. 1 L = 1000 ml; 1 kg ຜະລິດຕະພັນ = 1000 g.', 'kg active is total active mass for this line, not gross product mass. 1 L = 1000 ml; 1 kg product = 1000 g.')}</p><div id="amu-components">${components()}</div><button type="button" id="amu-add">+ ${label('ສານອອກລິດ', 'Active ingredient')}</button><p><button type="button" id="amu-calculate">${label('ກວດສູດ / ຄຳນວນ', 'Check calculation')}</button><button type="submit">${label('ບັນທຶກເພື່ອລໍຖ້າກວດ', 'Save draft')}</button></p><pre id="amu-result" style="white-space:pre-wrap"></pre></form></section>
 <section class="amu-box amu-table"><h3>${label('ລາຍການ ແລະ ການກວດຢືນຢັນ', 'Movements and review')}</h3><table><thead><tr><th>Date / Source</th><th>Product</th><th>Movement / Registry</th><th>kg / Status</th><th>${label('ຈັດການ', 'Actions')}</th></tr></thead><tbody>${records.map(r => `<tr><td>${E(String(r.movement_date).slice(0, 10))}<br>${E(r.payload.sourceRef)} / ${E(r.payload.lineRef)}</td><td>${E(r.payload.productName)}<br>${E(r.payload.companyName)}</td><td>${E(r.movement_type)}<br>${E(r.payload.registrationBasis)}</td><td>${format(r.calculation.totalKg)}<br>${E(r.status)} · v${r.version}<br>${E((r.calculation.issues || []).join('; '))}</td><td>${r.status !== 'VOID' ? `<button data-edit="${r.id}">${label('ດັດແກ້', 'Edit')}</button>${r.status === 'DRAFT' ? `<button data-review="${r.id}">${label('ກວດຢືນຢັນ', 'Review')}</button>` : ''}<button data-void="${r.id}">${label('ຍົກເລີກ', 'Void')}</button>` : ''}</td></tr>`).join('') || '<tr><td colspan="5">—</td></tr>'}</tbody></table></section>`;
        bind();
    }
    function capture() { const f = root.querySelector('#amu-form'); for (const [k, v] of new FormData(f).entries())
        form[k] = v; root.querySelectorAll('[data-component]').forEach(el => { const c = form.components[Number(el.dataset.component)]; el.querySelectorAll('[data-key]').forEach(input => c[input.dataset.key] = input.type === 'checkbox' ? input.checked : input.value); }); if (form.registrationBasis !== 'REGISTERED') {
        form.productId = null;
        form.packageId = null;
    } }
    function bind() {
        root.querySelector('#amu-refresh').onclick = async () => { year = root.querySelector('#amu-year').value; try {
            await load();
            draw();
        }
        catch (e) {
            notify(e);
        } };
        root.querySelector('#amu-new').onclick = () => { blank(); draw(); root.querySelector('#amu-form').scrollIntoView({ behavior: 'smooth' }); };
        root.querySelector('#amu-add').onclick = () => { capture(); form.components.push({ name: '', classCode: '', mode: 'mg/ml', massBasis: 'LABEL_COMPOUND', strength: '', evidence: '' }); draw(); };
        root.querySelectorAll('[data-remove]').forEach(b => b.onclick = () => { capture(); form.components.splice(Number(b.dataset.remove), 1); draw(); });
        root.querySelector('#amu-calculate').onclick = async () => { capture(); try {
            const r = await ctx.api('/animuse/ledger/calculate', { method: 'POST', body: JSON.stringify(form) });
            root.querySelector('#amu-result').textContent = r.data.issues.length ? r.data.issues.join('\n') : `${format(r.data.totalKg)} kg\n` + r.data.data.components.map(c => `${c.name}: ${format(c.kg)} kg`).join('\n');
        }
        catch (e) {
            notify(e);
        } };
        root.querySelector('#amu-form').onsubmit = async (e) => { e.preventDefault(); capture(); try {
            await ctx.api('/animuse/ledger' + (editing ? '/' + editing.id : ''), { method: editing ? 'PATCH' : 'POST', body: JSON.stringify({ ...form, version: editing?.version }) });
            blank();
            await load();
            draw();
            notify(label('ບັນທຶກແລ້ວ — ຍັງບໍ່ນັບຈົນກວ່າຈະກວດຢືນຢັນ', 'Saved; excluded from totals until reviewed'));
        }
        catch (e) {
            notify(e);
        } };
        root.querySelectorAll('[data-edit]').forEach(b => b.onclick = () => { editing = records.find(r => r.id === b.dataset.edit); form = structuredClone(editing.payload); draw(); root.querySelector('#amu-form').scrollIntoView({ behavior: 'smooth' }); });
        for (const action of ['review', 'void'])
            root.querySelectorAll('[data-' + action + ']').forEach(b => b.onclick = async () => { const r = records.find(r => r.id === b.dataset[action]); const note = prompt(label(action === 'review' ? 'ກວດເອກະສານ, ປະລິມານ, ສູດ ແລະ ການນັບຊ້ຳແລ້ວ: ລະບຸບັນທຶກການກວດ' : 'ເຫດຜົນຍົກເລີກ', action === 'review' ? 'Review source, actual quantities, formula and duplicates; enter review note' : 'Void reason')); if (!note)
                return; try {
                await ctx.api('/animuse/ledger/' + r.id + '/' + action, { method: 'POST', body: JSON.stringify({ version: r.version, note }) });
                await load();
                draw();
            }
            catch (e) {
                notify(e);
            } });
        root.querySelector('#amu-trade-find').onclick = async () => { try {
            const r = await ctx.api('/animuse/ledger/trade-items?q=' + encodeURIComponent(root.querySelector('#amu-trade-q').value));
            const select = root.querySelector('#amu-trade');
            select.innerHTML = '<option value="">—</option>' + r.data.map((p, i) => `<option value="${i}">${E(p.sourceRef || p.applicationNo)} · ${E(p.productName)} · ${E(p.status)}</option>`).join('');
            select.onchange = () => { if (select.value === '')
                return; capture(); const p = r.data[Number(select.value)]; form.applicationItemId = p.id; for (const key of ['productName', 'sourceRef', 'lineRef', 'companyName'])
                form[key] = p[key] ?? ''; form.packCount = p.packCount ?? ''; form.arrivalDate = p.arrivalDate ? String(p.arrivalDate).slice(0, 10) : ''; form.movementType = p.movementType || 'IMPORT'; form.registrationBasis = 'NOT_LINKED'; form.productId = null; form.packageId = null; draw(); };
        }
        catch (e) {
            notify(e);
        } };
        root.querySelector('#amu-find').onclick = async () => { try {
            const r = await ctx.api('/animuse/ledger/presentations?q=' + encodeURIComponent(root.querySelector('#amu-reg-q').value));
            const select = root.querySelector('#amu-package');
            select.innerHTML = '<option value="">— Select exact presentation —</option>' + r.data.map((p, i) => `<option value="${i}">${E(p.registrationNo)} · ${E(p.productName)} · ${E(p.subCode || p.packSizeText || p.packageId)}</option>`).join('');
            select.onchange = () => { if (select.value === '')
                return; capture(); const p = r.data[Number(select.value)]; form.productId = p.productId; form.packageId = p.packageId; form.registrationNo = p.registrationNo; form.registrationBasis = 'REGISTERED'; form.productName = p.productName; const suggested = presentationToAmu(p, reference.substances || []); if (!form.components.length) {
                form.components = suggested.components;
                form.packSize = suggested.packSize;
                form.packUnit = suggested.packUnit;
                root.querySelector('[name="packSize"]').value = String(form.packSize);
                root.querySelector('[name="packUnit"]').value = form.packUnit;
                root.querySelector('#amu-components').innerHTML = components();
            } root.querySelector('[name="productName"]').value = p.productName; root.querySelector('[name="registrationBasis"]').value = 'REGISTERED'; root.querySelector('#amu-reg-info').textContent = `${p.registrationNo} · ${p.registrationStatus} · ${p.expiryDate || ''}\n${p.packSizeText || ''} · ${p.basisText || ''}\n` + p.composition.map(c => `${c.name}: ${c.quantity || '?'} ${c.unit || ''}`).join('\n') + '\n' + label('ກວດແລ້ວປ້ອນຄ່າທີ່ແນ່ນອນລົງສູດ; ບໍ່ຄາດເດົາຈາກຂໍ້ຄວາມ.', 'Verify and enter exact quantities below; text is not guessed into a formula.'); };
        }
        catch (e) {
            notify(e);
        } };
        root.querySelector('#amu-csv').onclick = () => { const cell = v => '"' + String(v ?? '').replace(/^[\s]*[=+@-]/, "'$&").replaceAll('"', '""') + '"'; const lines = [['Year', 'Document', 'Line', 'Date', 'Movement', 'Registry', 'Product', 'Status', 'Substance', 'Class', 'kg', 'Issues', 'Method']]; for (const r of records)
            for (const c of r.calculation.data.components)
                lines.push([year, r.payload.sourceRef, r.payload.lineRef, r.payload.arrivalDate, r.movement_type, r.payload.registrationBasis, r.payload.productName, r.status, c.name, c.classCode, r.status === 'REVIEWED' && !c.excluded ? c.kg : '', (r.calculation.issues || []).join('; '), r.calculation.methodVersion]); const blob = new Blob(['\uFEFF' + lines.map(r => r.map(cell).join(',')).join('\r\n')], { type: 'text/csv;charset=utf-8' }), url = URL.createObjectURL(blob), a = document.createElement('a'); a.href = url; a.download = 'LVSP-AMU-review-' + year + '.csv'; a.click(); URL.revokeObjectURL(url); };
    }
    try {
        await load();
        draw();
    }
    catch (e) {
        root.innerHTML = '<div class="amu-box" role="alert">' + E(e.message) + '</div>';
    }
}
