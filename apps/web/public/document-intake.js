const keys = ['productName', 'genericName', 'dosageForm', 'activeIngredients', 'strength', 'packSize', 'manufacturerName', 'manufacturingSite', 'manufacturingCountry', 'applicantName', 'importerName', 'targetSpecies', 'indications', 'dosageAdministration', 'withdrawalPeriod', 'storageConditions', 'shelfLife', 'originRegistrationNumber', 'originRegistrationIssueDate', 'originRegistrationExpiryDate', 'gmpNumber', 'gmpIssuer', 'gmpExpiryDate'];
const types = ['APPLICATION', 'GMP', 'COA', 'MSDS', 'REGISTRATION_CERTIFICATE', 'LABEL', 'PACKAGE_INSERT', 'MANUFACTURING', 'COMPOSITION', 'OTHER'];
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
let previewUrl = null;
export async function renderDocumentIntake({ root, api, lang, token }, selectedId) {
    if (previewUrl) {
        URL.revokeObjectURL(previewUrl);
        previewUrl = null;
    }
    const label = (lo, en) => lang === 'lo' ? lo : en;
    const message = (text) => { const node = root.querySelector('[data-message]'); if (node)
        node.textContent = text; };
    root.innerHTML = `<section class="intake"><h2>${label('ຮັບເອກະສານ ແລະ ກວດທານຄຳຂໍ', 'Dossier intake and review')}</h2><p>${label('ຮ່າງກວດທານ — ຍັງບໍ່ແມ່ນການອະນຸມັດ ຫຼື ໃບທະບຽນ', 'Review draft — not an approval or registration certificate')}</p><p data-message role="status">Loading…</p><div data-content></div></section>`;
    const content = root.querySelector('[data-content]');
    const reload = (id) => renderDocumentIntake({ root, api, lang, token }, id);
    try {
        if (!selectedId) {
            const rows = (await api('/document-intake')).data;
            content.innerHTML = `<form data-create><label>${label('ຊື່ຄຳຂໍ', 'Dossier title')}<input name="title" required maxlength="300"></label><button class="primary">${label('ເປີດຮ່າງໃໝ່', 'New intake')}</button></form><table><thead><tr><th>${label('ຄຳຂໍ', 'Dossier')}</th><th>${label('ສະຖານະ', 'Status')}</th></tr></thead><tbody>${rows.map((row) => `<tr><td><button data-open="${esc(row.id)}">${esc(row.title)}</button></td><td>${esc(row.status)}</td></tr>`).join('')}</tbody></table>`;
            content.querySelector('[data-create]').addEventListener('submit', async (event) => { event.preventDefault(); try {
                const title = new FormData(event.target).get('title');
                const draft = (await api('/document-intake', { method: 'POST', body: JSON.stringify({ title }) })).data;
                await reload(draft.id);
            }
            catch (e) {
                message(e.message);
            } });
            content.querySelectorAll('[data-open]').forEach(node => node.addEventListener('click', () => void reload(node.dataset.open)));
        }
        else {
            const draft = (await api('/document-intake/' + selectedId)).data;
            const locked = draft.status === 'REVIEWED';
            content.innerHTML = `<button data-back>${label('ກັບໄປລາຍການ', 'Back to list')}</button><h3>${esc(draft.title)} · ${esc(draft.status)}</h3><p class="intake-notice">${draft.aiStatus === 'CONFIGURED' ? label('AI ພ້ອມໃຫ້ວິເຄາະ; ຂໍ້ມູນທັງໝົດຕ້ອງກວດທານ.', 'AI extraction is configured. All suggested information requires human review.') : label('AI ຍັງບໍ່ໄດ້ເຊື່ອມຕໍ່. ສາມາດແນບເອກະສານ ແລະ ກວດທານເອງໄດ້.', 'AI is not configured. You can still upload and manually review documents.')}</p><form data-extract ${locked ? 'hidden' : ''}><label><input type="checkbox" name="disclosure" required>${label(`ອະນຸຍາດສົ່ງເອກະສານໃນຮ່າງນີ້ໄປ ${esc(draft.aiProvider?.label || 'AI provider')} ເພື່ອວິເຄາະ (ມີຄ່າ API)`, `I authorize sending this dossier to ${esc(draft.aiProvider?.label || 'AI provider')} for extraction (API charges apply)`)}</label><button ${draft.aiStatus !== 'CONFIGURED' ? 'disabled' : ''}>${label('ວິເຄາະດ້ວຍ AI', 'Extract with AI')}</button><small>AI pilot: maximum 8 files / 8 MiB</small></form><div class="intake-columns"><section><h3>${label('ເອກະສານຕົ້ນສະບັບ', 'Source documents')}</h3><p>PDF / PNG / JPEG / TXT · 2 MiB/file · 20 files</p><form data-upload ${locked ? 'hidden' : ''}><label>${label('ປະເພດ', 'Type')}<select name="documentType">${types.map(x => `<option ${x === 'OTHER' ? 'selected' : ''}>${x}</option>`).join('')}</select></label><input name="file" type="file" accept="application/pdf,image/png,image/jpeg,text/plain" required><button>${label('ແນບເອກະສານ', 'Attach document')}</button></form><ul>${draft.documents.map((doc) => `<li><button data-view="${esc(doc.id)}">${esc(doc.original_filename)}</button> · ${esc(doc.document_type)}${draft.ai_extraction?.classifications?.find((x) => x.documentId === doc.document_id) ? ' · AI suggestion: ' + esc(draft.ai_extraction.classifications.find((x) => x.documentId === doc.document_id).documentType) + ' (review required)' : ''}</li>`).join('')}</ul><div data-viewer>${label('ເລືອກເອກະສານເພື່ອເບິ່ງ', 'Select a document to preview')}</div></section><section><h3>${label('ຂໍ້ມູນກວດທານ', 'Reviewed fields')}</h3><form data-review><fieldset ${locked ? 'disabled' : ''}>${keys.map(key => `<label>${esc(key.replace(/([A-Z])/g, ' $1'))}<textarea name="${key}" maxlength="10000" rows="2" placeholder="${label('ບໍ່ພົບ / ຕ້ອງກວດທານ', 'Not found / requires review')}">${esc(draft.reviewed_fields?.[key] ?? (draft.ai_extraction?.extraction?.fields?.find((x) => x.key === key && x.status === 'FOUND')?.value || ''))}</textarea>${draft.ai_extraction?.extraction?.fields?.find((x) => x.key === key) ? `<small class="intake-evidence">${esc(draft.ai_extraction.extraction.fields.find((x) => x.key === key).status === 'FOUND' && draft.ai_extraction.extraction.fields.find((x) => x.key === key).confidence < 0.8 ? 'LOW CONFIDENCE — REVIEW' : draft.ai_extraction.extraction.fields.find((x) => x.key === key).status)} · ${esc(draft.ai_extraction.extraction.fields.find((x) => x.key === key).confidence ?? '—')} · ${esc(draft.ai_extraction.extraction.fields.find((x) => x.key === key).sources.map((x) => '[' + x.documentId + ' / ' + (x.page ?? x.location) + '] ' + x.quote).join(' | '))}</small>` : ''}</label>`).join('')}<label>${label('ບັນທຶກການກວດ ແລະ ເອກະສານທີ່ຂາດ', 'Review notes and missing documents')}<textarea name="note" maxlength="10000">${esc(draft.review_note)}</textarea></label><label><input type="checkbox" name="confirmed" required>${label('ຂ້ອຍໄດ້ກວດເອກະສານ ແລະ ຂໍ້ມູນແລ້ວ', 'I reviewed the source documents and these fields')}</label><button class="primary">${label('ບັນທຶກການກວດທານ', 'Confirm review')}</button></fieldset></form>${locked ? `<p>${label('ຜູ້ກວດ', 'Reviewed by')}: ${esc(draft.reviewed_by)} · ${esc(draft.reviewed_at)}</p>` : ''}</section></div>`;
            content.querySelector('[data-extract]').addEventListener('submit', async (event) => {
                event.preventDefault();
                const form = event.target;
                const button = form.querySelector('button');
                button.disabled = true;
                message(label('ກຳລັງວິເຄາະ…', 'Extracting…'));
                try {
                    await api('/document-intake/' + selectedId + '/extract', { method: 'POST', body: JSON.stringify({ version: draft.version, provider: draft.aiProvider.id, confirmProviderDisclosure: new FormData(form).get('disclosure') === 'on' }) });
                    await reload(selectedId);
                }
                catch (e) {
                    message(e.message);
                    button.disabled = false;
                }
            });
            content.querySelector('[data-back]').addEventListener('click', () => void reload());
            content.querySelector('[data-upload]').addEventListener('submit', async (event) => {
                event.preventDefault();
                const form = event.target;
                const button = form.querySelector('button');
                button.disabled = true;
                try {
                    const values = new FormData(form);
                    const file = values.get('file');
                    if (!file.size || file.size > 2097152)
                        throw new Error('Maximum 2 MiB per file');
                    const base64 = await new Promise((resolve, reject) => { const reader = new FileReader(); reader.onload = () => resolve(String(reader.result).split(',')[1]); reader.onerror = () => reject(new Error('Cannot read file')); reader.readAsDataURL(file); });
                    await api('/document-intake/' + selectedId + '/documents', { method: 'POST', body: JSON.stringify({ version: draft.version, filename: file.name, mimeType: file.type, base64, documentType: values.get('documentType') }) });
                    await reload(selectedId);
                }
                catch (e) {
                    message(e.message);
                    button.disabled = false;
                }
            });
            content.querySelector('[data-review]').addEventListener('submit', async (event) => {
                event.preventDefault();
                const form = event.target;
                const button = form.querySelector('button');
                button.disabled = true;
                try {
                    const values = new FormData(form);
                    const fields = Object.fromEntries(keys.map(key => [key, String(values.get(key) || '')]));
                    await api('/document-intake/' + selectedId + '/review', { method: 'POST', body: JSON.stringify({ version: draft.version, fields, note: String(values.get('note') || ''), confirmReviewed: values.get('confirmed') === 'on' }) });
                    await reload(selectedId);
                }
                catch (e) {
                    message(e.message);
                    button.disabled = false;
                }
            });
            content.querySelectorAll('[data-view]').forEach(node => node.addEventListener('click', async () => {
                try {
                    const doc = draft.documents.find((x) => x.id === node.dataset.view);
                    const response = await fetch('/api/v1/document-intake/' + selectedId + '/documents/' + doc.id, { headers: { authorization: 'Bearer ' + token() } });
                    if (!response.ok)
                        throw new Error('Document access failed: ' + response.status);
                    if (previewUrl)
                        URL.revokeObjectURL(previewUrl);
                    const blob = await response.blob();
                    previewUrl = URL.createObjectURL(blob);
                    const viewer = content.querySelector('[data-viewer]');
                    viewer.replaceChildren();
                    const download = document.createElement('a');
                    download.href = previewUrl;
                    download.download = doc.original_filename;
                    download.textContent = label('ດາວໂຫຼດຕົ້ນສະບັບ', 'Download original');
                    viewer.append(download);
                    if (doc.mime_type.startsWith('image/')) {
                        const image = document.createElement('img');
                        image.src = previewUrl;
                        image.alt = doc.original_filename;
                        image.style.maxWidth = '100%';
                        viewer.append(image);
                    }
                    else if (doc.mime_type === 'text/plain') {
                        const pre = document.createElement('pre');
                        pre.textContent = await blob.text();
                        viewer.append(pre);
                    }
                    else {
                        const iframe = document.createElement('iframe');
                        iframe.setAttribute('sandbox', '');
                        iframe.title = doc.original_filename;
                        iframe.src = previewUrl;
                        iframe.style.cssText = 'width:100%;height:70vh;border:1px solid #ccc';
                        viewer.append(iframe);
                    }
                }
                catch (e) {
                    message(e.message);
                }
            }));
        }
        message('');
    }
    catch (e) {
        message(e.message);
    }
}
