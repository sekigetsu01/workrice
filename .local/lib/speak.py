# speak's engine, run by ~/.local/bin/speak: txt, md, pdf, epub, docx, html and subtitles read aloud with Kokoro,
# played straight away or saved as an audiobook (.opus) for Books; -a queues books to be made in the background
import argparse, hashlib, html, json, os, re, shutil, subprocess, sys, tempfile, time, unicodedata

np = None

OCR_LANG = os.environ.get("SPEAK_OCR_LANG", "eng")
DATA = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"), "speak")
CONF = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "speak", "voices")
WORDS = os.path.join(os.path.dirname(CONF), "words")
RATE = 24000
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "speak")
PART_CHARS = 4000
STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "speak")
QUEUE = os.path.join(STATE, "queue.json")
WORKER = os.path.join(STATE, "worker.lock")
PROGRESS = os.path.join(STATE, "progress.json")
CONTROL = os.path.join(STATE, "control.json")
BOOKS = os.path.join(os.path.expanduser("~"), "Audiobooks")
READABLE = (".txt", ".md", ".markdown", ".pdf", ".epub", ".docx", ".html", ".htm", ".xhtml", ".srt", ".vtt", ".text", ".rst", ".org")
CHARS_PER_SEC = 14.5


def on_terminal(f):
    try:
        return f.isatty() and os.ttyname(f.fileno()).startswith("/dev/pts/")
    except (OSError, ValueError):
        return False


def STAGE(text, frac=None):
    pass
VOICES = {"heart": ("af_heart", "warm, natural woman"), "bella": ("af_bella", "bright, lively woman"),
          "nicole": ("af_nicole", "soft, close, almost whispered"), "sarah": ("af_sarah", "natural, even woman"),
          "onyx": ("am_onyx", "deep, flat man")}


class Failure(Exception):
    pass


def die(msg):
    raise Failure(msg)


def default_voice():
    try:
        for line in open(CONF):
            p = line.split("#", 1)[0].lower().split()
            if len(p) == 2 and p[0] == "default" and p[1] in VOICES:
                return p[1]
    except OSError:
        pass
    return "heart"


ABBREV = [
    (r"\b[Ee]\.\s?[Gg]\.,?", "for example,"), (r"\b[Ii]\.\s?[Ee]\.,?", "that is,"), (r"\bcf\.", "compare"),
    (r"\bet al\.(?=\s+[A-Z])", "and others."), (r"\bet al\.", "and others"), (r"\bapprox\.", "approximately"),
    (r"\bpp\.(?=\s*\d)", "pages"),
    (r"\bp\.(?=\s*\d)", "page"), (r"\b[Nn]o\.(?=\s*\d)", "number"), (r"\b[Ff]igs?\.(?=\s*\d)", "figure"),
    (r"\b[Vv]ol\.(?=\s*\d)", "volume"), (r"\b[Cc]h\.(?=\s*\d)", "chapter"), (r"\bProf\.", "Professor"),
    (r"\bJr\.", "Junior"), (r"\bSr\.", "Senior"), (r"\bMt\.(?=\s+[A-Z])", "Mount"), (r"\bAve\.", "Avenue"),
    (r"\bRd\.", "Road"),
]
ABBREV = [(re.compile(a), b) for a, b in ABBREV]
UNITS = {"km": "kilometer", "kg": "kilogram", "cm": "centimeter", "mm": "millimeter", "mg": "milligram",
         "ml": "milliliter", "mph": "miles per hour", "km/h": "kilometers per hour", "kph": "kilometers per hour",
         "lb": "pound", "lbs": "pound", "oz": "ounce", "ft": "foot", "°C": "degree Celsius", "°F": "degree Fahrenheit",
         "KB": "kilobyte", "MB": "megabyte", "GB": "gigabyte", "TB": "terabyte", "Hz": "hertz", "kHz": "kilohertz",
         "MHz": "megahertz", "GHz": "gigahertz", "kW": "kilowatt", "kWh": "kilowatt hour"}
PLURAL = {"foot": "feet", "degree Celsius": "degrees Celsius", "degree Fahrenheit": "degrees Fahrenheit",
          "miles per hour": "miles per hour", "kilometers per hour": "kilometers per hour", "hertz": "hertz",
          "kilohertz": "kilohertz", "megahertz": "megahertz", "gigahertz": "gigahertz", "kilowatt hour": "kilowatt hours"}
UNIT_RE = re.compile(r"(?<![\w.])(\d[\d,]*(?:\.\d+)?)\s?(" + "|".join(re.escape(u) for u in sorted(UNITS, key=len, reverse=True)) + r")(?![\w/])")
NUMBERED = r"(?:Chapter|Book|Part|Volume|Vol\.|Section|Act|Scene|Appendix|Phase|Stage|Level|Type|Class|Article|Psalm|Canto|Lecture|Lesson|Unit|Round)"
RULERS = set("""Henry Edward George William Richard Charles James Elizabeth Mary Anne Victoria Louis Philip Frederick
    Peter Ivan Alexander Nicholas Catherine John Paul Pius Leo Gregory Benedict Innocent Clement Urban Boniface Sixtus
    Alfonso Ferdinand Napoleon Gustav Gustavus Christian Olaf Harald Ramesses Ramses Amenhotep Thutmose Ptolemy
    Antiochus Constantine Justinian Otto Wilhelm Friedrich Francis Joseph Leopold Rudolf Casimir Pedro Juan Carlos
    Felipe Henri Darius Xerxes Cyrus Sargon Mehmed Murad Selim Suleiman Malcolm David Robert Kenneth Duncan Stephen
    Edmund Harold Ethelred Rama Umberto Manuel Sancho Alfred Matthias Sigismund Vasily Boris""".split())
ROMAN_RE = re.compile(r"\b([A-Z][a-z]+\.?|[A-Z]+)(\s+)([IVXLC]+)\b(?!['’])")
FOREIGN = {**dict(zip("αβγδεζηθικλμνξοπρσςτυφχψω", "a b g d e z e th i k l m n x o p r s s t y ph ch ps o".split())),
           **dict(zip("абвгдеёжзийклмнопрстуфхцчшщъыьэюяіїєґ",
                      "a b v g d e yo zh z i y k l m n o p r s t u f kh ts ch sh shch - y - e yu ya i yi ye g".split()))}
EMOJI = re.compile("[\U0001F000-\U0001FAFF\u2600-\u27BF\uFE0F\u200D]")
SLASH_ABBREV = {"c/o", "m/s", "w/o", "i/o", "a/c", "b/c", "s/he", "w/e", "y/o"}
FILE_EXT = r"(?:pdf|epub|docx?|odt|txt|md|conf|cfg|ini|toml|ya?ml|json|lua|qml|py|sh|zsh|js|css|html?|log|csv|xlsx?" \
           r"|png|jpe?g|webp|gif|svg|mp3|mp4|mkv|webm|opus|flac|m3u|srt|vtt|zip|tar|gz|kdbx|desktop|service|timer|so|ics)"
KEY_NAMES = {"?": "question mark", "/": "slash", "\\": "backslash", "-": "minus", "=": "equals", "+": "plus",
             "[": "open bracket", "]": "close bracket", "{": "open brace", "}": "close brace", "(": "open bracket",
             ")": "close bracket", "<": "less than", ">": "greater than", ";": "semicolon", ":": "colon",
             "'": "apostrophe", '"': "quote", "`": "backtick", ",": "comma", ".": "dot", "!": "exclamation mark",
             "#": "hash", "*": "star", "&": "and", "%": "percent", "^": "caret", "$": "dollar", "@": "at",
             "~": "tilde", "|": "pipe", "_": "underscore", "\u2191": "up", "\u2193": "down", "\u2190": "left", "\u2192": "right",
             "\u2606": "star", "\u2605": "star"}
LETTER_SOUND = {"a": "eh"}


def key_like(cell):
    return bool(re.search(r"\b(?:Ctrl|Super|Alt|Shift|Esc|Enter|Tab|Space|Backspace|BackSpace)\b|\w\+\S|(?<!\S)(?:[a-z]|[a-z]/[a-z]|_|[^\w\s]{1,2})(?!\S)|^(?:[A-Za-z]{1,2}[\s/·,]*)+$", cell))


def keys(cell):
    toks = cell.split(" ")
    out = []
    for n, t in enumerate(toks):
        nxt = toks[n + 1] if n + 1 < len(toks) else ""
        word_next = re.fullmatch(r"[A-Za-z][a-z]+[,.;:)]?", nxt) is not None
        if t == "/" and 0 < n < len(toks) - 1:
            out.append("or")
        elif t in KEY_NAMES and t not in "()":
            out.append(KEY_NAMES[t])
        elif re.fullmatch(r"(?:\S+\+)?[A-Za-z0-9]/[A-Za-z0-9][,]?", t):
            out.append(t.replace("/", " or "))
        elif "+" in t[1:] and len(t) > 2:
            out.append("+".join(KEY_NAMES.get(p, p) if len(p) == 1 and not p.isalnum() else p for p in t.split("+")))
        elif re.fullmatch(r"[A-Za-z][,]?", t) and not word_next:
            c, tail = t[0], t[1:]
            said = LETTER_SOUND.get(c.lower(), c.lower())
            out.append(("capital " if c.isupper() and len(toks) > 1 else "") + said + tail)
        else:
            out.append(t)
    return " ".join(out)


def letter(c):
    base = unicodedata.normalize("NFD", c)[0]
    said = FOREIGN.get(c.lower()) or FOREIGN.get(base.lower())
    if said:
        said = said.strip("-")
        return said.capitalize() if c.isupper() else said
    return base if unicodedata.name(base, "").startswith("LATIN") else ""


