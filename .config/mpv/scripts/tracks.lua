-- a: next audio track, s: subtitles on / off
local function osd(...) mp.commandv("osd-msg", ...) end

mp.add_key_binding(nil, "next-audio", function()
    local ids, cur = {}, mp.get_property_number("aid")
    for _, t in ipairs(mp.get_property_native("track-list", {})) do
        if t.type == "audio" then ids[#ids + 1] = t.id end
    end
    if #ids == 0 then return osd("show-text", "No audio") end
    local nxt = ids[1]
    for i, id in ipairs(ids) do
        if id == cur then nxt = ids[i % #ids + 1] break end
    end
    osd("set", "aid", tostring(nxt))
end)

mp.add_key_binding(nil, "toggle-subs", function()
    if not mp.get_property_native("sid") then
        mp.set_property("sid", "auto")
        if not mp.get_property_native("sid") then return osd("show-text", "No subtitles") end
        return osd("set", "sub-visibility", "yes")
    end
    osd("cycle", "sub-visibility")
end)
