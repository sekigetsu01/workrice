--- Audio previews: the cover, else mediainfo's details (scroll with J / K).
local M = {}

local HOME = os.getenv("HOME") or ""
local BOOKS = HOME .. "/Audiobooks/"
local CONF = os.getenv("XDG_CONFIG_HOME")
CONF = (CONF and CONF ~= "") and CONF or HOME .. "/.config"

local function books_cover(path)
	local out = Command("python3")
		:arg({ "-I", CONF .. "/books/lib.py", "cover", path })
		:stdout(Command.PIPED)
		:stderr(Command.NULL)
		:output()
	local img = out and out.status.success and out.stdout:gsub("%s+$", "") or ""
	return img ~= "" and Url(img) or nil
end

local function cache_of(job) return ya.file_cache { file = job.file, skip = 0 } end

local function extract(job)
	local cache = cache_of(job)
	if not cache or fs.cha(cache) then return cache end
	local status = Command("ffmpeg")
		:arg({
			"-nostdin", "-v", "error", "-i", tostring(job.file.path), "-an", "-map", "0:v:0", "-frames:v", "1",
			"-vf", string.format("scale='min(%d,iw)':'min(%d,ih)':force_original_aspect_ratio=decrease",
				rt.preview.max_width, rt.preview.max_height),
			"-f", "image2", "-y", tostring(cache),
		})
		:stdout(Command.NULL)
		:stderr(Command.NULL)
		:status()
	if not (status and status.success and fs.cha(cache)) then
		local f = io.open(tostring(cache), "w")
		if f then f:close() end
	end
	return cache
end

local function embedded(job)
	local cache = extract(job)
	local cha = cache and fs.cha(cache)
	return cha and cha.len > 0 and cache or nil
end

function M:peek(job)
	local path = tostring(job.file.path)
	local img
	if path:sub(1, #BOOKS) == BOOKS and fs.cha(Url(CONF .. "/books/lib.py")) then
		img = books_cover(path)
	else
		img = embedded(job)
	end
	if img then
		local _, err = ya.image_show(img, job.area)
		return ya.preview_widget(job, err)
	end

	local output = Command("mediainfo"):arg({ path }):stdout(Command.PIPED):stderr(Command.NULL):output()
	if not output or not output.status.success or output.stdout == "" then
		return require("file"):peek(job)
	end
	local lines = {}
	for line in (output.stdout .. "\n"):gmatch("(.-)\r?\n") do
		lines[#lines + 1] = line
	end
	local limit = job.area.h
	if job.skip > 0 and job.skip + limit > #lines then
		return ya.emit("peek", { math.max(0, #lines - limit), only_if = job.file.url, upper_bound = true })
	end
	local shown = table.concat(lines, "\n", job.skip + 1, math.min(#lines, job.skip + limit))
	ya.preview_widget(job, ui.Text.parse(shown):area(job.area))
end

function M:seek(job) require("code"):seek(job) end

function M:preload(job)
	if tostring(job.file.path):sub(1, #BOOKS) ~= BOOKS then extract(job) end
	return true
end

return M