def roman(s):
    vals = {"I": 1, "V": 5, "X": 10, "L": 50, "C": 100}
    n = 0
    for a, b in zip(s, s[1:] + " "):
        n += -vals[a] if vals.get(b, 0) > vals[a] else vals[a]
    back, m = "", n
    for v, r in ((100, "C"), (90, "XC"), (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")):
        back, m = back + r * (m // v), m % v
    return n if back == s else 0


def ordinal(n):
    return f"{n}{'th' if 10 <= n % 100 <= 20 else {1: 'st', 2: 'nd', 3: 'rd'}.get(n % 10, 'th')}"


def spoken(text):
    for a, b in ABBREV:
        text = a.sub(b, text)
    text = re.sub(r"(?<=[A-Z][a-z])(\s+)St\.", r"\1Street", text)
    text = re.sub(r"\bSt\.(?=\s+[A-Z])", "Saint", text)
    text = re.sub(r"\bSt\.", "Street", text)

    def rom(m):
        word, gap, num = m.groups()
        n = roman(num)
        if not n or num in ("XL", "XXL", "XXXL"):
            return m.group(0)
        if word in RULERS:
            return f"{word}{gap}the {ordinal(n)}"
        if (re.fullmatch(NUMBERED, word, re.I) and not (num == "I" and re.match(r"\s+[a-z]", text[m.end():]))) or len(num) > 1:
            return f"{word}{gap}{n}"
        return m.group(0)
    text = ROMAN_RE.sub(rom, text)

    def unit(m):
        num, u = m.groups()
        name = UNITS[u]
        if num.replace(",", "") not in ("1", "1.0"):
            name = PLURAL.get(name, name + "s")
        return f"{num} {name}"
    text = UNIT_RE.sub(unit, text)
    text = re.sub(r"(?<![\w.])(\d+(?:\.\d+)?) (s|secs?|ms|min|mins|hrs?)\b(?!['’\w])",
                  lambda m: f"{m.group(1)} " + {"s": "second", "sec": "second", "secs": "second", "ms": "millisecond",
                                                "min": "minute", "mins": "minute", "hr": "hour", "hrs": "hour"}[m.group(2)]
                  + ("" if m.group(1) in ("1", "1.0") else "s"), text)
    text = re.sub(r"(?<=\d)\s?°(?!\w)", " degrees", text)

    def clock(m):
        h, mins, ap = m.group(1), m.group(2), m.group(3) or ""
        said = h if mins == "00" and ap else (f"{h} o'clock" if mins == "00" else f"{h} oh {int(mins)}" if mins[0] == "0" else f"{h} {mins}")
        return said + (f" {ap}" if ap else "")
    text = re.sub(r"(?<=\d:\d\d)\s?[-–]\s?(?=\d{1,2}:\d\d)", " to ", text)
    text = re.sub(r"(?<![\d:])\b([01]?\d|2[0-3]):([0-5]\d)(?!:?\d)(?:\s?([AaPp]\.?[Mm])(?![a-zA-Z]))?", clock, text)
    text = re.sub(r"\b(1[0-2]|[1-9])([AaPp]\.?[Mm])(?![a-zA-Z])", r"\1 \2", text)
    text = re.sub(r"(?<=\d)\s?[–—]\s?(?=\d)", " to ", text)
    text = re.sub(r"\b((?i:pages|chapters|verses|lines|sections) \d+)-(?=\d+\b)", r"\1 to ", text)
    text = re.sub(r"\b(1\d{3}|20\d\d)-(1\d{3}|20\d\d)\b(?!-)", lambda m: f"{m.group(1)} to {m.group(2)}" if m.group(2) > m.group(1) else m.group(0), text)
    text = re.sub(r"\band/or\b", "and or", text)
    text = re.sub(r"(?<![\w/])[Nn]/[Aa](?![\w/])", "not applicable", text)
    text = re.sub(r"(?<=\w) / (?=\w)", " or ", text)
    text = re.sub(r"(?<![\w~./])([A-Za-z][a-z]+|[A-Za-z])/([A-Za-z][a-z]+|[A-Za-z])(?![\w/]|\.\w)",
                  lambda m: m.group(0) if m.group(0).lower() in SLASH_ABBREV else f"{m.group(1)} or {m.group(2)}", text)
    text = re.sub(r"\s*[·•]\s*", ", ", text)
    text = re.sub(r"(?<!\S)(--?)(?=[a-z][\w-]*)", lambda m: "dash " * len(m.group(1)), text)
    text = re.sub(r"(?<!-)\s*--\s*(?!-)|(?<=[A-Za-z])\s+-\s+(?=[A-Za-z])", " — ", text)
    text = re.sub(r"(?<=[\w)]) / (?=[\w(])", " or ", text)
    text = re.sub(r"(?<=\d)\s*…\s*(?=\d)", " to ", text)
    text = re.sub(r"(?<![\w~])~/((?:[^\s/]+/)*[^\s/]*\w)/?", lambda m: m.group(1).replace("/", " slash "), text)
    text = re.sub(r"(?<=\w\w)/(?=[\s,;:)]|$)", "", text)
    text = re.sub(r"(?<=\w)\.(?=" + FILE_EXT + r"\b)", " dot ", text)
    text = re.sub(r"(?<![\w.…])\.(?=[a-z])", "dot ", text)
    text = re.sub(r"(?<!\S)\./", "dot slash ", text)
    text = re.sub(r"(?<!\S)/(?=[\s.,;:)]|$)", "slash", text)
    for a, b in (("PgUp", "Page Up"), ("PgDn", "Page Down"), ("PrtSc", "Print Screen"), ("PrtScn", "Print Screen"),
                 ("IPv4", "I P v 4"), ("IPv6", "I P v 6")):
        text = re.sub(rf"\b{a}\b", b, text)
    text = re.sub(r"(?<=[A-Za-z])(\d{4,})\b", lambda m: " " + " ".join(m.group(1)), text)
    text = re.sub(r"(?<![\w.,:])0(?![\w]|[.,:]\d)", "zero", text)
    text = re.sub(r"(?<=[\w)'’\"”])\s*→\s*(?=[\w(])", ", then ", text)
    text = re.sub(r"(?<=\w) [›>] (?=[A-Z])", ", ", text)
    text = re.sub(r"[›▸]", " ", text)
    text = re.sub(r"(?<=\S) > (?=\d)", " greater than ", text)
    text = re.sub(r"(?<=\S) < (?=\d)", " less than ", text)
    text = re.sub(r"(?<!\S)\$(?!\S)", "dollar", text)
    text = re.sub(r"(?<!\S)\^(?!\S)", "caret", text)
    text = re.sub(r"(?<!\S)[☆★](?!\S)", "star", text)
    text = EMOJI.sub("", text)
    return re.sub(r"[^\W\d_\x00-\u024f]", lambda m: letter(m.group()), text)


SENTENCE_GAP = 0.3


HOMOGRAPHS = [
    (r"\b(?P<w>lead)(?=-(?:gr[ae]y|colou?red|lined|free|based|weighted|heavy)\b|\s+(?:pipes?|piping|poisoning|paint|"
     r"weights?|shot|pencils?|crystal|mines?|miners?|oxide|acid|balloons?|roofs?|sheets?|soldiers?|seals?|lining|"
     r"ingots?|bullets?|sinkers?|glass|content|levels?|exposure|smelter|ore)\b)", "lˈɛd"),
    (r"\b(?:heavy|grey|gray|dull|molten|solid|pure|red|white|sheet|of|as|like|into) (?P<w>lead)\b"
     r"(?!\s+(?:the|a|an|us|them|him|her|me|you|to|in|on|role|roles|singer|guitar|guitarist|story|stories|actor|"
     r"actress|character|investigator|author|vocals?|negotiator|developer|designer|engineer|time|times)\b)", "lˈɛd"),
    (r"\b(?P<w>bass)(?=\s+(?:guitars?|guitarists?|players?|lines?|drums?|notes?|clef|voices?|singers?|amps?|amplifiers?|"
     r"speakers?|boost|section|parts?|riffs?|solos?|strings?|tones?|frequencies)\b)", "bˈAs"),
    (r"\b(?:double|electric|acoustic|slap|fretless|upright|on|plays|played|playing|the deep) (?P<w>bass)\b"
     r"(?!\s+(?:fish|fishing|boat|lake))", "bˈAs"),
    (r"\b(?:took|take|takes|taking|gave|give|gives|giving) (?:a |his |her |their |my |our |your |another )?"
     r"(?:(?:deep|low|slight|stiff|formal|courtly|polite|final|last|quick|sweeping|little|small|short) )?(?P<w>bows?)\b", "bˈW"),
    (r"\b(?:a|his|her|their|my|another) (?:deep|low|slight|stiff|formal|courtly|polite|sweeping) (?P<w>bows?)\b", "bˈW"),
    (r"\b(?:must|to|would|will|did|didn't|not|should|shall|cannot|can't) (?P<w>bow)(?=\s+(?:down|low|before|to|"
     r"his|her|their|my|our|your)\b)", "bˈW"),
    (r"\b(?P<w>bows?)(?=\s+(?:to|and) stern\b)", "bˈW"),
    (r"\b(?:so|very|too|tiny|extremely|infinitely|almost|quite) (?P<w>minute)\b", "mInˈut"),
    (r"\b(?P<w>minute)(?=\s+(?:details?|amounts?|traces?|quantit(?:y|ies)|particles?|differences?|fractions?|organisms?|"
     r"creatures?|droplets?|specks?|portions?|variations?|adjustments?|fragments?|detail|grains?)\b)", "mInˈut"),
    (r"\b(?:had|have|has|having|got into|get into|gets into) (?:a |an |another |the |their |this |that )?(?:\w+ )?"
     r"(?P<w>rows?)\b(?!\s+(?:of|in|on|and|behind|after|at)\b)", "ɹˈW"),
    (r"\b(?:blazing|furious|almighty|flaming|terrible|bitter|awful|dreadful|family|domestic|public|huge|big) "
     r"(?P<w>rows?)\b(?!\s+(?:of|in|on|and|behind|at)\b)", "ɹˈW"),
]
HOMOGRAPHS = [(re.compile(a, re.I), b) for a, b in HOMOGRAPHS]


def homographs(text):
    for pat, sounds in HOMOGRAPHS:
        def put(m):
            w = m.group("w")
            sound = sounds + "z" if w.lower().endswith("s") and not sounds.endswith("s") and w.lower() != "bass" else sounds
            return m.group()[:m.start("w") - m.start()] + f"[{w}](/{sound}/)" + m.group()[m.end("w") - m.start():]
        text = pat.sub(put, text)
    return text


class Words:

    def __init__(self):
        self.mtime, self.re, self.said = None, None, {}

    def load(self):
        try:
            mtime = os.path.getmtime(WORDS)
        except OSError:
            mtime = None
        if mtime == self.mtime:
            return
        self.mtime, self.re, self.said = mtime, None, {}
        if mtime is None:
            return
        for line in open(WORDS, encoding="utf-8", errors="replace"):
            line = line.split("#", 1)[0].strip()
            if "=" not in line:
                continue
            word, said = (x.strip() for x in line.split("=", 1))
            if word and said:
                self.said[word.lower()] = said
        if self.said:
            alts = "|".join(re.escape(w) for w in sorted(self.said, key=len, reverse=True))
            self.re = re.compile(rf"(?<!\w)(?<!\w['’])({alts})(?=['’]s\b|(?!\w)(?!['’]\w))", re.I)

    def __call__(self, text):
        self.load()
        if not self.re:
            return text

        def put(m):
            said = self.said[m.group(1).lower()]
            return f"[{m.group(1)}]({said})" if len(said) > 2 and said[0] == "/" == said[-1] else said
        return self.re.sub(put, text)


class Voices:
    def __init__(self):
        global np
        import numpy as np
        from kokoro_onnx import Kokoro
        self.k = Kokoro(os.path.join(DATA, "kokoro-v1.0.onnx"), os.path.join(DATA, "voices-v1.0.bin"))
        self.words = Words()
        try:
            from misaki import en, espeak
            self.g2p = en.G2P(trf=False, british=False, fallback=espeak.EspeakFallback(british=False))
        except Exception:
            self.g2p = None

    def say(self, text, voice, speed):
        name, s = voice.lower(), speed or 1.0
        if name not in VOICES:
            die(f"no voice called '{name}' (speak -l lists them)")
        text, out = self.words(homographs(spoken(text))).strip(), []
        if re.search(r"\w", text):
            out.append(self.sound(text, VOICES[name][0], s))
        if re.search(r"[.!?…][\"”’')\]]*$", text):
            out.append(silence(SENTENCE_GAP / s))
        return np.concatenate(out) if out else silence(0)

    def sound(self, text, voice, speed):
        if self.g2p:
            sounds, _ = self.g2p(text)
            if sounds.strip():
                audio, _ = self.k.create(sounds, voice=voice, speed=speed, is_phonemes=True)
                return audio.astype(np.float32)
        text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)
        audio, _ = self.k.create(text, voice=voice, speed=speed, lang="en-us")
        return audio.astype(np.float32)


PHRASE_END = re.compile(r"[\w)\]\"'”’]$")
OPEN_END = re.compile(r"\b(?:a|an|the|and|or|of|to|in|on|with|for|by|from)$|\([^)]*$", re.I)
ROW, CELL = "", ""
CELL_GAP, ROW_GAP, TABLE_GAP = 0.15, 0.45, 0.8


class Row(tuple):
    last = False


def clean(text):
    text = html.unescape(text).replace("\r", "")
    text = re.sub(r"(\w)-\n(\w)", r"\1\2", text)
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"(?:https?://|www\.)\S+?(?=[.,;:!?)\]\"'”’]*(?:\s|$))", "", text)
    text = re.sub(r"(?m)^[ \t]*\|(.*)$", lambda m: "\ue002" + CELL.join(c.strip().replace("\\|", "|") for c in re.split(r"(?<!\\)\|", re.sub(r"(?<!\\)\|[ \t]*$", "", m.group(1).rstrip()))), text)
    text = re.sub(r"(?m)^(\ue002.*)\n(?!\ue002)", rf"\1\n{ROW}\n", text + "\n").replace("\ue002", ROW)
    text = re.sub(r"(?m)^[ \t]*#+[ \t]+(.*?)[ \t]*#*[ \t]*$", lambda m: m.group(1) + ("." if PHRASE_END.search(m.group(1)) else ""), text)
    text = re.sub(r"(?m)^[ \t]*(?:[-*+>]|\d{1,3}\.)[ \t]+", "• ", text)
    text = re.sub(r"(?<=\w)_(?=\w)", " ", text)
    text = re.sub(r"(?<=\w)\\?\|(?=\w)", " or ", text)
    text = re.sub(rf"(?m)^(?!{ROW}).*", lambda m: re.sub(r"[*_`|]{1,3}|~{1,3}(?!/)", "", m.group()), text)
    text = re.sub(rf"(?m)^{ROW}.*", lambda m: re.sub(rf"(?<=\w)[*_`]{{1,3}}|[*_`]{{1,3}}(?=\w)|~{{2}}", "", m.group()), text)
    text = re.sub(r"\s*(?:\.[ \t]*){4,}\d*", ". ", text)
    text = re.sub(r"([-=_·•])(?:[ \t]*\1){2,}", " ", text)
    text = re.sub(r"(?m)^\s*\d{1,4}\s*$", "", text)
    text = re.sub(r"(?mi)^\s*[ivxlc]{1,7}\s*$", "", text)
    text = re.sub(r"(?<=[a-z][.,;:!?\"”’)])\d{1,3}(?=\s|$)", "", text)
    paras = []

    def para(lines):
        lines = [l.strip() for l in lines if re.search(r"\w", l)]
        if not lines:
            return
        item = [l[0] in "•·" for l in lines] + [False]
        lines = [l.lstrip("•· ") for l in lines]
        width = max(map(len, lines))
        p = " ".join(l + ("," if n < len(lines) - 1 and (item[n] or item[n + 1] or len(l) < 0.6 * width)
                          and PHRASE_END.search(l) and not OPEN_END.search(l) else "") for n, l in enumerate(lines))
        p = re.sub(r"\s+", " ", p)
        if len(lines) == 1 and len(p) <= 80 and PHRASE_END.search(p) and not OPEN_END.search(p):
            p += "."
        paras.append(p)

    for p in re.split(r"\n\s*\n", text):
        run = []
        for l in p.split("\n"):
            l = l.strip()
            if not l.startswith(ROW):
                run.append(l)
                continue
            if l == ROW:
                if paras and isinstance(paras[-1], Row) and not run:
                    paras[-1].last = True
                continue
            cells = [re.sub(r"\s+", " ", c).strip() for c in l[1:].split(CELL)]
            cells = [c for c in cells if re.search(r"\w", c) or (re.fullmatch(r"\S{1,3}(?: \S{1,3})*", c) and c.strip(". "))]
            if len(cells) < 2:
                run += [re.sub(r"^(?:[-*+>]|\d{1,3}\.)[ \t]+", "• ", c) for c in cells]
                continue
            para(run)
            run = []
            paras.append(Row(cells))
        para(run)
    return paras


def from_subs(raw):
    out, last = [], None
    for line in raw.splitlines():
        line = re.sub(r"<[^>]+>", "", line).strip()
        if not line or line.isdigit() or "-->" in line or line.startswith(("WEBVTT", "Kind:", "Language:", "NOTE")):
            continue
        if line != last:
            out.append(line)
        last = line
    return [("", " ".join(out))]


def html_text(markup):
    from bs4 import BeautifulSoup
    soup = BeautifulSoup(markup, "html.parser")
    for t in soup(["script", "style", "nav", "sup"]):
        t.decompose()
    title = soup.find(["h1", "h2", "h3"])
    blocks = [ROW + CELL.join(c.get_text(" ", strip=True) for c in b.find_all(["th", "td"]))
              if b.name == "tr" else b.get_text(" ", strip=True)
              for b in soup.find_all(["p", "h1", "h2", "h3", "h4", "li", "blockquote", "div", "tr"])
              if b.name == "tr" or (not b.find(["p", "div"]) and not b.find_parent("tr"))]
    for i, b in enumerate(blocks[:-1]):
        if b.startswith(ROW) and not blocks[i + 1].startswith(ROW):
            blocks[i] += "\n" + ROW
    if blocks and blocks[-1].startswith(ROW):
        blocks[-1] += "\n" + ROW
    body = "\n\n".join(b for b in blocks if b) or soup.get_text("\n\n")
    return (title.get_text(" ", strip=True) if title else ""), body


def from_epub(path):
    import warnings
    warnings.filterwarnings("ignore")
    from ebooklib import epub, ITEM_DOCUMENT
    book = epub.read_epub(path, {"ignore_ncx": True})
    out = []
    for idref, _ in book.spine:
        item = book.get_item_with_id(idref)
        if item is None or item.get_type() != ITEM_DOCUMENT:
            continue
        title, body = html_text(item.get_content())
        if len(body.split()) > 20:
            out.append((title, body))
    return out


def ocr_page(path, i, cache):
    f = os.path.join(cache, f"p{i:05d}.txt")
    if os.path.exists(f):
        return open(f, encoding="utf-8").read()
    with tempfile.TemporaryDirectory() as d:
        subprocess.run(["pdftoppm", "-f", str(i + 1), "-l", str(i + 1), "-r", "300", "-gray", "-png", path, os.path.join(d, "p")],
                       check=True, stderr=subprocess.DEVNULL)
        img = os.path.join(d, os.listdir(d)[0])
        text = subprocess.run(["tesseract", img, "-", "-l", OCR_LANG],
                              capture_output=True, text=True).stdout
    os.makedirs(cache, exist_ok=True)
    with open(f + ".new", "w", encoding="utf-8") as o:
        o.write(text)
    os.replace(f + ".new", f)
    return text


def drop_headers(pages):
    def key(line):
        return re.sub(r"[\divxlc]+\b|\W", "", line.lower())

    def edges(lines):
        idx = [n for n, l in enumerate(lines) if l.strip() and len(l.strip()) <= 70 and not re.search(r"[.!?\"”’]\s*$", l)]
        top = [n for n in [n for n, l in enumerate(lines) if l.strip()][:2] if n in idx]
        bottom = [n for n in [n for n, l in enumerate(lines) if l.strip()][-2:] if n in idx]
        return [("t", n) for n in top] + [("b", n) for n in bottom]

    count = {}
    for text in pages:
        lines = text.splitlines()
        for k in {(side, key(lines[n])) for side, n in edges(lines) if key(lines[n])}:
            count[k] = count.get(k, 0) + 1
    common = {k for k, n in count.items() if n >= 3}
    if not common:
        return pages
    out = []
    for text in pages:
        lines = text.splitlines()
        gone = {n for side, n in edges(lines) if (side, key(lines[n])) in common}
        out.append("\n".join(l for n, l in enumerate(lines) if n not in gone))
    return out


PAGE_NO = re.compile(r"(?:\d{1,4}|[ivxlc]{1,7}|[IVXLC]{1,7})(?:\s+(?:\d{1,4}|[ivxlc]{1,7}))*")


def page_text(blocks):
    groups, k, used = [], 0, set()
    while k < len(blocks):
        if k in used:
            k += 1
            continue
        row = [k]
        while True:
            last_ = blocks[row[-1]]
            for j in range(row[-1] + 1, min(row[-1] + 4, len(blocks))):
                nxt = blocks[j]
                overlap = min(nxt[4], last_[4]) - max(nxt[2], last_[2])
                if j not in used and nxt[1] >= last_[3] - 2 and overlap >= 0.5 * min(nxt[4] - nxt[2], last_[4] - last_[2]):
                    row.append(j)
                    break
            else:
                break
        used.update(row)
        groups.append(row)
        k += 1
    def cols(g):
        return [blocks[i][1] for i in g]
    def table(g):
        return len(g) > 1 and any(h is not g and len(h) == len(g) and all(abs(a - b) <= 3 for a, b in zip(cols(g), cols(h)))
                                  for h in groups)
    out, prev = "", None
    for g in groups:
        if not table(g):
            for i in sorted(g):
                b = blocks[i]
                out += ("\n" if prev is not None and blocks[prev][0] == b[0] and not out.endswith("\n") else "\n\n") + b[5]
                prev = i
            continue
        cells = [re.sub(r"\s*\n\s*", " ", re.sub(r"(\w)-\n(\w)", r"\1\2", blocks[i][5])) for i in g]
        cells = [c for c in cells if not PAGE_NO.fullmatch(c.strip())]
        out += ("\n" + ROW + CELL.join(cells) + "\n") if len(cells) > 1 else ("\n\n" + cells[0] if cells else "")
        prev = None
    return out.strip("\n") + "\n"


def pdf_layout(path, first, last):
    import xml.etree.ElementTree as ET
    p = subprocess.Popen(["pdftotext", "-q", "-enc", "UTF-8", "-bbox-layout", "-f", str(first), "-l", str(last), path, "-"],
                         stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    pages = []
    try:
        for _, el in ET.iterparse(p.stdout, events=("end",)):
            tag = el.tag.rsplit("}", 1)[-1]
            if tag != "page":
                continue
            blocks = []
            for f, flow in enumerate(e for e in el if e.tag.endswith("flow")):
                for b in (e for e in flow if e.tag.endswith("block")):
                    lines = [" ".join(w.text or "" for w in ln) for ln in b if ln.tag.endswith("line")]
                    text = "\n".join(l for l in lines if l.strip())
                    if text:
                        blocks.append((f, *(float(b.get(k)) for k in ("xMin", "yMin", "xMax", "yMax")), text))
            el.clear()
            out = page_text(blocks)
            pages.append(out)
    except ET.ParseError:
        pages = None
    finally:
        p.stdout.close()
        p.wait()
    return pages if p.returncode == 0 and pages and len(pages) == last - first + 1 else None


def pdf_text(path, r, first, last, rows=True):
    if shutil.which("pdftotext"):
        texts = pdf_layout(path, first, last) if rows else None
        if texts:
            return texts
        p = subprocess.run(["pdftotext", "-q", "-enc", "UTF-8", "-f", str(first), "-l", str(last), path, "-"],
                           capture_output=True, text=True, errors="replace")
        texts = p.stdout.split("\f")[:last - first + 1]
        if p.returncode == 0 and len(texts) == last - first + 1:
            return texts
    return [r.pages[i].extract_text() or "" for i in range(first - 1, last)]


def from_pdf(path, pages=None):
    from pypdf import PdfReader
    r = PdfReader(path)
    n = len(r.pages)
    first, last = pages or (1, n)
    first, last = max(1, first), min(n, last)
    if first > last:
        die(f"{os.path.basename(path)} has {n} pages")
    starts = {}
    try:
        for o in r.outline:
            if not isinstance(o, list):
                starts.setdefault(r.get_destination_page_number(o), o.title)
    except Exception:
        pass
    texts, scanned = pdf_text(path, r, first, last), []
    for i, text in zip(range(first - 1, last), texts):
        if len(re.findall(r"[A-Za-z]{2,}", text)) < 8:
            scanned.append(i)
    if scanned:
        if not shutil.which("tesseract") or not shutil.which("pdftoppm"):
            die("this PDF has scanned pages: install tesseract, tesseract-data-eng and poppler (sys-setup does it)")
        st = os.stat(path)
        cache = os.path.join(CACHE, "ocr", hashlib.sha1(f"{os.path.abspath(path)}{st.st_size}{st.st_mtime}".encode()).hexdigest()[:16])
        for k, i in enumerate(scanned, 1):
            STAGE(f"reading scanned pages {k} of {len(scanned)}", k / len(scanned))
            texts[i - first + 1] = ocr_page(path, i, cache)
    texts = drop_headers(texts)
    out = []
    for i, text in zip(range(first - 1, last), texts):
        if i in starts or not out:
            out.append([starts.get(i, ""), ""])
        out[-1][1] += re.sub(r"([.!?][\"”’)]?)[ \t]*\n", r"\1\n\n", text) + "\n"
    return [tuple(c) for c in out]


def from_docx(path):
    import docx
    from docx.table import Table
    out = [["", ""]]
    for p in docx.Document(path).iter_inner_content():
        if isinstance(p, Table):
            for r in p.rows:
                cells = []
                for c in r.cells:
                    if not cells or c._tc is not cells[-1]._tc:
                        cells.append(c)
                out[-1][1] += ROW + CELL.join(c.text.replace("\n", " ") for c in cells) + "\n"
            out[-1][1] += ROW + "\n\n"
            continue
        if p.style.name.startswith("Heading 1"):
            if out[-1][1].strip():
                out.append([p.text, ""])
            else:
                out[-1][0] = p.text
        out[-1][1] += p.text + "\n\n"
    return [tuple(c) for c in out]


def read(path, pages=None):
    if path == "-":
        return [("", sys.stdin.read())]
    ext = os.path.splitext(path)[1].lower()
    if ext == ".epub":
        return from_epub(path)
    if ext == ".pdf":
        return from_pdf(path, pages)
    if ext == ".docx":
        return from_docx(path)
    raw = open(path, encoding="utf-8", errors="replace").read()
    if "\0" in raw[:4096]:
        die(f"can't read {os.path.basename(path)}: use txt, md, pdf, epub, docx, html, srt or vtt")
    if ext in (".srt", ".vtt"):
        return from_subs(raw)
    if ext in (".html", ".htm", ".xhtml"):
        return [html_text(raw)]
    return [("", raw)]


def book_meta(path):
    title = author = ""
    ext = os.path.splitext(path)[1].lower()
    try:
        if ext == ".epub":
            import warnings
            warnings.filterwarnings("ignore")
            from ebooklib import epub
            b = epub.read_epub(path, {"ignore_ncx": True})
            t, a = b.get_metadata("DC", "title"), b.get_metadata("DC", "creator")
            title, author = (t[0][0] if t else ""), (a[0][0] if a else "")
        elif ext == ".pdf":
            from pypdf import PdfReader
            m = PdfReader(path).metadata or {}
            title, author = str(m.get("/Title") or ""), str(m.get("/Author") or "")
        elif ext == ".docx":
            import docx
            cp = docx.Document(path).core_properties
            title, author = cp.title or "", cp.author or ""
    except Exception:
        pass
    title, author = re.sub(r"\s+", " ", title).strip(), re.sub(r"\s+", " ", author).strip()
    name = os.path.splitext(os.path.basename(path))[0]
    if not title or re.fullmatch(r"(untitled|microsoft word.*|document\d*|\W*)", title, re.I):
        title = name
        m = re.match(r"^(.+?)\s+[-–—]\s+(.+)$", name)
        if m and not author:
            author, title = m.group(1).strip(), m.group(2).strip()
    if re.fullmatch(r"(unknown|admin|user|\W*)", author, re.I):
        author = ""
    return title, author


def safe_name(s):
    s = re.sub(r'[/\\:*?"<>|\x00-\x1f]', "-", s).strip(" .")
    # 150 bytes, not characters: a long CJK title would pass the 255-byte limit on file names
    return s.encode()[:150].decode("utf-8", "ignore").strip(" .") or "audiobook"


def out_for(path, title, author, taken=()):
    # taken: names other books in the queue will have (two books of the same title would overwrite each other)
    base = os.path.join(BOOKS, safe_name(f"{author} - {title}" if author else title))
    out, k = base + ".opus", 2
    while os.path.exists(out) or out in taken:
        out, k = f"{base} ({k}).opus", k + 1
    return out


def book_cover(path, dst):
    ext = os.path.splitext(path)[1].lower()
    tmp = dst + ".tmp"
    try:
        if ext == ".epub":
            import warnings
            warnings.filterwarnings("ignore")
            from ebooklib import epub, ITEM_COVER, ITEM_IMAGE
            b = epub.read_epub(path, {"ignore_ncx": True})
            pick = None
            ids = [m[1].get("content") for m in b.get_metadata("OPF", "cover") if m[1].get("content")]
            for i in ids:
                pick = pick or b.get_item_with_id(i)
            pick = pick or next(iter(b.get_items_of_type(ITEM_COVER)), None)
            pick = pick or next((it for it in b.get_items_of_type(ITEM_IMAGE) if "cover" in it.get_name().lower()), None)
            if pick is None:
                return False
            with open(tmp, "wb") as f:
                f.write(pick.get_content())
        elif ext == ".pdf" and shutil.which("pdftoppm"):
            subprocess.run(["pdftoppm", "-f", "1", "-l", "1", "-jpeg", "-scale-to", "900", "-singlefile", path, tmp],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60)
            tmp += ".jpg"
        else:
            return False
        r = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", tmp, "-frames:v", "1",
                            "-vf", "scale=900:900:force_original_aspect_ratio=decrease", dst],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60)
        return r.returncode == 0
    except Exception:
        return False
    finally:
        for t in (tmp, dst + ".tmp", dst + ".tmp.jpg"):
            if os.path.exists(t):
                os.remove(t)


