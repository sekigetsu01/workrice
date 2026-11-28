.pragma library

// The calculator's conversions (Super+'): units ("5 ft to cm"), temperatures, fuel economy, and money
// ("50 pounds to yen", "$5 to €", at the rates fx saves). Used by CalcPanel.qml

const T = {};
function add(kind, size, names, label) {
    const n = names.split(" ");
    for (const x of n)
        T[x] = [kind, size, label || n[0], n[0]];
}
add("length", 1e-9, "nm nanometre nanometres nanometer nanometers");
add("length", 1e-6, "µm um micron microns micrometre micrometres", "µm");
add("length", 0.001, "mm millimetre millimetres millimeter millimeters");
add("length", 0.01, "cm centimetre centimetres centimeter centimeters");
add("length", 1, "m metre metres meter meters");
add("length", 1000, "km kilometre kilometres kilometer kilometers");
add("length", 0.0000254, "thou mil", "thou");
add("length", 0.0254, "in inch inches", "in");
add("length", 0.3048, "ft foot feet", "ft");
add("length", 0.9144, "yd yard yards");
add("length", 1609.344, "mi mile miles");
add("length", 1852, "nmi nauticalmile nauticalmiles", "nmi");
add("length", 9.4607304725808e15, "ly lightyear lightyears", "ly");
add("area", 1e-6, "mm2 mm² sqmm", "mm²");
add("area", 1e-4, "cm2 cm² sqcm", "cm²");
add("area", 1, "m2 m² sqm sqmetre sqmetres sqmeter sqmeters", "m²");
add("area", 1e6, "km2 km² sqkm", "km²");
add("area", 0.00064516, "in2 in² sqin sqinch sqinches", "in²");
add("area", 0.09290304, "ft2 ft² sqft sqfoot sqfeet", "ft²");
add("area", 0.83612736, "yd2 yd² sqyd sqyard sqyards", "yd²");
add("area", 2589988.110336, "mi2 mi² sqmi sqmile sqmiles", "mi²");
add("area", 4046.8564224, "acre acres ac", "acres");
add("area", 10000, "ha hectare hectares", "ha");
add("volume", 0.001, "ml millilitre millilitres milliliter milliliters cc cm3 cm³", "ml");
add("volume", 0.01, "cl centilitre centilitres");
add("volume", 0.1, "dl");
add("volume", 1, "l litre litres liter liters");
add("volume", 1000, "m3 m³", "m³");
add("volume", 0.016387064, "in3 in³", "in³");
add("volume", 28.316846592, "ft3 ft³", "ft³");
add("volume", 0.005, "tsp teaspoon teaspoons");
add("volume", 0.015, "tbsp tablespoon tablespoons");
add("volume", 0.25, "cup cups");
add("volume", 0.2365882365, "uscup uscups", "US cup");
add("volume", 0.0284130625, "floz fluidounce fluidounces impfloz", "fl oz");
add("volume", 0.0295735295625, "usfloz usfluidounce usfluidounces", "US fl oz");
add("volume", 0.56826125, "pt pint pints imppint imperialpint", "pt");
add("volume", 0.473176473, "uspint uspints uspt", "US pt");
add("volume", 1.1365225, "qt quart quarts impqt imperialquart", "qt");
add("volume", 0.946352946, "usqt usquart usquarts", "US qt");
add("volume", 4.54609, "gal gallon gallons impgal imperialgallon", "gal");
add("volume", 3.785411784, "usgal usgallon usgallons", "US gal");
add("mass", 1e-9, "µg ug microgram micrograms", "µg");
add("mass", 1e-6, "mg milligram milligrams");
add("mass", 0.0002, "ct carat carats", "ct");
add("mass", 0.001, "g gram grams gramme grammes");
add("mass", 1, "kg kilo kilos kilogram kilograms");
add("mass", 1000, "t tonne tonnes metricton", "t");
add("mass", 0.028349523125, "oz ounce ounces");
add("mass", 0.45359237, "lb lbs pound pounds", "lb");
add("mass", 6.35029318, "st stone stones", "st");
add("mass", 907.18474, "uston ton tons shortton", "US ton");
add("mass", 1016.0469088, "ukton longton imperialton", "UK ton");
add("speed", 1, "m/s mps", "m/s");
add("speed", 1 / 3.6, "kph kmh km/h kmph", "km/h");
add("speed", 0.44704, "mph");
add("speed", 0.3048, "ft/s fps", "ft/s");
add("speed", 1852 / 3600, "knot knots kn kt", "knots");
add("speed", 343, "mach");
add("speed", 299792458, "lightspeed");
add("time", 1e-9, "ns nanosecond nanoseconds");
add("time", 1e-6, "µs us microsecond microseconds", "µs");
add("time", 0.001, "ms millisecond milliseconds");
add("time", 1, "s sec secs second seconds");
add("time", 60, "min mins minute minutes");
add("time", 3600, "h hr hrs hour hours");
add("time", 86400, "d day days", "days");
add("time", 604800, "wk week weeks", "weeks");
add("time", 1209600, "fortnight fortnights");
add("time", 2629800, "mo month months", "months");
add("time", 31557600, "y yr yrs year years", "years");
add("time", 315576000, "decade decades");
add("time", 3155760000, "century centuries");
add("data", 0.125, "bit bits");
add("data", 125, "kbit kbits kb/s kbps", "kbit");
add("data", 125000, "mbit mbits mbps", "Mbit");
add("data", 125000000, "gbit gbits gbps", "Gbit");
add("data", 125000000000, "tbit tbits tbps", "Tbit");
add("data", 128, "kibit kibits", "Kibit");
add("data", 131072, "mibit mibits", "Mibit");
add("data", 134217728, "gibit gibits", "Gibit");
add("data", 137438953472, "tibit tibits", "Tibit");
add("data", 1, "b byte bytes", "B");
add("data", 1e3, "kb kilobyte kilobytes", "kB");
add("data", 1e6, "mb megabyte megabytes", "MB");
add("data", 1e9, "gb gigabyte gigabytes", "GB");
add("data", 1e12, "tb terabyte terabytes", "TB");
add("data", 1024, "kib", "KiB");
add("data", 1048576, "mib", "MiB");
add("data", 1073741824, "gib", "GiB");
add("data", 1099511627776, "tib", "TiB");
add("energy", 1, "j joule joules", "J");
add("energy", 1000, "kj kilojoule kilojoules", "kJ");
add("energy", 1e6, "mj megajoule megajoules", "MJ");
add("energy", 4.184, "cal calorie calories");
add("energy", 4184, "kcal kilocalorie kilocalories");
add("energy", 3600, "wh", "Wh");
add("energy", 3600000, "kwh", "kWh");
add("energy", 1055.05585262, "btu", "BTU");
add("energy", 1.602176634e-19, "ev", "eV");
add("power", 1, "w watt watts", "W");
add("power", 1000, "kw kilowatt kilowatts", "kW");
add("power", 745.69987158227, "hp horsepower", "hp");
add("power", 735.49875, "ps", "PS");
add("pressure", 1, "pa pascal pascals", "Pa");
add("pressure", 100, "hpa mbar millibar millibars", "hPa");
add("pressure", 1000, "kpa", "kPa");
add("pressure", 100000, "bar bars", "bar");
add("pressure", 6894.757293168, "psi");
add("pressure", 101325, "atm atmosphere atmospheres", "atm");
add("pressure", 133.322387415, "mmhg torr", "mmHg");
add("angle", 1, "deg degree degrees", "deg");
add("angle", 180 / Math.PI, "rad radian radians", "rad");
add("angle", 0.9, "grad gradian gradians", "grad");
add("angle", 360, "turn turns rev revs revolution revolutions", "turns");
add("frequency", 1, "hz hertz", "Hz");
add("frequency", 1e3, "khz", "kHz");
add("frequency", 1e6, "mhz", "MHz");
add("frequency", 1e9, "ghz", "GHz");
add("frequency", 1 / 60, "rpm", "rpm");
add("temp", "c", "c celsius centigrade", "°C");
add("temp", "f", "f fahrenheit", "°F");
add("temp", "k", "k kelvin", "K");
add("fuel", "mpg", "mpg");
add("fuel", "usmpg", "usmpg", "US mpg");
add("fuel", "l100", "l/100km", "l/100km");
add("fuel", "kpl", "kpl km/l", "km/l");

