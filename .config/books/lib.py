#!/usr/bin/env python3
# Books' library helper: the audiobooks in ~/Audiobooks with their saved places, marks, skips and covers, for the
# lists and previews in books (books runs it as lib.py COMMAND: rows, preview, marks …)
import importlib.util, json, os, re, subprocess, sys, time

HOME = os.path.expanduser("~")
CONF = os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")

LIB = os.path.abspath(os.environ.get("BOOKS_DIR") or os.path.join(HOME, "Audiobooks"))
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.join(HOME, ".cache"), "books")
TMP = ".%d.tmp" % os.getpid()
STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.join(HOME, ".local/state"), "books")
SPEAK = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.join(HOME, ".local/state"), "speak")
IDX = os.path.join(CACHE, "library.json")
POS = os.path.join(STATE, "pos.tsv")
MARKS = os.path.join(STATE, "marks.tsv")
SKIPS = os.path.join(STATE, "skips.tsv")
AUDIO_EXT = ("mp3", "m4b", "m4a", "opus", "ogg", "oga", "flac", "aac", "wav", "wma", "mka", "webm", "aiff", "aif")
YTLAST = os.path.join(STATE, "ytlast.tsv")
YTMODE = os.path.join(STATE, "list.yt")
YTMAP = os.path.join(STATE, "yt.tsv")
DL = os.path.join(STATE, "dl")
BOOKISH = (".epub", ".pdf", ".docx")
YT = re.compile(r"(?:youtube\.com/watch\?(?:.*&)?v=|youtu\.be/|music\.youtube\.com/watch\?(?:.*&)?v=|youtube\.com/shorts/)([A-Za-z0-9_-]{11})")


def load_screen():
    global screen, RST, BOLD, DIM, ACC, RED, YEL, fit, clean, clock
    spec = importlib.util.spec_from_file_location("screen", os.path.join(os.path.dirname(os.path.abspath(__file__)), "screen.py"))
    screen = importlib.util.module_from_spec(spec)
    sys.argv, argv = sys.argv[:1], sys.argv
    spec.loader.exec_module(screen)
    sys.argv = argv
    RST, BOLD, DIM, ACC, RED, YEL = screen.RST, screen.BOLD, screen.DIM, screen.ACC, screen.RED, screen.YEL
    fit, clean, clock = screen.fit, screen.clean, screen.clock


def natural(s):
    return [int(x) if x.isdigit() else x.lower() for x in re.split(r"(\d+)", s)]


def probe(f):
    try:
        r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration:format_tags:stream_tags", "-show_chapters",
                            "-of", "json", f], capture_output=True, text=True, timeout=30)
        j = json.loads(r.stdout or "{}")
    except (OSError, ValueError, subprocess.SubprocessError):
        j = {}
    tags = {}
    for s in j.get("streams") or []:
        tags.update({k.lower(): v for k, v in (s.get("tags") or {}).items()})
    tags.update({k.lower(): v for k, v in ((j.get("format") or {}).get("tags") or {}).items()})
    try:
        d = float((j.get("format") or {}).get("duration") or 0)
    except ValueError:
        d = 0.0
    voice = tags.get("voice") or ""
    if not voice:
        m = re.match(r"read by (\w[\w -]*?)(?: at [\d.]+×)?(?: \(speak\))?$", tags.get("comment") or "", re.I)
        voice = m.group(1) if m else (tags.get("narrator") or tags.get("performer") or "")
    author = tags.get("artist") or tags.get("album_artist") or tags.get("author") or tags.get("composer") or ""
    yt = ""
    for k in ("purl", "comment", "url"):
        v = str(tags.get(k) or "").strip()
        m = YT.search(v) if re.fullmatch(r"https?://\S+", v) else None
        if m:
            yt = m.group(1)
            break
    return {"d": d, "t": tags.get("title") or "", "a": author, "al": tags.get("album") or "", "v": voice,
            "c": len(j.get("chapters") or []), "y": yt}


def split_name(name):
    m = re.match(r"^(.+?)\s+[-–—]\s+(.+)$", name)
    return (m.group(1).strip(), m.group(2).strip()) if m else ("", name.strip())