def chunks(para, size=380):
    out, cur = [], ""
    for s in re.split(r"(?<=[.!?;:])\s+", para):
        while len(s) > size:
            cut = s.rfind(" ", 0, size)
            cut = cut if cut > 50 else size
            if cur:
                out.append(cur)
                cur = ""
            out.append(s[:cut])
            s = s[cut:].strip()
        if cur and len(cur) + len(s) > size:
            out.append(cur)
            cur = s
        else:
            cur = (cur + " " + s).strip()
    if cur:
        out.append(cur)
    return out


def plan(chapters, voice, speed):
    out = []
    for title, body in chapters:
        items = []
        paras = clean(body)
        for n, para in enumerate(paras):
            v, s = voice, speed
            if isinstance(para, Row):
                if n == 0 or not isinstance(paras[n - 1], Row) or paras[n - 1].last:
                    table = [paras[n]]
                    while not table[-1].last and n + len(table) < len(paras) and isinstance(paras[n + len(table)], Row):
                        table.append(paras[n + len(table)])
                    key_table = sum(map(key_like, (r[0] for r in table))) >= 0.4 * len(table)
                for k, cell in enumerate(para):
                    last = k == len(para) - 1
                    if (k == 0 and key_table) or not re.search(r"\w", cell):
                        cell = keys(cell)
                    if not re.search(r"[.!?…:;,][\"”’')\]]*$", cell):
                        cell += "." if last else ","
                    cs = chunks(cell)
                    end = (TABLE_GAP if para.last or n + 1 == len(paras) or not isinstance(paras[n + 1], Row) else ROW_GAP) if last else CELL_GAP
                    items += [(v, s, c, 0.08) for c in cs[:-1]] + [(v, s, cs[-1], end)]
                continue
            m = re.match(r"^\[?([A-Za-z][\w-]{1,20})\]?:\s+(.+)$", para)
            if m and m.group(1).lower() in VOICES:
                v, para = m.group(1), m.group(2)
            cs = chunks(para)
            items += [(v, s, c, 0.08) for c in cs[:-1]] + [(v, s, cs[-1], 0.45)]
        if items:
            out.append((title, items))
    if out:
        v, s, text, gap = out[0][1][0]
        m = re.match(r"(.{20,}?[.!?])\s+(.{20,})$", text) or re.match(r"(.{20,}?[,;:])\s+(.{20,})$", text)
        if len(text) > 120 and m:
            out[0][1][0:1] = [(v, s, m.group(1), 0.08), (v, s, m.group(2), gap)]
    return out


