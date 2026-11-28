-- yazi's start-up: sets up its plugins (git, smart-enter, zoxide, mime-ext); a copy pasted next to a file of the same
-- name (name_1) takes the original name back once that file's deleted; and the save mode of the file picker
require("git"):setup()

require("smart-enter"):setup {
	open_multi = true,
}

require("zoxide"):setup {
	update_db = true,
}

require("mime-ext"):setup()
require("mime-ext.local"):setup {
	fallback_file1 = true,
}

local copies_dir = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/yazi/clash-copies"

local function key(path)
	local h = 5381
	for i = 1, #path do h = (h * 33 + path:byte(i)) & 0xffffffff end
	return string.format("%08x", h)
end

local function add_copy(original, copy)
	if (original .. copy):find("[\t\n]") then return end
	local name = string.format("%s-%010d-%06d", key(original), os.time(), math.random(0, 999999))
	local tmp = copies_dir .. "/." .. name
	local f = io.open(tmp, "w")
	if not f then
		os.execute("mkdir -p -- " .. ya.quote(copies_dir))
		f = io.open(tmp, "w")
		if not f then return end
	end
	f:write(original, "\t", copy)
	f:close()
	if os.rename(tmp, copies_dir .. "/" .. name) then return copies_dir .. "/" .. name end
end

local function notes(glob)
	local out = {}
	for _, file in ipairs(fs.read_dir(Url(copies_dir), { glob = "**/" .. glob }) or {}) do
		local path, f = tostring(file.url), io.open(tostring(file.url), "r")
		if f then
			local original, copy = (f:read("a") or ""):match("^([^\t]+)\t(.+)$")
			f:close()
			out[#out + 1] = { path = path, time = file.url.name:sub(10), original = original, copy = copy }
		end
	end
	table.sort(out, function(a, b) return a.time < b.time end)
	return out
end

ya.async(function()
	local all, kept = notes("[0-9a-f]*"), {}
	for _, n in ipairs(all) do
		if n.original and fs.cha(Url(n.copy)) then kept[#kept + 1] = n else os.remove(n.path) end
	end
	for i = 1, #kept - 200 do os.remove(kept[i].path) end
end)

local on_moved = function(_from, _to) end
local on_restored = function(_copy, _original) end

local function track(body, moved)
	for _, item in ipairs(body.items or {}) do
		local from, to = tostring(item.from), tostring(item.to)
		local want = to:match("^(.*/)") .. from:match("[^/]+$")
		if want ~= to then add_copy(want, to) end
		if moved then on_moved(from, to) end
	end
end
ps.sub("duplicate", function(body) track(body, false) end)
ps.sub("move", function(body) track(body, true) end)

local deleting = require("deletes").deleting

local function restore_names(body)
	local paths, deleted = {}, {}
	for _, url in ipairs(body.urls or {}) do
		paths[#paths + 1] = tostring(url)
		deleted[tostring(url)] = true
	end
	ya.async(function()
		for _, original in ipairs(paths) do
			local done = fs.cha(Url(original)) ~= nil
			for _, n in ipairs(notes(key(original) .. "-*")) do
				if n.original == original then
					for _ = 1, 1200 do
						if deleted[n.copy] or not deleting(n.copy) or not fs.cha(Url(n.copy)) then break end
						ya.sleep(0.5)
					end
					if not fs.cha(Url(n.copy)) then
						os.remove(n.path)
					elseif not done and not deleting(n.copy) and os.rename(n.copy, original) then
						os.remove(n.path)
						done = true
						on_restored(n.copy, original)
					end
				end
			end
		end
	end)
end

ps.sub("delete", restore_names)

local save_state = os.getenv("YAZI_SAVE_STATE")
if save_state and os.getenv("YAZI_SAVE_FILE") then
	local current = os.getenv("YAZI_SAVE_FILE")
	local function record(path)
		current = path
		local f = io.open(save_state, "w")
		if f then
			f:write(path)
			f:close()
		end
	end
	local function exists(path)
		local f = io.open(path, "r")
		if f then f:close() end
		return f ~= nil
	end
	local function free_path(dir, name)
		local path = dir .. "/" .. name
		if not exists(path) then return path end
		local stem, ext = name:match("^(.+)(%.[^.]+)$")
		if not stem then stem, ext = name, "" end
		for i = 1, 999 do
			path = string.format("%s/%s_%d%s", dir, stem, i, ext)
			if not exists(path) then return path end
		end
	end

	record(current)
	local wanted = os.getenv("YAZI_SAVE_NAME") or current
	local wanted_name = wanted:match("[^/]+$")
	local note
	if wanted ~= current then note = add_copy(wanted, current) end
	local function drop_note()
		if note then os.remove(note) end
		note = nil
	end
	on_restored = function(copy, original)
		if copy == current then
			note = nil
			record(original)
		end
	end
	on_moved = function(from, to)
		if from == current then
			drop_note()
			record(to)
		end
	end
	ps.sub("rename", function(body)
		if tostring(body.from) == current then
			drop_note()
			record(tostring(body.to))
			wanted_name = current:match("[^/]+$")
		end
	end)
	local function follow()
		local cwd = tostring(cx.active.current.cwd)
		local dir = current:match("^(.*)/[^/]+$")
		if not dir or cwd == dir or not exists(current) then return end
		local dest = free_path(cwd, wanted_name)
		if not dest then return end
		local f = io.open(dest, "w")
		if not f then return end
		f:close()
		os.remove(current)
		drop_note()
		if dest ~= cwd .. "/" .. wanted_name then note = add_copy(cwd .. "/" .. wanted_name, dest) end
		record(dest)
		ya.emit("reveal", { Url(dest) })
	end
	ps.sub("cd", function()
		follow()
		if os.remove(save_state .. ".quick") then ya.emit("quit", {}) end
	end)
end