def single(p, c, folder=""):
    a0, t0 = split_name(os.path.splitext(os.path.basename(p))[0])
    return {"key": p, "title": c["t"] or t0, "author": c["a"] or a0 or folder, "voice": c["v"],
            "parts": [{"path": p, "dur": c["d"], "name": c["t"] or t0}], "dur": c["d"], "chapters": c["c"]}


def library():
    try:
        cache = json.load(open(IDX))
    except (OSError, ValueError):
        cache = {}
    seen, books = {}, []
    for d, dirs, files in os.walk(LIB):
        dirs[:] = sorted((x for x in dirs if not x.startswith(".")), key=natural)
        audio = sorted((f for f in files if not f.startswith(".") and f.lower().rsplit(".", 1)[-1] in AUDIO_EXT), key=natural)
        metas = []
        for f in audio:
            p = os.path.join(d, f)
            try:
                mt = os.path.getmtime(p)
            except OSError:
                continue
            c = cache.get(p)
            if not c or c.get("m") != mt or "y" not in c:
                c = probe(p)
                c["m"] = mt
            seen[p] = c
            metas.append((p, c))
        if not metas:
            continue
        parent = os.path.basename(os.path.dirname(d)) if os.path.dirname(d) != LIB and d != LIB else ""
        albums = {c["al"] for _, c in metas}
        parts = (len(albums) == 1 and "" not in albums) or (len(albums - {""}) <= 1 and all(c["c"] <= 1 for _, c in metas))
        if d != LIB and len(metas) >= 2 and parts:
            first = metas[0][1]
            a0, t0 = split_name(os.path.basename(d))
            books.append({"key": d, "title": first["al"] or t0, "author": first["a"] or a0 or parent, "voice": first["v"],
                          "parts": [{"path": p, "dur": c["d"], "name": c["t"] or os.path.splitext(os.path.basename(p))[0]} for p, c in metas],
                          "dur": sum(c["d"] for _, c in metas), "chapters": len(metas)})
        else:
            books += [single(p, c, os.path.basename(d) if d != LIB else "") for p, c in metas]
    if seen != cache:
        os.makedirs(CACHE, exist_ok=True)
        with open(IDX + TMP, "w") as f:
            json.dump(seen, f)
        os.replace(IDX + TMP, IDX)
    return books


def positions():
    out = {}
    try:
        for l in open(POS, encoding="utf-8", errors="replace"):
            r = l.rstrip("\n").split("\t")
            if len(r) >= 6:
                try:
                    out[r[0]] = {"part": int(r[1]), "sec": float(r[2]), "pos": float(r[3]), "dur": float(r[4]), "at": float(r[5])}
                except ValueError:
                    pass
    except OSError:
        pass
    return out


def finished(p, dur):
    return bool(p) and dur > 0 and (p["pos"] >= dur - min(60, dur * 0.05) or p["pos"] >= dur * 0.995)


def making():
    try:
        j = json.load(open(os.path.join(SPEAK, "progress.json")))
        os.kill(int(j.get("pid") or 0), 0)
    except (OSError, ValueError, TypeError):
        return []
    rows = []
    for it in j.get("items") or []:
        if not isinstance(it, dict) or not it.get("path"):
            continue
        it["paused"] = bool(j.get("paused"))
        rows.append(it)
    return rows


def downloads():
    out = []
    try:
        names = sorted(os.listdir(DL))
    except OSError:
        return out
    for n in names:
        try:
            r = open(os.path.join(DL, n), encoding="utf-8", errors="replace").read().rstrip("\n").split("\t") + ["", "", "", ""]
            os.kill(int(r[3]), 0)
        except (OSError, ValueError):
            continue
        out.append({"url": r[0], "title": r[1], "pct": r[2]})
    return out


def yt_results():
    out = []
    try:
        for l in open(YTLAST, encoding="utf-8", errors="replace"):
            f = l.rstrip("\n").split("\t") + ["", "", ""]
            if f[0]:
                try:
                    d = int(float(f[3] or 0))
                except ValueError:
                    d = 0
                out.append({"url": f[0], "title": f[1], "channel": f[2], "dur": d})
    except OSError:
        pass
    return out


def yt_downloaded(url):
    try:
        for l in open(YTMAP, encoding="utf-8", errors="replace"):
            r = l.rstrip("\n").split("\t")
            if len(r) >= 2 and r[0] == url and os.path.isfile(r[1]):
                return r[1]
    except OSError:
        pass
    return ""