def silence(sec):
    return np.zeros(int(RATE * sec), np.float32)


def player():
    return subprocess.Popen(["mpv", "--really-quiet", "--no-video", "--keep-open=no", "--input-ipc-server=", "--demuxer=rawaudio", "--demuxer-rawaudio-format=floatle",
                             f"--demuxer-rawaudio-rate={RATE}", "--demuxer-rawaudio-channels=1", "--cache=yes", "-"],
                            stdin=subprocess.PIPE)


def encoder(path, title):
    return subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-",
                             "-c:a", "libopus", "-b:a", "40k", "-application", "voip", "-metadata", f"title={title}", path],
                            stdin=subprocess.PIPE)


def fmt(sec):
    sec = int(sec)
    return f"{sec // 3600}:{sec // 60 % 60:02d}:{sec % 60:02d}" if sec >= 3600 else f"{sec // 60}:{sec % 60:02d}"


class Stopped(Exception):
    pass


class Restart(Stopped):
    pass


def stream(chapters, voices):
    sink = player()
    try:
        for n, (_, items) in enumerate(chapters, 1):
            for v, s, text, gap in items:
                sink.stdin.write(np.concatenate([voices.say(text, v, s), silence(gap)]).tobytes())
            if n < len(chapters):
                sink.stdin.write(silence(1.2).tobytes())
        sink.stdin.close()
        sink.wait()
    except (KeyboardInterrupt, BrokenPipeError):
        sink.kill()
        print("\nStopped.", file=sys.stderr)
        sys.exit(130)


