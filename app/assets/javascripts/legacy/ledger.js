const API_BASE = `/organizations/${window.HCB_ORGANIZATION_ID}`;

let ledger = [];
let provisional = [];
let matchedIds = new Set();
let discrepancyIds = new Set();

const fmt = (n) => (n < 0 ? "-$" : "$") + Math.abs(n).toFixed(2);

function amountMatches(amount, query) {
  const q = query.trim();
  if (!q) return true;
  const cleaned = q.replace(/[^0-9.-]/g, "");
  if (!cleaned) return false;
  const target = parseFloat(cleaned);
  if (Number.isNaN(target)) return false;
  return Math.abs(Math.abs(amount) - Math.abs(target)) < 0.005;
}

// `date` and the `after`/`before` filter values are all "YYYY-MM-DD" (HCB's
// transaction date, and <input type="date">'s value), so plain string
// comparison sorts correctly without parsing. Both bounds are inclusive.
function dateInRange(date, after, before) {
  if (after && date < after) return false;
  if (before && date > before) return false;
  return true;
}

function showLedgerMessage(html) {
  document.getElementById("ledger-body").innerHTML = `<tr><td colspan="6">${html}</td></tr>`;
}

async function load() {
  showLedgerMessage(`<div class="empty-msg loading-msg"><span class="loading-spinner"></span>Loading transactions…</div>`);
  provisional = [];
  let data, matchData;
  try {
    const matchesPromise = fetch(`${API_BASE}/api/matches`).then((r) => {
      if (!r.ok) throw new Error("bad response");
      return r.json();
    });

    await loadPagesStreaming(`${API_BASE}/api/ledger/page`, (rows, totalCount) => {
      // Pages arrive newest-first, same order the table displays in -- no
      // reordering needed for this provisional view. Running balance and the
      // zero-point cutoff aren't knowable until the full history is in, so
      // they're left blank until the final, authoritative render below.
      provisional.push(...rows.map((r) => ({ ...r, running_balance: null, is_zero_point: false })));
      renderProvisional(totalCount);
    });

    const [ledgerRes, matchDataResolved] = await Promise.all([
      fetch(`${API_BASE}/api/ledger`),
      matchesPromise,
    ]);
    if (!ledgerRes.ok) throw new Error("bad response");
    data = await ledgerRes.json();
    matchData = matchDataResolved;
  } catch (e) {
    showLedgerMessage(`<div class="empty-msg">Could not load transactions. <a href="#" class="nav-link load-retry">Retry</a></div>`);
    document.querySelector(".load-retry").addEventListener("click", (ev) => {
      ev.preventDefault();
      load();
    });
    return;
  }

  matchedIds = new Set();
  discrepancyIds = new Set();
  for (const m of matchData.matches) {
    const target = m.discrepancy === 0 ? matchedIds : discrepancyIds;
    for (const iid of m.incoming_ids) target.add(iid);
    for (const oid of m.outgoing_ids) target.add(oid);
  }

  // Keep the zero-point row (as a reference) and everything after it,
  // then show newest first.
  const zeroIdx = data.ledger.findIndex((r) => r.is_zero_point);
  const kept = zeroIdx >= 0 ? data.ledger.slice(zeroIdx) : data.ledger;
  ledger = [...kept].reverse();

  document.getElementById("stat-zero-date").textContent = data.zero_balance_date || "n/a";
  document.getElementById("stat-final-balance").textContent = fmt(data.final_balance);
  document.getElementById("stat-count").textContent = ledger.length;

  render();
}

// Shown while pages are still streaming in: raw rows with no search/filter/
// status styling and no running balance yet, just so the table isn't a blank
// spinner for however long the full drain takes.
function renderProvisional(totalCount) {
  document.getElementById("stat-count").textContent = totalCount
    ? `Loading… ${provisional.length} of ~${totalCount}`
    : `Loading… ${provisional.length}…`;
  const body = document.getElementById("ledger-body");
  body.innerHTML = provisional.map((r) => {
    const dirClass = r.amount > 0 ? "amt-in" : "amt-out";
    return `<tr>
      <td>${r.date}</td>
      <td class="memo-cell" title="${escapeHtml(r.memo)}">${escapeHtml(r.memo)}</td>
      <td class="num ${dirClass}">${fmt(r.amount)}</td>
      <td class="num">…</td>
      <td>${escapeHtml(r.user_name)}</td>
      <td>${escapeHtml(r.category_label)}</td>
    </tr>`;
  }).join("");
}

function rowStatus(r) {
  if (discrepancyIds.has(r.id)) return "discrepancy";
  if (matchedIds.has(r.id)) return "matched";
  return "unmatched";
}

function render() {
  const filter = document.getElementById("search-ledger").value.toLowerCase();
  const amountFilter = document.getElementById("search-ledger-amount").value;
  const afterFilter = document.getElementById("search-ledger-after").value;
  const beforeFilter = document.getElementById("search-ledger-before").value;
  const showStatus = {
    matched: document.getElementById("filter-matched").checked,
    discrepancy: document.getElementById("filter-discrepancy").checked,
    unmatched: document.getElementById("filter-unmatched").checked,
  };
  const body = document.getElementById("ledger-body");

  const rows = ledger.filter(
    (r) =>
      showStatus[rowStatus(r)] &&
      r.memo.toLowerCase().includes(filter) &&
      amountMatches(r.amount, amountFilter) &&
      dateInRange(r.date, afterFilter, beforeFilter)
  );

  body.innerHTML = rows.map((r) => {
    const dirClass = r.amount > 0 ? "amt-in" : "amt-out";
    const status = rowStatus(r);
    const statusClass = status === "discrepancy" ? "ledger-discrepancy" : status === "matched" ? "ledger-matched" : "";
    const rowClass = [statusClass, r.is_zero_point ? "zero-point" : ""].filter(Boolean).join(" ");
    return `<tr class="${rowClass}" ${r.is_zero_point ? 'id="zero-point-row"' : ""}>
      <td>${r.date}</td>
      <td class="memo-cell" title="${escapeHtml(r.memo)}">${escapeHtml(r.memo)}${r.is_zero_point ? ' <span class="zero-badge">balance hit $0 here</span>' : ""}</td>
      <td class="num ${dirClass}">${fmt(r.amount)}</td>
      <td class="num">${fmt(r.running_balance)}</td>
      <td>${escapeHtml(r.user_name)}</td>
      <td>${escapeHtml(r.category_label)}</td>
    </tr>`;
  }).join("");

  body.querySelectorAll("tr").forEach((tr, idx) => {
    tr.addEventListener("click", () => showDetailsModal(rows[idx]));
  });
}

document.getElementById("search-ledger").addEventListener("input", render);
document.getElementById("search-ledger-amount").addEventListener("input", render);
document.getElementById("search-ledger-after").addEventListener("input", render);
document.getElementById("search-ledger-before").addEventListener("input", render);
document.getElementById("filter-matched").addEventListener("change", render);
document.getElementById("filter-discrepancy").addEventListener("change", render);
document.getElementById("filter-unmatched").addEventListener("change", render);

load();