def yt_id(path):
    try:
        for l in open(YTMAP, encoding="utf-8", errors="replace"):
            r = l.rstrip("\n").split("\t")
            m = YT.search(r[0]) if len(r) >= 2 and r[1] == path else None
            if m:
                return m.group(1)
    except OSError:
        pass
    try:
        c = json.load(open(IDX)).get(path)
        if c and c.get("m") == os.path.getmtime(path) and "y" in c:
            return c["y"]
    except (OSError, ValueError, AttributeError):
        pass
    return probe(path)["y"]


def cover(path):
    m = YT.search(path) if not os.path.exists(path) else None
    vid = m.group(1) if m else (yt_id(path) if os.path.isfile(path) else "")
    if not vid:
        return None
    d = os.path.join(CACHE, "cover")
    dst = os.path.join(d, f"yt-{vid}.png")
    if os.path.isfile(dst) and os.path.getsize(dst):
        return dst
    os.makedirs(d, exist_ok=True)
    src, tmp = path, dst + ".part.png"
    try:
        if m:
            import urllib.request
            data = None
            for name in ("maxresdefault", "hqdefault"):
                try:
                    data = urllib.request.urlopen(urllib.request.Request(f"https://i.ytimg.com/vi/{vid}/{name}.jpg",
                                                                         headers={"User-Agent": "books"}), timeout=10).read()
                except OSError:
                    data = None
                if data and len(data) > 2000:
                    break
                data = None
            if not data:
                return None
            src = dst + ".part.jpg"
            with open(src, "wb") as f:
                f.write(data)
        r = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", src, "-an", "-map", "0:v:0", "-frames:v", "1",
                            "-vf", "scale=900:900:force_original_aspect_ratio=decrease", tmp],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)
        if r.returncode == 0 and os.path.isfile(tmp) and os.path.getsize(tmp):
            os.replace(tmp, dst)
            return dst
        return None
    except (OSError, subprocess.SubprocessError):
        return None
    finally:
        for f in (tmp, dst + ".part.jpg"):
            try:
                os.remove(f)
            except OSError:
                pass


def yt_rows(cols):
    tv = max(40, cols - 13)
    tc, tt = int(tv * 0.26), tv - int(tv * 0.26) - 2
    for r in yt_results():
        o = " " + fit(clean(r["channel"]), tc) + "  " + fit(clean(r["title"]), tt) + "  " + (clock(r["dur"]) if r["dur"] else "live").rjust(8)
        print(f"{r['url']}\t\t{o}")


def retag(key, title, author):
    import mutagen
    files = [key] if os.path.isfile(key) else [p["path"] for p in (find(key) or {"parts": []})["parts"]]
    for f in files:
        m = mutagen.File(f, easy=True)
        if m is None:
            continue
        if m.tags is None:
            m.add_tags()
        if os.path.isfile(key):
            m["title"] = title
        else:
            m["album"] = title
        if author:
            m["artist"] = author
        elif "artist" in m:
            del m["artist"]
        m.save()


def rekey(old, new):
    for f in (POS, MARKS, SKIPS, YTMAP):
        try:
            lines = open(f, encoding="utf-8").readlines()
        except OSError:
            continue
        out = []
        for l in lines:
            k, _, rest = l.partition("\t")
            if f == YTMAP:
                if rest.rstrip("\n") == old:
                    l = f"{k}\t{new}\n" if new else ""
            elif k == old:
                l = new + "\t" + rest if new else ""
            if l:
                out.append(l)
        with open(f + TMP, "w", encoding="utf-8") as o:
            o.writelines(out)
        os.replace(f + TMP, f)


def widths(cols):
    tv = max(40, cols - 13)
    ta = int(tv * 0.24)
    tt = int(tv * 0.40)
    tvo = int(tv * 0.14)
    tp = tv - ta - tt - tvo
    return ta, tt, tvo, tp


def colhead(cols):
    if os.path.exists(YTMODE):
        tv = max(40, cols - 13)
        tc, tt = int(tv * 0.26), tv - int(tv * 0.26) - 2
        print(BOLD + " " + fit("Channel", tc) + "  " + fit("Title", tt) + "  " + "Length".rjust(8) + RST, end="")
        return
    ta, tt, tvo, tp = widths(cols)
    print(BOLD + " " + fit("Author", ta) + "  " + fit("Title", tt) + "  " + fit("Voice", tvo) + "  " + fit("Progress", tp) + "  "
          + "Length".rjust(8) + RST, end="")


