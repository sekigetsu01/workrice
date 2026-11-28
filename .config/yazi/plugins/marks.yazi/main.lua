--- @since 26.8.15
-- Vim-style folder marks.
--   m + letter   save the current folder under that letter
--   m then -     clear all marks
--   ' + letter   jump back to it (the popup lists your marks)
-- Marks are saved in ~/.local/state/yazi/marks, so they survive restarts.

local KEYS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

local cwd = ya.sync(function() return tostring(cx.active.current.cwd) end)

local function store_dir()
	local state = os.getenv("XDG_STATE_HOME")
	if not state or state == "" then state = os.getenv("HOME") .. "/.local/state" end
	return state .. "/yazi"
end

local function load()
	local marks, order = {}, {}
	local f = io.open(store_dir() .. "/marks", "r")
	if not f then return marks, order end
	for line in f:lines() do
		local key, path = line:match("^(%w)\t(.+)$")
		if key and not marks[key] then
			marks[key] = path
			order[#order + 1] = key
		end
	end
	f:close()
	return marks, order
end

local function save(marks)
	fs.create("dir_all", Url(store_dir()))
	local f = io.open(store_dir() .. "/marks", "w")
	if not f then
		return ya.notify { title = "Marks", content = "Can't write " .. store_dir() .. "/marks", timeout = 4, level = "error" }
	end
	for i = 1, #KEYS do
		local k = KEYS:sub(i, i)
		if marks[k] then f:write(k, "\t", marks[k], "\n") end
	end
	f:close()
end

local function set_mark()
	local cands = { { on = "-", desc = "Clear all marks" } }
	for i = 1, #KEYS do
		cands[#cands + 1] = { on = KEYS:sub(i, i) }
	end
	local idx = ya.which { cands = cands, silent = true }
	if not idx then return end

	if idx == 1 then
		save {}
		return ya.notify { title = "Marks", content = "All marks cleared", timeout = 2 }
	end

	local key, dir = cands[idx].on, cwd()
	local marks = load()
	marks[key] = dir
	save(marks)
	ya.notify { title = "Marks", content = "'" .. key .. "  →  " .. dir, timeout = 2 }
end

local function jump()
	local marks, order = load()
	if #order == 0 then
		return ya.notify { title = "Marks", content = "No marks yet", timeout = 3 }
	end
	table.sort(order)
	local cands = {}
	for _, k in ipairs(order) do
		cands[#cands + 1] = { on = k, desc = marks[k] }
	end
	local idx = ya.which { cands = cands }
	if not idx then return end

	local dir = marks[cands[idx].on]
	if not fs.cha(Url(dir)) then
		return ya.notify { title = "Marks", content = dir .. " no longer exists", timeout = 3, level = "warn" }
	end
	ya.emit("cd", { dir })
end

return {
	entry = function(_, job)
		if job.args[1] == "jump" then jump() else set_mark() end
	end,
}