const USUAL = {
    c: ["f"], f: ["c"], k: ["c"],
    mm: ["in"], cm: ["in", "ft"], m: ["ft", "yd"], km: ["mi"], in: ["cm", "mm"], ft: ["m", "cm"], yd: ["m"], mi: ["km"], nmi: ["km"],
    mg: ["g"], g: ["oz"], kg: ["lb", "st"], oz: ["g"], lb: ["kg", "g", "st"], st: ["kg", "lb"], t: ["ukton", "uston"], uston: ["t"], ukton: ["t"],
    ml: ["floz", "tsp"], cl: ["ml", "floz"], l: ["pt", "gal"], floz: ["ml"], usfloz: ["ml"], pt: ["l", "ml"], uspint: ["l", "ml"],
    qt: ["l"], usqt: ["l"], gal: ["l"], usgal: ["l"], cup: ["ml"], uscup: ["ml"], tsp: ["ml"], tbsp: ["ml"],
    kph: ["mph"], mph: ["kph"], "m/s": ["kph", "mph"], knot: ["kph"], m2: ["ft2"], ft2: ["m2"], acre: ["ha"], ha: ["acre"],
    kcal: ["kj"], kj: ["kcal"], cal: ["j"], kwh: ["mj"], w: ["hp"], hp: ["kw"], kw: ["hp"], psi: ["bar"], bar: ["psi"], atm: ["psi"],
    deg: ["rad"], rad: ["deg"], mpg: ["l/100km"], usmpg: ["l/100km"], "l/100km": ["mpg"], kpl: ["mpg"]
};
const US = { pt: "uspint", gal: "usgal", qt: "usqt", floz: "usfloz" };
const SPLIT = { ft: ["in", 12], st: ["lb", 14] };
const CURRENCIES = "AUD BGN BRL CAD CHF CNY CZK DKK EUR GBP HKD HUF IDR ILS INR ISK JPY KRW MXN MYR NOK NZD PHP PLN RON SEK SGD THB TRY USD ZAR";