def left_of(b, p):
    if not p or b["dur"] <= 0:
        return b["dur"]
    return max(0, b["dur"] - p["pos"])


def last_book(books, pos):
    return max((b for b in books if b["key"] in pos and not finished(pos[b["key"]], b["dur"])),
               key=lambda b: pos[b["key"]]["at"], default=None)


def rows(cols):
    C, M = "\033[34m", "\033[90m"
    if os.path.exists(YTMODE):
        return yt_rows(cols)
    books = library()
    pos = positions()
    ta, tt, tvo, tp = widths(cols)
    W = cols + 4
    b = last_book(books, pos)
    if b:
        left = f"{clock(left_of(b, pos.get(b['key'])))} left"
        tag = " ▶ Resume "
        print(f":resume\t\t {BOLD}\033[7;34m{tag}{RST}  {BOLD}{fit(clean(b['title']), max(8, W - len(tag) - len(left) - 5))}{RST}  {M}{left}{RST}")
    print(f":new\t\t {C}＋ Make an audiobook{RST}  {M}from a book…{RST}")
    for it in making():
        st = it.get("status")
        frac = float(it.get("frac") or 0)
        left = it.get("left")
        if it.get("paused") and st != "waiting":
            what = "paused"
        elif st == "waiting":
            what = "waiting its turn"
        elif it.get("note"):
            what = it["note"]
        else:
            what = f"{int(frac * 100)}%" + (f"  ·  about {clock(left)} left" if isinstance(left, (int, float)) else "")
        voice = (it.get("voice") or "") + (f" {it['speed']:g}×" if it.get("speed") else "")
        print(f":making:{it['path']}\t\t{YEL}◌{RST}  Making  {it.get('title') or os.path.basename(it['path'])}   {M}{voice}  ·  {what}{RST}")
    for d in downloads():
        print(f":dl:{d['url']}\t\t{YEL}⇣{RST}  Downloading  {clean(d['title'])}   {M}from YouTube  ·  {d['pct'] or 'starting'}{RST}")

    if books:
        print(f":sep\t\t{M}{'─' * W}{RST}")

    def order(b):
        p = pos.get(b["key"])
        started = bool(p) and p["pos"] > 30
        done = finished(p, b["dur"])
        return (2 if done else 0 if started else 1, -(p["at"] if started else 0), b["author"].lower(), natural(b["title"]))
    for b in sorted(books, key=order):
        p = pos.get(b["key"])
        if finished(p, b["dur"]):
            prog = "finished"
        elif p and p["pos"] > 30 and b["dur"] > 0:
            prog = f"{int(100 * p['pos'] / b['dur'])}%  ·  {clock(left_of(b, p))} left"
        else:
            prog = "new"
        o = (" " + fit(clean(b["author"]), ta) + "  " + fit(clean(b["title"]), tt) + "  " + fit(clean(b["voice"]), tvo) + "  "
             + fit(prog, tp) + "  " + clock(b["dur"]).rjust(8))
        print(f"{b['key']}\t\t{o}")


def find(key):
    books = library()
    for b in books:
        if b["key"] == key:
            return b
    for b in books:
        if any(p["path"] == key for p in b["parts"]):
            return b
    return None


def last_key():
    b = last_book(library(), positions())
    return b["key"] if b else ""


def open_book(key, fresh=False):
    b = find(key)
    if not b and os.path.isfile(key):
        b = single(key, probe(key))
    if not b:
        return 1
    key = b["key"]
    p = positions().get(key)
    if p and not fresh and not finished(p, b["dur"]):
        b["part"], b["sec"] = max(0, min(len(b["parts"]) - 1, p["part"])), max(0, p["sec"] - 3)
    else:
        b["part"], b["sec"] = 0, 0
    os.makedirs(STATE, exist_ok=True)
    f = os.path.join(STATE, "open.json")
    with open(f + TMP, "w") as o:
        json.dump(b, o)
    os.replace(f + TMP, f)
    print(f)
    return 0


