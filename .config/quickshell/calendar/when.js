.pragma library

// The calendar's date helpers: day and month names, ISO dates (2026-11-27), and the 6 weeks of days in a
// month's grid.
var DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
var MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

function pad(n) {
    return (n < 10 ? "0" : "") + n;
}

function iso(d) {
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
}

function fromIso(s) {
    const m = /^(\d{4})-(\d\d)-(\d\d)/.exec(s || "");
    return m ? new Date(+m[1], m[2] - 1, +m[3]) : null;
}

function addDays(d, n) {
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
}

function wd(d) {
    return (d.getDay() + 6) % 7;
}

function diffDays(a, b) {
    return Math.round((Date.UTC(b.getFullYear(), b.getMonth(), b.getDate()) - Date.UTC(a.getFullYear(), a.getMonth(), a.getDate())) / 86400000);
}

function longDate(d, today) {
    const s = DAYS[wd(d)] + " " + d.getDate() + " " + MONTHS[d.getMonth()];
    return today && d.getFullYear() === today.getFullYear() ? s : s + " " + d.getFullYear();
}

function shortDate(d) {
    return DAYS[wd(d)].slice(0, 3) + " " + d.getDate() + " " + MONTHS[d.getMonth()].slice(0, 3);
}

function heading(d, today) {
    const n = diffDays(today, d);
    return n === 0 ? "Today" : n === 1 ? "Tomorrow" : n === -1 ? "Yesterday" : longDate(d, today);
}

function monthTitle(y, m) {
    return MONTHS[m] + " " + y;
}

function cells(y, m) {
    const first = new Date(y, m, 1), start = addDays(first, -wd(first)), out = [];
    for (let i = 0; i < 42; i++) {
        const d = addDays(start, i);
        out.push({ iso: iso(d), day: d.getDate(), inMonth: d.getMonth() === m });
    }
    return out;
}

function mk(y, m, d) {
    const x = new Date(y, m, d);
    return x.getFullYear() === y && x.getMonth() === m && x.getDate() === d ? x : null;
}

function year(s) {
    if (s === undefined || s === "")
        return -1;
    const y = +s;
    return y < 100 ? 2000 + y : y;
}

function monthOf(w) {
    if (w.length < 3)
        return -1;
    for (let i = 0; i < 12; i++)
        if (MONTHS[i].toLowerCase().startsWith(w) || w === "sept" && i === 8)
            return i;
    return -1;
}

function dayOf(w) {
    if (w.length < 2)
        return -1;
    for (let i = 0; i < 7; i++)
        if (DAYS[i].toLowerCase().startsWith(w) || w === "tues" && i === 1 || w === "weds" && i === 2 || (w === "thur" || w === "thurs") && i === 3)
            return i;
    return -1;
}

// the next one from today: this year's, else next year's (29 feb: the next leap year's)
function noYear(m, d, today) {
    for (let y = today.getFullYear(); y <= today.getFullYear() + 8; y++) {
        const x = mk(y, m, d);
        if (x && diffDays(today, x) >= 0)
            return x;
    }
    return null;
}

function parseDate(text, today) {
    let t = String(text).trim().toLowerCase().replace(/,/g, " ").replace(/(\d)(st|nd|rd|th)\b/g, "$1").replace(/(\d)([a-z])/g, "$1 $2").replace(/([a-z])(\d)/g, "$1 $2").replace(/\s+/g, " ");
    if (t === "" || t === "today" || t === "tod" || t === "now")
        return today;
    if (/^(tomorrow|tmrw?|tom)$/.test(t))
        return addDays(today, 1);
    if (t === "yesterday")
        return addDays(today, -1);
    let m = /^(?:in )?([+-]?) ?(\d+) ?(d|days?|w|wks?|weeks?)?$/.exec(t);
    if (m && (m[1] !== "" || m[3] !== undefined || /^in /.test(t)))
        return addDays(today, (m[1] === "-" ? -1 : 1) * +m[2] * (m[3] && m[3][0] === "w" ? 7 : 1));
    m = /^(next )?([a-z]+)$/.exec(t);
    if (m && dayOf(m[2]) >= 0) {
        const n = (dayOf(m[2]) - wd(today) + 7) % 7;
        return addDays(today, m[1] ? n || 7 : n);
    }
    const words = t.split(" ");
    if (words.length > 1 && dayOf(words[0]) >= 0 && monthOf(words[0]) < 0)
        t = words.slice(1).join(" ");
    if ((m = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(t)))
        return mk(+m[1], m[2] - 1, +m[3]);
    if ((m = /^(\d{1,2}) ?[\/.\-] ?(\d{1,2})(?: ?[\/.\-] ?(\d{2}|\d{4}))?$/.exec(t))) {
        const y = year(m[3]);
        return y < 0 ? noYear(m[2] - 1, +m[1], today) : mk(y, m[2] - 1, +m[1]);
    }
    let d = -1, mo = -1, y = -1;
    if ((m = /^(\d{1,2}) ([a-z]+)(?: (\d{2}|\d{4}))?$/.exec(t)))
        [d, mo, y] = [+m[1], monthOf(m[2]), year(m[3])];
    else if ((m = /^([a-z]+) (\d{1,2})(?: (\d{2}|\d{4}))?$/.exec(t)))
        [d, mo, y] = [+m[2], monthOf(m[1]), year(m[3])];
    if (mo >= 0)
        return y < 0 ? noYear(mo, d, today) : mk(y, mo, d);
    if ((m = /^(\d{1,2})$/.exec(t))) {
        // the next month that has this day, from this one on (30 typed on 31 Jan: 30 March)
        for (let i = 0; i <= 12; i++) {
            const f = new Date(today.getFullYear(), today.getMonth() + i, 1);
            const x = mk(f.getFullYear(), f.getMonth(), +m[1]);
            if (x && diffDays(today, x) >= 0)
                return x;
        }
        return null;
    }
    return null;
}