// currency symbols
const SYMBOLS = [["NZ$", "NZD"], ["HK$", "HKD"], ["MX$", "MXN"], ["CN¥", "CNY"], ["R$", "BRL"], ["A$", "AUD"], ["C$", "CAD"],
                 ["S$", "SGD"], ["$", "USD"], ["£", "GBP"], ["€", "EUR"], ["¥", "JPY"], ["₹", "INR"], ["₩", "KRW"], ["₺", "TRY"],
                 ["₪", "ILS"], ["฿", "THB"], ["₱", "PHP"], ["zł", "PLN"], ["Kč", "CZK"]];
const AFTER = ["PLN", "CZK"];
const NAMES = { yen: "JPY", dollar: "USD", buck: "USD", euro: "EUR", quid: "GBP", sterling: "GBP", rupee: "INR", yuan: "CNY",
                renminbi: "CNY", rmb: "CNY", won: "KRW", franc: "CHF", rand: "ZAR", peso: "MXN", real: "BRL", reais: "BRL",
                zloty: "PLN", zlotys: "PLN", baht: "THB", ringgit: "MYR", rupiah: "IDR", shekel: "ILS", lira: "TRY", lire: "TRY",
                forint: "HUF", koruna: "CZK", krona: "SEK", kronor: "SEK", krone: "NOK", kroner: "NOK" };
