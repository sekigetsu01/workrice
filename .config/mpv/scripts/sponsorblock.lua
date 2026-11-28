-- SponsorBlock in mpv: the parts its users mark (sponsors, self-promotion, like/subscribe reminders, intros, outros,
-- recaps, filler, non-music) are skipped while a YouTube video plays, with a note on screen. Streams, and downloads
-- that weren't cut (O in FreeTube: their link is in the file); a download that was cut (yt) is shorter than the video,
-- so it's left alone. SponsorBlock is asked by the first 4 characters of a hash of the video's id, not the id.

local utils = require "mp.utils"

local CATS = '["sponsor","selfpromo","interaction","intro","outro","preview","filler","music_offtopic"]'
local NAMES = {
    sponsor = "sponsor", selfpromo = "self-promotion", interaction = "like/subscribe reminder", intro = "intro",
    outro = "outro", preview = "recap", filler = "filler", music_offtopic = "non-music part",
}
local YT = { "youtube%.com/watch%?.-v=([%w_-]+)", "youtu%.be/([%w_-]+)", "youtube%.com/shorts/([%w_-]+)",
    "youtube%.com/live/([%w_-]+)", "^ytdl://([%w_-]+)$" }

local segs, done, gen = {}, {}, 0

local function video_id(s)
    if not s then return nil end
    for _, p in ipairs(YT) do
        local id = s:match(p)
        if id and #id == 11 then return id end
    end
end

-- a local file: the link yt-dlp keeps in it (--embed-metadata)
local function file_link()
    local tags = mp.get_property_native("metadata") or {}
    for k, v in pairs(tags) do
        local l = k:lower()
        if (l == "purl" or l == "comment" or l == "description") and video_id(v) then return v end
    end
end

local function apply(json, id, is_file)
    local data = utils.parse_json(json or "")
    if type(data) ~= "table" then return end
    local dur = mp.get_property_number("duration")
    for _, v in ipairs(data) do
        if v.videoID == id then
            for _, s in ipairs(v.segments or {}) do
                local vd = tonumber(s.videoDuration) or 0
                -- a file as long as the video (within 2 s) is uncut; the video's length unknown: trust it
                local fits = not is_file or vd == 0 or not dur or math.abs(vd - dur) <= 2
                if fits and (s.actionType or "skip") == "skip" and s.segment then
                    segs[#segs + 1] = { s.segment[1], s.segment[2], s.category }
                end
            end
        end
    end
end

mp.register_event("file-loaded", function()
    segs, done, gen = {}, {}, gen + 1
    local path = mp.get_property("path") or ""
    local is_file = not path:find("://")
    local id = video_id(path) or (is_file and video_id(file_link()))
    if not id then return end
    local h = mp.command_native({ name = "subprocess", args = { "sha256sum" }, stdin_data = id,
        capture_stdout = true, playback_only = false })
    local pre = h and h.stdout and h.stdout:sub(1, 4)
    if not pre or #pre ~= 4 then return end
    local mine = gen
    mp.command_native_async({ name = "subprocess", playback_only = false, capture_stdout = true,
        args = { "curl", "-fsS", "-m", "8", "-G", "--data-urlencode", "categories=" .. CATS,
            "https://sponsor.ajay.app/api/skipSegments/" .. pre } },
        function(ok, r)
            if ok and r and r.status == 0 and mine == gen then apply(r.stdout, id, is_file) end
        end)
end)

-- each part is skipped once (seek back into it to watch it)
mp.observe_property("time-pos", "number", function(_, t)
    if not t then return end
    for i, s in ipairs(segs) do
        if not done[i] and t >= s[1] and t < s[2] - 0.5 then
            done[i] = true
            mp.set_property_number("time-pos", s[2])
            mp.osd_message("Skipped " .. (NAMES[s[3]] or s[3] or "a part"), 2)
            return
        end
    end
end)
