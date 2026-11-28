.pragma library

// The bar's helpers: text sizes and baselines, CPU use from /proc/stat, memory, and the labels and tooltips for the
// focused window, network, battery, volume and the tray.
function pango(size) { return size / 1024 * 96 / 72; }

function asc(px, emoji) { return Math.ceil(px * (emoji ? 1900 / 2048 : 1.02) - 1e-9); }
function desc(px, emoji) { return Math.ceil(px * (emoji ? 500 / 2048 : 0.3) - 1e-9); }
function adv(px, emoji, k) { k = k || 1; return Math.round(px / k * (emoji ? 2550 / 2048 : 0.6)) * k; }

function chars(t) {
    const out = [];
    for (let i = 0; i < t.length; i++) {
        const c = t.charCodeAt(i);
        if (c >= 0xd800 && c < 0xdc00 && i + 1 < t.length) {
            out.push(t.slice(i, i + 2));
            i++;
        } else {
            out.push(t[i]);
        }
    }
    return out;
}

function runWidth(t, px, emoji, k) { return t ? chars(t).length * adv(px, emoji, k) : 0; }

function lineH(runs) {
    let a = 0, d = 0;
    for (const r of runs) if (r.t) { a = Math.max(a, asc(r.px, r.emoji)); d = Math.max(d, desc(r.px, r.emoji)); }
    return a + d;
}

function baseline(h, top, bottom, runs) {
    let a = 0;
    for (const r of runs) if (r.t) a = Math.max(a, asc(r.px, r.emoji));
    return top + Math.max(0, Math.floor((h - top - bottom - lineH(runs)) / 2)) + a;
}

function times(stat) {
    const line = stat.slice(0, stat.indexOf("\n"));
    if (!line.startsWith("cpu ")) return null;
    // guest and guest_nice (fields 9-10) are already counted in user and nice
    const v = line.slice(5).trim().split(/\s+/).slice(0, 8).map(Number);
    if (v.length < 5) return { idle: 0, total: 0 };
    return { idle: v[3] + v[4], total: v.reduce((a, b) => a + b, 0) };
}

function usage(prev, cur) {
    if (!prev || !cur) return 0;
    const f = Math.fround, di = f(cur.idle - prev.idle), dt = f(cur.total - prev.total);
    return dt > 0 ? Math.max(0, Math.trunc(f(100 * f(1 - f(di / dt))))) : 0;
}

function shortest(x) {
    for (let p = 1; p < 10; p++) {
        const s = x.toPrecision(p);
        if (Math.fround(Number(s)) === x) return String(Number(s));
    }
    return String(x);
}

function fixed1(x) {
    const s = x * 10, fl = Math.floor(s);
    const n = s - fl === 0.5 ? (fl % 2 === 0 ? fl : fl + 1) : Math.round(s);
    return (n / 10).toFixed(1);
}

function memory(text) {
    const m = {};
    for (const line of text.split("\n")) {
        const i = line.indexOf(":");
        if (i > 0) m[line.slice(0, i)] = parseInt(line.slice(i + 1));
    }
    const total = m.MemTotal || 0;
    const free = "MemAvailable" in m ? m.MemAvailable
        : (m.MemFree || 0) + (m.Buffers || 0) + (m.Cached || 0) + (m.SReclaimable || 0) - (m.Shmem || 0);
    if (!total) return null;
    const used = Math.fround(0.01 * Math.round((total - free) / 10485.76));
    return { text: shortest(used), tip: fixed1(used) + "/" + Number((total / 1048576).toFixed(1)) + " GiB" };
}

function volume(v) { return v + "%"; }

function volIcon(v) { return Math.min(1, Math.max(0, Math.floor(v / 50))) ? "\u{f057e}" : "\u{f0580}"; }

function windowInfo(obj, name) {
    const mons = obj && Array.isArray(obj.monitors) ? obj.monitors : [];
    const m = mons.find(x => x && name && x.name === name) || mons.find(x => x && x.active === true);
    const c = m && m.active_client ? m.active_client : {};
    let title = typeof c.title === "string" ? c.title : "";
    if (!title && typeof c.appid === "string") title = c.appid;
    const cps = chars(title);
    const short = cps.length <= 24 ? title : cps.slice(0, 23).join("") + "…";
    const lay = m && typeof m.layout_symbol === "string" ? m.layout_symbol : "";
    return { text: short && lay ? "[" + lay + "] " + short : short, tip: title };
}

function pomo(line) {
    try {
        const o = JSON.parse(line);
        return { text: String(o.text || ""), cls: String(o["class"] || ""), tip: String(o.tooltip || "") };
    } catch (e) {
        return null;
    }
}

function net(state, essid) {
    if (state === "wifi") {
        const cps = chars(essid);
        if (cps.length <= 16) return { icon: "", text: essid, tip: "" };
        return { icon: "", text: cps.slice(0, 15).join("") + "…", tip: esc(essid) };
    }
    if (state === "ethernet") return { icon: "", text: "Wired" };
    if (state === "disabled") return { icon: "", text: "⚠ Disabled" };
    return { icon: "", text: "Disconnected " };
}

function cpuTip(text) {
    let model = "", threads = 0, phys = "0";
    const cores = {};
    for (const line of String(text).split("\n")) {
        const i = line.indexOf(":");
        if (i < 0) continue;
        const k = line.slice(0, i).trim(), v = line.slice(i + 1).trim();
        if (k === "processor") threads++;
        else if ((k === "model name" || k === "Hardware" || k === "Model") && !model) model = v.replace(/\s+/g, " ");
        else if (k === "physical id") phys = v;
        else if (k === "core id") cores[phys + ":" + v] = true;
    }
    if (!threads) return "";
    const n = Object.keys(cores).length || threads;
    const counts = n + (n === 1 ? " core" : " cores") + " · " + threads + (threads === 1 ? " thread" : " threads");
    return model ? "<b>" + esc(model) + "</b><br>" + counts : counts;
}

function sortSets(list) {
    const a = Array.from(list || []);
    const num = a.every(w => w.id !== "" && !isNaN(Number(w.id)));
    return a.sort((x, y) => num ? Number(x.id) - Number(y.id) : (x.id < y.id ? -1 : x.id > y.id ? 1 : 0));
}

function esc(t) { return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\n/g, "<br>"); }

function trayTip(title, desc, fallback) {
    if (!title) return esc(fallback || "");
    return desc ? "<b>" + esc(title) + "</b><br>" + esc(desc) : esc(title);
}

function menuText(t){ return String(t || "").replace(/_(.)/g, "$1"); }

function battery(sys) {
    const p = sys ? sys.bat : undefined;
    if (typeof p !== "number") return { icon: "", text: "", cls: "", tip: "" };
    const st = sys.batStatus || "", left = sys.batLeft || "";
    const icons = ["\u{f007b}", "\u{f007c}", "\u{f007e}", "\u{f0080}", "\u{f0082}", "\u{f0079}"];
    const cls = st === "Charging" ? "charging" : st === "Full" || st === "Not charging" ? "plugged"
        : p <= 20 ? "critical" : p <= 30 ? "warning" : "";
    const icon = cls === "charging" || cls === "plugged" ? "\u{f0084}" : icons[Math.min(5, Math.round(p / 20))];
    const est = sys.batOnBattery ? sys.batOnBattery + " left on battery" : "";
    const tip = cls === "charging" ? [left ? left + " until full" : "", est].filter(x => x).join(" · ") || "Charging"
        : cls === "plugged" ? est || (st === "Full" ? "Full" : "Plugged in") : left ? left + " left" : "";
    return { icon: icon, text: p + "%", cls: cls, tip: tip };
}
