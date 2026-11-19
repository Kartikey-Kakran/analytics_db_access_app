const textarea = document.getElementById("sql");
const highlight = document.getElementById("highlight");
const editor = document.getElementById("editor");

const KEYWORDS = new Set((
  "select from where join inner left right full outer cross on using as with recursive " +
  "distinct all union intersect except case when then else end and or not null is in exists " +
  "between like ilike escape group by having order asc desc nulls first last limit offset " +
  "qualify window partition rows range unbounded preceding following current row filter " +
  "over values create replace view table temporary temp drop alter insert into update delete " +
  "returning copy to cast try_cast true false date interval at time zone lateral pivot unpivot"
).split(/\s+/));

let currentArgs = {};
let lastSentValue = null;
let sendTimer = null;
let hasUnacknowledgedEdits = false;

function escapeHtml(text) {
  return text.replace(/[&<>"']/g, (char) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  })[char]);
}

function renderHighlightedSql(sql) {
  const tables = new Set((currentArgs.tables || []).map((name) => name.toLowerCase()));
  const columns = new Set();
  const columnsByTable = currentArgs.columns || {};
  Object.values(columnsByTable).forEach((items) => {
    items.forEach((column) => columns.add(String(column).toLowerCase()));
  });

  const tokenPattern = /(--[^\n]*|\/\*[\s\S]*?\*\/|'(?:''|[^'])*'|"(?:""|[^"])*"|`[^`]*`|\b[A-Za-z_][A-Za-z0-9_$]*\b|\b\d+(?:\.\d+)?\b|\s+|.)/g;
  const tokens = sql.match(tokenPattern) || [];
  let expectTable = false;

  const html = tokens.map((token) => {
    if (token.startsWith("--") || token.startsWith("/*")) {
      return `<span class="comment">${escapeHtml(token)}</span>`;
    }
    if (token.startsWith("'")) {
      return `<span class="string">${escapeHtml(token)}</span>`;
    }
    if (/^\s+$/.test(token)) return escapeHtml(token);

    const quotedIdentifier = token.startsWith('"') || token.startsWith("`");
    const bareName = quotedIdentifier
      ? token.slice(1, -1).replace(/""/g, '"')
      : token;
    if (/^[A-Za-z_][A-Za-z0-9_$]*$/.test(bareName)) {
      const lower = bareName.toLowerCase();
      let style = "";
      if (!quotedIdentifier && KEYWORDS.has(lower)) {
        style = "keyword";
        expectTable = lower === "from" || lower === "join";
      } else if (expectTable && tables.has(lower)) {
        style = "table-name";
        expectTable = false;
      } else if (tables.has(lower)) {
        style = "table-name";
      } else if (columns.has(lower)) {
        style = "column-name";
        expectTable = false;
      } else {
        expectTable = false;
      }
      const escaped = escapeHtml(token);
      return style ? `<span class="${style}">${escaped}</span>` : escaped;
    }
    if (/^\d/.test(token)) return `<span class="number">${escapeHtml(token)}</span>`;
    if (/^[=<>!+*/%|-]+$/.test(token)) return `<span class="operator">${escapeHtml(token)}</span>`;
    return escapeHtml(token);
  }).join("");

  highlight.innerHTML = `${html}\n`;
  highlight.scrollTop = textarea.scrollTop;
  highlight.scrollLeft = textarea.scrollLeft;
}

function sendMessage(type, data = {}) {
  window.parent.postMessage({ isStreamlitMessage: true, type, ...data }, "*");
}

function handleRender(event) {
  const message = event.data;
  if (!message || message.type !== "streamlit:render") return;
  currentArgs = message.args || {};

  const incoming = String(currentArgs.value ?? currentArgs.default ?? "");
  if (lastSentValue !== null && incoming === lastSentValue) {
    hasUnacknowledgedEdits = false;
  }
  const editorIsFocused = document.activeElement === textarea;
  if (
    textarea.value !== incoming &&
    !hasUnacknowledgedEdits &&
    !editorIsFocused
  ) {
    textarea.value = incoming;
  }
  editor.style.height = `${Number(currentArgs.height) || 300}px`;
  renderHighlightedSql(textarea.value);
}

textarea.addEventListener("input", () => {
  hasUnacknowledgedEdits = true;
  renderHighlightedSql(textarea.value);
  window.clearTimeout(sendTimer);
  sendTimer = window.setTimeout(sendValueToStreamlit, 300);
});

function sendValueToStreamlit() {
  window.clearTimeout(sendTimer);
  if (textarea.value !== lastSentValue) {
    lastSentValue = textarea.value;
    sendMessage("streamlit:setComponentValue", {
      value: textarea.value,
      dataType: "json"
    });
  }
}

// Commit the current SQL as soon as the user leaves the editor.
textarea.addEventListener("blur", sendValueToStreamlit);

textarea.addEventListener("scroll", () => {
  highlight.scrollTop = textarea.scrollTop;
  highlight.scrollLeft = textarea.scrollLeft;
});

window.addEventListener("message", handleRender);
sendMessage("streamlit:componentReady", { apiVersion: 1 });
sendMessage("streamlit:setFrameHeight", { height: 300 });
