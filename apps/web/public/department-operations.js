const esc = (v) => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
let kind = 'work';
let month = '';
let editing = null;
export async function renderDepartmentOperations({ root, api, lang }) {
    const lo = lang === 'lo';
    const now = new Date();
    month ||= `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    const label = (a, b) => lo ? a : b;
    root.innerHTML = `<section class="panel"><div class="panel-head"><h2>${label('ວຽກປະຈຳເດືອນ / ງົບປະມານ', 'Monthly Work & Budget')}</h2><div class="toolbar"><input id="ops-month" type="month" value="${esc(month)}"><button id="ops-work" class="ghost">${label('ວຽກປະຈຳເດືອນ', 'Monthly work')}</button><button id="ops-budget" class="ghost">${label('ງົບປະມານ (ກີບ)', 'Budget (LAK)')}</button><button id="ops-export" class="ghost">CSV</button></div></div><p id="ops-message" role="status"></p><div id="ops-summary"></div><form id="ops-form" class="form-grid"><label><span>${label('ຫົວຂໍ້', 'Title')}</span><input name="title" maxlength="300" required></label>${kind === 'budget' ? `<label><span>${label('ງົບຕາມແຜນ (ກີບ)', 'Planned amount (LAK)')}</span><input name="plannedAmount" type="number" min="0" step="1" value="0" required></label><label><span>${label('ໃຊ້ຈ່າຍຈິງ (ກີບ)', 'Actual amount (LAK)')}</span><input name="actualAmount" type="number" min="0" step="1" value="0" required></label>` : `<label><span>${label('ແຜນວຽກ / ຜົນຄາດໝາຍ', 'Plan / Expected result')}</span><textarea name="plannedResult"></textarea></label><label><span>${label('ຜົນປະຕິບັດຈິງ', 'Actual result')}</span><textarea name="actualResult"></textarea></label>`}<label><span>${label('ໝາຍເຫດ / ເລກອ້າງອີງ', 'Notes / Reference')}</span><textarea name="notes"></textarea></label><div><button class="primary" type="submit">${label('ບັນທຶກຮ່າງ', 'Save draft')}</button><button id="ops-cancel" class="ghost" type="button">${label('ຍົກເລີກແກ້ໄຂ', 'Cancel edit')}</button></div></form><div class="table-wrap"><table><thead><tr><th>${label('ຫົວຂໍ້', 'Title')}</th><th>${kind === 'budget' ? 'LAK' : label('ແຜນ / ຜົນ', 'Plan / Result')}</th><th>${label('ສະຖານະ', 'Status')}</th><th>${label('ດຳເນີນການ', 'Actions')}</th></tr></thead><tbody id="ops-rows"></tbody></table></div></section>`;
    const message = root.querySelector('#ops-message');
    const form = root.querySelector('#ops-form');
    const reload = () => renderDepartmentOperations({ root, api, lang });
    root.querySelector('#ops-month').onchange = (e) => { month = e.target.value; editing = null; reload(); };
    for (const tab of ['work', 'budget'])
        root.querySelector('#ops-' + tab).onclick = () => { kind = tab; editing = null; reload(); };
    root.querySelector('#ops-cancel').onclick = () => { editing = null; form.reset(); };
    let rows = [];
    try {
        rows = (await api(`/department-operations/${kind}?month=${encodeURIComponent(month)}`)).data;
    }
    catch (e) {
        message.textContent = e.message;
        return;
    }
    if (kind === 'budget') {
        const verified = rows.filter(x => x.status === 'VERIFIED');
        const planned = verified.reduce((n, x) => n + BigInt(x.plannedAmount), 0n), actual = verified.reduce((n, x) => n + BigInt(x.actualAmount), 0n);
        root.querySelector('#ops-summary').textContent = label('ສະເພາະລາຍການທີ່ກວດຢືນຢັນ: ', 'Verified entries only: ') + `${planned.toLocaleString()} − ${actual.toLocaleString()} = ${(planned - actual).toLocaleString()} LAK`;
    }
    else
        root.querySelector('#ops-summary').textContent = `${rows.filter(x => x.status === 'VERIFIED').length} / ${rows.length} ${label('ລາຍການກວດຢືນຢັນແລ້ວ', 'entries verified')}`;
    root.querySelector('#ops-rows').innerHTML = rows.map(x => `<tr><td>${esc(x.title)}<small>${esc(x.notes)}</small></td><td>${kind === 'budget' ? `${esc(BigInt(x.plannedAmount).toLocaleString())} / ${esc(BigInt(x.actualAmount).toLocaleString())}` : `${esc(x.plannedResult)}<br>${esc(x.actualResult)}`}</td><td>${esc(x.status)}</td><td>${['DRAFT', 'RETURNED'].includes(x.status) ? `<button class="ghost" data-id="${esc(x.id)}" data-action="edit">${label('ແກ້ໄຂ', 'Edit')}</button><button class="ghost" data-id="${esc(x.id)}" data-action="submit">${label('ສົ່ງກວດ', 'Submit')}</button>` : x.status === 'SUBMITTED' ? `<button class="ghost" data-id="${esc(x.id)}" data-action="verify">${label('ຢືນຢັນ', 'Verify')}</button><button class="ghost" data-id="${esc(x.id)}" data-action="return">${label('ສົ່ງຄືນ', 'Return')}</button>` : ''}</td></tr>`).join('') || `<tr><td colspan="4">${label('ຍັງບໍ່ມີລາຍການໃນເດືອນນີ້', 'No entries for this month')}</td></tr>`;
    if (editing) {
        for (const [key, value] of Object.entries(editing)) {
            const input = form.elements.namedItem(key);
            if (input)
                input.value = String(value ?? '');
        }
    }
    form.onsubmit = async (e) => {
        e.preventDefault();
        try {
            const data = { ...Object.fromEntries(new FormData(form)), reportMonth: month };
            if (editing)
                data.version = editing.version;
            await api(`/department-operations/${kind}${editing ? '/' + editing.id : ''}`, { method: editing ? 'PATCH' : 'POST', body: JSON.stringify(data) });
            editing = null;
            reload();
        }
        catch (e) {
            message.textContent = e.message;
        }
    };
    root.querySelectorAll('[data-action]').forEach((button) => button.onclick = async () => {
        const row = rows.find(x => x.id === button.dataset.id);
        const action = button.dataset.action;
        if (action === 'edit') {
            editing = row;
            reload();
            return;
        }
        try {
            await api(`/department-operations/${kind}/${row.id}/${action}`, { method: 'POST', body: JSON.stringify({ version: row.version }) });
            reload();
        }
        catch (e) {
            message.textContent = e.message;
        }
    });
    root.querySelector('#ops-export').onclick = () => {
        const keys = kind === 'budget' ? ['reportMonth', 'title', 'plannedAmount', 'actualAmount', 'currency', 'status', 'notes'] : ['reportMonth', 'title', 'plannedResult', 'actualResult', 'status', 'notes'];
        const cell = (x) => '"' + String(x ?? '').replace(/^[=+@\-\t\r]/, "'$&").replace(/"/g, '""') + '"';
        const csv = '\ufeff' + [keys, ...rows.map(x => keys.map(k => x[k]))].map(x => x.map(cell).join(',')).join('\r\n');
        const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
        const link = document.createElement('a');
        link.href = url;
        link.download = `LVSP-${kind}-${month}.csv`;
        link.click();
        setTimeout(() => URL.revokeObjectURL(url), 1000);
    };
}
