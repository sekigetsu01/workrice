#!/usr/bin/env python3
# Books' now-playing screen in the terminal: the book's cover, chapter and progress, kept up to date from mpv's
# socket; the keys pressed there go to mpv
import base64, fcntl, importlib.util, json, os, re, select, shutil, signal, socket, struct, subprocess
import sys, termios, threading, time, tty, unicodedata

SOCK = sys.argv[1] if len(sys.argv) > 1 else ""
MPV_PID = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 0
HOME = os.path.expanduser("~")
HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.join(HOME, ".cache"), "books", "cover")

RST, BOLD, DIM, ACC = "\033[0m", "\033[1m", "\033[90m", "\033[34m"
SEL = "\033[30;44m"
TAG = "\033[7;35m"
RED, YEL, GRN = "\033[31m", "\033[33m", "\033[32m"
BOX = "\033[34m"
ANSI = re.compile(r"\033\[[0-9;?]*[A-Za-z]")
AUDIO_EXT = ("mp3", "m4b", "m4a", "opus", "ogg", "oga", "flac", "aac", "wav", "wma", "mka", "webm", "aiff", "aif")

out = sys.stdout


def cwidth(ch):
    if unicodedata.combining(ch):
        return 0
    return 2 if unicodedata.east_asian_width(ch) in "WF" else 1


def vlen(s):
    return sum(cwidth(c) for c in ANSI.sub("", s))


def clean(s):
    return "".join(c if c.isprintable() else " " for c in str(s or ""))


def fit(s, w, pad=True):
    if w <= 0:
        return ""
    cut = vlen(s) > w
    lim = w - 1 if cut else w
    res, n, i = [], 0, 0
    while i < len(s):
        m = ANSI.match(s, i)
        if m:
            res.append(m.group())
            i = m.end()
            continue
        c = cwidth(s[i])
        if n + c > lim:
            break
        res.append(s[i])
        n += c
        i += 1
    if cut:
        res.append("…")
        n += 1
    return "".join(res) + RST + (" " * (w - n) if pad else "")


def secs(n):
    n = int(n)
    if n < 120:
        return f"{n} s"
    return f"{n // 60} min" + (f" {n % 60} s" if n % 60 else "")


def clock(t):
    if t is None or t < 0:
        return "--:--"
    t = int(t)
    h, m, s = t // 3600, t // 60 % 60, t % 60
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


def split_name(n):
    for sep in (" - ", " – ", " — "):
        if sep in n:
            a, t = n.split(sep, 1)
            if a.strip():
                return a.strip(), t.strip()
    return "", n.strip()


def magick():
    return shutil.which("magick") or shutil.which("convert")


def png_size(path):
    try:
        with open(path, "rb") as f:
            head = f.read(24)
        if head[:8] == b"\x89PNG\r\n\x1a\n":
            return struct.unpack(">II", head[16:24])
    except OSError:
        pass
    return None


def cover_file(path):
    try:
        spec = importlib.util.spec_from_file_location("bookslib", os.path.join(HERE, "lib.py"))
        lib = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(lib)
        return lib.cover(path)
    except Exception:
        return None


IN_KITTY = bool(os.environ.get("KITTY_WINDOW_ID")) or os.environ.get("TERM") == "xterm-kitty"
COVER_ID = 7
UNCOVER = "\033_Ga=d,d=I,i=%d,q=2\033\\" % COVER_ID


def scaled(img, px, ph=None, fill=False, fmt="png"):
    mg = magick()
    if not mg or not img:
        return None
    w, h = int(px), int(ph or px)
    size = ["-resize", f"{w}x{h}^", "-gravity", "center", "-extent", f"{w}x{h}"] if fill else ["-resize", f"{w}x{h}"]
    extra = ["-colors", "255"] if fmt == "sixel" else []
    try:
        r = subprocess.run([mg, img, *size, *extra, f"{fmt}:-"], stdout=subprocess.PIPE,
                           stderr=subprocess.DEVNULL, timeout=20)
        return r.stdout if r.returncode == 0 and r.stdout else None
    except Exception:
        return None


def sixel(img, px, ph=None, fill=False):
    if not IN_KITTY:
        return scaled(img, px, ph, fill, "sixel")
    data = scaled(img, px, ph, fill)
    if not data:
        return None
    b = base64.standard_b64encode(data)
    chunks = [b[i:i + 4096] for i in range(0, len(b), 4096)]
    out = []
    for i, ch in enumerate(chunks):
        more = int(i < len(chunks) - 1)
        head = f"a=T,f=100,i={COVER_ID},q=2,C=1,m={more}" if i == 0 else f"m={more}"
        out.append(b"\033_G" + head.encode() + b";" + ch + b"\033\\")
    return b"".join(out)