def info_lines(b, p, cols):
    out = [BOLD + fit(clean(b["title"]), cols, pad=False)]
    if b["author"]:
        out.append(RED + fit(clean(b["author"]), cols, pad=False))
    if b["voice"]:
        out.append(DIM + "read by " + YEL + fit(clean(b["voice"]), cols - 8, pad=False))
    ch = b.get("chapters") or 0
    out.append(DIM + clock(b["dur"]) + (f"  ·  {ch} chapter{'s' if ch != 1 else ''}" if ch > 1 else ""))
    if finished(p, b["dur"]):
        out.append(ACC + "finished")
    elif p and p["pos"] > 30 and b["dur"] > 0:
        f = p["pos"] / b["dur"]
        w = max(6, cols - 16)
        out.append(ACC + "━" * int(f * w) + DIM + "─" * (w - int(f * w)) + RST + f"  {int(f * 100)}%")
        out.append(DIM + f"{clock(left_of(b, p))} left")
    return out


def draw_cover(img, cols, lines):
    cw, ch = screen.cell_size()
    if not img or lines < 3:
        return False
    bw, bh = int((cols - 2) * cw), int(lines * ch)
    if screen.IN_KITTY:
        key = os.path.join(screen.CACHE, os.path.basename(img).rsplit(".", 1)[0] + f".{bw}x{bh}f.png")
        if not (os.path.isfile(key) and os.path.getsize(key)):
            data = screen.scaled(img, bw, bh, fill=True)
            if not data:
                return False
            try:
                with open(key + ".part", "wb") as f:
                    f.write(data)
                os.replace(key + ".part", key)
            except OSError:
                return False
        try:
            r = subprocess.run(["kitten", "icat", "--clear", "--transfer-mode=memory", "--unicode-placeholder",
                                "--stdin=no", f"--place={cols - 2}x{lines}@0x0", key],
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=10)
        except (OSError, subprocess.SubprocessError):
            return False
        if r.returncode or not r.stdout:
            return False
        data = r.stdout[:-1] if r.stdout.endswith(b"\n") else r.stdout
        screen.out.flush()
        os.write(1, data + b"\033[m")
        screen.out.write("\n")
        screen.out.flush()
        return True
    key = os.path.join(screen.CACHE, os.path.basename(img).rsplit(".", 1)[0] + f".{bw}x{bh}f.six")
    try:
        data = open(key, "rb").read()
    except OSError:
        data = screen.sixel(img, bw, bh, fill=True)
        if data:
            try:
                open(key, "wb").write(data)
            except OSError:
                pass
    if not data:
        return False
    screen.out.write(" ")
    screen.out.flush()
    os.write(1, data)
    screen.out.write("\n")
    screen.out.flush()
    return True