// words that are another unit on their own but money beside a currency
const MONEY_TOO = { pound: "GBP", pounds: "GBP", y: "JPY" };
const WHOLE = ["JPY", "KRW", "IDR", "HUF", "ISK"];
function symbolCode(sym) {
    const hit = SYMBOLS.find(p => p[0].toLowerCase() === sym.toLowerCase());
    return hit ? hit[1] : sym;
}
function symbols(t) {
    const alt = SYMBOLS.map(p => p[0].replace(/[$]/g, "\\$")).join("|");
    t = t.replace(new RegExp("(" + alt + ")\\s*(-?\\d[\\d,]*(?:\\.\\d+)?)", "gi"), (m, sym, n) => n.replace(/,/g, "") + " " + symbolCode(sym) + " ");
    t = t.replace(new RegExp("(\\d)\\s*(" + alt + ")(?![a-z])", "gi"), (m, d, sym) => d + " " + symbolCode(sym));
    return t.replace(new RegExp("(^|\\s|[a-z])(" + alt + ")(?=\\s|$)", "gi"), (m, a, sym) => (/[a-z]/i.test(a) ? a + " " : a) + symbolCode(sym));
}
function spaced(t, rates) {
    t = t.replace(/\s*(->|→|=)\s*/g, " $1 ");
    return t.replace(/[a-zµ°][a-z0-9°²³µ\/]*/gi, w => {
        if (unit(w, rates))
            return w;
        const re = /into|to|in|as/gi;
        let k;
        while ((k = re.exec(w))) {
            const a = w.slice(0, k.index), b = w.slice(re.lastIndex);
            if ((a === "" || unit(a, rates)) && (b === "" || unit(b, rates)) && (a !== "" || b !== ""))
                return [a, k[0], b].filter(x => x !== "").join(" ");
        }
        return w;
    });
}
function money(code, n) {
    const hit = SYMBOLS.find(p => p[1] === code);
    return !hit ? n + " " + code : AFTER.indexOf(code) !== -1 ? n + " " + hit[0] : hit[0] + n;
}

function unit(u, rates) {
    // a capital prefix with a small b is bits (Mb, Gb, Kib); all-lowercase mb/gb/kb stay bytes
    if (/^[KMGT]i?b$/.test(u))
        return T[u.slice(0, -1).toLowerCase() + "bit"];
    u = u.toLowerCase().replace(/°/g, "");
    const hit = T[u] || (/s$/.test(u) && T[u.slice(0, -1)]);
    if (hit)
        return hit;
    const named = NAMES[u] || (/s$/.test(u) && NAMES[u.slice(0, -1)]);
    if (named)
        return ["money", named, named, named];
    const code = u.toUpperCase();
    if (/^[A-Z]{3}$/.test(code) && (CURRENCIES.indexOf(code) !== -1 || (rates && rates[code] !== undefined)))
        return ["money", code, code, code];
    return null;
}

function commas(s) {
    const d = s.indexOf(".");
    const i = d < 0 ? s : s.slice(0, d);
    let out = "", n = 0;
    for (let k = i.length - 1; k >= 0; k--) {
        out = i[k] + out;
        if (++n % 3 === 0 && k > 0 && i[k - 1] !== "-")
            out = "," + out;
    }
    return out + (d < 0 ? "" : s.slice(d));
}
function full(x) {
    if (!isFinite(x))
        return String(x);
    const a = Math.abs(x);
    if (a !== 0 && (a < 1e-6 || a >= 1e15))
        return parseFloat(x.toPrecision(6)).toExponential().replace("e+", "e");
    return commas(String(parseFloat(x.toPrecision(10))));
}
function shown(x) {
    const a = Math.abs(x);
    if (a === 0 || !isFinite(x))
        return String(x);
    if (a < 1e-6 || a >= 1e15)
        return parseFloat(x.toPrecision(4)).toExponential().replace("e+", "e");
    if (a >= 1000)
        return commas(String(Math.round(x)));
    return String(parseFloat(x.toPrecision(4)));
}
function scale(r) {
    const mul = String(parseFloat(r.toPrecision(10))).length, div = String(parseFloat((1 / r).toPrecision(10))).length;
    return r >= 1 || mul <= div ? " × " + full(r) : " ÷ " + full(1 / r);
}

