-- an open mpv takes the new wallpaper's colours
local mp = require "mp"
local utils = require "mp.utils"

local file = (os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")) .. "/wal/mpv-colors.conf"
local function mtime()
    local i = utils.file_info(file)
    return i and i.mtime or 0
end
local seen = mtime()

mp.add_periodic_timer(2, function()
    local m = mtime()
    if m == seen then return end
    seen = m
    local f = io.open(file, "r")
    if not f then return end
    for line in f:lines() do
        local k, v = line:match('^([%w-]+)="(.*)"$')
        if k == "script-opts-append" then
            mp.commandv("change-list", "script-opts", "append", v)
        elseif k then
            mp.set_property(k, v)
        end
    end
    f:close()
end)
