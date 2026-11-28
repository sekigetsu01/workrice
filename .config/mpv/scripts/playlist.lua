-- Tab: the playlist (the folder's videos, or a YouTube playlist) as a panel down the right; c: the video's chapters.
-- In the panel: Ctrl+j / Ctrl+k (or down / up) move, gg / G first / last, Enter plays, Tab / Esc hides.

local utils = require "mp.utils"

local HOME = os.getenv("HOME")
local STATE = (os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")) .. "/mpv"
local CACHE = (os.getenv("XDG_CACHE_HOME") or (HOME .. "/.cache"))
local FILE = STATE .. "/watched.json"
local OPEN_FILE = STATE .. "/playlist-open"
-- thumbnail size
local TW, TH = 320, 180
local THUMBS = CACHE .. "/mpv/thumbs/" .. TW .. "x" .. TH
local WAL = CACHE .. "/wal/colors.json"
-- watched: this close to the end (or past this share of it); kept for later: past this many seconds in
local END_SECONDS, END_SHARE, KEEP_AFTER = 20, 0.95, 10
local GG_SECONDS = 0.5

local function load()
    local f = io.open(FILE)
    if not f then return {} end
    local data = utils.parse_json(f:read("*a") or "")
    f:close()
    return type(data) == "table" and data or {}
end

local function save(data)
    utils.subprocess({ args = { "mkdir", "-p", STATE }, playback_only = false })
    local tmp = FILE .. ".new"
    local f = io.open(tmp, "w")
    if not f then return end
    f:write(utils.format_json(data))
    f:close()
    os.rename(tmp, FILE)
end

local function full(cwd, f)
    if f:find("://") then return f end
    return mp.command_native({ "normalize-path", utils.join_path(cwd, f) }) or utils.join_path(cwd, f)
end

local function local_video()
    local path = mp.get_property("path")
    if not path or path:find("://") then return nil end
    local v = mp.get_property_native("current-tracks/video")
    if not v or v.albumart or v.image then return nil end
    return full(mp.get_property("working-directory") or "", path)
end

mp.add_hook("on_unload", 50, function()
    local path = local_video()
    if not path then return end
    local pos, dur = mp.get_property_number("time-pos"), mp.get_property_number("duration")
    if not pos or not dur or dur <= 0 then return end
    local data = load()
    local done = pos >= dur * END_SHARE or (dur > 6 * END_SECONDS and pos >= dur - END_SECONDS) or mp.get_property_bool("eof-reached")
    if done then
        data[path] = { done = true, dur = dur }
        mp.command("delete-watch-later-config")
    elseif pos > KEEP_AFTER then
        data[path] = { done = data[path] and data[path].done or false, pos = pos, dur = dur }
        mp.command("write-watch-later-config")
    else
        return
    end
    save(data)
end)

local view = nil
do
    local f = io.open(OPEN_FILE)
    if f then
        local s = f:read("*l")
        f:close()
        view = (s == "1" and "playlist") or (s == "chapters" and "chapters") or nil
    end
end

local function count()
    if view == "chapters" then return mp.get_property_number("chapters", 0) or 0 end
    return mp.get_property_number("playlist-count", 0) or 0
end

local function current_index()
    if view == "chapters" then return (mp.get_property_number("chapter", -1) or -1) + 1 end
    return (mp.get_property_number("playlist-pos", 0) or 0) + 1
end
local scroll, cursor, hover = 0, nil, nil
local follow = true
local rows = {}
local slots = {}
local osd = mp.create_osd_overlay("ass-events")
local shown = false
local render

local colors, colors_mtime = {}, nil
local function wal()
    local info = utils.file_info(WAL)
    if info and info.mtime ~= colors_mtime then
        colors_mtime = info.mtime
        local f = io.open(WAL)
        local j = f and utils.parse_json(f:read("*a") or "")
        if f then f:close() end
        if type(j) == "table" and j.colors then
            for k, v in pairs(j.colors) do colors[k] = v end
        end
    end
    local function ass(hex)
        local r, g, b = (hex or "#ffffff"):match("#(%x%x)(%x%x)(%x%x)")
        return "&H" .. b .. g .. r .. "&"
    end
    return {
        bg = ass(colors.color0 or "#18180a"),
        pick = ass(colors.color8 or "#6d6d59"),
        accent = ass(colors.color4 or "#ac544f"),
        text = ass(colors.color7 or "#c5c5c1"),
        dim = ass(colors.color8 or "#6d6d59"),
    }
end

local watched, watched_mtime = {}, nil
local function watched_data()
    local info = utils.file_info(FILE)
    local m = info and info.mtime or 0
    if m ~= watched_mtime then watched, watched_mtime = load(), m end
    return watched
end

local function hash(s)
    local a, b = 5381, 0
    for i = 1, #s do
        local c = s:byte(i)
        a, b = (a * 33 + c) % 4294967296, (b * 65599 + c) % 4294967296
    end
    return string.format("%08x%08x", a, b)
end

local function youtube_id(url)
    if not url:find("youtu") then return nil end
    return url:match("[?&]v=([%w_-]+)") or url:match("youtu%.be/([%w_-]+)") or url:match("/shorts/([%w_-]+)")
end

local function clock(s)
    s = math.floor(s + 0.5)
    local h, m = math.floor(s / 3600), math.floor(s % 3600 / 60)
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s % 60) end
    return string.format("%d:%02d", m, s % 60)
end

local ytmeta, ytasked = {}, {}
local function yt_playlist(url)
    if ytmeta[url] or ytasked[url] then return ytmeta[url] end
    ytasked[url] = true
    mp.command_native_async({
        name = "subprocess", playback_only = false, capture_stdout = true, capture_stderr = true,
        args = { "yt-dlp", "--ignore-config", "--no-warnings", "--flat-playlist", "-J", "--", url },
    }, function(_, res)
        local j = res and res.status == 0 and utils.parse_json(res.stdout or "")
        if type(j) ~= "table" then return end
        local m = { title = j.title, channel = j.channel or j.uploader, videos = {} }
        for _, e in ipairs(j.entries or {}) do
            if e.id then m.videos[e.id] = { dur = tonumber(e.duration), channel = e.channel or e.uploader } end
        end
        ytmeta[url] = m
        render()
    end)
    return nil
end

local function thumb_for(path, ytdur)
    local yt = youtube_id(path)
    if yt then
        return THUMBS .. "/yt-" .. yt .. (ytdur and ("-" .. math.floor(ytdur)) or "") .. ".bgra",
            "https://i.ytimg.com/vi/" .. yt .. "/mqdefault.jpg", ytdur and clock(ytdur) or ""
    end
    if path:find("://") then return nil end
    local info = utils.file_info(path)
    if not info or not info.is_file then return nil end
    return THUMBS .. "/" .. hash(path .. info.size .. info.mtime) .. ".bgra", path, nil
end

local queue, queued, failed, busy = {}, {}, {}, false
local function next_thumb()
    if busy or #queue == 0 then return end
    local job = table.remove(queue, 1)
    busy = true
    local fs = math.floor(TH * 0.16)
    local script = [[
        mkdir -p "$(dirname "$2")"
        len=$4 t=${5:-0}
        case $1 in
            http*) ;;
            *) [ -z "$5" ] && {
               d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$1")
               printf '%s\n' "$d" > "$2.dur"
               t=$(awk "BEGIN { print ${d:-0} * 0.25 }")
               len=$(awk "BEGIN { s = int(${d:-0} + 0.5); h = int(s / 3600); m = int(s % 3600 / 60)
                   if (s <= 0) exit; if (h) printf \"%d:%02d:%02d\", h, m, s % 60; else printf \"%d:%02d\", m, s % 60 }"); } ;;
        esac
        vf="scale=]] .. TW .. ":" .. TH .. ":force_original_aspect_ratio=increase,crop=" .. TW .. ":" .. TH .. [["
        if [ -n "$len" ]; then
            printf '%s' "$len" > "$2.txt"
            vf="$vf,drawtext=textfile=$2.txt:font=JetBrains Mono\\\\:style=Bold:fontsize=]] .. fs .. [[:fontcolor=white:box=1:boxcolor=black@0.8:boxborderw=]] .. math.floor(fs * 0.2) .. "|" .. math.floor(fs * 0.35) .. [[:x=w-tw-]] .. math.floor(fs * 0.6) .. [[:y=h-th-]] .. math.floor(fs * 0.45) .. [["
        fi
        ffmpeg -nostdin -v error -ss "$t" -i "$1" -frames:v 1 -vf "$vf" -f rawvideo -pix_fmt bgra -y "$2.part"
        rm -f "$2.txt"
        [ "$(stat -c %s "$2.part" 2>/dev/null)" = "$3" ] && mv "$2.part" "$2" || { rm -f "$2.part"; exit 1; }
    ]]
    mp.command_native_async({
        name = "subprocess", playback_only = false, capture_stdout = true, capture_stderr = true,
        args = { "sh", "-c", script, "sh", job.src, job.out, tostring(TW * TH * 4), job.len or "", job.at or "" },
    }, function(_, res)
        busy = false
        queued[job.out] = nil
        if not res or res.status ~= 0 then failed[job.out] = true end
        render()
        next_thumb()
    end)