function temp(v, a, b) {
    const n = full(v);
    const ways = {
        "c>f": [v * 9 / 5 + 32, "°F = °C × 9⁄5 + 32", n + " × 9⁄5 + 32"],
        "f>c": [(v - 32) * 5 / 9, "°C = (°F − 32) × 5⁄9", "(" + n + " − 32) × 5⁄9"],
        "c>k": [v + 273.15, "K = °C + 273.15", n + " + 273.15"],
        "k>c": [v - 273.15, "°C = K − 273.15", n + " − 273.15"],
        "f>k": [(v - 32) * 5 / 9 + 273.15, "K = (°F − 32) × 5⁄9 + 273.15", "(" + n + " − 32) × 5⁄9 + 273.15"],
        "k>f": [(v - 273.15) * 9 / 5 + 32, "°F = (K − 273.15) × 9⁄5 + 32", "(" + n + " − 273.15) × 9⁄5 + 32"]
    };
    return ways[a + ">" + b] || [v, "same unit", n];
}
function fuel(v, a, b, la, lb) {
    const toKpl = { mpg: 1.609344 / 4.54609, usmpg: 1.609344 / 3.785411784, kpl: 1 };
    const kpl = a === "l100" ? 100 / v : v * toKpl[a];
    const out = b === "l100" ? 100 / kpl : kpl / toKpl[b];
    const n = full(v);
    if (a === b)
        return [v, "same unit", n];
    if (a === "l100" || b === "l100") {
        const other = a === "l100" ? b : a, K = full(100 / toKpl[other]);
        const name = other === "kpl" ? "km/l" : other === "usmpg" ? "US mpg" : "mpg";
        return [out, a === "l100" ? name + " = " + K + " ÷ l/100km" : "l/100km = " + K + " ÷ " + name, K + " ÷ " + n];
    }
    const r = toKpl[a] / toKpl[b];
    return [out, lb + " = " + la + scale(r), n + scale(r)];
}

function linear(parts, to) {
    let out = 0;
    const gen = [], fill = [];
    for (const p of parts) {
        const r = p.u[1] / to[1];
        out += p.v * r;
        gen.push(r === 1 ? p.u[2] : p.u[2] + scale(r));
        fill.push(r === 1 ? full(p.v) : full(p.v) + scale(r));
    }
    return [out, to[2] + " = " + gen.join(" + "), fill.join(" + ")];
}

function segments(src, rates) {
    const out = [], re = /[a-zµ°][a-z0-9°²³µ\/]*/gi;
    let last = 0, w;
    while ((w = re.exec(src))) {
        const u = unit(w[0], rates);
        if (!u)
            continue;
        out.push({ expr: src.slice(last, w.index).trim(), u: u });
        last = re.lastIndex;
    }
    return out.length && src.slice(last).trim() === "" ? out : null;
}

