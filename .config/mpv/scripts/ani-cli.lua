-- Fixes for videos from ani-cli's source (played with the zokoanime referrer); others are left alone.
--  * Japanese and English audio (ani-cli passes at most one), named, starting in Japanese;
--    subtitles only with Japanese
--  * the "h!anime.at" logo burned into the top-right corner is blurred away
-- For every episode ani-cli plays (it runs mpv with ANI_CLI_PLAYER set, see ~/.local/bin/ani-cli):
--  * openings and endings skipped by key (→ l k), with times from ani-skip; never by themselves
--  * resume where you stopped; ani-cli -c then offers the unfinished episode again
local function from_ani_cli()
    return mp.get_property("referrer", ""):find("zokoanime", 1, true) ~= nil
end

-- Audio: the languages are listed in master.m3u8 next to the quality folder ani-cli plays (…/1080/index.m3u8)
local first_lang = "ja"
local keep = { ja = true, en = true }
local done_for

local function add_languages()
    if not from_ani_cli() then return end
    local path = mp.get_property("path", "")
    local base = path:match("^(https?://.+)/[^/]+/index%.m3u8")
    if not base or done_for == path then return end
    done_for = path
    mp.command_native_async({
        name = "subprocess", playback_only = false, capture_stdout = true, capture_stderr = true,
        args = { "curl", "-fsS", "--max-time", "15", "-e", mp.get_property("referrer"), base .. "/master.m3u8" },
    }, function(ok, r)
        if not (ok and r.status == 0) then return end
        local langs = {}
        for line in r.stdout:gmatch("[^\r\n]+") do
            if line:find("^#EXT%-X%-MEDIA:TYPE=AUDIO") then
                local uri = line:match('URI="([^"]+)"')
                local lang = line:match('LANGUAGE="([^"]+)"') or ""
                if uri and keep[lang] then
                    if not uri:find("^https?://") then uri = base .. "/" .. uri end
                    langs[#langs + 1] = { uri = uri, name = line:match('NAME="([^"]+)"') or "", lang = lang }
                end
            end
        end
        if #langs == 0 then return end
        -- ani-cli's own unnamed copy of the default language keeps playing while the named list
        -- loads (a few seconds), then gives way to it
        local old = {}
        for _, t in ipairs(mp.get_property_native("track-list", {})) do
            if t.type == "audio" and t.external then old[t.id] = true end
        end
        for _, a in ipairs(langs) do mp.commandv("audio-add", a.uri, "auto", a.name, a.lang) end
        local pick
        for _, t in ipairs(mp.get_property_native("track-list", {})) do
            if t.type == "audio" and not old[t.id] and (t.lang == first_lang or not pick) then
                pick = t.id
                if t.lang == first_lang then break end
            end
        end
        if pick then mp.set_property_number("aid", pick) end
        for id in pairs(old) do mp.commandv("audio-remove", id) end
    end)
end

-- The subtitles translate the Japanese lines, timed to them, so they show with Japanese (always,
-- even if they were switched off) and never with the English dub, whose script differs
mp.observe_property("current-tracks/audio/lang", "string", function(_, lang)
    if not (lang and from_ani_cli()) then return end
    local ja = lang == first_lang
    if ja and not mp.get_property_native("sid") then mp.set_property("sid", "auto") end
    mp.set_property_bool("sub-visibility", ja)
end)

mp.register_event("file-loaded", add_languages)
-- loaded into an mpv that's already playing
if mp.get_property("path") then add_languages() end

-- Logo: the box is a share of the frame, so it fits every quality (measured on 1080p: 1719,19 180x39)
local applied

mp.observe_property("video-dec-params", "native", function(_, v)
    if not (v and v.w and v.h) or not from_ani_cli() then return end
    local box = string.format("@hianime:delogo=x=%d:y=%d:w=%d:h=%d",
        math.floor(v.w * 0.8953), math.floor(v.h * 0.0176),
        math.ceil(v.w * 0.0938), math.ceil(v.h * 0.0361))
    if box == applied then return end
    if applied then mp.commandv("vf", "remove", "@hianime") end
    mp.commandv("vf", "append", box)
    applied = box
end)

-- Everything below: any episode ani-cli plays, whatever the source
if not os.getenv("ANI_CLI_PLAYER") then return end
local utils = require("mp.utils")

-- Skipping. ani-mpv passes ani-skip's times as aniskip-* script-opts (as skip-* ani-skip's own script
-- would skip on its own). Inside an opening or ending, → l and k jump to its end; elsewhere they do
-- what input.conf says.
local seg = { op_start = 0, op_end = 0, ed_start = 0, ed_end = 0 }
require("mp.options").read_options(seg, "aniskip")
local parts = {}
if seg.op_end > seg.op_start then parts[#parts + 1] = { name = "opening", from = seg.op_start, to = seg.op_end } end
if seg.ed_end > seg.ed_start then parts[#parts + 1] = { name = "ending", from = seg.ed_start, to = seg.ed_end } end

local function part_at(t)
    for _, p in ipairs(parts) do
        if t and t >= p.from and t < p.to - 1 then return p end
    end
end

if #parts > 0 then
    local normal = {}
    for _, b in ipairs(mp.get_property_native("input-bindings", {})) do
        local k = b.key
        if (k == "RIGHT" or k == "l" or k == "k") and (not normal[k] or b.priority > normal[k].priority) then
            normal[k] = b
        end
    end
    for _, k in ipairs({ "RIGHT", "l", "k" }) do
        mp.add_forced_key_binding(k, "skip-" .. k, function()
            local p = part_at(mp.get_property_number("time-pos"))
            if p then
                mp.set_property_number("time-pos", p.to)
                mp.osd_message("Skipped the " .. p.name, 2)
            elseif normal[k] then
                mp.command(normal[k].cmd)
            end
        end, { repeatable = true })
    end
    -- a note as one starts
    local inside
    mp.observe_property("time-pos", "number", function(_, t)
        local p = part_at(t)
        if p and p ~= inside then
            mp.osd_message(string.format("%s%s: → l k skip it", p.name:sub(1, 1):upper(), p.name:sub(2)), 4)
        end
        inside = p
    end)
end

-- Resume. Positions are kept by title ("<show> Episode <n>"), since each play gets a new link.
local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local store = mp.command_native({ "expand-path", "~~state/ani-cli-positions.json" })
if not store:find("^/") then store = state_home .. "/mpv/ani-cli-positions.json" end
local hist = state_home .. "/ani-cli/ani-hsts"
local title, last, ready

local function load_store()
    local f = io.open(store)
    if not f then return {} end
    local data = utils.parse_json(f:read("*a") or "")
    f:close()
    return type(data) == "table" and data or {}
end

local function write_atomic(path, text)
    local tmp = path .. ".tmp"
    local f = io.open(tmp, "w")
    if not f then
        mp.command_native({ name = "subprocess", playback_only = false, args = { "mkdir", "-p", (utils.split_path(path)) } })
        f = io.open(tmp, "w")
        if not f then return end
    end
    f:write(text)
    f:close()
    os.rename(tmp, path)
end

-- ani-cli -c offers the episode after the one in its history; for an unfinished episode the history
-- says the one before, so -c comes back to it. Whole-number episodes after the first only.
local function set_history(show, ep)
    local f = io.open(hist)
    if not f then return end
    local out, changed = {}, false
    for line in f:lines() do
        local e, id, name = line:match("^([^\t]+)\t([^\t]+)\t(.*)$")
        if name == show and e ~= ep then line, changed = ep .. "\t" .. id .. "\t" .. name, true end
        out[#out + 1] = line
    end
    f:close()
    if changed then write_atomic(hist, table.concat(out, "\n") .. "\n") end
end

local function finished(t)
    local dur = mp.get_property_number("duration")
    if mp.get_property_native("eof-reached") then return true end
    if seg.ed_end > seg.ed_start then return t >= seg.ed_start end
    return dur and t >= dur - 90
end

local function save(final)
    if not (title and ready and last) then return end
    local data = load_store()
    local done = finished(last)
    if done or last < 30 then data[title] = nil else data[title] = math.floor(last) end
    write_atomic(store, utils.format_json(data))
    if final then
        local show, ep = title:match("^(.*) Episode (%d+)$")
        if show and tonumber(ep) > 1 then set_history(show, done and ep or tostring(tonumber(ep) - 1)) end
    end
end

mp.register_event("file-loaded", function()
    title = mp.get_property("media-title")
    local pos = load_store()[title]
    if pos then
        mp.commandv("seek", tostring(pos), "absolute")
        mp.osd_message(string.format("Resumed at %d:%02d", math.floor(pos / 60), pos % 60), 3)
    end
    ready = true
end)
mp.observe_property("time-pos", "number", function(_, t) if t and ready then last = t end end)
mp.add_periodic_timer(15, function() save(false) end)
mp.register_event("end-file", function() save(true); ready = false end)