def preview(item):
    cols = int(os.environ.get("FZF_PREVIEW_COLUMNS") or 40)
    lines = int(os.environ.get("FZF_PREVIEW_LINES") or 20)
    pad = "  "
    if item == ":new":
        print(f"\n{pad}{BOLD}Make an audiobook{RST}\n")
        print(pad + DIM + fit("Pick a book (epub, pdf, docx, txt…) and a voice; it's read aloud in the background and", cols - 4, pad=False))
        print(pad + DIM + fit("appears here when it's done.", cols - 4, pad=False))
        return
    if item.startswith(":making:"):
        src = item[8:]
        it = next((x for x in making() if x.get("path") == src), None)
        print(f"\n{pad}{BOLD}{fit(clean((it or {}).get('title') or os.path.basename(src)), cols - 4, pad=False)}{RST}")
        if not it:
            print(f"\n{pad}{DIM}finished{RST}")
            return
        if it.get("author"):
            print(pad + RED + fit(clean(it["author"]), cols - 4, pad=False))
        print(pad + DIM + "read by " + YEL + clean(it.get("voice") or "") + (f" {it['speed']:g}×" if it.get("speed") else "") + RST + "\n")
        f = float(it.get("frac") or 0)
        w = max(6, cols - 12)
        print(pad + ACC + "█" * int(f * w) + DIM + "░" * (w - int(f * w)) + RST + f" {int(f * 100)}%")
        left = it.get("left")
        st = "paused" if it.get("paused") and it.get("status") != "waiting" else (
            "waiting its turn" if it.get("status") == "waiting" else (it.get("note") or (f"about {clock(left)} left" if isinstance(left, (int, float)) else "working out the time left…")))
        print(pad + DIM + st + RST)
        print("\n" + pad + DIM + fit(src.replace(HOME, "~", 1), cols - 4, pad=False) + RST)
        return
    if item.startswith(":dl:") or YT.search(item):
        url = item[4:] if item.startswith(":dl:") else item
        r = next((x for x in yt_results() if x["url"] == url), None) or {"title": "", "channel": "", "dur": 0}
        d = next((x for x in downloads() if x["url"] == url), None)
        info = [BOLD + fit(clean(r["title"] or (d or {}).get("title") or url), cols - 4, pad=False)]
        if r["channel"]:
            info.append(RED + fit(clean(r["channel"]), cols - 4, pad=False))
        if r["dur"]:
            info.append(DIM + clock(r["dur"]))
        if d:
            info.append(YEL + "downloading  ·  " + (d["pct"] or "starting"))
        elif yt_downloaded(url):
            info.append(ACC + "in your books")
        img = cover(url)
        room = lines - len(info) - 2
        if not draw_cover(img, cols, room):
            screen.out.write("\n" * max(0, room // 2 - 1) + ACC + "▶".center(cols) + RST + "\n" * max(0, room - room // 2 + 1))
        screen.out.write("\n" + "\n".join(pad + x + RST for x in info) + "\n")
        screen.out.flush()
        return
    key = last_key() if item == ":resume" else item
    b = find(key) if key else None
    if not b:
        return
    p = positions().get(key)
    info = info_lines(b, p, cols - 4)
    img = cover(b["parts"][0]["path"]) if len(b["parts"]) == 1 else None
    room = lines - len(info) - 2
    if not draw_cover(img, cols, room):
        screen.out.write("\n" * max(0, room + 1))
    screen.out.write("\n" + "\n".join(pad + x + RST for x in info) + "\n")
    screen.out.flush()


def mark_rows(key):
    b = find(key)
    before = [0.0]
    for pt in (b["parts"] if b else []):
        before.append(before[-1] + (pt["dur"] or 0))
    rows_ = []
    try:
        for l in open(MARKS, encoding="utf-8", errors="replace"):
            r = l.rstrip("\n").split("\t")
            if len(r) >= 4 and r[0] == key:
                try:
                    part, sec = int(r[1]), float(r[2])
                except ValueError:
                    continue
                at = (before[part] if part < len(before) else 0) + sec
                made = ""
                try:
                    made = time.strftime("%-d %b", time.localtime(float(r[4]))) if len(r) > 4 else ""
                except ValueError:
                    pass
                rows_.append((at, part, sec, r[3], made))
    except OSError:
        pass
    for n, (at, part, sec, label, made) in enumerate(sorted(rows_), 1):
        print(f"{part}\t{sec}\t\033[34m{n:>2}\033[0m  {clock(at):>8}   {clean(label)}   \033[90m{made}\033[0m")


def del_mark(key, part, sec):
    keep = []
    try:
        for l in open(MARKS, encoding="utf-8", errors="replace"):
            r = l.rstrip("\n").split("\t")
            if len(r) >= 3 and r[0] == key and r[1] == part and abs(float(r[2] or 0) - float(sec or 0)) < 0.05:
                continue
            keep.append(l)
    except (OSError, ValueError):
        return
    with open(MARKS + TMP, "w", encoding="utf-8") as f:
        f.writelines(keep)
    os.replace(MARKS + TMP, MARKS)


def skip_rows(key):
    b = find(key)
    before = [0.0]
    for pt in (b["parts"] if b else []):
        before.append(before[-1] + (pt["dur"] or 0))
    rows_ = []
    try:
        for l in open(SKIPS, encoding="utf-8", errors="replace"):
            r = l.rstrip("\n").split("\t")
            if len(r) >= 4 and r[0] == key:
                try:
                    part, a, z = int(r[1]), float(r[2]), float(r[3])
                except ValueError:
                    continue
                at = before[part] if part < len(before) else 0
                made = ""
                try:
                    made = time.strftime("%-d %b", time.localtime(float(r[4]))) if len(r) > 4 else ""
                except ValueError:
                    pass
                rows_.append((at + a, at + z, part, r[2], made))
    except OSError:
        pass
    for n, (a, z, part, sec, made) in enumerate(sorted(rows_), 1):
        print(f"{part}\t{sec}\t\033[34m{n:>2}\033[0m  {clock(a):>8} – {clock(z):<8}  {clock(z - a):>8}   \033[90m{made}\033[0m")


def del_skip(key, part, sec):
    keep = []
    try:
        for l in open(SKIPS, encoding="utf-8", errors="replace"):
            r = l.rstrip("\n").split("\t")
            try:
                if len(r) >= 3 and r[0] == key and r[1] == part.strip() and abs(float(r[2]) - float(sec)) < 0.05:
                    continue
            except ValueError:
                pass
            keep.append(l)
    except OSError:
        return
    with open(SKIPS + TMP, "w", encoding="utf-8") as f:
        f.writelines(keep)
    os.replace(SKIPS + TMP, SKIPS)


def book_files():
    out = []
    for d, dirs, files in os.walk(HOME):
        depth = d[len(HOME):].count(os.sep)
        dirs[:] = [x for x in dirs if not x.startswith(".") and x not in ("node_modules", "venv", "__pycache__", "plugged", "go")
                   and os.path.join(d, x) != LIB and depth < 5]
        for f in files:
            if f.lower().endswith(BOOKISH) and not f.startswith("."):
                p = os.path.join(d, f)
                try:
                    out.append((os.path.getmtime(p), p))
                except OSError:
                    pass
    for _, p in sorted(out, reverse=True):
        folder = os.path.dirname(p).replace(HOME, "~", 1)
        print(f"{p}\t\t\033[34m▤\033[0m  {clean(os.path.splitext(os.path.basename(p))[0])}   \033[90m{folder}  ·  {p.rsplit('.', 1)[-1]}\033[0m")


def control(**c):
    os.makedirs(SPEAK, exist_ok=True)
    f = os.path.join(SPEAK, "control.json")
    try:
        old = json.load(open(f))
    except (OSError, ValueError):
        old = {}
    if "remove" in c:
        c["remove"] = list(dict.fromkeys((old.get("remove") or []) + c["remove"]))
    old.update(c)
    with open(f + TMP, "w") as o:
        json.dump(old, o)
    os.replace(f + TMP, f)
    for _ in range(20):
        if not os.path.exists(f):
            break
        time.sleep(0.1)


def main(a):
    cmd = a[0] if a else ""
    if cmd not in ("making", "pause", "cancel", "delmark", "delskip", "ytdone", "rekey", "forget", "cover"):
        load_screen()
    if cmd == "rows":
        rows(int(a[1]) if len(a) > 1 and a[1].isdigit() else 90)
    elif cmd == "colhead":
        colhead(int(a[1]) if len(a) > 1 and a[1].isdigit() else 90)
    elif cmd == "count":
        print(len(library()))
    elif cmd == "open":
        return open_book(a[1], fresh=len(a) > 2 and a[2] == "fresh")
    elif cmd == "last":
        print(last_key())
    elif cmd == "preview":
        preview(a[1] if len(a) > 1 else "")
    elif cmd == "info":
        b = find(a[1])
        if b:
            print(f"{b['author']}\t{b['title']}")
    elif cmd == "marks":
        mark_rows(a[1])
    elif cmd == "delmark":
        del_mark(a[1], a[2], a[3])
    elif cmd == "skips":
        skip_rows(a[1])
    elif cmd == "delskip":
        del_skip(a[1], a[2], a[3])
    elif cmd == "cover":
        print(cover(os.path.abspath(a[1])) or "")
    elif cmd == "bookfiles":
        book_files()
    elif cmd == "cancel":
        if making():
            control(remove=[a[1]])
    elif cmd == "pause":
        rows_ = making()
        if rows_:
            control(pause=not rows_[0].get("paused"))
    elif cmd == "making":
        print(len(making()) + len(downloads()))
    elif cmd == "retag":
        retag(a[1], a[2], a[3] if len(a) > 3 else "")
    elif cmd == "rekey":
        rekey(a[1], a[2])
    elif cmd == "forget":
        rekey(a[1], "")
    elif cmd == "ytfile":
        print(yt_downloaded(a[1]))
    elif cmd == "ytdone":
        os.makedirs(STATE, exist_ok=True)
        with open(YTMAP, "a", encoding="utf-8") as o:
            o.write(f"{a[1]}\t{a[2]}\n")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except BrokenPipeError:
        pass
