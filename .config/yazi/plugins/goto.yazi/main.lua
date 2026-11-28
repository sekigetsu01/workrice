-- g: go to a folder by its key: your folders in ~/.config/shell/dirs (the same keys as the shell's), then the
-- built-in ones (g top, h ~, c ~/.config, d ~/Downloads, Space jump, f follow a link)
local HOME = os.getenv("HOME")

local BUILTIN = {
	{ "g", "Go to top", "arrow", { "top" } },
	{ "h", "~", "cd", { HOME } },
	{ "c", "~/.config", "cd", { HOME .. "/.config" } },
	{ "d", "~/Downloads", "cd", { HOME .. "/Downloads" } },
	{ "<Space>", "Jump interactively", "cd", { interactive = true } },
	{ "f", "Follow hovered symlink", "follow", {} },
}

local function entries()
	local list, seen = {}, {}
	local config = os.getenv("XDG_CONFIG_HOME")
	local f = io.open((config and config ~= "" and config or HOME .. "/.config") .. "/shell/dirs")
	if f then
		for line in f:lines() do
			local key, path = line:match("^%S+%s+(%S+)%s+%S+%s+(.-)%s*$")
			if key and key ~= "-" and not seen[key] then
				seen[key] = true
				list[#list + 1] = { key, path, "cd", { path:sub(1, 1) == "~" and HOME .. path:sub(2) or path } }
			end
		end
		f:close()
	end
	for _, e in ipairs(BUILTIN) do
		if not seen[e[1]] then list[#list + 1] = e end
	end
	return list
end

return {
	entry = function()
		local list, cands = entries(), {}
		for i, e in ipairs(list) do
			cands[i] = { on = e[1], desc = e[2] }
		end
		local idx = ya.which { cands = cands }
		if idx then ya.emit(list[idx][3], list[idx][4]) end
	end,
}