def ffesc(s):
    return re.sub(r"([=;#\\])", r"\\\1", str(s).replace("\n", " "))


def run_file(chapters, voices, out, play, title, ui, tags=None, src=None):
    parts = []
    for n, (_, items) in enumerate(chapters):
        cur, size = [], 0
        for it in items:
            cur.append(it)
            size += len(it[2])
            if size >= PART_CHARS:
                parts.append((n, cur))
                cur, size = [], 0
        if cur:
            parts.append((n, cur))
    key = hashlib.sha1(json.dumps([title, chapters]).encode()).hexdigest()[:16]
    work = os.path.join(CACHE, key)
    os.makedirs(work, exist_ok=True)
    total = sum(len(i[2]) for _, items in parts for i in items) or 1
    sink = player() if play else None
    done = 0
    lengths = []
    ui.book_start(total, len(chapters), os.path.exists(os.path.join(work, "00000.len")))
    try:
        for k, (n, items) in enumerate(parts):
            f = os.path.join(work, f"{k:05d}")
            chars = sum(len(i[2]) for i in items)
            if os.path.exists(f + ".len"):
                lengths.append(int(open(f + ".len").read()))
                done += chars
                ui.progress(done, sum(lengths) / RATE, n, made=False)
                continue
            enc = encoder(f + ".part.opus", title)
            count = 0
            for v, s, text, gap in items:
                ui.wait_if_paused()
                a = np.concatenate([voices.say(text, v, s), silence(gap)])
                enc.stdin.write(a.tobytes())
                if sink:
                    try:
                        sink.stdin.write(a.tobytes())
                    except BrokenPipeError:
                        sink = None
                count += len(a)
                done += len(text)
                ui.progress(done, (sum(lengths) + count) / RATE, n, made=len(text))
            if k + 1 < len(parts) and parts[k + 1][0] != n:
                enc.stdin.write(silence(1.2).tobytes())
                count += int(RATE * 1.2)
            enc.stdin.close()
            if enc.wait():
                raise RuntimeError("ffmpeg couldn't save the audio")
            os.replace(f + ".part.opus", f + ".opus")
            with open(f + ".len", "w") as o:
                o.write(str(count))
            lengths.append(count)
        if sink:
            try:
                sink.stdin.close()
                sink.wait()
            except BrokenPipeError:
                pass
        ui.stage("joining the parts")
    except (KeyboardInterrupt, BrokenPipeError, Stopped) as e:
        if sink:
            sink.kill()
        if isinstance(e, Restart):
            shutil.rmtree(work, ignore_errors=True)
            raise
        for p in os.listdir(work):
            if p.endswith(".part.opus"):
                os.unlink(os.path.join(work, p))
        raise Stopped()

    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with open(os.path.join(work, "list.txt"), "w") as o:
        for k in range(len(parts)):
            o.write(f"file '{k:05d}.opus'\n")
    meta = os.path.join(work, "meta.txt")
    with open(meta, "w") as o:
        o.write(f";FFMETADATA1\ntitle={ffesc(title)}\n")
        for k, v in (tags or {}).items():
            if v:
                o.write(f"{k}={ffesc(v)}\n")
        if len(chapters) > 1:
            pos, starts = 0, {}
            for (n, _), length in zip(parts, lengths):
                starts.setdefault(n, pos)
                pos += length
            for n, start in sorted(starts.items()):
                end = starts.get(n + 1, pos)
                name = chapters[n][0] or f"Part {n + 1}"
                o.write(f"[CHAPTER]\nTIMEBASE=1/{RATE}\nSTART={start}\nEND={end}\ntitle={ffesc(name)}\n")
    fd, tmp = tempfile.mkstemp(suffix=".opus", dir=os.path.dirname(os.path.abspath(out)), prefix=".speak-")
    os.close(fd)
    r = subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", os.path.join(work, "list.txt"),
                        "-i", meta, "-map", "0:a", "-map_metadata", "1", "-map_chapters", "1", "-c", "copy", tmp],
                       stdin=subprocess.DEVNULL)
    if r.returncode:
        os.unlink(tmp)
        raise RuntimeError("ffmpeg couldn't join the parts (they're kept: start it again)")
    mask = os.umask(0)
    os.umask(mask)
    os.chmod(tmp, 0o666 & ~mask)
    if src:
        book_cover(src, os.path.splitext(out)[0] + ".jpg")
    os.replace(tmp, out)
    shutil.rmtree(work, ignore_errors=True)
    return sum(lengths) / RATE


