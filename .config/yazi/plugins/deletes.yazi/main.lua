-- D: deletes the selected files (or the hovered one) for good, no bin and no question; init.lua asks it which files
-- are still being deleted
local targets = ya.sync(function()
	local list = {}
	for _, file in pairs(cx.active.selected) do
		list[#list + 1] = tostring(file.url)
	end
	local hovered = cx.active.current.hovered
	if #list == 0 and hovered then list[1] = tostring(hovered.url) end
	return list
end)

local mark = ya.sync(function(state, list)
	state.busy = state.busy or {}
	for _, path in ipairs(list) do
		state.busy[path] = true
	end
end)

local M = {}

function M:entry()
	local list = targets()
	if #list == 0 then return end
	mark(list)
	ya.emit("remove", { permanently = true, force = true })
end

M.deleting = ya.sync(function(state, path)
	if not (state.busy and state.busy[path]) then return false end
	local s = cx.tasks.summary
	if s.total - s.success - s.failed > 0 then return true end
	state.busy[path] = nil
	return false
end)

return M