function parseTime(text) {
    const t = String(text).trim().toLowerCase().replace(/\s+/g, "").replace(/\./g, ":");
    if (t === "" || t === "allday" || t === "-" || t === "none")
        return "";
    if (t === "noon" || t === "midday")
        return "12:00";
    if (t === "midnight")
        return "00:00";
    const m = /^(\d{1,2})(?::?(\d{2}))?(am|pm|a|p)?$/.exec(t);
    if (!m)
        return null;
    let h = +m[1];
    const mi = m[2] === undefined ? 0 : +m[2];
    if (m[3]) {
        if (h < 1 || h > 12)
            return null;
        h = h % 12 + (m[3][0] === "p" ? 12 : 0);
    }
    return h > 23 || mi > 59 ? null : pad(h) + ":" + pad(mi);
}

function parseEnd(text, start) {
    const t = String(text).trim().toLowerCase().replace(/\s+/g, "");
    if (t === "")
        return "";
    const m = /^\+?(?:(\d+(?:\.\d+)?)(?:h|hrs?|hours?))?(?:(\d+)(?:m|mins?|minutes?)?)?$/.exec(t);
    if (m && (t[0] === "+" || /[a-z]/.test(t)) && (m[1] !== undefined || m[2] !== undefined)) {
        if (!start)
            return null;
        const mins = Math.round((m[1] ? +m[1] * 60 : 0) + (m[2] ? +m[2] : 0));
        const [h, mi] = start.split(":").map(Number), tot = (h * 60 + mi + mins) % 1440;
        return mins > 0 ? pad(Math.floor(tot / 60)) + ":" + pad(tot % 60) : null;
    }
    const e = parseTime(t);
    // a bare 1-11 before the start is pm when that's after it (14:30 to 4: 16:00; 22:00 to 2 stays 02:00 next day)
    if (e && start && !/[ap]m?$/.test(t) && e < start) {
        const h = +e.slice(0, 2), pm = pad(h + 12) + e.slice(2);
        if (h >= 1 && h <= 11 && pm > start)
            return pm;
    }
    return e || null;
}

function endDay(ev) {
    const s = ev.s.slice(0, 10), e = ev.e.slice(0, 10);
    if (ev.allday)
        return e > s ? iso(addDays(fromIso(e), -1)) : s;
    return e > s && ev.e.slice(11) === "00:00" ? iso(addDays(fromIso(e), -1)) : e < s ? s : e;
}

function byDay(events, from, to) {
    const map = {};
    for (const ev of events) {
        let d = ev.s.slice(0, 10) < from ? from : ev.s.slice(0, 10);
        const last = endDay(ev) > to ? to : endDay(ev);
        for (let n = 0; d <= last && n < 62; n++, d = iso(addDays(fromIso(d), 1)))
            (map[d] = map[d] || []).push(ev);
    }
    return map;
}

function timeLine(ev, dayIso, today) {
    if (ev.allday) {
        const last = endDay(ev);
        return last <= ev.s.slice(0, 10) ? "All day" : dayIso === last ? "All day · last day" : "All day · until " + shortDate(fromIso(last));
    }
    const sd = ev.s.slice(0, 10), ed = ev.e.slice(0, 10), st = ev.s.slice(11), et = ev.e.slice(11);
    if (sd === ed || endDay(ev) === sd)
        return st === et ? st : st + "–" + et;
    if (dayIso && dayIso > sd)
        return dayIso < ed ? "All day · until " + shortDate(fromIso(ed)) + " " + et : "Until " + et;
    return st + "–" + et + " " + shortDate(fromIso(ed));
}