def short(path):
    home = os.path.expanduser("~")
    return "~" + path[len(home):] if path == home or path.startswith(home + "/") else path


def notify(title, body=""):
    try:
        subprocess.run(["notify-send", "-a", "speak", title, body], stderr=subprocess.DEVNULL)
    except OSError:
        pass


def estimate(path, pages):
    ext = os.path.splitext(path)[1].lower()
    try:
        if ext == ".pdf":
            from pypdf import PdfReader
            r = PdfReader(path)
            first, last = pages or (1, len(r.pages))
            texts = pdf_text(path, r, max(1, first), min(len(r.pages), last), rows=False)
            return sum(len(t) if len(re.findall(r"[A-Za-z]{2,}", t)) >= 8 else 1800 for t in texts)
        return sum(len(b) for _, b in read(path, pages))
    except Exception:
        return None


class UI:

    HELP = [("j / k, gg / G", "pick a book (arrow keys too)"),
            ("v / V", "next / previous voice for that book"),
            ("] / [", "faster / slower (0.1× steps)"),
            ("J / K", "move the book down / up the list"),
            ("dd", "take the book off the list"),
            ("Enter / Esc", "for the book being made: start it again with the change / keep going"),
            ("p or Space", "pause / carry on"),
            ("q", "stop (the list is kept; c s in yazi or speak -w carries on)"),
            ("?", "this help")]

    def __init__(self, items, voice, live):
        import threading
        self.items = items
        self.voice = voice
        self.live = live and on_terminal(sys.stdout)
        self.lock = threading.RLock()
        self.paused = threading.Event()
        self.stop = threading.Event()
        self.restart = threading.Event()
        self.anykey = threading.Event()
        self.queue_mode = False
        self.last_merge = 0.0
        self.cur = None
        self.sel = 0
        self.pending = None
        self.message = ""
        self.removed = set()
        self.help = False
        self.last_key = b""
        self.stage_text, self.stage_frac = "", None
        self.done = self.total = 0
        self.audio = 0.0
        self.chapter = self.chapters = 0
        self.made = 0
        self.busy = 0.0
        self.t_last = time.time()
        self.audio_per_char = 1 / CHARS_PER_SEC
        self.last_draw = 0.0
        self.size = {}
        self.old = None
        if self.live and on_terminal(sys.stdin):
            import termios, tty
            self.old = termios.tcgetattr(0)
            tty.setcbreak(0)
            threading.Thread(target=self.keys, daemon=True).start()
        if self.live:
            sys.stdout.write("\x1b[?25l\x1b[?1049h")
        threading.Thread(target=self.sizes, daemon=True).start()

    def close(self):
        if self.old is not None:
            import termios
            termios.tcsetattr(0, termios.TCSADRAIN, self.old)
            self.old = None
        if self.live:
            sys.stdout.write("\x1b[?1049l\x1b[?25h")
            sys.stdout.flush()

    def keys(self):
        while True:
            c = os.read(0, 8)
            if not c:
                return
            self.anykey.set()
            if self.done_all():
                continue
            with self.lock:
                self.key(c)
            self.draw(force=True)

    def key(self, c):
        seq = {b"\x1b[A": b"k", b"\x1b[B": b"j", b"\x1bOA": b"k", b"\x1bOB": b"j", b"\r": b"\n"}
        c = seq.get(c, c)
        prev, self.last_key = self.last_key, c
        self.message = ""
        books = self.items
        it = books[self.sel] if 0 <= self.sel < len(books) else None
        if c == b"?":
            self.help = not self.help
        elif self.help and c in (b"\x1b", b"q"):
            self.help = False
        elif c == b"\x1b":
            if self.pending:
                self.pending = None
                self.message = "keeping going as it was"
        elif c == b"\n":
            if self.pending and self.cur:
                self.cur["voice"], self.cur["speed"] = self.pending
                self.pending = None
                self.restart.set()
                self.paused.clear()
                self.message = f"starting {self.cur['title']} again"
                self.save()
        elif c == b"j":
            self.sel = min(self.sel + 1, len(books) - 1)
        elif c == b"k":
            self.sel = max(self.sel - 1, 0)
        elif c == b"G":
            self.sel = len(books) - 1
        elif c == b"g" and prev == b"g":
            self.sel = 0
            self.last_key = b""
        elif c in (b"v", b"V", b"]", b"["):
            if not it or it["status"] not in ("waiting", "working"):
                self.message = "that one's finished"
                return
            names = list(VOICES)
            voice = (self.pending or (it["voice"], it["speed"]))[0] if it is self.cur else it["voice"]
            speed = (self.pending or (it["voice"], it["speed"]))[1] if it is self.cur else it["speed"]
            if c in (b"v", b"V"):
                i = names.index(voice) if voice in names else 0
                voice = names[(i + (1 if c == b"v" else -1)) % len(names)]
            else:
                speed = round(min(2.0, max(0.5, (speed or 1.0) + (0.1 if c == b"]" else -0.1))), 1)
                speed = None if speed == 1.0 else speed
            if it is self.cur:
                self.pending = (voice, speed)
            else:
                it["voice"], it["speed"] = voice, speed
                self.save()
        elif c in (b"J", b"K"):
            if not it or it["status"] != "waiting":
                return
            step = 1 if c == b"J" else -1
            j = self.sel + step
            if 0 <= j < len(books) and books[j]["status"] == "waiting":
                books[self.sel], books[j] = books[j], books[self.sel]
                self.sel = j
                self.save()
        elif c == b"d" and prev == b"d":
            self.last_key = b""
            if not it:
                return
            self.removed.add(it["path"])
            if it is self.cur:
                it["status"] = "removed"
                self.restart.set()
                self.paused.clear()
            else:
                books.remove(it)
                self.sel = min(self.sel, len(books) - 1)
            self.message = f"took {it['title']} off the list"
            self.save()
        elif c in (b"p", b" "):
            if self.paused.is_set():
                self.paused.clear()
                self.t_last = time.time()
            else:
                self.paused.set()
        elif c == b"q":
            self.stop.set()
            self.paused.clear()

    def save(self):
        if not self.queue_mode:
            return
        keep = [it for it in self.items if it["status"] in ("waiting", "working")]

        gone, self.removed = self.removed, set()

        def put(q):
            mine = {it["path"] for it in keep}
            extra = [it for it in q if it["path"] not in mine | gone]
            q[:] = [{k: v for k, v in it.items() if k not in ("secs", "note")} | {"status": "waiting"} for it in keep] + extra
        queue_edit(put)

    def done_all(self):
        return all(it["status"] in ("done", "failed") for it in self.items)

    def merge_queue(self):
        self.last_merge = time.time()
        q = queue_edit(lambda q: [dict(it) for it in q])
        with self.lock:
            have = {it["path"] for it in self.items if it["status"] in ("waiting", "working")}
            new = [it for it in q if it["status"] == "waiting" and it["path"] not in have]
            if new:
                self.items.extend(new)
        if new:
            import threading
            threading.Thread(target=self.sizes, daemon=True).start()

    def sizes(self):
        for it in list(self.items):
            if it["path"] not in self.size and it["path"] != "-" and "text" not in it:
                self.size[it["path"]] = estimate(it["path"], it.get("pages"))
                self.draw()

    def book_start(self, total, chapters, resumed):
        self.total, self.chapters, self.done, self.audio = total, chapters, 0, 0.0
        self.size[self.cur["path"]] = total
        self.stage_text = "carrying on from where it stopped" if resumed else ""
        self.stage_frac = None
        self.t_last = time.time()
        self.draw(force=True)

    def stage(self, text, frac=None):
        self.stage_text, self.stage_frac = text, frac
        self.check()
        self.draw()

    def check(self):
        if self.restart.is_set():
            raise Restart()
        if self.stop.is_set():
            raise Stopped()

    def progress(self, done, audio, chapter, made):
        now = time.time()
        if made:
            self.made += made
            self.busy += now - self.t_last
        self.t_last = now
        self.done, self.audio, self.chapter = done, audio, chapter + 1
        if done:
            self.audio_per_char = audio / done
        if self.stage_text and (made or not self.stage_text.startswith("carrying")):
            self.stage_text = ""
        self.check()
        if self.queue_mode and now - self.last_merge > 3:
            self.merge_queue()
        self.draw()

    def wait_if_paused(self):
        self.check()
        if self.paused.is_set():
            self.draw(force=True)
            while self.paused.is_set() and not self.stop.is_set() and not self.restart.is_set():
                time.sleep(0.2)
            self.t_last = time.time()
            self.check()

    def rate(self):
        return self.made / self.busy if self.busy > 5 and self.made > 500 else None

    def bar(self, frac, width):
        frac = max(0.0, min(1.0, frac))
        full = int(frac * width)
        return "\x1b[34m" + "█" * full + "\x1b[2m" + "░" * (width - full) + "\x1b[0m"

    def draw(self, force=False):
        now = time.time()
        if not force and now - self.last_draw < 0.5:
            return
        self.last_draw = now
        if not self.live:
            return
        with self.lock:
            text = self.render()
        sys.stdout.write("\x1b[H\x1b[2J" + text)
        sys.stdout.flush()

    def render(self):
        cols = max(60, min(shutil.get_terminal_size((90, 24)).columns, 120))
        bw = cols - 12
        namew = cols - 40
        rate = self.rate()
        out = ["\x1b[1m  speak\x1b[0m  \x1b[2mmaking audiobooks\x1b[0m", "  " + "─" * (cols - 4)]
        if self.help:
            out.append("  \x1b[1mKeys\x1b[0m")
            out += [f"  \x1b[34m{k:<16}\x1b[0m {v}" for k, v in self.HELP]
            out += ["", "  \x1b[2m? or Esc closes this\x1b[0m"]
            return "\n".join(out) + "\n"
        self.sel = max(0, min(self.sel, len(self.items) - 1))
        left_all, unknown = 0.0, False
        for n, it in enumerate(self.items):
            name = it["title"] if len(it["title"]) <= namew else it["title"][:namew - 1] + "…"
            mark = "\x1b[7m" if n == self.sel else ""
            voice, speed = it.get("voice") or self.voice, it.get("speed")
            if it is self.cur and self.pending:
                voice, speed = self.pending
            vs = f"{voice}{f' {speed:g}×' if speed else ''}"
            st, size = it["status"], self.size.get(it["path"])
            if st == "done":
                out.append(f"  \x1b[32m✓\x1b[0m  {mark}{name:<{namew}}\x1b[0m \x1b[2m{vs:<11} {fmt(it.get('secs', 0))} of audio\x1b[0m")
            elif st == "failed":
                out.append(f"  \x1b[31m✗\x1b[0m  {mark}{name:<{namew}}\x1b[0m \x1b[31m{it.get('note', 'failed')[:30]}\x1b[0m")
            elif st == "removed":
                out.append(f"  \x1b[2m–  {mark}{name:<{namew}}\x1b[0m \x1b[2mtaking it off…\x1b[0m")
            elif it is self.cur:
                frac = self.done / self.total if self.total else 0
                if self.restart.is_set():
                    state = "\x1b[33mstarting again…\x1b[0m"
                elif self.paused.is_set():
                    state = "\x1b[33mpaused\x1b[0m"
                elif self.stop.is_set():
                    state = "\x1b[33mstopping…\x1b[0m"
                elif self.chapters > 1:
                    state = f"\x1b[2mch {self.chapter}/{self.chapters}\x1b[0m"
                else:
                    state = ""
                vsc = f"\x1b[33m{vs:<11}\x1b[0m" if self.pending else f"{vs:<11}"
                out.append(f"  \x1b[1;34m▶\x1b[0m  {mark}\x1b[1m{name:<{namew}}\x1b[0m {vsc} {state}")
                if self.stage_text and self.stage_frac is not None:
                    out.append(f"     {self.bar(self.stage_frac, bw)} {self.stage_frac * 100:3.0f}%")
                    out.append(f"     \x1b[2m{self.stage_text}\x1b[0m")
                else:
                    left = (self.total - self.done) / rate if rate else None
                    if left is not None:
                        left_all += left
                    out.append(f"     {self.bar(frac, bw)} {frac * 100:3.0f}%")
                    info = self.stage_text or (f"{fmt(self.audio)} of audio made  ·  "
                                               + (f"{fmt(left)} left" if left is not None else "working out time left…"))
                    out.append(f"     \x1b[2m{info}\x1b[0m")
            else:
                if size:
                    left_all += size / rate if rate else 0
                    unknown |= rate is None
                    note = f"≈ {fmt(size * self.audio_per_char)} of audio"
                else:
                    unknown = True
                    note = "waiting"
                out.append(f"  \x1b[2m·\x1b[0m  {mark}{name:<{namew}}\x1b[0m {vs:<11} \x1b[2m{note}\x1b[0m")
        books = [it for it in self.items if it["status"] not in ("failed", "removed")]
        if len(books) > 1:
            sized = [self.size.get(it["path"]) or 0 for it in books]
            done_chars = sum(sz for it, sz in zip(books, sized) if it["status"] == "done") + (self.done if self.cur else 0)
            frac = done_chars / sum(sized) if sum(sized) else 0
            ndone = sum(1 for it in books if it["status"] == "done")
            if ndone == len(books):
                tail = f"all {ndone} done"
            else:
                tail = f"{ndone} of {len(books)} done  ·  " + (f"about {fmt(left_all)} left for all of them" if rate and not unknown
                                                              else "working out time left…")
            out += ["", "  \x1b[1mAll books\x1b[0m", f"     {self.bar(frac, bw)} {frac * 100:3.0f}%", f"     \x1b[2m{tail}\x1b[0m"]
        out.append("  " + "─" * (cols - 4))
        if self.done_all():
            out.append("  \x1b[1mAll done.\x1b[0m  Saved next to each book.  Any key closes.")
        elif self.pending and self.cur:
            v, sp = self.pending
            out.append(f"  \x1b[33mEnter: start {self.cur['title'][:30]} again with {v}{f' {sp:g}×' if sp else ''}"
                       f" (what's made so far is redone) · Esc: keep going\x1b[0m")
        else:
            if self.message:
                out.append(f"  \x1b[33m{self.message}\x1b[0m")
            out.append("  \x1b[2mj/k pick · v voice · ] [ speed · J/K order · dd remove · p pause · q stop · ? help\x1b[0m")
        return "\n".join(out) + "\n"