def cell_size():
    try:
        fd = os.open("/dev/tty", os.O_RDONLY)
        try:
            r, c, xp, yp = struct.unpack("HHHH", fcntl.ioctl(fd, termios.TIOCGWINSZ, b"\0" * 8))
        finally:
            os.close(fd)
        if xp and yp and c and r:
            return xp / c, yp / r
    except OSError:
        pass
    return 8.0, 16.0


class UI:
    def __init__(self, sock):
        self.sock = sock
        self.buf = b""
        self.st = {}
        self.ud = {}
        self.tpos = None
        self.cursor = 0
        self.moved = 0.0
        self.rows = {}
        self.cov = {"key": None, "img": None, "six": None, "six_geo": None, "pending": None, "drawn": None, "busy": False}
        self.geo = None
        self.size_sent = None
        self.wake_r, self.wake_w = os.pipe()
        os.set_blocking(self.wake_w, False)
        self.dirty = True
        self.full = True
        self.last_poll = 0.0
        self.note, self.note_until = "", 0.0
        self.skip_edit, self.skip_typed = None, ""
        self.browse_until = 0.0
        self.list_rows = []
        self.bar = None
        self.bin = os.environ.get("BOOKS_BIN") or "books"
        self.back = False

    def qpos(self):
        p = self.ud.get("qpos")
        return p if isinstance(p, int) else -1

    def jump(self, i):
        self.send("script-message", "books-chapter", str(i))

    def send(self, *cmd, rid=0):
        try:
            self.sock.sendall((json.dumps({"command": list(cmd), "request_id": rid}) + "\n").encode())
        except OSError:
            pass

    def wake(self):
        try:
            os.write(self.wake_w, b"x")
        except OSError:
            pass

    def on_line(self, line):
        try:
            m = json.loads(line)
        except ValueError:
            return
        if m.get("event") == "property-change":
            n = m.get("name")
            if n == "user-data/music":
                old = self.ud.get("qpos")
                self.ud = m.get("data") or {}
                p = self.ud.get("qpos")
                if p != old and isinstance(p, int) and p >= 0 and time.time() - self.moved > 4:
                    self.cursor = p
            else:
                self.st[n] = m.get("data")
            self.dirty = True
        elif m.get("request_id") == 7:
            v = m.get("data")
            if v != self.tpos:
                self.tpos = v
                self.dirty = True
        elif m.get("event") in ("seek", "playback-restart", "file-loaded"):
            self.poll()

    def poll(self):
        self.last_poll = time.time()
        self.send("get_property", "time-pos", rid=7)

    def layout(self):
        W, H = shutil.get_terminal_size((80, 24))
        try:
            _, _, xp, yp = struct.unpack("HHHH", fcntl.ioctl(1, termios.TIOCGWINSZ, b"\0" * 8))
        except OSError:
            xp = yp = 0
        cw = xp / W if xp and W else 8.0
        ch = yp / H if yp and H else 16.0
        view = self.ud.get("view") or "main"
        g = {"W": W, "H": H, "view": view, "cov": None}
        if view != "main":
            g.update(top=1, h=max(3, H - 4), bar=H - 2, foot=H - 1)
            return g
        if W >= 80 and H >= 22:
            return self.layout_panels(g, W, H, cw, ch)
        st = 1 if self.status_text() else 0
        n = max(1, min(5, (H - 12) // 3))
        bw = max(20, min(64, W - 12))
        fixed = 2 + st + 1 + 1 + 1 + n + 2
        crows = 0
        cov = None
        if magick() and W >= 30:
            crows = min(H - fixed - 2, int(H * 0.45))
            if crows >= 5:
                px = int(min(crows * ch, W * 0.45 * cw))
                ccols, crows = max(1, int(px / cw + 0.999)), max(1, int(px / ch + 0.999))
                cov = {"cols": ccols, "rows": crows, "px": px, "cw": cw, "ch": ch}
            else:
                crows = 0
        total = (crows + 1 if cov else 0) + fixed - 1
        top = max(0, (H - 1 - total) // 2)
        r = top
        if cov:
            cov.update(row=r, col=(W - cov["cols"]) // 2)
            r += cov["rows"] + 1
        g["cov"] = cov
        g["title"], g["artist"] = r, r + 1
        r += 2
        g["status"] = r if st else None
        r += st + 1
        g["bar"], g["bw"], g["bx"] = r, bw, (W - bw) // 2
        r += 2
        g["list"], g["n"] = r, n
        g["foot"] = H - 1
        return g

    def layout_panels(self, g, W, H, cw, ch):
        x0, top = 2, 4
        U = W - 4
        C = H - 8
        lw = max(26, min(60, int(U * 0.36)))
        rx, rw = x0 + lw + 1, U - lw - 1
        g.update(panel=True, x0=x0, top=top, C=C, lw=lw, rx=rx, rw=rw, bar=H - 3, foot=H - 1)
        g["ctop"], g["ch"] = top, C
        ir, ic = g["ch"] - 2, lw - 2
        cov = None
        if magick() and ir >= 3:
            cols, rows = max(1, ic - 2), ir
            cov = {"cols": cols, "rows": rows, "px": int(min(ir * ch, cols * cw)), "pw": int(cols * cw), "ph": int(rows * ch),
                   "cw": cw, "ch": ch, "row": g["ctop"] + 1, "col": x0 + 2, "inner": (g["ctop"] + 1, x0 + 1, ir, ic)}
        g["cov"] = cov
        vh = max(5, min(12, C // 3))
        g["vh"] = vh
        g["qh"] = C - vh
        g["n"] = max(1, g["qh"] - 4)
        return g

    def frame(self, row, x, w, h, inner=None, skip=False, mark=()):
        self.put(row, x, w, BOX + "╭" + "─" * (w - 2) + "╮")
        for r in range(h - 2):
            self.put(row + 1 + r, x, 1, (ACC + BOLD + "┃") if r in mark else (BOX + "│"))
            self.put(row + 1 + r, x + w - 1, 1, BOX + "│")
            if inner and not skip:
                t = inner(r)
                if t is not None:
                    self.put(row + 1 + r, x + 1, w - 2, t)
        self.put(row + h - 1, x, w, BOX + "╰" + "─" * (w - 2) + "╯")

    def three(self, row, W, left, mid, right):
        lw, rw = vlen(left), vlen(right)
        room = max(0, W - 4 - 2 * max(lw, rw) - 2)
        m = fit(mid, room, pad=False) if room else ""
        ml = vlen(m)
        mx = max(lw + 3, (W - ml) // 2)
        line = "  " + left + RST + " " * max(1, mx - 2 - lw) + m + RST
        line += " " * max(1, W - 2 - rw - vlen(line)) + right
        self.put(row, 0, W, line)

    def render_panels(self, g):
        W, ud, st = g["W"], self.ud, self.st
        now = ud.get("now") or {}
        a, t, al = clean(now.get("artist")), clean(now.get("title")), clean(now.get("album"))
        state = "[Paused]" if st.get("pause") else "[Playing]"
        vol = st.get("volume")
        vol = int(round(vol)) if isinstance(vol, (int, float)) else 100
        vb = min(10, max(0, round(vol / 10)))
        vtxt = f"{DIM}Vol {ACC}{'━' * vb}{DIM}{'─' * (10 - vb)}{RST} " + (f"{RED}muted" if st.get("mute") else f"{vol:>3}%")
        bk = ud.get("book") or {}
        bp, bd = bk.get("pos"), bk.get("dur")
        pct = f"   {int(100 * bp / bd)}%" if isinstance(bp, (int, float)) and isinstance(bd, (int, float)) and bd > 0 else ""
        left2 = f"{clock(bp)} / {clock(bd)}{DIM}{pct}"
        sub = (RED + a if a else "") + (DIM + "  ·  read by " + YEL + al if al else "")
        sp = st.get("speed")
        nq, q = len(ud.get("queue") or []), self.qpos()
        modes = "  ".join(x for x in [
            (DIM + f"chapter {q + 1} of {nq}") if nq > 1 and q >= 0 else "",
            (ACC if isinstance(sp, (int, float)) and abs(sp - 1) > 0.001 else DIM) + f"[ ] {sp if isinstance(sp, (int, float)) else 1:.2f}×"] if x)
        self.three(1, W, YEL + state, BOLD + (t or "nothing playing"), vtxt)
        self.three(2, W, left2, sub, modes)

        x0, top, lw, rx, rw = g["x0"], g["top"], g["lw"], g["rx"], g["rw"]
        iw = lw - 2
        c, cv = g["cov"], self.cov
        if c:
            self.want_cover(g)
        has = bool(c and (cv["busy"] or cv["pending"] or (cv["img"] and cv["six"] != b""))) and cv["key"] == self.cover_key()
        ir = g["ch"] - 2

        if not magick():
            why = ["covers need ImageMagick:", "sudo pacman -S imagemagick"]
        elif c and cv["img"] and cv["six"] == b"":
            why = ["couldn't draw the cover"]
        else:
            why = []

        def cov_row(r):
            mid = ir // 2
            if mid + 1 <= r < mid + 1 + len(why):
                t = fit(why[r - mid - 1], iw - 2, pad=False)
                return " " * max(0, (iw - vlen(t)) // 2) + DIM + t
            return ""
        self.frame(g["ctop"], x0, lw, g["ch"], cov_row, skip=has)
        queue = [clean(x) for x in (ud.get("queue") or [])]
        qd = ud.get("qdur") or []
        pos = self.qpos()
        n = len(queue)
        self.cursor = max(0, min(self.cursor, n - 1)) if n else 0
        browsing = time.time() < self.browse_until
        rows = g["n"]
        qiw = rw - 2
        bar = n > rows
        tw_all = qiw - (1 if bar else 0)
        dw = 8
        rest = max(10, tw_all - 2 - dw - 2)
        tw = int(rest * 0.56)
        aw = rest - tw
        focus = self.cursor if browsing else max(0, pos)
        first = max(0, min(focus - rows // 3, n - rows)) if n > rows else 0
        self.list_rows = []

        def q_row(r):
            if r == 0:
                return ("  " + YEL + BOLD + fit("Chapter", tw, pad=True) + " " + RED + BOLD + fit("Starts", aw, pad=True) + " "
                        + ACC + BOLD + "Length".rjust(dw))
            if r == 1:
                return DIM + "─" * tw_all
            k = r - 2
            if not n:
                return (DIM + "  no chapters") if k == 0 else ""
            i = first + k
            sb = ""
            if bar:
                th = max(1, rows * rows // n)
                tpos = (rows - th) * first // max(1, n - rows)
                sb = (ACC + "█") if tpos <= k < tpos + th else (DIM + "│")
            if i >= n:
                return " " * tw_all + sb
            self.list_rows.append((g["top"] + 1 + r, i))
            ar, ti = split_name(queue[i])
            try:
                d = float(qd[i]) if i < len(qd) and qd[i] else 0
            except (TypeError, ValueError):
                d = 0
            ds = clock(d) if d > 0 else ""
            body = fit(ti, tw) + " " + fit(ar, aw) + " " + ds.rjust(dw)
            if browsing and i == self.cursor:
                mark, style = ("▶ " if i == pos else "  "), SEL
            elif i == pos:
                mark, style = "▶ ", YEL + BOLD
            elif i < pos:
                mark, style = "  ", DIM
            else:
                mark, style = "  ", ""
            plain = ANSI.sub("", body)
            return style + mark + plain + RST + sb
        self.frame(top, rx, rw, g["qh"], q_row)
        marks = [str(x) for x in (ud.get("marks") or [])]

        def mk_row(r):
            if r == 0:
                return "  " + YEL + BOLD + "Bookmarks" + RST + (DIM + f"   {len(marks)}" if marks else "")
            if not marks:
                return (DIM + "  none yet") if r == 1 else ""
            i = r - 1
            if i >= len(marks):
                return ""
            tm, _, lab = marks[i].partition("\t")
            tm, lab = clean(tm), clean(lab)
            return "  " + (ACC + f"{i + 1}" if i < 9 else DIM + "·") + RST + "  " + DIM + tm.rjust(8) + RST + "  " + lab
        self.frame(top + g["qh"], rx, rw, g["vh"], mk_row)
        dur, tp = st.get("duration"), self.tpos
        cs, ce = 0, dur
        cb = ud.get("cbar")
        if isinstance(cb, list) and len(cb) == 2 and all(isinstance(x, (int, float)) for x in cb) and cb[1] > cb[0]:
            cs, ce = cb
        span = (ce - cs) if isinstance(ce, (int, float)) else None
        rel = (tp - cs) if isinstance(tp, (int, float)) else None
        f = (rel / span) if isinstance(rel, (int, float)) and span and span > 0 else 0
        f = max(0.0, min(1.0, f))
        self.bar_span = (cs, span)
        lt, rt = clock(max(0, rel) if rel is not None else None), clock(span)
        bx = 2 + len(lt) + 2
        bw = max(10, W - bx - len(rt) - 4)
        full = int(f * bw)
        self.put(g["bar"], 0, W, "  " + lt + "  " + ACC + "━" * full + ("●" if full < bw else "") + DIM + "─" * max(0, bw - full - 1)
                 + RST + "  " + rt)
        self.bar = (g["bar"], bx, bw)
        fl = self.skip_prompt() or clean(ud.get("flash")) or (self.note if time.time() < self.note_until else "")
        self.put(g["foot"], 0, W, self.foot_line(W, fl, lead=2))
        out.write("\033[H")
        out.flush()

    def put(self, row, col, w, s):
        s = fit(s, w)
        k = (row, col)
        if self.rows.get(k) != (w, s):
            self.rows[k] = (w, s)
            out.write(f"\033[{row + 1};{col + 1}H{s}")

    def blank_cover(self, g):
        c = g["cov"] or self.cov.get("area")
        if not c:
            return
        row, col, rows, cols = c.get("inner") or (c["row"], c["col"], c["rows"], c["cols"])
        if IN_KITTY:
            out.write(UNCOVER)
        for r in range(rows):
            out.write(f"\033[{row + r + 1};{col + 1}H" + " " * cols)
            self.rows.pop((row + r, col), None)
        self.cov["drawn"] = None

    def cover_key(self):
        return str((self.ud.get("now") or {}).get("path") or "")

    def want_cover(self, g):
        path = (self.ud.get("now") or {}).get("path") or ""
        c = g["cov"]
        cv = self.cov
        if not path and cv["key"]:
            if cv["drawn"]:
                self.blank_cover(g)
            cv.update(key=None, img=None, six=None, six_geo=None, pending=None)
        if not c or not path:
            return
        ck = self.cover_key()
        if cv["key"] != ck:
            if cv["drawn"]:
                self.blank_cover(g)
            cv.update(key=ck, img=None, six=None, six_geo=None, pending=None, busy=True)

            def job(p=path, k=ck):
                img = cover_file(p)
                if self.cov["key"] == k:
                    self.cov["img"] = img
                    self.cov["busy"] = False
                    self.wake()
            threading.Thread(target=job, daemon=True).start()
            return
        if cv["busy"] or not cv["img"]:
            return
        geo = (c.get("pw", c["px"]), c.get("ph", c["px"]), c["row"], c["col"])
        if cv["six_geo"] != geo:
            if cv["pending"] == geo:
                return
            cv["pending"] = geo

            def job2(img=cv["img"], key=ck, gg=geo):
                data = sixel(img, gg[0], gg[1])
                if self.cov["key"] == key and self.cov["pending"] == gg:
                    self.cov.update(six=data or b"", six_geo=gg, pending=None, drawn=None)
                    self.wake()
            threading.Thread(target=job2, daemon=True).start()
            return
        if cv["six"] and cv["drawn"] != geo:
            self.blank_cover(g)
            r0, c0 = c["row"], c["col"]
            size = png_size(cv["img"])
            if size and size[0] and size[1]:
                w, h = size
                bw, bh = c.get("pw", c["px"]), c.get("ph", c["px"])
                k = min(bw / w, bh / h)
                r0 += max(0, int((c["rows"] - h * k / c.get("ch", 16)) / 2))
                c0 += max(0, int((c["cols"] - w * k / c.get("cw", 8)) / 2))
            out.write(f"\033[{r0 + 1};{c0 + 1}H")
            out.flush()
            os.write(1, cv["six"])
            cv["drawn"] = geo
            cv["area"] = c

    def status_text(self):
        st = self.st
        vol = st.get("volume")
        if st.get("mute"):
            return "muted"
        if isinstance(vol, (int, float)) and int(round(vol)) != 100:
            return f"vol {int(round(vol))}%"
        return ""

    def foot_line(self, W, fl, lead=1):
        tags = self.tags()
        left = " " * lead + tags
        if not fl:
            return left
        room = W - vlen(left) - (3 if tags else 0) - 1
        if room < 8:
            return left
        m = fit(fl, room, pad=False)
        at = max(vlen(left) + (3 if tags else 0), (W - vlen(m)) // 2)
        return left + " " * (at - vlen(left)) + ACC + m

    def tags(self):
        eff = clean(self.ud.get("effect"))
        if not eff:
            return ""
        return "  ".join(f"{TAG} {e.strip()} {RST}" for e in eff.split("+") if e.strip())

    def centre(self, row, W, s, style=""):
        t = fit(s, W - 4, pad=False)
        pad = max(0, (W - vlen(t)) // 2)
        self.put(row, 0, W, " " * pad + style + t)

    def progress(self, row, W, x=0, bw=10, compact=False):
        st, now = self.st, self.ud.get("now") or {}
        dur, tp = st.get("duration"), self.tpos
        f = (tp / dur) if isinstance(tp, (int, float)) and isinstance(dur, (int, float)) and dur > 0 else 0
        f = max(0.0, min(1.0, f))
        lt, rt = f"{clock(tp)}  ", f"  {clock(dur)}"
        if compact:
            icon = "‖" if st.get("pause") else "▶"
            a, t = clean(now.get("artist")), clean(now.get("title"))
            pre = fit(f" {ACC}{icon}{RST}  {t}" + (f"{DIM}  ·  {a}" if a else ""), max(10, int(W * 0.45)), pad=False) + "    "
            bw = max(10, W - vlen(pre) - len(lt) - len(rt) - 1)
        else:
            pre = " " * max(0, x - len(lt))
        full = int(f * bw)
        bar = ACC + "━" * full + ("●" if full < bw else "") + DIM + "─" * max(0, bw - full - 1) + RST
        self.put(row, 0, W, pre + DIM + lt + RST + bar + DIM + rt)
        self.bar = (row, vlen(pre) + len(lt), bw)
        self.bar_span = (0, None)

    def render(self):
        g = self.layout()
        W, H, view = g["W"], g["H"], g["view"]
        key = (W, H, view, g["cov"]["rows"] if g["cov"] else 0, g.get("status"), g.get("panel"), g.get("vh"))
        if self.geo != key:
            self.geo = key
            self.full = True
        if self.full:
            out.write("\033[2J" + (UNCOVER if IN_KITTY else ""))
            self.rows = {}
            self.cov["drawn"] = None
            self.full = False
        size = {"w": W - 2, "h": g.get("h", H - 4), "hw": W - 2, "fw": W - 2}
        if size != self.size_sent:
            self.size_sent = size
            self.send("set_property", "user-data/music/size", size)
        ud = self.ud
        now = ud.get("now") or {}
        fl = self.skip_prompt() or clean(ud.get("flash")) or (self.note if time.time() < self.note_until else "")

        if view != "main":
            if self.cov.get("drawn"):
                self.blank_cover(g)
            lines = (ud.get("screen") or "").split("\n")
            for r in range(g["h"]):
                self.put(g["top"] + r, 1, W - 2, lines[r] if r < len(lines) else "")
            tags = self.tags()
            self.put(H - 3, 0, W, (" " * max(0, (W - vlen(fl)) // 2) + ACC + fl) if fl else "")
            self.progress(g["bar"], W, compact=True)
            self.put(g["foot"], 0, W, " " + tags)
            out.write("\033[H")
            out.flush()
            return

        if g.get("panel"):
            return self.render_panels(g)
        queue = [clean(x) for x in (ud.get("queue") or [])]
        pos = self.qpos()
        n = len(queue)
        self.cursor = max(0, min(self.cursor, n - 1)) if n else 0
        if g["cov"]:
            self.want_cover(g)
        a, t = clean(now.get("artist")), clean(now.get("title"))
        self.centre(g["title"], W, t or "nothing playing", BOLD)
        self.centre(g["artist"], W, a, DIM)
        if g["status"] is not None:
            self.centre(g["status"], W, self.status_text(), ACC)
        self.progress(g["bar"], W, g["bx"], g["bw"])
        self.draw_list(g, queue, pos)
        self.put(g["foot"], 0, W, self.foot_line(W, fl))
        out.write("\033[H")
        out.flush()

    def draw_list(self, g, queue, pos):
        W, n, rows = g["W"], len(queue), g["n"]
        lw = min(W - 4, max(30, g["bw"]))
        x0 = (W - lw) // 2
        browsing = time.time() < self.browse_until
        self.list_rows = []
        if not n:
            for r in range(rows):
                self.put(g["list"] + r, 0, W, (" " * x0 + DIM + "no chapters") if r == 0 else "")
            return
        if browsing:
            first = max(0, min(self.cursor - rows // 2, n - rows))
            idx = list(range(first, min(n, first + rows)))
        else:
            idx = [i for i in range(pos + 1, n)][:rows]
        lab = 6
        for r in range(rows):
            if r >= len(idx):
                self.put(g["list"] + r, 0, W, "")
                continue
            i = idx[r]
            label = ("next" if r == 0 and not browsing else "").ljust(lab)
            text = fit(queue[i], lw - lab, pad=False)[: -len(RST)]
            if browsing and i == self.cursor:
                line = " " * x0 + DIM + label + RST + SEL + " " + text + " " + RST
            elif i == pos:
                line = " " * x0 + DIM + label + RST + ACC + "▶ " + text
            elif browsing and i < pos:
                line = " " * x0 + DIM + label + text
            else:
                line = " " * x0 + DIM + label + RST + (text if r == 0 or browsing else DIM + text)
            self.put(g["list"] + r, 0, W, line)
            self.list_rows.append((g["list"] + r, i))

    def hold_size(self):
        if time.time() - getattr(self, "held", 0) < 0.5:
            return
        self.held = time.time()
        try:
            subprocess.Popen([self.bin, "--hold-size"], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError:
            pass

    def key(self, k):
        n = len(self.ud.get("queue") or [])
        view = self.ud.get("view") or "main"
        pos = max(0, self.qpos())
        if self.skip_edit is not None:
            self.skip_key(k)
            self.dirty = True
            return
        if k == "T" and view == "main":
            self.skip_edit = ""
            self.dirty = True
            return
        browse = k in ("UP", "C-k", "DOWN", "C-j", "PGUP", "PGDN", "HOME", "END", "g", "G")
        if browse and view == "main" and n:
            if time.time() >= self.browse_until:
                self.cursor = pos
            step = {"UP": -1, "C-k": -1, "DOWN": 1, "C-j": 1, "PGUP": -5, "PGDN": 5}.get(k)
            if step:
                self.cursor = max(0, min(n - 1, self.cursor + step))
            elif k in ("HOME", "g"):
                self.cursor = 0
            elif k in ("END", "G"):
                self.cursor = n - 1
            self.browse_until = time.time() + 6
            self.moved = time.time()
        elif k == "ENTER":
            if n and view == "main" and time.time() < self.browse_until:
                self.jump(self.cursor)
                self.browse_until = 0
        elif k == "q":
            if view != "main":
                self.send("script-message", "music-view", "main")
            else:
                self.back = True
            self.browse_until = 0
        elif k == "ESC":
            if view != "main":
                self.send("script-message", "music-view", "main")
            elif self.ud.get("skipmark"):
                self.send("script-message", "books-skip-cancel")
            elif time.time() >= self.browse_until:
                self.back = True
            self.browse_until = 0
        elif k.startswith("C-"):
            self.send("keypress", "Ctrl+" + k[2:])
        elif k:
            self.send("keypress", {" ": "SPACE", "#": "SHARP"}.get(k, k))
            self.poll()
        self.dirty = True

    def skip_key(self, k):
        if not self.skip_edit:
            if k in SKIP_PAIRS:
                self.skip_edit, self.skip_typed = SKIP_PAIRS[k], ""
            elif k in ("ESC", "ENTER", "T", "q"):
                self.skip_edit = None
            return
        t = self.skip_typed
        if len(k) == 1 and k.isdigit() and not t.endswith("m") and len(t) < 5:
            self.skip_typed += k
        elif k == "m" and t and not t.endswith("m"):
            self.skip_typed += k
        elif k == "BS":
            self.skip_typed = t[:-1]
        elif k == "ENTER":
            n = int(t.rstrip("m") or 0) * (60 if t.endswith("m") else 1)
            if n > 0:
                self.send("script-message", "music-skip-set", self.skip_edit, str(n))
            self.skip_edit = ""
        elif k == "ESC":
            self.skip_edit = ""

    def skip_prompt(self):
        if self.skip_edit is None:
            return ""
        sk = self.ud.get("skips") or {}
        if not self.skip_edit:
            now = "   ".join(f"{SKIP_NAMES[p]}  {secs(sk[p])}" for p in SKIP_NAMES if isinstance(sk.get(p), (int, float)))
            return f"Skips   {now}  ·  press one to change, esc: done"
        now = sk.get(self.skip_edit)
        was = f" (now {secs(now)})" if isinstance(now, (int, float)) else ""
        return f"{SKIP_NAMES[self.skip_edit]} skips{was}: seconds, or 5m  {self.skip_typed}▏  enter saves, esc back"

    def mouse(self, b, x, y, press):
        if not press:
            return
        view = self.ud.get("view") or "main"
        if b in (64, 65):
            if view == "main":
                self.key("UP" if b == 64 else "DOWN")
            return
        if b != 0:
            return
        row, col = y - 1, x - 1
        br = self.bar
        if br and row == br[0] and br[1] <= col < br[1] + br[2]:
            cs, span = getattr(self, "bar_span", (0, None))
            if span:
                self.send("seek", cs + (col - br[1]) / br[2] * span, "absolute")
            else:
                self.send("seek", (col - br[1]) / br[2] * 100, "absolute-percent")
            self.poll()
            return
        if view == "main":
            for r, i in getattr(self, "list_rows", []):
                if r == row:
                    self.jump(i)
                    self.browse_until = 0
                    self.dirty = True
                    return


SEQ = {"[A": "UP", "[B": "DOWN", "[C": "RIGHT", "[D": "LEFT", "[5~": "PGUP", "[6~": "PGDN", "[H": "HOME", "[F": "END",
       "[1~": "HOME", "[4~": "END", "OH": "HOME", "OF": "END", "OQ": "F2", "[12~": "F2", "[3~": "DEL",
       "OA": "UP", "OB": "DOWN", "OC": "RIGHT", "OD": "LEFT"}
SKIP_PAIRS = {"LEFT": "arrows", "RIGHT": "arrows", "h": "hl", "l": "hl", "j": "jk", "k": "jk"}
SKIP_NAMES = {"arrows": "← →", "hl": "h l", "jk": "j k"}
MOUSE = re.compile(r"\[<(\d+);(\d+);(\d+)([Mm])")
KITTY = re.compile(r"\[(\d+)(?:;(\d+))?u")
MODDED = re.compile(r"\[(\d+);(\d+)([A-Z~])")
KEYPAD = dict(zip(range(57399, 57427), list("0123456789./*-+") + ["ENTER", "=", ",", "LEFT", "RIGHT", "UP", "DOWN",
                                                                  "PGUP", "PGDN", "HOME", "END", "", "DEL"]))
CTRL = {"\x13": "s", "\x12": "r", "\x04": "d", "\x02": "b", "\x06": "f", "\x15": "u", "\x0f": "o", "\x03": "c", "\x0c": "l", "\x10": "p", "\x14": "t"}


def keys(data):
    s = data.decode("utf-8", "replace")
    i = 0
    while i < len(s):
        c = s[i]
        if c == "\033":
            rest = s[i + 1:]
            m = KITTY.match(rest)
            if m:
                code, mods = int(m.group(1)), (int(m.group(2) or 1) - 1) & ~(64 | 128)
                i += 1 + m.end()
                if code in KEYPAD and not mods & 6:
                    if KEYPAD[code]:
                        yield KEYPAD[code]
                elif code == 27 and not mods:
                    yield "ESC"
                elif code == 13 and not mods:
                    yield "ENTER"
                elif mods == 4 and 32 < code < 127:
                    yield "C-" + chr(code)
                elif not mods & 6 and 32 <= code < 0x110000:
                    yield chr(code)
                continue
            m = MOUSE.match(rest)
            if m:
                yield ("mouse", int(m.group(1)), int(m.group(2)), int(m.group(3)), m.group(4) == "M")
                i += 1 + m.end()
                continue
            m = MODDED.match(rest)
            if m:
                i += 1 + m.end()
                if not (int(m.group(2)) - 1) & ~(64 | 128):
                    name = SEQ.get("[" + (m.group(1) if m.group(3) == "~" else "") + m.group(3)) or SEQ.get("O" + m.group(3))
                    if name:
                        yield name
                continue
            for seq, name in SEQ.items():
                if rest.startswith(seq):
                    yield name
                    i += 1 + len(seq)
                    break
            else:
                if not rest:
                    yield "ESC"
                    i += 1
                elif rest[0] in "[O":
                    j = 1
                    while j < len(rest) and not rest[j].isalpha() and rest[j] != "~":
                        j += 1
                    i += 2 + j
                else:
                    i += 2
            continue
        i += 1
        if c in "\r":
            yield "ENTER"
        elif c == "\n":
            yield "C-j"
        elif c == "\x0b":
            yield "C-k"
        elif c in CTRL:
            yield "C-" + CTRL[c]
        elif c in "\x7f\x08":
            yield "BS"
        elif c.isprintable():
            yield c


def main():
    sock = None
    for _ in range(100):
        try:
            sock = socket.socket(socket.AF_UNIX)
            sock.connect(SOCK)
            break
        except OSError:
            sock = None
            if MPV_PID:
                try:
                    os.kill(MPV_PID, 0)
                except OSError:
                    return 1
            time.sleep(0.1)
    if not sock:
        print("The player didn't start.", file=sys.stderr)
        return 1
    ui = UI(sock)
    for i, p in enumerate(["pause", "volume", "mute", "duration", "user-data/music", "speed"], 1):
        ui.send("observe_property", i, p)
    ui.poll()

    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    sig_r, sig_w = os.pipe()
    os.set_blocking(sig_w, False)
    signal.set_wakeup_fd(sig_w)
    quit_flag = []
    signal.signal(signal.SIGWINCH, lambda *a: None)
    for s in (signal.SIGHUP, signal.SIGTERM):
        signal.signal(s, lambda *a: quit_flag.append(1))
    try:
        tty.setraw(fd)
        out.write("\033[?1049h\033[>1u\033[?25l\033[?7l\033[?1000h\033[?1006h\033[2J")
        out.flush()
        while not quit_flag and not ui.back:
            if ui.dirty:
                ui.dirty = False
                ui.render()
            playing = not ui.st.get("pause")
            wait = max(0.0, ui.last_poll + 0.5 - time.time()) if playing else None
            r, _, _ = select.select([sock, fd, sig_r, ui.wake_r], [], [], wait)
            if not r and playing:
                ui.poll()
            if sig_r in r:
                os.read(sig_r, 512)
                ui.dirty = True
                ui.hold_size()
            if ui.wake_r in r:
                os.read(ui.wake_r, 512)
                ui.dirty = True
            if fd in r:
                data = os.read(fd, 4096)
                if not data:
                    break
                for k in keys(data):
                    if isinstance(k, tuple):
                        ui.mouse(*k[1:])
                    else:
                        ui.key(k)
            if sock in r:
                try:
                    chunk = sock.recv(65536)
                except OSError:
                    chunk = b""
                if not chunk:
                    break
                ui.buf += chunk
                while b"\n" in ui.buf:
                    line, ui.buf = ui.buf.split(b"\n", 1)
                    ui.on_line(line)
    finally:
        if quit_flag:
            ui.send("quit")
        out.write((UNCOVER if IN_KITTY else "") + "\033[?1006l\033[?1000l\033[?7h\033[?25h\033[<u\033[?1049l")
        out.flush()
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
    return 10 if ui.back and not quit_flag else 0


if __name__ == "__main__":
    sys.exit(main())
