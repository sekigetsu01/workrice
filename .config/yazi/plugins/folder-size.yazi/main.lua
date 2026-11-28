--- Show how much space the hovered file/folder takes (or all selected ones
--- together) as a notification. Uses du.
local targets = ya.sync(function()
	local tab, out = cx.active, {}
	for _, file in pairs(tab.selected) do
		out[#out + 1] = tostring(file.url)
	end
	if #out == 0 and tab.current.hovered then
		out[1] = tostring(tab.current.hovered.url)
	end
	return out
end)

local function human(bytes)
	local units = { "B", "K", "M", "G", "T" }
	local i = 1
	while bytes >= 1024 and i < #units do
		bytes = bytes / 1024
		i = i + 1
	end
	return i == 1 and string.format("%d %s", bytes, units[i]) or string.format("%.1f %s", bytes, units[i])
end

local function entry()
	local paths = targets()
	if #paths == 0 then
		return
	end

	ya.notify { title = "Size", content = "Counting…", timeout = 1 }
	local output, err = Command("du"):arg({ "-sbc", "--" }):arg(paths):output()
	if not output then
		return ya.notify { title = "Size", content = "du failed: " .. tostring(err), timeout = 4, level = "error" }
	end

	local total = output.stdout:match("(%d+)%s+total%s*$")
	if not total then
		return ya.notify { title = "Size", content = "Couldn't read the size", timeout = 4, level = "error" }
	end

	local name = #paths == 1 and paths[1]:match("[^/]+$") or (#paths .. " items")
	ya.notify { title = "Size", content = name .. ": " .. human(tonumber(total)), timeout = 5 }
end

return { entry = entry }