def queue_edit(change):
    import fcntl
    os.makedirs(STATE, exist_ok=True)
    with open(QUEUE + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            q = json.load(open(QUEUE))
        except (OSError, ValueError):
            q = []
        r = change(q)
        with open(QUEUE + ".new", "w") as f:
            json.dump(q, f)
        os.replace(QUEUE + ".new", QUEUE)
    return r


def maker_lock():
    import fcntl
    os.makedirs(STATE, exist_ok=True)
    f = open(WORKER, "a")
    try:
        fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        f.close()
        return None
    return f


def take_over():
    lock = maker_lock()
    if lock:
        queue_edit(lambda q: q.__setitem__(slice(None), [dict(it, status="waiting") for it in q if it["status"] in ("waiting", "working")]))
    return lock


def add(files, voice, speed, pages):
    good, bad = [], []
    for f in files:
        f = os.path.abspath(f)
        if not os.path.isfile(f) or not f.lower().endswith(READABLE):
            bad.append(os.path.basename(f))
        else:
            good.append(f)
    if bad:
        notify("Can't read these aloud", ", ".join(bad) + "\n(books and writing: pdf, epub, docx, txt, md, html…)")
    if not good:
        return

    def put(q):
        waiting = {it["path"] for it in q if it["status"] in ("waiting", "working")}
        new = [f for f in good if f not in waiting]
        taken = {it["out"] for it in q if it["status"] in ("waiting", "working")}
        for f in new:
            title, author = meta[f]
            out = out_for(f, title, author, taken)
            taken.add(out)
            q.append({"path": f, "out": out, "title": title, "author": author,
                      "voice": voice, "speed": speed, "pages": pages, "status": "waiting"})
        return new
    meta = {f: book_meta(f) for f in good}
    new = queue_edit(put)
    if new:
        notify("Making " + ("an audiobook" if len(new) == 1 else f"{len(new)} audiobooks"),
               "\n".join(meta[f][0] for f in new) + "\nYou can follow it in Books (Alt+b)")
    lock = maker_lock()
    if not lock:
        return
    lock.close()
    me = os.path.expanduser("~/.local/bin/speak")
    subprocess.Popen([me, "--worker"], start_new_session=True, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL)


def make(voices, ui, play=False):
    global STAGE
    STAGE = ui.stage
    while True:
        if ui.queue_mode:
            ui.merge_queue()
        with ui.lock:
            nxt = next((it for it in ui.items if it["status"] in ("waiting", "working")), None)
            if nxt is None:
                return True
            ui.cur = nxt
            nxt["status"] = "working"
            ui.restart.clear()
            ui.pending = None
        try:
            STAGE("reading the book")
            ui.draw(force=True)
            src = [("", nxt["text"])] if "text" in nxt else read(nxt["path"], tuple(nxt["pages"]) if nxt.get("pages") else None)
            chapters = plan(src, nxt["voice"], nxt["speed"])
            if not chapters:
                raise RuntimeError("no readable text")
            v, sp = nxt.get("voice") or "", nxt.get("speed")
            tags = {"artist": nxt.get("author") or "", "voice": v + (f" {sp:g}×" if sp else ""),
                    "comment": f"Read by {v}" + (f" at {sp:g}×" if sp else "") + " (speak)",
                    "source": "" if "text" in nxt else os.path.abspath(nxt["path"])}
            secs = run_file(chapters, voices, nxt["out"], play, nxt["title"], ui, tags, None if "text" in nxt else nxt["path"])
            nxt.update(status="done", secs=secs)
        except Restart:
            with ui.lock:
                if nxt["status"] == "removed":
                    ui.items.remove(nxt)
                else:
                    nxt["status"] = "waiting"
                ui.cur = None
                ui.restart.clear()
                ui.save()
            continue
        except (Stopped, KeyboardInterrupt):
            nxt["status"] = "waiting"
            return False
        except (Exception, SystemExit) as e:
            nxt.update(status="failed", note=str(e) or "failed")
        with ui.lock:
            ui.cur = None
            ui.stage_text = ""
        if ui.queue_mode:
            path = nxt["path"]
            queue_edit(lambda q: q.__setitem__(slice(None), [it for it in q if it["path"] != path]))
        ui.draw(force=True)


def finish(ui, items, wait):
    ok = [it for it in items if it["status"] == "done"]
    if ok:
        notify("Audiobook ready" if len(ok) == 1 else f"{len(ok)} audiobooks ready",
               "\n".join(f"{short(it['out'])} ({fmt(it['secs'])})" for it in ok))
    bad = [it for it in items if it["status"] == "failed"]
    if bad and not ui.live:
        notify("Couldn't make " + ("an audiobook" if len(bad) == 1 else f"{len(bad)} audiobooks"),
               "\n".join(f"{it['title']}: {it.get('note')}" for it in bad))
    ui.draw(force=True)
    if wait and ui.live and on_terminal(sys.stdin):
        ui.anykey.clear()
        ui.anykey.wait()
    ui.close()
    for it in items:
        if it["status"] == "done":
            print(f"Saved {short(it['out'])} ({fmt(it['secs'])})", file=sys.stderr)
        elif it["status"] == "failed":
            print(f"speak: {it['title']}: {it.get('note')}", file=sys.stderr)


def samples(voices, out):
    line = "White snow blankets the land as I travel alone through heaven and earth. Alone without any attachments, my solitary shadow travels freely."
    chapters = [(v, [(v, None, f"This is {v}. {line}", 0.9)]) for v in VOICES]
    ui = UI([{"path": "samples", "out": out, "title": "voice samples", "voice": "all", "speed": None, "status": "working"}], "all", True)
    ui.cur = ui.items[0]
    try:
        secs = run_file(chapters, voices, out, False, "speak voice samples", ui)
        ui.cur.update(status="done", secs=secs)
    except Stopped:
        ui.close()
        sys.exit(130)
    finish(ui, ui.items, False)


class Quiet(UI):

    def __init__(self, voice):
        super().__init__([], voice, False)
        self.last_write = 0.0
        import threading
        threading.Thread(target=self.watch_control, daemon=True).start()

    def watch_control(self):
        while not self.stop.is_set():
            time.sleep(0.5)
            self.poll_control()

    def poll_control(self):
        try:
            os.replace(CONTROL, CONTROL + ".taken")
            with open(CONTROL + ".taken") as f:
                c = json.load(f)
            os.remove(CONTROL + ".taken")
        except (OSError, ValueError):
            return
        with self.lock:
            if "pause" in c:
                (self.paused.set if c["pause"] else self.paused.clear)()
                self.t_last = time.time()
            for path in c.get("remove") or []:
                it = next((x for x in self.items if x["path"] == path and x["status"] in ("waiting", "working")), None)
                if not it:
                    continue
                self.removed.add(path)
                if it is self.cur:
                    it["status"] = "removed"
                    self.restart.set()
                    self.paused.clear()
                else:
                    self.items.remove(it)
            self.save()
        self.write(force=True)

    def draw(self, force=False):
        self.poll_control()
        self.write(force)

    def write(self, force=False):
        now = time.time()
        if not force and now - self.last_write < 1:
            return
        self.last_write = now
        rate = self.rate()
        rows = []
        with self.lock:
            for it in self.items:
                st = it["status"]
                if st not in ("waiting", "working"):
                    continue
                row = {k: it.get(k) for k in ("path", "out", "title", "author", "voice", "speed")}
                if it is self.cur:
                    row["status"] = "paused" if self.paused.is_set() else ("starting" if self.stage_text else "working")
                    row["frac"] = self.done / self.total if self.total else 0
                    row["left"] = (self.total - self.done) / rate if rate else None
                    row["note"] = self.stage_text
                else:
                    size = self.size.get(it["path"])
                    row["status"], row["frac"] = "waiting", 0
                    row["left"] = size / rate if (rate and size) else None
                    row["note"] = ""
                rows.append(row)
        try:
            with open(PROGRESS + ".new", "w") as f:
                json.dump({"pid": os.getpid(), "paused": self.paused.is_set(), "items": rows, "time": now}, f)
            os.replace(PROGRESS + ".new", PROGRESS)
        except OSError:
            pass

    def wait_if_paused(self):
        self.check()
        if self.paused.is_set():
            self.write(force=True)
            while self.paused.is_set() and not self.stop.is_set() and not self.restart.is_set():
                time.sleep(0.5)
                self.poll_control()
            self.t_last = time.time()
            self.check()


def worker():
    try:
        os.sched_setscheduler(0, os.SCHED_IDLE, os.sched_param(0))
    except (AttributeError, OSError):
        try:
            os.nice(19)
        except OSError:
            pass
    lock = take_over()
    if not lock:
        return
    try:
        os.remove(CONTROL)
    except OSError:
        pass
    ui = Quiet(default_voice())
    ui.queue_mode = True
    voices = None

    def let_go(q):
        if not any(it["status"] == "waiting" for it in q):
            try:
                os.remove(PROGRESS)
            except OSError:
                pass
            lock.close()
            return True
    try:
        while True:
            ui.merge_queue()
            if any(it["status"] == "waiting" for it in ui.items):
                if voices is None:
                    ui.stage("loading the voice")
                    ui.write(force=True)
                    voices = Voices()
                make(voices, ui)
                continue
            finish(ui, ui.items, wait=False)
            with ui.lock:
                ui.items.clear()
            if queue_edit(let_go):
                break
    finally:
        if not lock.closed:
            let_go([])


def window():
    lock = take_over()
    if not lock:
        print("speak: already making them (the speak window, or in the background: see Books)")
        return
    ui = UI([], default_voice(), True)
    ui.queue_mode = True
    ui.merge_queue()
    if not ui.items:
        ui.close()
        print("Nothing waiting. In yazi, select books and press c s.")
        time.sleep(2)
        return
    ui.stage("loading the voice")
    ui.cur = ui.items[0]
    ui.draw(force=True)
    ui.cur = None
    voices = Voices()
    ok = make(voices, ui)
    if not ok:
        ui.close()
        print("Stopped. The rest are kept: select a book in yazi and press c s, or run speak --window, to carry on.")
        time.sleep(1.5)
        return
    finish(ui, ui.items, wait=True)


def main():
    ap = argparse.ArgumentParser(prog="speak", description="Read text, documents and books aloud in a natural voice.")
    ap.add_argument("files", nargs="*", help="txt, md, pdf, epub, docx, html, srt or vtt; - for stdin")
    ap.add_argument("-v", "--voice", help="voice name (speak -l lists them)")
    ap.add_argument("-s", "--speed", type=float, help="0.5 to 2.0")
    ap.add_argument("-o", "--output", help="where to save the audio (.opus); with one book only")
    ap.add_argument("-p", "--play", action="store_true", help="play while it's being made")
    ap.add_argument("-c", "--clipboard", action="store_true", help="read out what's on the clipboard")
    ap.add_argument("--pages", help="PDFs: only these pages, e.g. 12-340 (skip the contents, index…)")
    ap.add_argument("-a", "--add", action="store_true", help="add the books to the queue: they're made in the background, follow them in Books (yazi: c s)")
    ap.add_argument("-w", "--window", action="store_true", help="open the speak window and make what's waiting")
    ap.add_argument("--worker", action="store_true", help="make what's waiting in the background (the Books player shows it)")
    ap.add_argument("--voices-tsv", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("-l", "--list", action="store_true", help="list the voices")
    ap.add_argument("--samples", action="store_true", help="save a file with a sample of every voice")
    a = ap.parse_args()

    if a.voices_tsv:
        d = default_voice()
        for v, (_, desc) in VOICES.items():
            print(f"{v}\t{desc}\t{'default' if v == d else ''}")
        return
    if a.list:
        for v, (_, d) in VOICES.items():
            print(f"  {v:<8}{d}")
        print(f"\nDefault: {default_voice()}  (change it with 'default nicole' in ~/.config/speak/voices)")
        return
    if a.speed is not None and not 0.5 <= a.speed <= 2.0:
        die("speed must be between 0.5 and 2.0")
    if a.voice and a.voice.lower() not in VOICES:
        die(f"no voice called '{a.voice}' (speak -l lists them)")
    voice = (a.voice or default_voice()).lower()
    pages = None
    if a.pages:
        m = re.fullmatch(r"(\d*)\s*-\s*(\d*)|(\d+)", a.pages.strip())
        if not m:
            die("--pages takes a range like 12-340, 12- or -340")
        pages = (int(m.group(3)), int(m.group(3))) if m.group(3) else (int(m.group(1) or 1), int(m.group(2) or 10 ** 6))

    if a.add:
        add(a.files, voice, a.speed, pages)
        return
    if a.window:
        window()
        return
    if a.worker:
        worker()
        return

    if a.samples:
        voices = Voices()
        samples(voices, a.output or os.path.join(os.path.expanduser("~/Downloads"), "speak-voices.opus"))
        return

    items = []
    if a.clipboard:
        try:
            text = subprocess.run(["wl-paste", "-n", "-t", "text"], capture_output=True, text=True).stdout
        except OSError:
            text = ""
        if not text.strip():
            die("the clipboard has no text")
        if not a.output:
            voices = Voices()
            stream(plan([("", text)], voice, a.speed), voices)
            return
        items.append({"path": "clipboard", "text": text, "out": a.output, "title": "clipboard"})
    elif not a.files:
        ap.print_help()
        return
    else:
        if a.output and len(a.files) > 1:
            die("-o works with one book at a time")
        for f in a.files:
            if f == "-":
                text = sys.stdin.read()
                if not a.output:
                    voices = Voices()
                    stream(plan([("", text)], voice, a.speed), voices)
                    return
                items.append({"path": "-", "text": text, "out": a.output, "title": "stdin"})
                continue
            if not os.path.isfile(f):
                die(f"no such file: {f}")
            title, author = book_meta(f)
            out = a.output or out_for(f, title, author, {it["out"] for it in items})
            if os.path.abspath(out) == os.path.abspath(f):
                die(f"{f} is already audio")
            items.append({"path": os.path.abspath(f), "out": out, "title": title, "author": author})
    for it in items:
        it.update(voice=voice, speed=a.speed, pages=pages, status="waiting")
    ui = UI(items, voice, True)
    voices = Voices()
    try:
        ok = make(voices, ui, play=a.play)
    except KeyboardInterrupt:
        ok = False
    if not ok:
        ui.close()
        print("Stopped. Run the same command again to carry on from here.", file=sys.stderr)
        sys.exit(130)
    finish(ui, items, wait=False)


if __name__ == "__main__":
    try:
        main()
    except Failure as e:
        print(f"speak: {e}", file=sys.stderr)
        sys.exit(1)