function convert(text, evaluate, fx) {
    const rates = fx.rates();
    const s0 = symbols(text).replace(/(\d)\s*'\s*(\d+(?:\.\d+)?)\s*(?:"|'')?/g, "$1 ft $2 in ").replace(/(\d)\s*(?:"|'')/g, "$1 in ").replace(/(\d)\s*'/g, "$1 ft ")
        .replace(/\b(?:deg|degs|degree|degrees)\s*(?=(?:c|f|k|celsius|fahrenheit|kelvin)\b)/gi, "")
        .replace(/\bsquare\s*/gi, "sq").replace(/\b(us|uk|imp|imperial|fl|fluid|sq|long|short|metric)\s+(?=[a-z])/gi, "$1");
    let s = spaced(s0, rates).replace(/\s+/g, " ").trim();
    if ((s.match(/[a-z]+/gi) || []).some(w => { const u = unit(w, rates); return u && u[0] === "money"; }))
        s = s.replace(/(^|[^a-z])(pounds?|y)(?![a-z])/gi, (m, a, w) => a + MONEY_TOO[w.toLowerCase()]);
    let target = null, segs = null, typed = false;
    const m = /^(.*\S) (?:in|to|as|into|=|->|→) ([a-zµ°][a-z0-9°²³µ\/]*)$/i.exec(s);
    if (m && unit(m[2], rates)) {
        segs = segments(m[1], rates);
        if (segs) {
            target = unit(m[2], rates);
            typed = true;
        }
    }
    if (!segs) {
        segs = segments(s, rates);
        if (!segs)
            return null;
        if (segs.length > 1 && segs[segs.length - 1].expr === "")
            target = segs.pop().u;
    }
    if (segs.some(g => g.expr === ""))
        return null;
    const kind = segs[0].u[0];
    const linearKind = ["temp", "fuel", "money"].indexOf(kind) === -1;
    if (segs.some(g => g.u[0] !== kind) || (segs.length > 1 && !linearKind))
        return null;
    let targets;
    if (target) {
        targets = [target];
    } else if (kind === "money") {
        targets = [unit({ JPY: "GBP", USD: "GBP" }[segs[0].u[1]] || "JPY", rates)];
    } else {
        const usual = USUAL[segs[segs.length - 1].u[3]];
        if (!usual)
            return null;
        targets = usual.map(k => T[k]);
    }
    const parts = [];
    for (const g of segs) {
        const a = evaluate(g.expr);
        if (!a.ok)
            return null;
        parts.push({ v: parseFloat(a.value), u: g.u });
    }
    const to = targets[0];
    if (to[0] !== kind)
        return !typed ? null : { ok: false, msg: "Can't turn " + segs[0].u[2] + " into " + to[2] };
    const v = parts[0].v;
    if (kind === "money") {
        fx.ensure();
        if (!fx.rates() && !target)
            return null;
        if (!fx.rates())
            return fx.loading() ? { pending: true } : { ok: false, msg: fx.stale() ? "No exchange rates yet: Update rates (bottom right)" : "No exchange rates (offline?)" };
        const R = fx.rates();
        if (R[parts[0].u[1]] === undefined || R[to[1]] === undefined)
            return { ok: false, msg: "No rate for " + (R[parts[0].u[1]] === undefined ? parts[0].u[1] : to[1]) };
        const rate = R[to[1]] / R[parts[0].u[1]], out = (v * rate).toFixed(WHOLE.indexOf(to[1]) !== -1 ? 0 : 2), rs = String(parseFloat(rate.toPrecision(6)));
        if (!target) {
            const as = Number.isInteger(v) ? String(v) : v.toFixed(2);
            return { ok: true, value: as, shown: money(parts[0].u[1], commas(as)), unit: "",
                     formula: "= " + money(to[1], commas(out)) + "\n" + money(parts[0].u[1], "1") + " = " + money(to[1], rs) };
        }
        return { ok: true, value: out, shown: money(to[1], commas(out)), unit: "",
                 formula: to[2] + " = " + parts[0].u[2] + " × " + rs + "\n" + money(parts[0].u[1], full(v)) + " × " + rs + " = " + money(to[1], commas(out)) };
    }
    const one = t => kind === "temp" ? temp(v, parts[0].u[1], t[1]) : kind === "fuel" ? fuel(v, parts[0].u[1], t[1], parts[0].u[2], t[2]) : linear(parts, t);
    const [out, general, filled] = one(to);
    const lines = [general, filled + " = " + full(out) + " " + to[2]];
    const split = SPLIT[to[3]];
    if (split && out > 0) {
        let whole = Math.floor(out + 1e-9), rest = Math.round((out - whole) * split[1] * 100) / 100;
        if (rest >= split[1]) {
            whole++;
            rest = 0;
        }
        if (whole > 0 && rest > 0)
            lines.push("= " + whole + " " + to[2] + " " + rest + " " + T[split[0]][2]);
    }
    const usSrc = parts.length === 1 && US[parts[0].u[3]], usTo = US[to[3]];
    if (usSrc && !usTo && !/^us/.test(to[3]))
        lines.push("US " + parts[0].u[2] + ": " + shown(linear([{ v: v, u: T[usSrc] }], to)[0]) + " " + to[2]);
    else if (usTo && !usSrc && parts.every(p => !US[p.u[3]]))
        lines.push("US: " + shown(linear(parts, T[usTo])[0]) + " " + T[usTo][2]);
    if (targets.length > 1)
        lines.push(targets.slice(1).map(t => shown(one(t)[0]) + " " + t[2]).join("  ·  "));
    return { ok: true, value: String(parseFloat(out.toPrecision(10))), shown: shown(out), unit: to[2], formula: lines.join("\n") };
}
