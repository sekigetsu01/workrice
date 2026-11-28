-- Books' mpv script: opens a book at its saved place, saves it as it plays, and does chapters, speed, marks and
-- skips (books/input.conf binds the keys; the books script sends it books-* messages)
local mp = require "mp"
local utils = require "mp.utils"
local fmt = string.format

local HOME = os.getenv("HOME") or ""
local state = os.getenv("BOOKS_STATE") or ((os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")) .. "/books")
local bin = os.getenv("BOOKS_BIN") or "books"

local book = nil
local chapters = {}
local marks = {}
local pending = nil
local flash_msg, flash_timer = nil, nil
local help_on, screen_w, screen_h = false, 80, 40
local last_saved = 0
local loaded = nil
local skips = {}
local mark_from = nil
local skip_prev, landed = nil, nil
local skipping = false
local old_speed = nil


local function clock(t)
    if not t or t < 0 then return "--:--" end
    t = math.floor(t)
    local h, m, s = math.floor(t / 3600), math.floor(t / 60) % 60, t % 60
    if h > 0 then return fmt("%d:%02d:%02d", h, m, s) end
    return fmt("%d:%02d", m, s)
end

local function multi() return book and #book.parts > 1 end

local function part_index()
    return math.max(0, mp.get_property_number("playlist-pos", 0))
end

local function before(part)
    local t = 0
    if book then for i = 1, part do t = t + (book.parts[i] and book.parts[i].dur or 0) end end
    return t
end

local function book_pos()
    local tp = mp.get_property_number("time-pos")
    if not tp or not book then return nil end
    return before(part_index()) + tp
end

local function chapter_index()
    if multi() then return part_index() end
    local c = mp.get_property_number("chapter", 0) or 0
    return math.max(0, math.min(#chapters - 1, c))
end

local function publish()
    local q, qd = {}, {}
    for i, c in ipairs(chapters) do
        q[i] = clock(multi() and before(i - 1) or c.start) .. " - " .. c.name
        qd[i] = c.len or 0
    end
    local ci = chapter_index()
    local c = chapters[ci + 1]
    local cbar = c and (multi() and { 0, c.len } or { c.start, c.start + (c.len or 0) }) or nil
    local ml = {}
    for i, m in ipairs(marks) do
        ml[i] = clock(before(m.part) + m.sec) .. "\t" .. (m.label or "")
    end
    local sp = mp.get_property_number("speed", 1)
    mp.set_property_native("user-data/music/queue", q)
    mp.set_property_native("user-data/music/qdur", qd)
    mp.set_property_native("user-data/music/qpos", ci)
    mp.set_property_native("user-data/music/cbar", cbar or {})
    mp.set_property_native("user-data/music/marks", ml)
    mp.set_property_native("user-data/music/book", { pos = book_pos() or 0, dur = book and book.dur or 0 })
    mp.set_property_native("user-data/music/effect", math.abs(sp - 1) > 0.001 and fmt("%.2f×", sp) or "")
    if book then
        mp.set_property_native("user-data/music/now", { artist = book.author or "", title = book.title or "", album = book.voice or "",
            path = book.key })
    end
end

local SKIP = { arrows = 10, hl = 30, jk = 300 }
local function secs(n)
    if n < 120 then return n .. " s" end
    local m = math.floor(n / 60)
    return n % 60 == 0 and (m .. " min") or fmt("%d min %d s", m, n % 60)
end

local function render_help()
    local rows = {
        { "Listening", "" }, { "space", "play / pause" }, { "←  →", "back / on " .. secs(SKIP.arrows) }, { "h  l", "back / on " .. secs(SKIP.hl) },
        { "j  k", "back / on " .. secs(SKIP.jk) }, { "T", "how far those skip" }, { "N n, K J", "previous / next chapter" }, { "[  ]", "slower / faster (5%, same voice)" },
        { "{  }", "slower / faster (25%)" }, { "backspace", "normal speed" }, { "-  =  m", "volume down / up / mute" },
        { "", "" }, { "Bookmarks", "" }, { "b", "bookmark this spot" }, { "1 … 9", "go to bookmark 1 … 9" },
        { "B", "all bookmarks: enter goes, d deletes" },
        { "", "" }, { "Skipping", "" }, { "t … t", "skip from here to there from now on" }, { "esc", "forget the t you just pressed" },
        { "S", "all skips: enter goes, d deletes" },
        { "", "" }, { "Book", "" }, { "↑ ↓  enter", "pick a chapter and go to it (or click it)" },
        { "e", "rename the book" }, { "q  esc", "back to your books" }, { "Super+q", "close the player" },
        { "?", "close this help" },
    }
    local function width(s)
        local w = 0
        for _ in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do w = w + 1 end
        return w
    end
    local function line(r)
        if r[1] == "" then return "", 0 end
        if r[2] == "" then return "\27[1;34m" .. r[1] .. "\27[0m", width(r[1]) end
        local w = math.max(12, width(r[1]) + 1)
        return "\27[1m" .. r[1] .. string.rep(" ", w - width(r[1])) .. "\27[0m\27[90m" .. r[2] .. "\27[0m", w + width(r[2])
    end
    local out = { "" }
    local split = 1
    while rows[split] and rows[split][1] ~= "Bookmarks" do split = split + 1 end
    if #rows + 1 > screen_h and screen_w >= 110 and rows[split] then
        local lw = 0
        for i = 1, split - 1 do lw = math.max(lw, select(2, line(rows[i]))) end
        local pad = string.rep(" ", math.max(1, math.floor((screen_w - lw - 4 - 52) / 2)))
        for i = 1, math.max(split - 1, #rows - split + 1) do
            local l, w = "", 0
            if i < split then l, w = line(rows[i]) end
            out[#out + 1] = pad .. l .. string.rep(" ", lw + 4 - w) .. (rows[split + i - 1] and line(rows[split + i - 1]) or "")
        end
    else
        local pad = string.rep(" ", math.max(1, math.floor((screen_w - 52) / 2)))
        for _, r in ipairs(rows) do out[#out + 1] = pad .. line(r) end
    end
    mp.set_property_native("user-data/music/screen", table.concat(out, "\n"))
    mp.set_property_native("user-data/music/view", help_on and "help" or "main")
end

local function flash(m)
    flash_msg = m
    mp.set_property_native("user-data/music/flash", m)
    if flash_timer then flash_timer:kill() end
    flash_timer = mp.add_timeout(4, function()
        flash_msg = nil
        mp.set_property_native("user-data/music/flash", "")
    end)
end

local function read_tsv(file)
    local rows = {}
    local f = io.open(file, "r")
    if not f then return rows end
    for l in f:lines() do
        local r = {}
        for x in (l .. "\t"):gmatch("([^\t]*)\t") do r[#r + 1] = x end
        rows[#rows + 1] = r
    end
    f:close()
    return rows
end

local function write_tsv(file, rows)
    local tmp = file .. "." .. utils.getpid() .. ".tmp"
    local f = io.open(tmp, "w")
    if not f then return end
    for _, r in ipairs(rows) do f:write(table.concat(r, "\t"), "\n") end
    f:close()
    os.rename(tmp, file)
end

local function save_pos(force)
    if not book or not loaded or loaded.key ~= book.key then return end
    local part = loaded.part
    local tp = mp.get_property_number("time-pos")
    if not tp then return end
    local now = os.time()
    if not force and now - last_saved < 5 then return end
    last_saved = now
    local rows, out = read_tsv(state .. "/pos.tsv"), {}
    for _, r in ipairs(rows) do if r[1] ~= book.key then out[#out + 1] = r end end
    out[#out + 1] = { book.key, tostring(part), fmt("%.1f", tp), fmt("%.1f", before(part) + tp), fmt("%.1f", book.dur or 0), tostring(now),
                      fmt("%.2f", mp.get_property_number("speed", 1)) }
    write_tsv(state .. "/pos.tsv", out)
end

local function book_speed(key)
    for _, r in ipairs(read_tsv(state .. "/pos.tsv")) do
        if r[1] == key then return tonumber(r[7]) or old_speed or 1 end
    end
    return 1
end

local function load_marks()
    marks = {}
    if not book then return end
    for _, r in ipairs(read_tsv(state .. "/marks.tsv")) do
        if r[1] == book.key then marks[#marks + 1] = { part = tonumber(r[2]) or 0, sec = tonumber(r[3]) or 0, label = r[4] or "" } end
    end
    table.sort(marks, function(a, b) return before(a.part) + a.sec < before(b.part) + b.sec end)
end

local function load_skips()
    skips = {}
    if not book then return end
    for _, r in ipairs(read_tsv(state .. "/skips.tsv")) do
        local a, b = tonumber(r[3]), tonumber(r[4])
        if r[1] == book.key and a and b and b > a then skips[#skips + 1] = { part = tonumber(r[2]) or 0, a = a, b = b } end
    end
end

local function set_marking(m)
    mark_from = m
    mp.set_property("keep-open", m and "always" or "no")
    mp.set_property_native("user-data/music/skipmark", m ~= nil)
end

local function go_to(part, sec)
    if multi() and part ~= part_index() then
        pending = { part = part, sec = sec }
        mp.set_property_number("playlist-pos", part)
    else
        mp.commandv("seek", tostring(sec), "absolute")
    end
    mp.set_property_bool("pause", false)
end

local function load_chapters()
    chapters = {}
    if not book then return end
    if multi() then
        for i, p in ipairs(book.parts) do chapters[i] = { name = p.name or ("Part " .. i), start = 0, len = p.dur or 0 } end
        return
    end
    local dur = mp.get_property_number("duration") or book.dur or 0
    local list = mp.get_property_native("chapter-list") or {}
    for i, c in ipairs(list) do
        local nxt = list[i + 1] and list[i + 1].time or dur
        local st = math.max(0, c.time or 0)
        chapters[i] = { name = (c.title and c.title ~= "") and c.title or ("Chapter " .. i), start = st, len = math.max(0, nxt - st) }
    end
    if #chapters == 0 then chapters[1] = { name = "The whole book", start = 0, len = dur } end
end

local function set_chapter(i)
    if (mp.get_property_number("chapters", 0) or 0) > 0 then return mp.set_property_number("chapter", i) end
    mp.commandv("seek", tostring(chapters[i + 1] and chapters[i + 1].start or 0), "absolute")
end

mp.register_script_message("books-open", function(file, how)
    local f = io.open(file, "r")
    if not f then return end
    local b = utils.parse_json(f:read("*a") or "")
    f:close()
    if type(b) ~= "table" or type(b.parts) ~= "table" or #b.parts == 0 then return end
    save_pos(true)
    book = { key = b.key, title = b.title, author = b.author, voice = b.voice, parts = b.parts, dur = b.dur or 0 }
    local m3u = state .. "/now.m3u"
    local o = io.open(m3u, "w")
    if not o then return end
    o:write("#EXTM3U\n")
    for _, p in ipairs(book.parts) do o:write(p.path, "\n") end
    o:close()
    pending = { part = math.max(0, math.min(#book.parts - 1, tonumber(b.part) or 0)), sec = tonumber(b.sec) or 0 }
    load_marks()
    load_skips()
    set_marking(nil)
    mp.set_property_number("speed", math.max(0.5, math.min(3, book_speed(book.key))))
    mp.commandv("loadlist", m3u, "replace")
    if pending.part > 0 then mp.set_property_number("playlist-pos", pending.part) end
    mp.set_property_bool("pause", how == "paused")
end)

mp.register_script_message("books-close", function(key)
    if not book or book.key ~= key then return end
    book, loaded, pending = nil, nil, nil
    chapters, marks, skips = {}, {}, {}
    set_marking(nil)
    mp.commandv("stop")
    mp.set_property_native("user-data/music/now", { title = "", path = "" })
    publish()
end)

mp.register_event("file-loaded", function()
    skip_prev, landed = -1, nil
    if pending and part_index() == pending.part then
        if pending.sec > 1 then
            skip_prev = nil
            mp.commandv("seek", tostring(pending.sec), "absolute")
        end
        pending = nil
    elseif pending and multi() then
        mp.set_property_number("playlist-pos", pending.part)
        return
    end
    loaded = book and { key = book.key, part = part_index() } or nil
    if mark_from and loaded and mark_from.part ~= loaded.part then
        set_marking(nil)
        flash("Skip cancelled")
    end
    load_chapters()
    publish()
end)

mp.register_script_message("books-rekey", function(old, new)
    if not book or book.key ~= old then return end
    save_pos(true)
    book.key = new
    if loaded and loaded.key == old then loaded.key = new end
end)

mp.register_script_message("books-chapter", function(i)
    i = tonumber(i)
    if not i or not chapters[i + 1] then return end
    if multi() then go_to(i, 0) else set_chapter(i) mp.set_property_bool("pause", false) end
end)

mp.register_script_message("books-jump", function(part, sec)
    part, sec = tonumber(part), tonumber(sec)
    if part and sec then go_to(part, sec) end
end)

local function next_chapter(step)
    return function()
        local ci = chapter_index()
        if step < 0 then
            local c = chapters[ci + 1]
            local tp = mp.get_property_number("time-pos", 0)
            local into = multi() and tp or (tp - (c and c.start or 0))
            if into > 3 then
                if multi() then mp.commandv("seek", "0", "absolute") else set_chapter(ci) end
                return flash("Start of " .. (c and c.name or "the chapter"))
            end
        end
        local t = ci + step
        if t < 0 then return flash("This is the first chapter") end
        if t >= #chapters then return flash("This is the last chapter") end
        if multi() then go_to(t, 0) else set_chapter(t) end
        flash(chapters[t + 1].name)
    end
end
mp.add_key_binding(nil, "chapter-next", next_chapter(1))
mp.add_key_binding(nil, "chapter-prev", next_chapter(-1))

local function save_settings()
    local f = io.open(state .. "/settings", "w")
    if not f then return end
    if old_speed then f:write(fmt("speed=%.2f\n", old_speed)) end
    for k, v in pairs(SKIP) do f:write("skip_", k, "=", v, "\n") end
    f:close()
end

local function nudge(step)
    return function()
        local sp = mp.get_property_number("speed", 1)
        local r = step and math.max(0.5, math.min(3, math.floor((sp + step) * 100 + 0.5) / 100)) or 1
        mp.set_property_number("speed", r)
        flash(r == 1 and "Speed 1.00× (normal)" or fmt("Speed %.2f×", r))
    end
end
mp.add_key_binding(nil, "speed-down", nudge(-0.05))
mp.add_key_binding(nil, "speed-up", nudge(0.05))
mp.add_key_binding(nil, "speed-down-big", nudge(-0.25))
mp.add_key_binding(nil, "speed-up-big", nudge(0.25))
mp.add_key_binding(nil, "speed-reset", nudge(nil))
mp.observe_property("speed", "number", function()
    save_pos(true)
    publish()
end)

mp.add_key_binding(nil, "mark", function()
    local tp = mp.get_property_number("time-pos")
    if not book or not tp then return end
    local c = chapters[chapter_index() + 1]
    local label = c and c.name or ""
    local f = io.open(state .. "/marks.tsv", "a")
    if not f then return flash("Couldn't save the bookmark") end
    f:write(book.key, "\t", tostring(part_index()), "\t", fmt("%.1f", tp), "\t", (label:gsub("[\t\n]", " ")), "\t", tostring(os.time()), "\n")
    f:close()
    load_marks()
    publish()
    flash(fmt("Bookmarked %s%s", clock(book_pos()), label ~= "" and ("  ·  " .. label) or ""))
end)
for n = 1, 9 do
    mp.add_key_binding(nil, "mark-" .. n, function()
        local m = marks[n]
        if not m then return flash(#marks == 0 and "No bookmarks yet (b makes one)" or fmt("There are %d bookmarks", #marks)) end
        go_to(m.part, m.sec)
        flash(fmt("Bookmark %d  ·  %s", n, clock(before(m.part) + m.sec)))
    end)
end
mp.add_key_binding(nil, "marks", function()
    if book then mp.commandv("run", bin, "--window", "--marks", book.key) end
end)
mp.register_script_message("books-marks-changed", function() load_marks() publish() end)

local function past_end(part)
    if part < #book.parts - 1 then return go_to(part + 1, 0) end
    mp.set_property_bool("pause", false)
    mp.commandv("seek", "100", "absolute-percent")
end

mp.add_key_binding(nil, "skip-mark", function()
    local tp = mp.get_property_number("time-pos")
    if not book or not loaded or not tp then return end
    local part = loaded.part
    if not mark_from then
        set_marking({ part = part, sec = tp })
        return flash(fmt("Skip from %s  ·  t to end", clock(before(part) + tp)))
    end
    local dur = mp.get_property_number("duration") or 0
    local a, b = math.min(mark_from.sec, tp), math.max(mark_from.sec, tp)
    local to_end = dur > 0 and dur - b < 1
    if to_end then b = dur end
    a, b = math.floor(a * 10 + 0.5) / 10, math.floor(b * 10 + 0.5) / 10
    set_marking(nil)
    if b - a < 1 then return flash("Skip cancelled") end
    local f = io.open(state .. "/skips.tsv", "a")
    if not f then return flash("Couldn't save the skip") end
    f:write(book.key, "\t", tostring(part), "\t", fmt("%.1f", a), "\t", fmt("%.1f", b), "\t", tostring(os.time()), "\n")
    f:close()
    load_skips()
    flash(fmt("Skipping %s – %s", clock(before(part) + a), clock(before(part) + b)))
    if to_end and tp >= dur - 1 then past_end(part) end
end)
mp.register_script_message("books-skip-cancel", function()
    if mark_from then
        set_marking(nil)
        flash("Skip cancelled")
    end
end)
mp.observe_property("eof-reached", "bool", function(_, v)
    if v and mark_from and book then flash(fmt("Skip from %s  ·  t to end", clock(before(mark_from.part) + mark_from.sec))) end
end)
mp.add_key_binding(nil, "skips", function()
    if book then mp.commandv("run", bin, "--window", "--skips", book.key) end
end)
mp.register_script_message("books-skips-changed", load_skips)

mp.register_event("seek", function()
    skip_prev, landed, skipping = nil, not skipping, false
end)
mp.observe_property("time-pos", "number", function(_, pos)
    local prev = skip_prev
    skip_prev = pos
    if landed == true then landed = pos end
    if not pos or not prev or mark_from or not loaded or not book or pos < prev or pos - prev > 4 then return end
    for _, k in ipairs(skips) do
        if k.part == loaded.part and prev < k.a and pos >= k.a and pos < k.b
            and not (landed and landed >= k.a - 1 and landed <= k.a) then
            local dur = mp.get_property_number("duration") or 0
            skip_prev, skipping = nil, true
            flash("Skipped " .. clock(k.b - k.a))
            if dur > 0 and k.b >= dur - 0.5 then return past_end(loaded.part) end
            return mp.commandv("seek", tostring(k.b), "absolute")
        end
    end
end)

mp.add_key_binding(nil, "rename", function()
    if book then mp.commandv("run", bin, "--window", "--rename", book.key) end
end)
mp.add_key_binding(nil, "help", function() help_on = not help_on render_help() end)
mp.register_script_message("music-view", function(v) help_on = v == "help" render_help() end)
mp.observe_property("user-data/music/size", "native", function(_, v)
    if type(v) == "table" and v.w then screen_w, screen_h = v.w, v.h or screen_h render_help() end
end)

for _, p in ipairs({ "chapter", "playlist-pos", "duration" }) do
    mp.observe_property(p, "native", function()
        if p == "duration" then load_chapters() end
        publish()
    end)
end
mp.observe_property("pause", "bool", function(_, v)
    if v then save_pos(true) end
    publish()
end)
mp.add_periodic_timer(2, function()
    if not mp.get_property_bool("pause") then save_pos(false) publish() end
end)
mp.add_hook("on_unload", 50, function()
    save_pos(true)
    loaded = nil
end)
mp.register_event("shutdown", function() save_pos(true) end)

do
    local f = io.open(state .. "/settings", "r")
    if f then
        for l in f:lines() do
            local v = l:match("^speed=([%d.]+)$")
            if v and tonumber(v) then old_speed = math.max(0.5, math.min(3, tonumber(v))) end
            local k, n = l:match("^skip_(%a+)=(%d+)$")
            if k and SKIP[k] then SKIP[k] = tonumber(n) end
        end
        f:close()
    end
    mp.set_property_native("user-data/music/flags", {})
    mp.set_property_native("user-data/music/skips", SKIP)
    render_help()
end

mp.register_script_message("music-skip", function(k, dir)
    if SKIP[k] then mp.commandv("seek", tostring(SKIP[k] * (tonumber(dir) or 1))) end
end)
mp.register_script_message("music-skip-set", function(k, v)
    v = tonumber(v)
    if not SKIP[k] or not v or v < 1 then return end
    SKIP[k] = math.floor(v)
    save_settings()
    mp.set_property_native("user-data/music/skips", SKIP)
    render_help()
end)
