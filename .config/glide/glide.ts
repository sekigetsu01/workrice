// Glide browser config. Reload with <leader>R; ? in the browser lists the keys.

glide.fs.read("search.js", "utf8").then((text) => {
  const engines: [string, string, string, string][] = JSON.parse(text.slice(text.indexOf("["), text.lastIndexOf("]") + 1));
  engines.forEach(([, name, keyword, url], i) => glide.search_engines.add({
    name, keyword, search_url: url, is_default: i === 0,
    favicon_url: new URL("/favicon.ico", url).href,
  }));
}).catch((err) => console.error("search engines:", err));

// Extensions (installed if missing)
// Pywalfox needs its helper: pywalfox install --manifest-path ~/.glide-browser/native-messaging-hosts
for (const slug of [
  "ublock-origin",
  "darkreader",
  "pywalfox",
  "youtube-recommended-videos",
  "sponsorblock",
  "videospeed",
  "libredirect",
]) {
  glide.addons.install(`https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi`)
    .catch((err) => console.error(`${slug} install failed:`, err));
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const ex = (cmd: string) => glide.excmds.execute(cmd as any);
const key = (seq: string) => glide.keys.send(seq, { skip_mappings: true });
function editing_now(): Promise<boolean> {
  return Promise.race([
    glide.ctx.is_editing().catch(() => false),
    new Promise<boolean>((r) => setTimeout(() => r(false), 100)),
  ]);
}
function edit_or(page: () => unknown, edit: () => unknown) {
  return async () => ((await editing_now()) ? edit() : page());
}
const map = (modes: GlideMode | GlideMode[], lhs: string, rhs: glide.ExcmdString | glide.KeymapCallback | glide.KeymapContentCallback, description: string) =>
  glide.keymaps.set(modes, lhs, rhs, { description });
const current_host = () => { try { return glide.ctx.url.hostname; } catch { return ""; } };

async function tab_at(i: number) {
  const tabs = await glide.tabs.query({ currentWindow: true });
  return i ? tabs[Math.min(i, tabs.length) - 1] : tabs[tabs.length - 1];
}
async function move_tab_smoothly(tab_id: number, index: number) {
  const tabs = () => [...document.querySelectorAll("#tabbrowser-tabs tab.tabbrowser-tab:not([hidden])")] as HTMLElement[];
  const before = new Map(tabs().map((t) => [t, t.getBoundingClientRect().left]));
  await browser.tabs.move(tab_id, { index });
  const moved: HTMLElement[] = [];
  for (const t of tabs()) {
    const from = before.get(t);
    if (from === undefined) continue;
    const dx = from - t.getBoundingClientRect().left;
    if (Math.abs(dx) < 1) continue;
    t.style.transition = "none";
    t.style.transform = `translateX(${dx}px)`;
    moved.push(t);
  }
  if (!moved.length) return;
  moved[0]!.getBoundingClientRect();
  for (const t of moved) {
    t.style.transition = "transform 180ms ease-out";
    t.style.transform = "";
  }
  setTimeout(() => { for (const t of moved) t.style.transition = ""; }, 250);
}
async function go_to_tab(i: number) {
  const tab = await tab_at(i);
  if (tab?.id !== undefined && (i === 0 || tab.index === i - 1)) await browser.tabs.update(tab.id, { active: true });
}
for (let i = 1; i <= 9; i++) {
  map("normal", `<leader>${i}`, () => go_to_tab(i), `Go to tab ${i}`);
  map(["normal", "insert"], `<C-${i}>`, async () => {
    const tab = await glide.tabs.active();
    const target = await tab_at(i);
    if (target && target.id !== tab.id) await move_tab_smoothly(tab.id, target.index);
  }, `Move tab to position ${i}`);
}
async function toggle_mute(tab_id?: number) {
  const tab = tab_id === undefined ? await glide.tabs.active() : await browser.tabs.get(tab_id);
  if (tab?.id !== undefined) await browser.tabs.update(tab.id, { muted: !tab.mutedInfo?.muted });
}
map("normal", "t", "tab_new", "New tab");
map("normal", "<leader>n", "tab_new", "New tab");
map("normal", "x", edit_or(() => ex("tab_close"), () => ex("motion x")), "Close tab (text box: delete char)");
map("normal", "<leader>q", "tab_close", "Close tab");
map("normal", "X", edit_or(() => ex("tab_reopen"), () => ex("motion X")), "Reopen closed tab (text box: delete char before)");
map("normal", "J", edit_or(() => ex("tab_prev"), async () => {
  await key("<End>"); await key("<Del>"); await key("<Space>");
}), "Tab left (text box: join lines)");
map("normal", "K", "tab_next", "Tab right");
map("normal", "<C-Left>", "tab_prev", "Tab left");
map("normal", "<C-Right>", "tab_next", "Tab right");
map("normal", "g0", () => go_to_tab(1), "First tab");
map("normal", "g$", () => go_to_tab(0), "Last tab");
map("normal", "gm", () => toggle_mute(), "Mute / unmute tab");
map("normal", "T", "commandline_show tab ", "Search open tabs");
glide.keymaps.del("normal", "<leader><leader>");

async function urlbar_focus(text = "") {
  await key("<C-l>");
  if (text) await key(text);
}
async function in_new_tab(fn: () => Promise<void>) {
  const tab = await browser.tabs.create({});
  for (let i = 0; i < 40 && tab.id !== undefined; i++) {
    if ((await browser.tabs.get(tab.id).catch(() => null))?.status !== "loading") break;
    await sleep(50);
  }
  await sleep(50);
  await fn();
}
const open_clipboard = async () => { await urlbar_focus(); await key("<C-v><CR>"); };
const in_urlbar = () => document.getElementById("urlbar")?.hasAttribute("focused") ?? false;
map(["normal", "insert"], "<C-j>", () => key(in_urlbar() ? "<Down>" : "<C-j>"), "Address bar: next suggestion");
map(["normal", "insert"], "<C-k>", () => key(in_urlbar() ? "<Up>" : "<C-k>"), "Address bar: previous suggestion");

map("normal", "d", edit_or(() => ex("scroll_half_page_down"), () => start_op("d")), "Half page down (text box: delete …)");
map("normal", "u", edit_or(() => ex("scroll_half_page_up"), () => ex("undo")), "Half page up (text box: undo)");
map("normal", "gg", edit_or(() => ex("scroll_top"), () => key("<C-Home>")), "Top (text box: start of text)");
map("normal", "G", edit_or(() => ex("scroll_bottom"), () => key("<C-End>")), "Bottom (text box: end of text)");
map("normal", "r", edit_or(() => ex("reload"), () => ex("r")), "Reload (text box: replace char)");
map("normal", "<C-r>", edit_or(() => ex("reload"), () => ex("redo")), "Reload (text box: redo)");
map("normal", "yy", edit_or(() => ex("url_yank"), yank_line), "Copy page URL (text box: copy the line)");
map("normal", "p", edit_or(open_clipboard, () => key("<C-v>")), "Open clipboard URL (text box: paste)");
map("normal", "P", edit_or(() => in_new_tab(open_clipboard), () => key("<C-v>")), "Clipboard URL in new tab (text box: paste)");
map("normal", "o", edit_or(urlbar_focus, () => ex("motion o")), "Address bar (text box: new line below)");
map("normal", "O", () => in_new_tab(() => urlbar_focus()), "Address bar in a new tab");
map("normal", "b", edit_or(() => urlbar_focus("*<Space>"), () => ex("motion b")), "Bookmarks (text box: word back)");
map("normal", "B", edit_or(() => in_new_tab(() => urlbar_focus("*<Space>")), () => ex("motion B")), "Bookmarks in a new tab");
map("normal", "H", "back", "Back");
map("normal", "L", "forward", "Forward");
map(["normal", "insert", "ignore"], "<C-f>", async () => {
  if (await glide.findbar.is_open()) await glide.findbar.close();
  else await glide.findbar.open();
}, "Find bar on / off");
map("normal", "n", () => glide.findbar.next_match(), "Next match");

async function image_url(content: any): Promise<string> {
  return content.execute((el: any) => el.currentSrc || el.src || "");
}
async function image_data(url: string): Promise<string> {
  const tab = await glide.tabs.active();
  return glide.content.execute(async (url: string) => {
    const blob = await (await fetch(url)).blob();
    return new Promise<string>((ok, fail) => {
      const r = new FileReader();
      r.onload = () => ok(r.result as string);
      r.onerror = () => fail(r.error);
      r.readAsDataURL(blob);
    });
  }, { tab_id: tab.id, args: [url] });
}
async function copy_image(url: string) {
  const blob = await (await fetch(await image_data(url))).blob();
  const bmp = await createImageBitmap(blob);
  const canvas = new OffscreenCanvas(bmp.width, bmp.height);
  canvas.getContext("2d")!.drawImage(bmp, 0, 0);
  const png = await canvas.convertToBlob({ type: "image/png" });
  await navigator.clipboard.write([new ClipboardItem({ "image/png": png })]);
}
const save_image = async (url: string) => { await browser.downloads.download({ url }); };
function pick_image(action: (url: string) => Promise<void>) {
  return () => glide.hints.show({
    selector: "img", include: "img",
    action: async ({ content }) => {
      const url = await image_url(content);
      if (!url) return;
      try { await action(url); } catch (err) { console.error("image action failed:", err); }
    },
  });
}
map("normal", "yi", pick_image(copy_image), "Copy an image (pick with hints)");
map("normal", "yI", pick_image((url) => navigator.clipboard.writeText(url)), "Copy an image's URL (pick with hints)");
map("normal", "yd", pick_image(save_image), "Save an image (pick with hints)");
map("normal", "N", () => glide.findbar.previous_match(), "Previous match");
map("normal", "<leader>s", () => key("<C-s>"), "Save page");
const in_browser_bar = async (tab_id: number) =>
  !(await glide.content.execute(() => document.hasFocus(), { tab_id }).catch(() => true));
map("normal", "<leader>R", "config_reload", "Reload this config");
map("normal", "<leader>m", toggle_compact_mode, "Compact mode on / off");
map("normal", "?", () => toggle_help(), "Show keys");

let pending_op: "d" | "c" = "d";
const op_done = () => ex(pending_op === "c" ? "mode_change insert" : "mode_change normal");
async function start_op(op: "d" | "c") {
  pending_op = op;
  await ex(`mode_change op-pending --operator=${op}`);
}
async function op_keys(...seq: string[]) {
  for (const s of seq) await key(s);
  await op_done();
}
async function yank_line() {
  await key("<End>"); await key("<S-Home>"); await key("<C-c>"); await key("<End>");
}
map("normal", "c", edit_or(() => {}, () => start_op("c")), "Change … (text box)");
for (const [lhs, seq, what] of [
  ["w", ["<C-Del>"], "word"], ["W", ["<C-Del>"], "WORD"], ["e", ["<C-Del>"], "to word end"],
  ["b", ["<C-BS>"], "word back"], ["B", ["<C-BS>"], "WORD back"],
  ["$", ["<S-End>", "<Del>"], "to end of line"], ["0", ["<S-Home>", "<Del>"], "to start of line"],
  ["^", ["<S-Home>", "<Del>"], "to start of line"], ["G", ["<C-S-End>", "<Del>"], "to end of text"],
  ["gg", ["<C-S-Home>", "<Del>"], "to start of text"], ["c", ["<End>", "<S-Home>", "<Del>"], "the line"],
] as const) {
  map("op-pending", lhs, () => op_keys(...seq), what);
}
const text_op = (op: "d" | "c", ...seq: string[]) => edit_or(() => {}, () => { pending_op = op; return op_keys(...seq); });
map("normal", "D", text_op("d", "<S-End>", "<Del>"), "Delete to end of line (text box)");
map("normal", "C", text_op("c", "<S-End>", "<Del>"), "Change to end of line (text box)");
map("normal", "S", text_op("c", "<End>", "<S-Home>", "<Del>"), "Change the line (text box)");
map("normal", "Y", edit_or(() => {}, yank_line), "Copy the line (text box)");
map("normal", "V", edit_or(() => {}, async () => {
  await ex("motion v"); await key("<End>"); await key("<S-Home>");
}), "Select the line (text box)");
for (const [lhs, seq] of [["j", "<S-Down>"], ["k", "<S-Up>"], ["e", "<C-S-Right>"], ["b", "<C-S-Left>"],
  ["$", "<S-End>"], ["0", "<S-Home>"], ["^", "<S-Home>"], ["G", "<C-S-End>"], ["gg", "<C-S-Home>"]] as const) {
  map("visual", lhs, () => key(seq), "Grow selection");
}
map("visual", "x", async () => { await key("<Del>"); await ex("mode_change normal"); }, "Delete selection");
map("visual", "<C-c>", "visual_selection_copy", "Copy the selection");
map("normal", "<C-c>", () => key("<C-c>"), "Copy the selection");
map("visual", "p", async () => { await key("<C-v>"); await ex("mode_change normal"); }, "Paste over selection");

const HELP: Array<[string, Array<[string, string]>]> = [
  ["Navigating the page", [
    ["j / k", "Scroll down / up"], ["h / l", "Scroll left / right"],
    ["gg / G", "Top / bottom of the page"], ["d / u", "Half a page down / up"],
    ["r", "Reload"], ["yy", "Copy the page URL"],
    ["yi / yI / yd", "Pick an image: copy it / copy its URL / save it"],
    ["p / P", "Open the clipboard's URL here / in a new tab"],
    ["s", "The page's search box (or the address bar)"],
    ["i", "Insert mode"], ["v", "Visual mode"], ["gi", "Focus a text box"],
    ["f / F", "Open a link here / in a new tab"],
    ["Ctrl+C", "Copy what's selected"],
  ]],
  ["Find", [["Ctrl+F", "Open / close the find bar"], ["Esc", "Close the find bar (when it has focus)"], ["n / N", "Next / previous match"]]],
  ["Address bar", [
    ["o / O", "Open a URL or history here / in a new tab"],
    ["b / B", "Open a bookmark here / in a new tab"], ["T", "Search open tabs"],
    ["Esc", "Normal mode in the bar: w b x dw cw… edit it"],
    ["Esc Esc", "Leave the address bar: back to the page"],
  ]],
  ["History", [["H / L", "Back / forward"]]],
  ["Tabs", [
    ["t", "New tab"], ["J / K", "Tab left / right"], ["g0 / g$", "First / last tab"],
    ["Space 1-9", "Go to tab 1-9"], ["Ctrl+1-9", "Move this tab to 1-9"],
    ["yt", "Duplicate tab"], ["x / X", "Close tab / reopen closed tab"],
    ["gm", "Mute / unmute tab"],
    ["Space T", "Save this window's tabs: Glide opens with them (no tabs open: back to a blank tab)"],
    ["Drag a tab", "Reorder · out: new window · onto another window's tabs"],
  ]],
  ["In a text box (Esc first, like Vim)", [
    ["dw db de d$ dd", "Delete word / back / to end / line"],
    ["cw cb c$ cc C S", "Change (delete, then type)"],
    ["D  x  X", "Delete to end of line / char / char before"],
    ["yy  p", "Copy line / paste"], ["u  Ctrl+r", "Undo / redo"],
    ["v  V", "Select (V: the whole line), then:"],
    ["  d c y x p", "  delete / change / copy / delete / paste over"],
    ["w b e 0 $ gg G", "Move"], ["i a A I o", "Type (insert mode)"],
  ]],
  ["Glide", [
    ["Space i", "Keys off / on for this site (remembered)"],
    ["Esc Esc", "Keys off / on for now (or Shift+Esc, or click the mode)"],
    ["Space m", "Compact mode"], ["Space s", "Save the page"],
    ["Space R", "Reload the config"], ["?", "This list (Esc closes)"],
  ]],
];
const close_help = () => { const el = document.getElementById("glide-key-help"); el?.remove(); return !!el; };
function toggle_help() {
  if (close_help()) return;
  const el = (tag: string, className: string, children: any[] | string) =>
    DOM.create_element(tag, typeof children === "string" ? { className, textContent: children } : { className, children });
  const overlay = DOM.create_element("div", {
    id: "glide-key-help",
    children: [el("div", "kh-box", [
      el("div", "kh-head", "Keyboard shortcuts"),
      ...HELP.map(([title, rows]) => el("div", "kh-section", [
        el("div", "kh-title", title),
        ...rows.map(([keys, what]) => el("div", "kh-row", [el("span", "kh-keys", keys), el("span", "kh-what", what)])),
      ])),
    ])],
  }) as HTMLElement;
  overlay.addEventListener("click", close_help);
  document.body.insertAdjacentElement("afterend", overlay);
}

const MODE_LABELS: Record<string, string> = {
  normal: "nor", insert: "ins", visual: "vis", hint: "hint", command: "cmd", "op-pending": "op", ignore: "ign",
};

let win_id: number | undefined;
glide.excmds.create({ name: "glide_window_probe", description: "Internal: find this window" }, async ({ tab_id }) => {
  win_id ??= (await browser.tabs.get(tab_id).catch(() => null))?.windowId;
});
async function this_window_id() {
  if (win_id === undefined) await ex("glide_window_probe").catch(() => {});
  return win_id ?? (await browser.windows.getCurrent()).id;
}

let label_fresh = false;
function update_labels() {
  if (!label_fresh) { label_fresh = true; document.getElementById("glide-mode")?.remove(); }
  let label = document.getElementById("glide-mode");
  if (!label) {
    const toolbar = document.getElementById("TabsToolbar");
    const items = toolbar?.querySelector(":scope > .toolbar-items");
    if (!toolbar || !items) return;
    label = DOM.create_element("div", { id: "glide-mode" }) as HTMLElement;
    label.addEventListener("click", (e: MouseEvent) => { e.stopPropagation(); toggle_keys_for_now(); });
    toolbar.insertBefore(label, items);
  }
  const mode = glide.ctx.mode, text = MODE_LABELS[mode] ?? mode.slice(0, 3);
  if (label.textContent !== text) label.textContent = text;
}

let compact = false;
function toggle_compact_mode() {
  compact = !compact;
  document.getElementById("compact-mode-trigger")?.remove();
  if (!compact) return glide.styles.remove("compact-mode");
  document.body.appendChild(DOM.create_element("div", { id: "compact-mode-trigger" }));
  glide.styles.add(`
    #compact-mode-trigger { position: fixed; top: 0; left: 0; right: 0; height: 12px; z-index: 999997; }
    #navigator-toolbox {
      position: fixed !important; top: 0; left: 0; right: 0; z-index: 999998 !important;
      transform: translateY(-100%); opacity: 0;
      transition: transform 0.2s ease 0.15s, opacity 0.2s ease 0.15s;
    }
    :root:has(#compact-mode-trigger:hover) #navigator-toolbox,
    #navigator-toolbox:hover, #navigator-toolbox:focus-within {
      transform: none; opacity: 1; transition-delay: 0s;
    }
    #PersonalToolbar, #toolbar-menubar, #sidebar-box, #sidebar-splitter, #statuspanel {
      display: none !important;
    }
    :root { --shimmer-top-bottom-browser-margin: 0 !important; }
    #browser, #appcontent, #tabbrowser-tabbox { margin: 0 !important; padding: 0 !important; top: 0 !important; }
  `, { id: "compact-mode", overwrite: true });
}

const NO_VIM_PREF = "_glide.no_vim_sites";
const saved_sites = () => String(glide.prefs.get(NO_VIM_PREF) ?? "").split(",").filter(Boolean);
const site_matches = (host: string, site: string) => host === site || host.endsWith("." + site);
let off_by_site = false;
let keys_on_here = "";

async function set_keys(on: boolean) {
  await ex(on ? "mode_change normal" : "mode_change ignore");
  update_labels();
}
async function apply_site_rule(url: string) {
  let host = "";
  try { host = new URL(url).hostname; } catch {}
  if (host !== keys_on_here) keys_on_here = "";
  const off = !!host && host !== keys_on_here && saved_sites().some((s) => site_matches(host, s));
  if (off && glide.ctx.mode !== "ignore") { off_by_site = true; await set_keys(false); }
  else if (!off && off_by_site) { off_by_site = false; if (glide.ctx.mode === "ignore") await set_keys(true); }
}
async function toggle_keys_for_now() {
  const on = glide.ctx.mode === "ignore";
  off_by_site = false;
  keys_on_here = on ? current_host() : "";
  await set_keys(on);
}
async function toggle_site() {
  const host = current_host();
  if (!host) return;
  const saved = saved_sites();
  if (saved.some((s) => site_matches(host, s))) {
    glide.prefs.set(NO_VIM_PREF, saved.filter((s) => !site_matches(host, s)).join(","));
    off_by_site = false;
    return set_keys(true);
  }
  if (glide.ctx.mode === "ignore") return toggle_keys_for_now();
  glide.prefs.set(NO_VIM_PREF, [...saved, host].join(","));
  off_by_site = true;
  return set_keys(false);
}
map("normal", "<leader>i", toggle_site, "Glide's keys off / on for this site");
let last_esc = 0;
map(["normal", "ignore"], "<Esc>", async ({ tab_id }) => {
  if (close_help()) return;
  if (await glide.findbar.is_focused()) { last_esc = 0; return glide.findbar.close(); }
  if (glide.ctx.mode === "normal" && await in_browser_bar(tab_id)) { last_esc = 0; return key("<F6>"); }
  if (Date.now() - last_esc < 400) { last_esc = 0; return toggle_keys_for_now(); }
  last_esc = Date.now();
  await key("<Esc>");
}, "Esc twice: Glide's keys off / on");
glide.autocmds.create("UrlEnter", /^https?:\/\/([a-z0-9-]+\.)?youtube\.com\//, () => {
  for (const k of ["s", "d", "r", "z", "x", "v"]) glide.buf.keymaps.del("normal", k);
});

