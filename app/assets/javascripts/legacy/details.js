function escapeHtml(s) {
  return (s || "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]));
}

const fmtDetail = (n) => (n < 0 ? "-$" : "$") + Math.abs(n).toFixed(2);

function commentsFieldHtml(html) {
  return `
    <div class="modal-field" id="detail-comments-field">
      <div class="field-label">Comments</div>
      <div class="field-value" id="detail-comments-value">${html}</div>
    </div>
  `;
}

function commentHtml(c) {
  const author = escapeHtml(c.user_name) || "Someone";
  const fileHtml = c.file_url ? ` <a href="${escapeHtml(c.file_url)}" target="_blank" rel="noopener">attachment</a>` : "";
  return `<div class="detail-comment"><strong>${author}:</strong> ${escapeHtml(c.content)}${fileHtml}</div>`;
}

function showDetailsModal(t) {
  const overlay = document.getElementById("detail-modal-overlay");
  const title = document.getElementById("detail-modal-title");
  const body = document.getElementById("detail-modal-body");

  title.textContent = `${t.date} — ${fmtDetail(t.amount)}`;

  const fields = [
    ["Memo", t.memo],
    ["Tags", t.tags],
    ["User", t.user_name],
    ["Category", t.category_label],
  ];

  const isManual = t.id < 0;
  const deleteHtml = isManual
    ? `<div class="modal-field"><button type="button" class="danger" id="detail-delete-tx">Delete transaction</button></div>`
    : "";

  body.innerHTML = fields.map(([label, value]) => `
    <div class="modal-field">
      <div class="field-label">${label}</div>
      <div class="field-value">${escapeHtml(value) || "—"}</div>
    </div>
  `).join("") + (isManual ? "" : commentsFieldHtml("Loading…")) + deleteHtml;

  overlay.classList.remove("hidden");

  if (isManual) {
    document.getElementById("detail-delete-tx").addEventListener("click", () => deleteManualTransaction(t.id));
  } else {
    loadComments(t.id);
  }
}

async function loadComments(transactionId) {
  try {
    const res = await fetch(`${API_BASE}/api/transactions/${transactionId}/comments`);
    if (!res.ok) throw new Error("bad response");
    const data = await res.json();
    const valueEl = document.getElementById("detail-comments-value");
    if (!valueEl) return; // modal was closed/reopened for another transaction before this resolved
    valueEl.innerHTML = data.comments.length ? data.comments.map(commentHtml).join("") : "—";
  } catch (e) {
    const valueEl = document.getElementById("detail-comments-value");
    if (valueEl) valueEl.textContent = "Could not load comments.";
  }
}

async function deleteManualTransaction(id) {
  if (!confirm("Delete this manually-added transaction? This cannot be undone.")) return;
  const res = await fetch(`/api/transactions/${id}`, { method: "DELETE" });
  if (!res.ok) {
    const err = await res.json();
    alert("Could not delete transaction: " + err.error);
    return;
  }
  hideDetailsModal();
  if (typeof loadAll === "function") loadAll();
  else if (typeof load === "function") load();
}

function hideDetailsModal() {
  document.getElementById("detail-modal-overlay").classList.add("hidden");
}

function wireDetailButtons(root) {
  root.querySelectorAll(".info-icon").forEach((el) => {
    el.addEventListener("click", (e) => {
      e.stopPropagation();
      const t = JSON.parse(el.dataset.detail);
      showDetailsModal(t);
    });
  });
  root.querySelectorAll(".hcb-link").forEach((el) => {
    el.addEventListener("click", (e) => e.stopPropagation());
  });
}

function wireSearchClears() {
  document.querySelectorAll(".search-clear").forEach((btn) => {
    const input = document.getElementById(btn.dataset.clearTarget);
    if (!input) return;
    const sync = () => btn.classList.toggle("visible", input.value.length > 0);
    input.addEventListener("input", sync);
    btn.addEventListener("click", () => {
      input.value = "";
      input.dispatchEvent(new Event("input"));
      input.focus();
    });
    sync();
  });
}

wireSearchClears();

document.getElementById("detail-modal-close").addEventListener("click", hideDetailsModal);
document.getElementById("detail-modal-overlay").addEventListener("click", (e) => {
  if (e.target.id === "detail-modal-overlay") hideDetailsModal();
});
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") hideDetailsModal();
});
