--- @sync entry
-- R, when saving from another app: save straight into the folder you last saved to
return {
	entry = function()
		local state = os.getenv("YAZI_SAVE_STATE")
		if not state then
			ya.notify { title = "Save", content = "R only works when saving a file for another app", timeout = 3 }
			return
		end
		local home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
		local f = io.open(home .. "/yazi/last-save-dir", "r")
		local dir = f and f:read("*l")
		if f then f:close() end
		local ok = dir and dir ~= "" and os.rename(dir, dir)
		if not ok then
			ya.notify { title = "Save", content = "Nothing saved yet: pick a folder and press q", timeout = 3 }
			return
		end
		if tostring(cx.active.current.cwd) == dir then
			ya.emit("quit", {})
			return
		end
		local m = io.open(state .. ".quick", "w")
		if m then m:close() end
		ya.emit("cd", { Url(dir) })
	end,
}
