--- Notes (.md, and text files with no extension): Markdown rendered by glow, with the note's pictures drawn in place.
local M = {}

local HOME = os.getenv("HOME") or ""
local PIC_EXT = { png = true, jpg = true, jpeg = true, gif = true, webp = true, bmp = true, avif = true }

local function is_markdown(path)
	local p = path:lower()
	return p:match("%.md$") or p:match("%.markdown$")
end

local function has_ext(path) return path:match("[^/]+$"):match(".%.[^.]+$") ~= nil end

local function hash(s)
	local h = 5381
	for i = 1, #s do h = (h * 33 + s:byte(i)) & 0xffffffff end
	return string.format("%08x", h)
end

local function resolve(dest, dir)
	dest = dest:gsub("^%s+", ""):gsub("%s+$", "")
	dest = dest:match("^<(.*)>$") or dest:match('^(%S+)%s+["\'(].*$') or dest
	local file = dest:gsub("^file://", ""):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
	if file:sub(1, 2) == "~/" then
		file = HOME .. file:sub(2)
	elseif file:sub(1, 1) ~= "/" then
		file = dir .. "/" .. file
	end
	return dest, file
end

local function pictures(path)
	local f = io.open(path, "r")
	if not f then return {} end
	local src = f:read(1048576) or ""
	f:close()
	if not src:find("![", 1, true) then return {} end
	local dir, out, seen, fence = path:match("^(.*)/[^/]*$") or ".", {}, {}, false
	for line in (src .. "\n"):gmatch("(.-)\r?\n") do
		if line:match("^%s?%s?%s?```") or line:match("^%s?%s?%s?~~~") then
			fence = not fence
		elseif not fence then
			for dest in line:gmatch("!%[[^%]]*%]%(([^)]+)%)") do
				local raw, file = resolve(dest, dir)
				local ext = (file:match("%.([%w]+)$") or ""):lower()
				if PIC_EXT[ext] and not seen[raw] then
					local cha = fs.cha(Url(file))
					if cha and not cha.is_dir then
						seen[raw] = true
						out[#out + 1] = { raw = raw, file = file, mtime = cha.mtime or 0, len = cha.len or 0 }
					end
				end
			end
		end
	end
	return out
end

local function cached(job, pic)
	local base = ya.file_cache { file = job.file, skip = 0 }
	if not base then return nil end
	local name = pic.file:match("[^/]+$"):gsub("[^%w%.%-_]", "_")
	return Url(tostring(base.parent) .. "/note-pic-" .. hash(pic.file .. "|" .. pic.mtime .. "|" .. pic.len) .. "-" .. name)
end

local function precache(job, pic)
	local cache = cached(job, pic)
	if not cache then return Url(pic.file) end
	if not fs.cha(cache) and not ya.image_precache(Url(pic.file), cache) then return Url(pic.file) end
	return cache
end

local function background()
	local cache = os.getenv("XDG_CACHE_HOME")
	local f = io.open(((cache and cache ~= "") and cache or HOME .. "/.cache") .. "/wal/colors.json")
	if not f then return "black" end
	local bg = (f:read("a") or ""):match('"background"%s*:%s*"(#%x+)"')
	f:close()
	return bg or "black"
end

local function composite(job, parts, ch)
	local base = ya.file_cache { file = job.file, skip = 0 }
	if not base then return nil end
	local bg, key, args = background(), {}, {}
	for _, p in ipairs(parts) do
		local h = math.floor((p.rows or p.gap) * ch + 0.5)
		if p.pic then
			local ew = p.ew or p.pw
			key[#key + 1] = table.concat({ p.pic.file, p.pic.mtime, p.pic.len, p.pw, p.ph, h, ew }, "|")
			ya.list_merge(args, { "(", p.pic.file .. "[0]", "-resize", p.pw .. "x" .. p.ph .. "!",
				"-background", bg, "-gravity", "NorthWest", "-extent", ew .. "x" .. h, ")" })
		else
			key[#key + 1] = "gap" .. h
			ya.list_merge(args, { "-size", "1x" .. h, "xc:" .. bg })
		end
	end
	local out = tostring(base.parent) .. "/note-pics-" .. hash(table.concat(key, ";") .. bg) .. ".png"
	if fs.cha(Url(out)) then return Url(out) end
	ya.list_merge(args, { "-background", bg, "-gravity", "NorthWest", "-append", "-alpha", "remove", "-alpha", "off", "+repage", out .. ".part.png" })
	local status = Command("magick"):arg(args):stdout(Command.NULL):stderr(Command.NULL):status()
	if not (status and status.success and os.rename(out .. ".part.png", out)) then
		os.remove(out .. ".part.png")
		return precache(job, parts[1].pic)
	end
	return Url(out)
end

local get_cell = ya.sync(function(st) return st.cell end)
local set_cell = ya.sync(function(st, c) st.cell = c end)
local CELL_PY = [[
import fcntl, os, struct, termios
fd = os.open("/dev/tty", os.O_RDONLY | os.O_NOCTTY)
r, c, x, y = struct.unpack("HHHH", fcntl.ioctl(fd, termios.TIOCGWINSZ, bytes(8)))
print(x / c if c and x else 0, y / r if r and y else 0)
]]
local function cell_size()
	local c = get_cell()
	if c and os.time() - c.t < 30 then return c.w, c.h end
	local out = Command("python3"):arg({ "-Ic", CELL_PY }):stdout(Command.PIPED):stderr(Command.NULL):output()
	local w, h = (out and out.stdout or ""):match("^([%d.]+)%s+([%d.]+)")
	w, h = tonumber(w) or 0, tonumber(h) or 0
	if w < 2 or h < 2 then w, h = 8, 16 end
	set_cell { w = w, h = h, t = os.time() }
	return w, h
end

local function glow(job, path)
	return Command("glow")
		:arg({ "-s", "dark", "-w", tostring(job.area.w), "--", path })
		:env("CLICOLOR_FORCE", "1")
		:stdout(Command.PIPED)
		:stderr(Command.NULL)
		:output()
end

local function split(s)
	local lines = {}
	for line in (s .. "\n"):gmatch("(.-)\r?\n") do
		lines[#lines + 1] = line
	end
	return lines
end

local function scan(line, pics)
	if not line:find("\27]8;", 1, true) then return nil end
	local other, found, cur, i, n = {}, nil, nil, 1, #line
	while i <= n do
		local s, e, uri = line:find("^\27%]8;[^;\7\27]*;([^\7\27]*)\7", i)
		if not s then s, e, uri = line:find("^\27%]8;[^;\7\27]*;([^\7\27]*)\27\\", i) end
		if s then
			cur = uri ~= "" and uri or nil
			if cur and pics[cur] then found = cur end
			i = e + 1
		else
			s, e = line:find("^\27%[[%d;:]*[A-Za-z]", i)
			if s then
				i = e + 1
			else
				if not (cur and pics[cur]) then other[#other + 1] = line:sub(i, i) end
				i = i + 1
			end
		end
	end
	return found, table.concat(other)
end

local function blank(line)
	return line:gsub("\27%[[%d;:]*[A-Za-z]", ""):gsub("\27%]8;[^\7\27]*\7", ""):match("^%s*$") ~= nil
end

local function pure(text) return text:gsub("•", ""):gsub("^%s*Image:", ""):gsub("→", ""):match("^[%s%-%*%d%.%)]*$") ~= nil end

local function layout(lines, pics, job, kitty)
	local by_raw = {}
	for _, p in ipairs(pics) do by_raw[p.raw] = p end
	local cw, ch = cell_size()
	local cap_rows = math.max(3, math.floor(job.area.h * 2 / 3))
	local box_w = math.max(1, job.area.w - 2)
	local function box(p)
		local info = ya.image_info(Url(p.file))
		if not info or info.w == 0 or info.h == 0 then return nil end
		local s = math.min(1, box_w * cw / info.w, cap_rows * ch / info.h,
			rt.preview.max_width / info.w, rt.preview.max_height / info.h)
		local part = {
			pic = p,
			pw = math.max(1, math.floor(info.w * s)),
			ph = math.max(1, math.floor(info.h * s)),
			w = math.max(1, math.min(box_w, math.ceil(info.w * s / cw))),
			rows = math.max(1, math.min(cap_rows, math.ceil(info.h * s / ch))),
		}
		return { parts = { part }, w = part.w, rows = part.rows }
	end

	local found = {}
	for i, line in ipairs(lines) do
		local url, other = scan(line, by_raw)
		if url then found[i] = { url = url, pure = pure(other) } end
	end

	local entries, i = {}, 1
	while i <= #lines do
		local f = found[i]
		if not f then
			entries[#entries + 1] = { line = lines[i], rows = 1 }
			i = i + 1
		else
			local j, all_pure = i, f.pure
			while found[j + 1] and found[j + 1].url == f.url do
				j = j + 1
				all_pure = all_pure and found[j].pure
			end
			local b = box(by_raw[f.url])
			if not all_pure or not b then
				for k = i, j do entries[#entries + 1] = { line = lines[k], rows = 1 } end
			end
			if b then entries[#entries + 1] = b end
			i = j + 1
		end
	end

	if kitty then return entries, ch, cw end

	local merged, k = {}, 1
	while k <= #entries do
		local m = entries[k]
		k = k + 1
		if m.parts then
			while true do
				local n = k
				if entries[n] and entries[n].line and blank(entries[n].line) then n = n + 1 end
				local nxt = entries[n]
				if not (nxt and nxt.parts and m.rows + (n - k) + nxt.rows <= job.area.h) then break end
				if n > k then m.parts[#m.parts + 1] = { gap = n - k } end
				for _, part in ipairs(nxt.parts) do m.parts[#m.parts + 1] = part end
				m.w, m.rows, k = math.max(m.w, nxt.w), m.rows + (n - k) + nxt.rows, n + 1
			end
		end
		merged[#merged + 1] = m
	end
	return merged, ch, cw
end

local KITTY = (os.getenv("KITTY_WINDOW_ID") or "") ~= "" or os.getenv("TERM") == "xterm-kitty"
local PLACEHOLDER = utf8.char(0x10EEEE)
local MARKS = {}
for _, cp in ipairs({
	0x0305, 0x030D, 0x030E, 0x0310, 0x0312, 0x033D, 0x033E, 0x033F, 0x0346, 0x034A, 0x034B, 0x034C, 0x0350, 0x0351,
	0x0352, 0x0357, 0x035B, 0x0363, 0x0364, 0x0365, 0x0366, 0x0367, 0x0368, 0x0369, 0x036A, 0x036B, 0x036C, 0x036D,
	0x036E, 0x036F, 0x0483, 0x0484, 0x0485, 0x0486, 0x0487, 0x0592, 0x0593, 0x0594, 0x0595, 0x0597, 0x0598, 0x0599,
	0x059C, 0x059D, 0x059E, 0x059F, 0x05A0, 0x05A1, 0x05A8, 0x05A9, 0x05AB, 0x05AC, 0x05AF, 0x05C4, 0x0610, 0x0611,
	0x0612, 0x0613, 0x0614, 0x0615, 0x0616, 0x0617, 0x0657, 0x0658, 0x0659, 0x065A, 0x065B, 0x065D, 0x065E, 0x06D6,
	0x06D7, 0x06D8, 0x06D9, 0x06DA, 0x06DB, 0x06DC, 0x06DF, 0x06E0, 0x06E1, 0x06E2, 0x06E4, 0x06E7, 0x06E8, 0x06EB,
	0x06EC, 0x0730, 0x0732, 0x0733, 0x0735, 0x0736, 0x073A, 0x073D, 0x073F, 0x0740, 0x0741, 0x0743, 0x0745, 0x0747,
	0x0749, 0x074A, 0x07EB, 0x07EC, 0x07ED, 0x07EE, 0x07EF, 0x07F0, 0x07F1, 0x07F3, 0x0816, 0x0817, 0x0818, 0x0819,
	0x081B, 0x081C, 0x081D, 0x081E, 0x081F, 0x0820, 0x0821, 0x0822,
}) do MARKS[#MARKS + 1] = utf8.char(cp) end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64(s)
	return ((s:gsub(".", function(x)
		local r, b = "", x:byte()
		for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0") end
		return r
	end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
		if #x < 6 then return "" end
		local c = 0
		for i = 1, 6 do c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
		return B64:sub(c + 1, c + 1)
	end) .. ({ "", "==", "=" })[#s % 3 + 1])
end

local get_sent = ya.sync(function(st, id) return (st.sent or {})[id] end)
local set_sent = ya.sync(function(st, id, t)
	st.sent = st.sent or {}
	st.sent[id] = t
end)

local function kitty_send(img, cols, rows)
	local path = tostring(img)
	local id = tonumber(hash(path .. "|" .. cols .. "x" .. rows):sub(3), 16)
	if id == 0 then id = 1 end
	local t = get_sent(id)
	if t and os.time() - t < 120 then return id end
	local tty = io.open("/dev/tty", "w")
	if not tty then return nil end
	tty:setvbuf("full", 65536)
	tty:write(string.format("\27_Ga=T,U=1,q=2,f=100,t=f,i=%d,c=%d,r=%d;%s\27\\", id, cols, rows, base64(path)))
	tty:close()
	set_sent(id, os.time())
	return id
end

local function kitty_row(id, r, cols)
	local fg = string.format("\27[38;2;%d;%d;%dm", (id >> 16) & 255, (id >> 8) & 255, id & 255)
	return "\27[0m  " .. fg .. PLACEHOLDER .. (MARKS[r + 1] or MARKS[#MARKS]) .. MARKS[1]
		.. string.rep(PLACEHOLDER, cols - 1) .. "\27[0m"
end

local function plain(job, md)
	if not md then return require("code"):peek(job) end
	local output = glow(job, tostring(job.file.path))
	if not output or not output.status.success or output.stdout == "" then
		return require("code"):peek(job)
	end
	local lines = split(output.stdout)
	local limit = job.area.h
	if job.skip > 0 and job.skip + limit > #lines then
		return ya.emit("peek", { math.max(0, #lines - limit), only_if = job.file.url, upper_bound = true })
	end
	local shown = table.concat(lines, "\n", job.skip + 1, math.min(#lines, job.skip + limit))
	ya.preview_widget(job, ui.Text.parse(shown):area(job.area))
end

function M:peek(job)
	local path = tostring(job.file.path)
	local md = is_markdown(path)
	if not md and has_ext(path) then return require("code"):peek(job) end
	local pics = (job.area.w >= 10 and job.area.h >= 5) and pictures(path) or {}
	if #pics == 0 then return plain(job, md) end

	local output = glow(job, path)
	if not output or not output.status.success or output.stdout == "" then
		return plain(job, md)
	end
	local kitty = KITTY and job.area.h <= #MARKS
	local entries, ch, cw = layout(split(output.stdout), pics, job, kitty)
	if kitty then
		local area, skip, out, row = job.area, job.skip, {}, 0
		local total = 0
		for _, e in ipairs(entries) do total = total + e.rows end
		if skip > 0 and skip + area.h > total then
			return ya.emit("peek", { math.max(0, total - area.h), only_if = job.file.url, upper_bound = true })
		end
		for _, e in ipairs(entries) do
			local top, bot = row, row + e.rows
			local vt, vb = math.max(top, skip), math.min(bot, skip + area.h)
			if vb > vt then
				if e.line then
					out[#out + 1] = e.line
				else
					local part = e.parts[1]
					part.ew = e.w * cw
					local img = composite(job, e.parts, ch)
					local id = img and tostring(img):match("/note%-pics%-%x+%.png$") and kitty_send(img, e.w, e.rows)
					for r = vt - top, vb - top - 1 do
						if id then
							out[#out + 1] = kitty_row(id, r, e.w)
						elseif r == 0 then
							out[#out + 1] = "\27[2m  ▣ " .. part.pic.file:match("[^/]+$") .. "\27[0m"
						else
							out[#out + 1] = ""
						end
					end
				end
			end
			row = bot
			if row >= skip + area.h then break end
		end
		return ya.preview_widget(job, ui.Text.parse(table.concat(out, "\n")):area(area))
	end

	local area, skip, total = job.area, job.skip, 0
	for _, e in ipairs(entries) do total = total + e.rows end
	if skip > 0 and skip + area.h > total then
		return ya.emit("peek", { math.max(0, total - area.h), only_if = job.file.url, upper_bound = true })
	end

	local widgets, boxes, run, run_y, row = {}, {}, {}, 0, 0
	local function flush()
		if #run == 0 then return end
		widgets[#widgets + 1] = ui.Text.parse(table.concat(run, "\n"))
			:area(ui.Rect { x = area.x, y = run_y, w = area.w, h = #run })
		run = {}
	end
	for _, e in ipairs(entries) do
		local top, bot = row, row + e.rows
		local vt, vb = math.max(top, skip), math.min(bot, skip + area.h)
		if vb > vt then
			local y = area.y + vt - skip
			if e.line then
				if #run == 0 then run_y = y end
				run[#run + 1] = e.line
			else
				flush()
				boxes[#boxes + 1] = { e = e, y = y, h = vb - vt }
			end
		end
		row = bot
		if row >= skip + area.h then break end
	end
	flush()

	local chosen
	for _, b in ipairs(boxes) do
		if b.h == b.e.rows then chosen = b break end
	end
	if not chosen then
		for _, b in ipairs(boxes) do
			if b.h >= math.min(3, b.e.rows) then chosen = b break end
		end
	end
	if chosen then
		local parts = chosen.e.parts
		local img = #parts == 1 and precache(job, parts[1].pic) or composite(job, parts, ch)
		if img then
			ya.image_show(img, ui.Rect { x = area.x + 2, y = chosen.y, w = chosen.e.w, h = chosen.h })
		end
	end
	for _, b in ipairs(boxes) do
		if b ~= chosen then
			local names = {}
			for _, part in ipairs(b.e.parts) do
				if part.pic then names[#names + 1] = part.pic.file:match("[^/]+$") end
			end
			widgets[#widgets + 1] = ui.Text.parse("\27[2m  ▣ " .. table.concat(names, ", ") .. "\27[0m")
				:area(ui.Rect { x = area.x, y = b.y, w = area.w, h = 1 })
		end
	end
	ya.preview_widget(job, widgets)
end

function M:seek(job) require("code"):seek(job) end

function M:preload(job)
	for _, pic in ipairs(pictures(tostring(job.file.path))) do
		precache(job, pic)
	end
	return true
end

return M
