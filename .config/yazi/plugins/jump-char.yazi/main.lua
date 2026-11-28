--- Vim-style f for the file list: press i, then a letter/digit, and the cursor
--- jumps to the next file whose name starts with it (case doesn't matter).
--- n / N go to the next / previous match; Esc clears the highlight.
local KEYS = "abcdefghijklmnopqrstuvwxyz0123456789._-"

local cands = {}
for i = 1, #KEYS do
	cands[#cands + 1] = { on = KEYS:sub(i, i) }
end

local hovered_name = ya.sync(function()
	local h = cx.active.current.hovered
	return h and h.name:lower() or ""
end)

return {
	entry = function()
		local idx = ya.which { cands = cands, silent = true }
		if not idx then return end

		local ch = cands[idx].on
		local on_match = hovered_name():sub(1, 1) == ch
		local query = "^" .. ch:gsub("[%.%-]", "\\%0")
		ya.emit("escape", { find = true })
		ya.emit("find_do", { query, insensitive = true })
		if on_match then ya.emit("find_arrow", {}) end
	end,
}
