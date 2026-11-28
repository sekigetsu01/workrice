-- A: make a folder (a/b/c makes the whole path) and go into it, like mkcd in the shell
local cwd = ya.sync(function() return tostring(cx.active.current.cwd) end)

return {
	entry = function()
		local name, event = ya.input {
			title = "Make folder and go in:",
			pos = { "top-center", y = 3, w = 50 },
		}
		if event ~= 1 or not name or name == "" then return end
		local path = name:sub(1, 1) == "/" and name or (cwd() .. "/" .. name)
		local ok, err = fs.create("dir_all", Url(path))
		if not ok then
			return ya.notify { title = "mkcd", content = tostring(err), level = "error", timeout = 5 }
		end
		ya.emit("cd", { path })
	end,
}
