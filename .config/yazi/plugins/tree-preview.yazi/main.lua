-- Folder preview: eza tree that follows yazi's hidden-files toggle (Ctrl+S)
local show_hidden = ya.sync(function() return cx.active.pref.show_hidden end)

local M = {}

function M:peek(job)
	job.args = {
		"eza -T --level=2 --color=always --icons=always --group-directories-first --no-quotes "
			.. (show_hidden() and "-a " or "")
			.. '-- "$1" 2>/dev/null | tail -n +2',
	}
	require("piper"):peek(job)
end

function M:seek(job) require("piper"):seek(job) end

return M