end

local function want_thumb(out, src, len, at)
    if queued[out] or failed[out] then return end
    queued[out] = true
    queue[#queue + 1] = { out = out, src = src, len = len, at = at }
    next_thumb()
end

local function chapter_thumb(path, start, len)
    if path:find("://") then return nil end
    local info = utils.file_info(path)
    if not info or not info.is_file then return nil end
    local at = start + math.min(3, len * 0.2)
    return THUMBS .. "/" .. hash(path .. info.size .. info.mtime .. "@" .. string.format("%.3f", start)) .. ".bgra",
        path, clock(len), string.format("%.3f", at)
end

local function esc(s)
    return (s:gsub("\\", "\\\239\187\191"):gsub("{", "\\{"):gsub("}", "\\}"))
end

local function chars(s)
    local t = {}
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do t[#t + 1] = ch end
    return t
end

local function cut(s, n)
    local t = chars(s)
    if #t <= n then return s end
    return table.concat(t, "", 1, math.max(n - 1, 0)) .. "…"
end

local function wrap(s, n)
    local t = chars(s)
    if #t <= n then return { s } end
    local brk = n
    for i = n + 1, math.floor(n * 0.5), -1 do
        if t[i] == " " then brk = i - 1; break end
    end
    local first = table.concat(t, "", 1, brk)
    local rest = table.concat(t, "", brk + 1):gsub("^%s+", "")
    return { first, cut(rest, n) }
end

local function rect(x, y, w, h, color, alpha)
    if w <= 0 or h <= 0 then return "" end
    return string.format("{\\an7\\pos(0,0)\\bord0\\shad0\\1c%s\\1a&H%02X&\\p1}m %d %d l %d %d l %d %d l %d %d{\\p0}",
        color, alpha, x, y, x + w, y, x + w, y + h, x, y + h)
end

local function text(x, y, an, size, bold, color, alpha, clip, s)
    return string.format("{\\an%d\\pos(%d,%d)\\fs%d\\b%d\\q2\\bord0\\shad0\\1c%s\\1a&H%02X&%s}%s",
        an, x, y, size, bold and 1 or 0, color, alpha or 0,
        clip and string.format("\\clip(%d,%d,%d,%d)", clip[1], clip[2], clip[3], clip[4]) or "", s)
end

local function title_of(e)
    if e.title then return e.title end
    local _, name = utils.split_path(e.filename)
    return (name:gsub("%.[%w]+$", ""))
end

local function play(i)
    hover = nil
    if view == "chapters" then
        mp.set_property_number("chapter", i - 1)
    elseif i ~= (mp.get_property_number("playlist-pos", 0) or 0) + 1 then
        mp.set_property_number("playlist-pos", i - 1)
    end
end

local function choose(i)
    cursor, follow = math.max(1, math.min(count(), i)), true
    render()
end

local function move(by)
    choose((cursor or math.max(1, current_index())) + by)
end

local function set_view(v)
    if v ~= view then
        cursor, hover, follow = nil, nil, true
        view = v
        if v then scroll = math.max(0, current_index() - 2) end
    end
    utils.subprocess({ args = { "mkdir", "-p", STATE }, playback_only = false })
    local f = io.open(OPEN_FILE, "w")
    if f then f:write(view == "playlist" and "1\n" or view == "chapters" and "chapters\n" or "0\n"); f:close() end
    render()
end

local function row_at(mx, my)
    for _, r in ipairs(rows) do
        if mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h then return r.i end
    end
end

local function wheel(by)
    scroll, follow = scroll + by, false
    local mpos = mp.get_property_native("mouse-pos")
    hover = mpos and row_at(mpos.x, mpos.y)
    render()
end

mp.set_key_bindings({
    { "MBTN_LEFT", function()
        local mpos = mp.get_property_native("mouse-pos")
        local i = mpos and row_at(mpos.x, mpos.y)
        if i then cursor = i; play(i) end
    end, function() end },
    { "MBTN_LEFT_DBL", function() end },
    { "WHEEL_UP", function() wheel(-1) end },
    { "WHEEL_DOWN", function() wheel(1) end },
}, "playlist-panel", "force")

local function on_mouse(_, mpos)
    local i = mpos and mpos.hover and row_at(mpos.x, mpos.y) or nil
    if i ~= hover then hover = i; render() end
end

local last_g = 0
local KEYS = {
    { "Ctrl+j", function() move(1) end, true },
    { "Ctrl+k", function() move(-1) end, true },
    { "DOWN", function() move(1) end, true },
    { "UP", function() move(-1) end, true },
    { "g", function()
        local now = mp.get_time()
        if now - last_g <= GG_SECONDS then last_g = 0; choose(1) else last_g = now end
    end },
    { "G", function() choose(count()) end },
    { "ENTER", function() if cursor then play(cursor) end end },
    { "KP_ENTER", function() if cursor then play(cursor) end end },
    { "ESC", function() set_view(nil) end },
}

local ticker = mp.add_periodic_timer(1, function() render() end)
ticker:kill()

local function set_shown(v)
    if v == shown then return end
    shown = v
    if v then
        for n, k in ipairs(KEYS) do
            mp.add_forced_key_binding(k[1], "playlist-key-" .. n, k[2], { repeatable = k[3] or false })
        end
        mp.enable_key_bindings("playlist-panel", "allow-hide-cursor+allow-vo-dragging")
        mp.observe_property("mouse-pos", "native", on_mouse)
        ticker:resume()
    else
        for n in ipairs(KEYS) do mp.remove_key_binding("playlist-key-" .. n) end
        mp.disable_key_bindings("playlist-panel")
        mp.unobserve_property(on_mouse)
        ticker:kill()
        last_g = 0
    end
end

local margin_set = nil
local function set_margin(r)
    if r == margin_set then return end
    margin_set = r
    mp.set_property_number("video-margin-ratio-right", r or 0)
end

local function clear()
    if margin_set then set_margin(nil) end
    osd:remove()
    for id in pairs(slots) do mp.command_native({ "overlay-remove", id }) end
    slots, rows = {}, {}
    mp.set_mouse_area(0, 0, 0, 0, "playlist-panel")
    set_shown(false)
end

local function showing_video()
    local v = mp.get_property_native("current-tracks/video")
    return v and not v.albumart and not v.image
end

local function folder_name(e, cwd)
    local dir = utils.split_path(full(cwd, e.filename))
    dir = dir:gsub("/+$", "")
    return dir:match("([^/]+)$") or dir
end

local function playlist_item(list, i, cwd, data, yt)
    local e = list[i]
    local path = full(cwd, e.filename)
    local d = data[path]
    local playing = e.current or e.playing
    local done = d and d.done and not playing
    local ytid = youtube_id(path)
    local ytv = yt and ytid and yt.videos[ytid]
    local share
    if playing then
        local pos, dur = mp.get_property_number("time-pos"), mp.get_property_number("duration")
        if pos and dur and dur > 0 then share = pos / dur end
    elseif done then
        share = 1
    elseif d and d.pos and d.dur and d.dur > 0 then
        share = d.pos / d.dur
    end
    local info
    if ytv and ytv.channel then
        info = ytv.channel
    elseif done then
        info = "Watched"
    elseif d and d.pos and d.dur and d.dur > d.pos then
        info = clock(d.dur - d.pos) .. " left"
    end
    local out, src, len = thumb_for(path, ytv and ytv.dur)
    return {
        playing = playing, done = done, share = share, title = title_of(e), info = info,
        out = out, src = src, len = len,
        need_dur = out and not src:find("://") and not utils.file_info(out .. ".dur"),
    }
end

local function chapter_item(list, i, current, path)
    local ch = list[i]
    local start = ch.time or 0
    local dur = mp.get_property_number("duration")
    local stop = (list[i + 1] and list[i + 1].time) or dur or start
    local len = math.max(0, stop - start)
    local playing = i == current
    local done = i < current
    local share
    if playing then
        local pos = mp.get_property_number("time-pos")
        if pos and len > 0 then share = math.max(0, math.min(1, (pos - start) / len)) end
    elseif done then
        share = 1
    end
    local title = ch.title
    if not title or title == "" then title = "Chapter " .. i end
    local out, src, lenstr, at = chapter_thumb(path, start, len)
    return {
        playing = playing, done = done, share = share, title = title,
        info = clock(start) .. " · " .. clock(len) .. " long",
        out = out, src = src, len = lenstr, at = at,
    }
end

render = function()
    local W, H = mp.get_property_number("osd-width", 0), mp.get_property_number("osd-height", 0)
    local chaps = view == "chapters"
    local list = mp.get_property_native(chaps and "chapter-list" or "playlist") or {}
    if not view or #list < (chaps and 1 or 2) or W <= 0 or H <= 0 or not showing_video() then return clear() end
    set_shown(true)

    local c = wal()
    local data, cwd = watched_data(), mp.get_property("working-directory") or ""
    local current = current_index()
    local head, sub, yt, path
    if chaps then
        path = full(cwd, mp.get_property("path") or "")
        head = mp.get_property("media-title") or "Chapters"
        sub = "Chapters · " .. (current > 0 and current or "–") .. " / " .. #list
    else
        local ce = list[current] or list[1]
        local ytpl = ce["playlist-path"] and ce["playlist-path"]:find("://") and ce["playlist-path"]
        yt = ytpl and yt_playlist(ytpl)
        head = (yt and yt.title) or (ytpl and "YouTube playlist") or folder_name(ce, cwd)
        sub = ((yt and yt.channel) and (yt.channel .. " · ") or "") .. current .. " / " .. #list
    end

    local fs = math.max(11, math.floor(H * 0.019 + 0.5))
    local cw = fs * 0.5
    local m = math.floor(W * 0.012)
    local pw = math.min(W - 2 * m, math.max(fs * 24, math.floor(W * 0.3)))
    local x, y0 = W - m - pw, m
    local ph = H - y0 - math.max(m, math.floor(H * 0.08))
    set_margin(math.floor((pw + 2 * m) / W * 1000 + 0.5) / 1000)
    local line = math.max(2, math.floor(fs / 7))

    local hpad = math.floor(fs * 0.9)
    local tfs = math.floor(fs * 1.3)
    local hh = hpad + math.floor(tfs * 1.25) + math.floor(fs * 1.1) + hpad
    local ass = { rect(x, y0, pw, ph, c.bg, 0x08) }
    ass[#ass + 1] = text(x + hpad, y0 + hpad, 7, tfs, true, c.text, 0, nil,
        esc(cut(head, math.floor((pw - 2 * hpad) / (tfs * 0.6)))))
    ass[#ass + 1] = text(x + hpad, y0 + hpad + math.floor(tfs * 1.25), 7, math.floor(fs * 0.9), false, c.text, 0x60,
        nil, esc(sub))
    ass[#ass + 1] = rect(x, y0 + hh - 1, pw, 1, c.dim, 0x80)

    local ly0 = y0 + hh
    local lh = ph - hh
    local rh = math.floor(fs * 4.6)
    local pad = math.floor(fs * 0.4)
    local th = rh - 2 * pad - line
    local tw = math.floor(th * 16 / 9)
    local numw = math.floor(fs * 2.2)
    local thx = x + numw
    local tx = thx + tw + math.floor(fs * 0.7)
    local textw = x + pw - math.floor(fs * 0.9) - tx
    local n = math.min(#list, math.max(1, math.floor(lh / rh)))

    if cursor then cursor = math.max(1, math.min(cursor, #list)) end
    local focus = cursor or math.max(1, current)
    scroll = math.max(0, math.min(scroll, #list - n))
    if follow and focus <= scroll then scroll = focus - 1 elseif follow and focus > scroll + n then scroll = focus - n end

    if #list > n then
        local sh = math.max(line * 3, math.floor(lh * n / #list))
        local sy = ly0 + math.floor((lh - sh) * scroll / (#list - n))
        ass[#ass + 1] = rect(x + pw - line - 2, sy, line, sh, c.dim, 0x20)
    end
    rows = {}
    local used = {}
    for k = 1, n do
        local i = scroll + k
        local y = ly0 + (k - 1) * rh
        rows[k] = { x = x, y = y, w = pw, h = rh, i = i }
        local it = chaps and chapter_item(list, i, current, path) or playlist_item(list, i, cwd, data, yt)
        local playing, done = it.playing, it.done

        if cursor and i == cursor then
            ass[#ass + 1] = rect(x, y, pw, rh, c.pick, 0x38)
        elseif i == hover then
            ass[#ass + 1] = rect(x, y, pw, rh, c.pick, 0xA0)
        elseif playing then
            ass[#ass + 1] = rect(x, y, pw, rh, c.pick, 0x70)
        end
        ass[#ass + 1] = text(x + math.floor(numw / 2), y + math.floor(rh / 2), 5,
            playing and fs or math.floor(fs * 0.85), false, playing and c.accent or c.text, playing and 0 or 0x60, nil,
            playing and "▶" or tostring(i))
        ass[#ass + 1] = rect(thx, y + pad, tw, th, c.bg, 0x20)

        if it.share then
            local by = y + pad + th
            ass[#ass + 1] = rect(thx, by, tw, line, c.dim, 0x60)
            ass[#ass + 1] = rect(thx, by, math.floor(tw * math.min(it.share, 1)), line, c.accent, done and 0x50 or 0)
        end

        local lines = wrap(it.title, math.max(4, math.floor(textw / cw)))
        local lh1 = math.floor(fs * 1.25)
        local info = it.info
        local block = #lines * lh1 + (info and math.floor(fs * 1.15) or 0)
        local ty = y + math.floor((rh - block) / 2)
        local clip = { tx, y, tx + textw, y + rh }
        for li, s in ipairs(lines) do
            ass[#ass + 1] = text(tx, ty + (li - 1) * lh1, 7, fs, playing, c.text, (done and i ~= cursor) and 0x60 or 0,
                clip, esc(s))
        end
        if info then
            ass[#ass + 1] = text(tx, ty + #lines * lh1 + math.floor(fs * 0.1), 7, math.floor(fs * 0.85), false, c.text,
                0x70, clip, esc(cut(info, math.floor(textw / (cw * 0.85)))))
        end

        local out = it.out
        local id = k - 1
        if out and utils.file_info(out) and not it.need_dur then
            local key = table.concat({ out, thx, y + pad, tw, th }, "|")
            if slots[id] ~= key then
                mp.command_native({ name = "overlay-add", id = id, x = thx, y = y + pad, file = out, offset = 0,
                    fmt = "bgra", w = TW, h = TH, stride = TW * 4, dw = tw, dh = th })
                slots[id] = key
            end
            used[id] = true
        elseif out then
            want_thumb(out, it.src, it.len, it.at)
        end
    end
    for id in pairs(slots) do
        if not used[id] then
            mp.command_native({ "overlay-remove", id })
            slots[id] = nil
        end
    end

    osd.res_x, osd.res_y, osd.z = W, H, 10
    osd.data = table.concat(ass, "\n")
    osd:update()
    mp.set_mouse_area(x, y0, x + pw, y0 + ph, "playlist-panel")
end

mp.add_key_binding("TAB", "playlist", function()
    if view ~= "playlist" and mp.get_property_number("playlist-count", 0) < 2 then mp.osd_message("Nothing else in the playlist") end
    set_view(view ~= "playlist" and "playlist" or nil)
end)
mp.add_key_binding("c", "chapters", function()
    if (mp.get_property_number("chapters", 0) or 0) < 1 then return mp.osd_message("No chapters") end
    if view == "chapters" then return set_view(nil) end
    set_view("chapters")
end)

mp.register_event("file-loaded", function()
    cursor, follow = math.max(1, current_index()), true
    scroll = math.max(0, cursor - 2)
    render()
end)
mp.observe_property("chapter", "number", function()
    if view == "chapters" then cursor, follow = math.max(1, current_index()), true end
    render()
end)
for _, prop in ipairs({ "osd-dimensions", "playlist-count", "chapter-list", "current-tracks/video" }) do
    mp.observe_property(prop, "native", function() render() end)
end

render()
