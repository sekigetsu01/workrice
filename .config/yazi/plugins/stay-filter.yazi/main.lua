--- @since 26.8.15
-- f: filter the list as you type. Enter or Esc closes the box and keeps only
-- the matching files in view (Esc in the list then shows everything again).
-- If only one folder is left, it goes straight in and you keep typing.

local hovered = ya.sync(function()
	local h = cx.active.current.hovered
	return { dir = h and h.cha.is_dir, unique = #cx.active.current.files == 1 }
end)

local function prompt()
	return ya.input { title = "Filter:", pos = { "top-center", y = 2, w = 50 }, realtime = true, debounce = 0.1 }
end

return {
	entry = function()
		local input = prompt()
		while true do
			local value, event = input:recv()
			if event == 1 or event == 3 then
				ya.emit("filter_do", { value, smart = true, done = event == 1 })
			end
			if event ~= 3 then break end
			local h = hovered()
			if value ~= "" and h.unique and h.dir then
				ya.emit("escape", { filter = true })
				ya.emit("enter", {})
				input = prompt()
			end
		end
	end,
}
