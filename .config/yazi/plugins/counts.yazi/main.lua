--- Vim-style counts for yazi.
--- Bound to the digit keys in keymap.toml; after a number press:
---   j / <Down>   move down N files        k / <Up>   move up N files
---   h            go up N folders
---   gg / G       go to file number N      gt         go to tab N
--- Any other key (e.g. Esc) cancels. Numbers can have several digits: 12j.

local ACTIONS = {
	{ on = "j" }, { on = "<Down>" }, { on = "k" }, { on = "<Up>" },
	{ on = "h" }, { on = "G" }, { on = { "g", "g" } }, { on = { "g", "t" } },
}

local CANDS = {}
for i = 0, 9 do
	CANDS[#CANDS + 1] = { on = tostring(i) }
end
for _, a in ipairs(ACTIONS) do
	CANDS[#CANDS + 1] = a
end

local cwd = ya.sync(function() return tostring(cx.active.current.cwd) end)

local function run(action, n)
	local key = type(action.on) == "table" and table.concat(action.on) or action.on
	if key == "j" or key == "<Down>" then
		ya.emit("arrow", { tostring(n) })
	elseif key == "k" or key == "<Up>" then
		ya.emit("arrow", { tostring(-n) })
	elseif key == "h" then
		local dir = cwd()
		for _ = 1, n do
			local parent = dir:match("^(.*)/[^/]+/?$")
			if not parent then break end
			dir = parent == "" and "/" or parent
		end
		ya.emit("cd", { dir })
	elseif key == "G" or key == "gg" then
		ya.emit("arrow", { "top" })
		if n > 1 then ya.emit("arrow", { tostring(n - 1) }) end
	elseif key == "gt" then
		ya.emit("tab_switch", { tostring(n - 1) })
	end
end

return {
	entry = function(_, job)
		local n = tonumber(job.args[1]) or 0
		while true do
			local idx = ya.which { cands = CANDS, silent = true }
			if not idx then return end
			if idx <= 10 then
				n = n * 10 + (idx - 1)
				if n > 99999 then return end
			else
				if n > 0 then run(ACTIONS[idx - 10], n) end
				return
			end
		end
	end,
}