const yt_links = glide.messengers.create<{ open: null }>(async () => {
  const tab = await glide.tabs.active();
  const url = await glide.content.execute(() => {
    const g = globalThis as any;
    const u = g.yt_pending;
    g.yt_pending = null;
    return u;
  }, { tab_id: tab.id }).catch(() => null);
  if (url) glide.process.spawn("sh", ["-c", 'exec ~/.local/bin/open-link "$1"', "sh", url]).catch(console.error);
});
glide.autocmds.create("UrlEnter", /^https?:/, ({ url, tab_id }) => {
  if (/^https?:\/\/([a-z0-9-]+\.)*(youtube\.com|youtu\.be)\//.test(url)) return;
  yt_links.content.execute((messenger) => {
    const g = globalThis as any;
    if (g.yt_links) return;
    g.yt_links = true;
    window.addEventListener("click", (e: MouseEvent) => {
      if (e.button !== 0 || e.ctrlKey || e.shiftKey || e.metaKey || e.altKey) return;
      const a = e.composedPath().find((el: any) => el?.localName === "a" && el.href) as HTMLAnchorElement | undefined;
      let host = "";
      try { host = new URL(a?.href ?? "").hostname.toLowerCase(); } catch { return; }
      if (!/^((www|m)\.)?(youtube\.com|youtu\.be)$/.test(host)) return;
      e.preventDefault();
      e.stopImmediatePropagation();
      g.yt_pending = a!.href;
      messenger.send("open");
    }, true);
  }, { tab_id });
});

function focus_guard(mode: string, allow_ms: number, install: boolean) {
  const g = globalThis as any;
  g.mode = mode;
  if (allow_ms) g.allow_until = Date.now() + allow_ms;
  if (g.installed || !install) return;
  g.installed = true;
  g.allow_until ??= 0;
  const editable = (el: any) => !!el && (el.isContentEditable || el.tagName === "TEXTAREA" || (el.tagName === "INPUT"
    && !["button", "checkbox", "radio", "submit", "reset", "file", "image", "range", "color", "hidden"].includes((el.type || "").toLowerCase())));
  const unfocus = (el: any) => { if (Date.now() >= g.allow_until && editable(el)) { el.blur?.(); g.blurred_at = Date.now(); } };
  for (const t of ["mousedown", "pointerdown", "touchstart"]) window.addEventListener(t, () => (g.allow_until = Date.now() + 1000), true);
  window.addEventListener("keydown", (e: KeyboardEvent) => { if (e.key === "Tab") g.allow_until = Date.now() + 1000; }, true);
  document.addEventListener("focusin", (e: FocusEvent) => { if (g.mode === "normal") unfocus(e.composedPath()[0]); }, true);
  if (mode !== "ignore") unfocus(document.activeElement);
}
const guard = (tab_id: number, mode: string, allow_ms = 0, install = false) =>
  glide.content.execute(focus_guard, { tab_id, args: [mode, allow_ms, install] }).catch(() => {});
const guard_just_blurred = () => document.hasFocus() && Date.now() - ((globalThis as any).blurred_at ?? 0) < 500;
map("normal", "gi", async ({ tab_id }) => { await guard(tab_id, "normal", 1500); await ex("focusinput last"); }, "Focus a text box");
function focus_page_search(): boolean {
  (globalThis as any).allow_until = Date.now() + 1500;
  for (const sel of ['input[type="search"]', '[role="search"] input', 'input[name="q"]', 'input[name="query"]',
    'input[name="search"]', 'input[name="s"]', 'input[aria-label*="search" i]', 'input[placeholder*="search" i]',
    'input[id*="search" i]', ".search-bar input"]) {
    const el = Array.from(document.querySelectorAll<HTMLInputElement>(sel))
      .find((e) => !e.disabled && e.type !== "hidden" && e.getClientRects().length);
    if (el) { el.focus(); el.select?.(); return true; }
  }
  return false;
}
map("normal", "s", async ({ tab_id }) => {
  if (await editing_now()) return ex("motion s");
  if (!(await glide.content.execute(focus_page_search, { tab_id }).catch(() => false))) await urlbar_focus();
}, "Search box (page or address bar)");

const CARET_STYLE = { block: 0, underline: 1, line: 2 } as const;
const caret_for_mode = () => CARET_STYLE[glide.modes.get(glide.ctx.mode)?.caret ?? "line"];
const OWNER_PREF = "user.glide.caret_owner";
const MY_TOKEN = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
const caret_mine = () => glide.prefs.get(OWNER_PREF) === MY_TOKEN;
function claim_caret() {
  if (caret_mine()) return;
  glide.prefs.set(OWNER_PREF, MY_TOKEN);
}
function fix_caret() {
  if (!caret_mine()) return;
  const want = caret_for_mode(), was = glide.prefs.get("glide.caret.style");
  if (was === want) return;
  glide.prefs.set("glide.caret.style", want);
}
function refresh_caret() {
  if (!caret_mine()) return;
  const want = caret_for_mode();
  glide.prefs.set("glide.caret.style", want === 2 ? 0 : 2);
  glide.prefs.set("glide.caret.style", want);
}
function refresh_caret_soon() {
  refresh_caret();
  setTimeout(fix_caret, 150);
}
function listen(name: string, type: string, fn: (e: any) => void) {
  const d = document as any, k = `__glide_${name}`;
  if (d[k]) document.removeEventListener(type, d[k], true);
  document.addEventListener(type, (d[k] = fn), true);
}
for (const t of ["keydown", "mousedown"]) listen(`caret_${t}`, t, () => { claim_caret(); fix_caret(); });
listen("caret_focus", "focus", () => fix_caret());
listen("help_close", "keydown", (e: KeyboardEvent) => {
  if ((e.key === "Escape" || e.key === "q") && close_help()) e.preventDefault();
});
browser.windows.onFocusChanged.addListener(async (id: number) => {
  if (id !== browser.windows.WINDOW_ID_NONE && id === await this_window_id()) { claim_caret(); fix_caret(); }
});
let caret_ticking = false;
async function caret_tick() {
  if (caret_ticking) return;
  caret_ticking = true;
  try {
    if (!caret_mine()) {
      if (win_id === undefined) await ex("glide_window_probe").catch(() => {});
      const last = await browser.windows.getLastFocused().catch(() => null);
      if (win_id !== undefined && last?.focused && last.id === win_id) claim_caret();
    }
    fix_caret();
  } finally {
    caret_ticking = false;
  }
}
{
  const d = document as any;
  if (d.__glide_caret_timer) clearInterval(d.__glide_caret_timer);
  d.__glide_caret_timer = setInterval(caret_tick, 150);
}

glide.autocmds.create("ConfigLoaded", () => {
  document.getElementById("compact-mode-trigger")?.remove();
  update_labels();
});
glide.autocmds.create("UrlEnter", /.*/, async ({ url, tab_id }) => {
  close_help();
  win_id ??= (await browser.tabs.get(tab_id).catch(() => null))?.windowId;
  await apply_site_rule(url);
  update_labels();
  refresh_caret_soon();
});
glide.autocmds.create("UrlEnter", /^https?:/, async ({ tab_id }) => {
  for (const wait of [0, 400]) { await sleep(wait); await guard(tab_id, glide.ctx.mode, 0, true); }
});
glide.autocmds.create("ModeChanged", "*", async ({ old_mode, new_mode }) => {
  update_labels();
  refresh_caret_soon();
  const tab = await glide.tabs.active().catch(() => null);
  if (!tab) return;
  await guard(tab.id, new_mode, old_mode === "hint" || new_mode === "hint" ? 1500 : 0);
  if (old_mode === "normal" && new_mode === "insert" && !(await editing_now())
    && await glide.content.execute(guard_just_blurred, { tab_id: tab.id }).catch(() => false)) await ex("mode_change normal");
});

glide.o.which_key_delay = 1_000_000_000;  // no Space popup
glide.o.hint_size = "13px";
const MONO = `"JetBrainsMono Nerd Font", "JetBrains Mono", monospace`;
glide.styles.add(`
  :root {
    --tb-bg: var(--lwt-accent-color, #111111);
    --tb-fg: var(--lwt-text-color, #e0e0e0);
    --tb-dim: color-mix(in srgb, var(--tb-fg) 65%, transparent);
    --tb-line: color-mix(in srgb, var(--tb-fg) 18%, transparent);
    --tb-active-bg: var(--tab-selected-bgcolor, var(--toolbar-bgcolor, #333333));
    --tb-active-fg: var(--tab-selected-textcolor, var(--toolbar-color, var(--tb-fg)));
    --tb-accent: var(--tab-line-color, var(--lwt-tab-line-color, var(--tb-fg)));
    --glide-hint-background: var(--tb-bg) !important;
    --glide-hint-color: var(--tb-fg) !important;
    --glide-hint-border: solid 1px var(--tb-accent) !important;
  }
  /* the whole browser interface in JetBrains Mono */
  :root, :root * { font-family: ${MONO} !important; }
  #urlbar, #urlbar-input, .urlbarView, #PersonalToolbar, menupopup, menu, menuitem,
  panel, findbar, #statuspanel, glide-commandline { font-size: 14px !important; }
  #glide-toolbar-mode-button { display: none !important; }
  #sidebar-button { display: none !important; }
  #import-button { display: none !important; }
  #tabbrowser-tabpanels, #tabbrowser-tabbox, browser[type="content"] { background-color: var(--tb-active-bg) !important; }

  /* tab bar: never set a tab's position, width or flex, or dragging tabs breaks */
  :root {
    --tab-min-height: 36px !important; --tab-block-margin: 0px !important; --tab-border-radius: 6px !important;
    --tab-shadow-max-size: 0px !important; --tab-inline-padding: 14px !important; --tabstrip-min-height: 36px !important;
    --tab-box-shadow-selected: none !important;
    --tb-hover: color-mix(in srgb, var(--tb-fg) 8%, transparent);
    --tb-press: color-mix(in srgb, var(--tb-fg) 15%, transparent);
    --tb-tab-bg: var(--toolbar-bgcolor, var(--tb-active-bg));
    --tabs-navbar-separator-style: none !important;
  }
  #nav-bar { border-top: none !important; box-shadow: none !important; }
  #TabsToolbar {
    background: var(--tb-bg) !important; color: var(--tb-dim) !important; border-bottom: none !important;
    font-size: 14px !important; min-height: 0 !important; padding-inline: 4px !important;
  }
  #TabsToolbar .titlebar-spacer, #TabsToolbar .titlebar-buttonbox-container, #firefox-view-button, #alltabs-button,
  #tabbrowser-tabs .tab-icon-overlay, #tabbrowser-tabs .tab-secondary-label { display: none !important; }
  .tabbrowser-tab, .tab-stack, .tab-content { min-height: 36px !important; max-height: 36px !important; height: 36px !important; }
  #tabbrowser-tabs { margin: 0 !important; padding: 0 !important; border: none !important; }
  .tabbrowser-tab { padding: 0 !important; border: none !important; }
  .tabbrowser-tab {
    background-image: linear-gradient(var(--tb-line), var(--tb-line)) !important;
    background-repeat: no-repeat !important; background-size: 1px 14px !important;
    background-position: right 0 top 13px !important;
  }
  .tabbrowser-tab:is([selected], :hover, [dragtarget]),
  .tabbrowser-tab:has(+ .tabbrowser-tab:is([selected], :hover)),
  .tabbrowser-tab:last-of-type { background-image: none !important; }
  .tab-label {
    overflow: hidden !important; text-overflow: ellipsis !important; white-space: nowrap !important;
    line-height: 32px !important;
  }
  .tab-background {
    margin: 4px 2px 0 !important; min-height: 0 !important; max-height: 32px !important; height: 32px !important;
    border: none !important; border-radius: 6px 6px 0 0 !important; outline: none !important;
    box-shadow: none !important; background: transparent !important; transition: background-color 0.1s ease !important;
  }
  .tabbrowser-tab:hover:not([selected]) .tab-background { background: var(--tb-hover) !important; }
  .tabbrowser-tab[selected] .tab-background { background: var(--tb-tab-bg) !important; }
  .tab-content { padding: 4px 12px 0 14px !important; gap: 8px; color: var(--tb-dim) !important; }
  .tabbrowser-tab:hover .tab-content { color: var(--tb-fg) !important; }
  .tabbrowser-tab[selected] .tab-content { color: var(--tb-active-fg) !important; }
  .tab-icon-image, .tab-throbber, .tab-icon-pending, .tab-sharing-icon-overlay { margin: 0 !important; }
  .tab-close-button {
    opacity: 0; margin: 0 !important; padding: 4px !important; width: auto !important; height: auto !important;
    border-radius: 4px !important; background: transparent !important; fill: currentColor !important;
  }
  .tab-close-button > .toolbarbutton-icon { width: 12px !important; height: 12px !important; }
  .tabbrowser-tab:hover .tab-close-button, .tabbrowser-tab[selected] .tab-close-button { opacity: 0.6; }
  .tabbrowser-tab .tab-close-button:hover { opacity: 1; background: var(--tb-press) !important; }
  .tab-audio-button { margin: 0 !important; border-radius: 4px !important; color: var(--tb-accent) !important; fill: var(--tb-accent) !important; }
  .tab-audio-button:hover { background: var(--tb-press) !important; }
  #tabs-newtab-button, #new-tab-button {
    padding: 0 !important; margin: 4px 2px 0 !important; align-self: center !important; min-height: 0 !important;
    color: var(--tb-dim) !important; fill: currentColor !important; background: none !important;
    border: none !important; box-shadow: none !important; outline: none !important;
  }
  #tabs-newtab-button > .toolbarbutton-icon, #new-tab-button > .toolbarbutton-icon {
    width: 28px !important; height: 28px !important; padding: 8px !important; border-radius: 6px !important;
    background: none !important; box-shadow: none !important; border: none !important; outline: none !important;
  }
  #tabs-newtab-button:hover, #new-tab-button:hover { color: var(--tb-fg) !important; }
  #tabs-newtab-button:hover > .toolbarbutton-icon, #new-tab-button:hover > .toolbarbutton-icon { background: var(--tb-hover) !important; }
  #scrollbutton-up, #scrollbutton-down, #tabbrowser-arrowscrollbox::part(scrollbutton-up),
  #tabbrowser-arrowscrollbox::part(scrollbutton-down) { color: var(--tb-dim) !important; fill: currentColor !important; }
  #tabbrowser-arrowscrollbox::part(overflow-start-indicator), #tabbrowser-arrowscrollbox::part(overflow-end-indicator) { display: none !important; }
  #glide-mode {
    display: flex !important; align-items: center !important; justify-content: center !important;
    flex: none !important; box-sizing: border-box !important; align-self: center !important;
    height: 28px !important; min-height: 28px !important; line-height: 28px !important; min-width: 44px !important;
    padding: 0 10px !important; margin: 4px 4px 0 0 !important; border-radius: 6px !important;
    cursor: pointer; white-space: nowrap; transition: background-color 0.1s ease;
    color: var(--tb-fg); background: var(--tb-hover);
  }
  #glide-mode:hover { background: var(--tb-press); }

  div.glide-internal-hint-marker {
    background: var(--tb-bg) !important; border: 1px solid var(--tb-accent) !important; border-radius: 0 !important;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.6) !important; padding: 1px 4px !important;
  }
  div.glide-internal-hint-marker span { color: var(--tb-fg) !important; text-shadow: none !important; font-weight: bold !important; opacity: 1 !important; }
  div.glide-internal-hint-marker > span.glide-matching-character { color: var(--tb-accent) !important; }

  #glide-key-help {
    position: fixed; inset: 0; z-index: 2147483647; font-size: 13px;
    display: flex; align-items: center; justify-content: center;
    background: color-mix(in srgb, var(--tb-bg) 55%, transparent);
  }
  #glide-key-help .kh-box {
    background: var(--tb-bg); color: var(--tb-fg); border: 1px solid var(--tb-line); padding: 18px 24px;
    max-height: 85vh; overflow: auto; column-count: 2; column-gap: 40px; width: 1040px; max-width: 94vw; box-sizing: border-box;
  }
  #glide-key-help .kh-head { column-span: all; font-size: 16px; margin-bottom: 10px; }
  #glide-key-help .kh-section { break-inside: avoid; margin-bottom: 14px; }
  #glide-key-help .kh-title { color: var(--tb-accent); margin-bottom: 4px; }
  #glide-key-help .kh-row { display: flex; gap: 12px; line-height: 1.6; }
  #glide-key-help .kh-keys { min-width: 130px; flex-shrink: 0; font-weight: bold; }
  #glide-key-help .kh-what { color: var(--tb-dim); }
`, { id: "glide-look", overwrite: true });

const BLANK = `file://${glide.path.home_dir}/.config/glide/blank.html`;
glide.o.newtab_url = BLANK;
glide.autocmds.create("ConfigLoaded", async () => {
  try {
    for (const t of await browser.tabs.query({})) {
      if (t.id && (t.url ?? "").split(/[?#]/)[0] === BLANK) await browser.tabs.reload(t.id);
    }
  } catch (_) {  }
});

const START_TABS = `${glide.path.home_dir}/.config/glide/start-tabs`;
map("normal", "<leader>T", async () => {
  const urls = (await glide.tabs.query({ currentWindow: true }))
    .map((t) => t.url ?? "")
    .filter((u) => u && u.split(/[?#]/)[0] !== BLANK && !/^about:(blank|home|newtab|privatebrowsing)$/.test(u));
  await glide.fs.write(START_TABS, "# Glide opens with these tabs (<leader>T in Glide sets them from the open ones)\n" +
    urls.map((u) => u + "\n").join(""));
  glide.process.spawn("notify-send", ["--app-name=Glide",
    urls.length ? `Start tabs: these ${urls.length}` : "No start tabs", urls.length
      ? "Glide opens with them from now on"
      : "Glide opens on a blank tab again"]).catch(console.error);
}, "Start tabs: Glide opens with these");

// Yours (these win over arkenfox's below)
const DOH = "https://dns.mullvad.net/dns-query";
const MY_PREFS: Record<string, string | number | boolean> = {
  "browser.startup.homepage": BLANK,
  "browser.startup.page": 1,                       // the blank page
  "browser.newtab.preload": false,
  "browser.sessionstore.resume_from_crash": false,
  "browser.cache.disk.enable": true,
  "browser.autofocus": false,
  "browser.toolbars.bookmarks.visibility": "always",
  "browser.bookmarks.addedImportButton": true,
  "toolkit.tabbox.switchByScrolling": false,
  "ui.key.menuAccessKeyFocuses": false,
  "ui.key.menuAccessKey": 0,
  "privacy.query_stripping.enabled": true,
  "privacy.query_stripping.enabled.pbmode": true,
  "privacy.query_stripping.strip_on_share.enabled": true,
  "network.cookie.cookieBehavior": 5,
  "privacy.sanitize.sanitizeOnShutdown": true,
  "privacy.clearOnShutdown_v2.browsingHistoryAndDownloads": true,
  "privacy.clearOnShutdown_v2.downloads": true,
  "privacy.clearOnShutdown_v2.formdata": true,
  "privacy.clearOnShutdown_v2.cache": true,
  "privacy.clearOnShutdown_v2.cookiesAndStorage": false,
  "privacy.clearOnShutdown_v2.siteSettings": false,
  // DNS: Mullvad's encrypted DNS, falling back to the normal DNS
  "network.trr.mode": 2,
  "network.trr.uri": DOH,
  "network.trr.custom_uri": DOH,
  "network.trr.bootstrapAddr": "194.242.2.2",
  // pages prefer dark mode
  "layout.css.prefers-color-scheme.content-override": 0,
  "ui.systemUsesDarkTheme": 1,
  // everything (tabs, bars, pages) 15% bigger
  "layout.css.devPixelsPerPx": "1.15",
};
// arkenfox 144 + user-overrides.js
const ARKENFOX: Record<string, string | number | boolean> = {
  "_glide.arkenfox": "arkenfox 144 + overrides",
  "browser.aboutConfig.showWarning": false,
  "browser.newtabpage.activity-stream.showSponsored": false,
  "browser.newtabpage.activity-stream.showSponsoredTopSites": false,
  "browser.newtabpage.activity-stream.showSponsoredCheckboxes": false,
  "browser.newtabpage.activity-stream.default.sites": "",
  "geo.provider.ms-windows-location": false,
  "geo.provider.use_corelocation": false,
  "geo.provider.use_geoclue": false,
  "extensions.getAddons.showPane": false,
  "extensions.htmlaboutaddons.recommendations.enabled": false,
  "browser.discovery.enabled": false,
  "browser.newtabpage.activity-stream.feeds.telemetry": false,
  "browser.newtabpage.activity-stream.telemetry": false,
  "app.shield.optoutstudies.enabled": false,
  "app.normandy.enabled": false,
  "app.normandy.api_url": "",
  "breakpad.reportURL": "",
  "browser.tabs.crashReporting.sendReport": false,
  "browser.crashReports.unsubmittedCheck.autoSubmit2": false,
  "captivedetect.canonicalURL": "",
  "network.captive-portal-service.enabled": false,
  "network.connectivity-service.enabled": false,
  "browser.safebrowsing.downloads.remote.enabled": false,
  "network.prefetch-next": false,
  "network.dns.disablePrefetch": true,
  "network.dns.disablePrefetchFromHTTPS": true,
  "network.http.speculative-parallel-limit": 0,
  "browser.places.speculativeConnect.enabled": false,
  "network.proxy.socks_remote_dns": true,
  "network.file.disable_unc_paths": true,
  "network.gio.supported-protocols": "",
  "browser.urlbar.speculativeConnect.enabled": false,
  "browser.urlbar.quicksuggest.enabled": false,
  "browser.urlbar.suggest.quicksuggest.nonsponsored": false,
  "browser.urlbar.suggest.quicksuggest.sponsored": false,
  "browser.search.suggest.enabled": false,
  "browser.urlbar.suggest.searches": false,
  "browser.urlbar.trending.featureGate": false,
  "browser.urlbar.addons.featureGate": false,
  "browser.urlbar.amp.featureGate": false,
  "browser.urlbar.importantDates.featureGate": false,
  "browser.urlbar.market.featureGate": false,
  "browser.urlbar.mdn.featureGate": false,
  "browser.urlbar.weather.featureGate": false,
  "browser.urlbar.wikipedia.featureGate": false,
  "browser.urlbar.yelp.featureGate": false,
  "browser.urlbar.yelpRealtime.featureGate": false,
  "browser.formfill.enable": false,
  "browser.search.separatePrivateDefault": true,
  "browser.search.separatePrivateDefault.ui.enabled": true,
  "signon.autofillForms": false,
  "signon.formlessCapture.enabled": false,
  "network.auth.subresource-http-auth-allow": 1,
  "security.webauthn.always_allow_direct_attestation": false,
  "browser.privatebrowsing.forceMediaMemoryCache": true,
  "media.memory_cache_max_size": 65536,
  "browser.sessionstore.privacy_level": 2,
  "toolkit.winRegisterApplicationRestart": false,
  "browser.shell.shortcutFavicons": false,
  "security.ssl.require_safe_negotiation": true,
  "security.tls.enable_0rtt_data": false,
  "security.cert_pinning.enforcement_level": 2,
  "security.remote_settings.crlite_filters.enabled": true,
  "security.pki.crlite_mode": 2,
  "dom.security.https_only_mode": true,
  "dom.security.https_only_mode_send_http_background_request": false,
  "security.ssl.treat_unsafe_negotiation_as_broken": true,
  "browser.xul.error_pages.expert_bad_cert": true,
  "network.http.referer.XOriginTrimmingPolicy": 2,
  "privacy.userContext.enabled": true,
  "privacy.userContext.ui.enabled": true,
  "media.peerconnection.ice.proxy_only_if_behind_proxy": true,
  "media.peerconnection.ice.default_address_only": true,
  "dom.disable_window_move_resize": true,
  "browser.download.start_downloads_in_tmp_dir": true,
  "browser.helperApps.deleteTempFileOnExit": true,
  "browser.uitour.enabled": false,
  "devtools.debugger.remote-enabled": false,
  "permissions.manager.defaultsUrl": "",
  "network.IDN_show_punycode": true,
  "pdfjs.disabled": false,
  "pdfjs.enableScripting": false,
  "browser.tabs.searchclipboardfor.middleclick": false,
  "browser.contentanalysis.enabled": false,
  "browser.contentanalysis.default_result": 0,
  "privacy.antitracking.isolateContentScriptResources": true,
  "security.csp.reporting.enabled": false,
  "browser.download.useDownloadDir": false,
  "browser.download.alwaysOpenPanel": false,
  "browser.download.manager.addToRecentDocs": false,
  "extensions.enabledScopes": 5,
  "extensions.postDownloadThirdPartyPrompt": false,
  "browser.contentblocking.category": "strict",
  "privacy.trackingprotection.allow_list.baseline.enabled": true,
  "privacy.trackingprotection.allow_list.convenience.enabled": true,
  "privacy.clearSiteData.cache": true,
  "privacy.clearSiteData.cookiesAndStorage": false,
  "privacy.clearSiteData.historyFormDataAndDownloads": false,
  "privacy.clearSiteData.browsingHistoryAndDownloads": false,
  "privacy.clearSiteData.formdata": true,
  "privacy.clearHistory.cache": true,
  "privacy.clearHistory.cookiesAndStorage": false,
  "privacy.clearHistory.historyFormDataAndDownloads": false,
  "privacy.clearHistory.browsingHistoryAndDownloads": false,
  "privacy.clearHistory.formdata": true,
  "privacy.sanitize.timeSpan": 0,
  "privacy.window.maxInnerWidth": 1600,
  "privacy.window.maxInnerHeight": 900,
  "privacy.resistFingerprinting.block_mozAddonManager": true,
  "privacy.spoof_english": 1,
  "widget.non-native-theme.use-theme-accent": false,
  "browser.link.open_newwindow": 3,
  "browser.link.open_newwindow.restriction": 0,
  "extensions.blocklist.enabled": true,
  "network.http.referer.spoofSource": false,
  "security.dialog_enable_delay": 1000,
  "privacy.firstparty.isolate": false,
  "extensions.webcompat.enable_shims": true,
  "security.tls.version.enable-deprecated": false,
  "extensions.webcompat-reporter.enabled": false,
  "extensions.quarantinedDomains.enabled": true,
  "datareporting.policy.dataSubmissionEnabled": false,
  "datareporting.healthreport.uploadEnabled": false,
  "toolkit.telemetry.unified": false,
  "toolkit.telemetry.enabled": false,
  "toolkit.telemetry.server": "data:,",
  "toolkit.telemetry.archive.enabled": false,
  "toolkit.telemetry.newProfilePing.enabled": false,
  "toolkit.telemetry.shutdownPingSender.enabled": false,
  "toolkit.telemetry.updatePing.enabled": false,
  "toolkit.telemetry.bhrPing.enabled": false,
  "toolkit.telemetry.firstShutdownPing.enabled": false,
  "toolkit.telemetry.coverage.opt-out": true,
  "toolkit.coverage.opt-out": true,
  "toolkit.coverage.endpoint.base": "",
  "browser.startup.homepage_override.mstone": "ignore",
  "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons": false,
  "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features": false,
  "browser.urlbar.showSearchTerms.enabled": false,
  "privacy.fingerprintingProtection": true,
  "privacy.fingerprintingProtection.overrides": "-CanvasRandomization,-EfficientCanvasRandomization,-WebGLRandomization",
  "privacy.resistFingerprinting": false,
  // US English to sites
  "intl.accept_languages": "en-US, en",
  "javascript.use_us_english_locale": true,
  // the browser's region US too, never looked up from your IP
  "browser.search.region": "US",
  "browser.region.update.enabled": false,
  "browser.region.network.url": "",
  "spellchecker.dictionary": "en-US",
  "privacy.resistFingerprinting.pbmode": false,
  "widget.use-xdg-desktop-portal.file-picker": 1,
  "browser.download.always_ask_before_handling_new_types": false,
  "toolkit.legacyUserProfileCustomizations.stylesheets": true,
  "browser.newtabpage.enabled": false,
  "browser.newtabpage.activity-stream.showWeather": false,
  "browser.newtabpage.activity-stream.system.showWeather": false,
  "browser.newtabpage.activity-stream.feeds.topsites": false,
  "browser.newtabpage.activity-stream.feeds.section.topstories": false,
  "browser.newtabpage.activity-stream.showSearch": false,
  "permissions.default.geo": 2,
  "browser.profiles.enabled": false,
  "identity.fxaccounts.enabled": false,
};
for (const [name, value] of Object.entries({ ...ARKENFOX, ...MY_PREFS })) glide.prefs.set(name, value);
for (const name of ["font.name.monospace.x-western", "font.size.monospace.x-western", "privacy.resistFingerprinting.letterboxing"]) glide.prefs.clear(name);
