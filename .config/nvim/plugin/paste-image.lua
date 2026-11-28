-- Pictures in notes: p / P, Ctrl+v (insert) and Alt+v paste the clipboard's picture into a Markdown note
-- (:PasteImage NAME too), and a note's pictures show in place in kitty
local M = {}
package.loaded["paste-image"] = M

local WIKI = vim.fn.expand("~/sync/notes/vimwiki")
local ROOT = vim.fn.stdpath("cache") .. "/paste-image"
local CACHE = ROOT .. "/" .. vim.fn.getpid()
local SHORT = vim.fn.fnamemodify(ROOT, ":~")
local CACHE_LINKS = { "()(" .. vim.pesc(SHORT) .. "/%d+/[%w%-]+%.%w+)()" }
if SHORT ~= ROOT then table.insert(CACHE_LINKS, "()(" .. vim.pesc(ROOT) .. "/%d+/[%w%-]+%.%w+)()") end
local function short(path) return SHORT .. path:sub(#ROOT + 1) end
local TYPES = { "image/png", "image/jpeg", "image/webp", "image/gif" }
local EXT = { ["image/png"] = "png", ["image/jpeg"] = "jpg", ["image/webp"] = "webp", ["image/gif"] = "gif" }
local IMAGE_FILE = { png = true, jpg = true, jpeg = true, webp = true, gif = true, svg = true, bmp = true }
local MARKDOWN = { markdown = true, vimwiki = true, rmd = true, quarto = true }
local SHOWN = {}
local HIJACK = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" }

vim.filetype.add({ pattern = { [vim.pesc(vim.env.HOME) .. "/[^/.]+"] = { function(_, buf)
    local first = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    if not first:match("^#!") then return "markdown" end
end, { priority = -math.huge } } } })

local pending = {}
local moved = {}

local KITTY = vim.env.KITTY_WINDOW_ID ~= nil or vim.env.TERM == "xterm-kitty"
local image_ok, image = false, nil
local snacks_on = false
local function load_snacks()
    local ok, snacks = pcall(require, "snacks")
    if not ok then return false end
    local html_ok, html = pcall(vim.treesitter.language.add, "html")
    SHOWN = vim.tbl_extend("force", {}, MARKDOWN, (html_ok and html) and { html = true } or {})
    vim.treesitter.language.register("markdown", { "vimwiki", "rmd", "quarto" })
    snacks.setup({ image = {
        enabled = true,
        doc = {
            enabled = true, inline = true, float = false, max_width = 80, max_height = 40,
            conceal = function() return false end,
        },
        resolve = function(file, src)
            if src:match("^%a[%w+.-]*:") then return nil end
            if src:sub(1, 1) == "~" then return vim.fn.expand(src) end
            if src:sub(1, 1) == "/" then return src end
            return vim.fs.normalize(vim.fs.dirname(file) .. "/" .. src)
        end,
    } })
    Snacks.image.setup()
    snacks_on = true
    return true
end
local function load_image()
    load_image = function() end
    if vim.tbl_contains(vim.v.argv, "--headless") then return end
    if KITTY and load_snacks() then return end
    image_ok, image = pcall(require, "image")
    if not image_ok then return end
    if vim.fn.executable("magick") == 0 and vim.fn.executable("convert") == 0 then
        image_ok = false
        return vim.schedule(function()
            vim.notify("Pictures in notes need ImageMagick: sudo pacman -S imagemagick", vim.log.levels.WARN)
        end)
    end
    local html_ok, html = pcall(vim.treesitter.language.add, "html")
    SHOWN = vim.tbl_extend("force", {}, MARKDOWN, (html_ok and html) and { html = true } or {})
    image.setup({
        backend = "sixel",
        processor = "magick_cli",
        integrations = {
            markdown = {
                enabled = true,
                clear_in_insert_mode = false,
                download_remote_images = true,
                only_render_image_at_cursor = false,
                filetypes = { "markdown", "vimwiki", "rmd", "quarto" },
            },
            html = { enabled = SHOWN.html == true, clear_in_insert_mode = false },
            neorg = { enabled = false },
            css = { enabled = false },
        },
        max_width_window_percentage = 100,
        max_height_window_percentage = 50,
        window_overlap_clear_enabled = true,
        editor_only_render_when_focused = false,
        hijack_file_patterns = HIJACK,
    })
    local function upvalue(fn, name)
        if type(fn) ~= "function" then return nil end
        for i = 1, 60 do
            local n, v = debug.getupvalue(fn, i)
            if not n then return nil end
            if n == name then return v, i end
        end
    end
    local md = package.loaded["image/integrations/markdown"]
    local md_config = md and upvalue(md.setup, "config")
    if md_config and md_config.query_buffer_images then
        md_config.query_buffer_images = function(buf)
            local found, fence = {}, nil
            for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
                local f = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
                if f then
                    if not fence then fence = f elseif f:sub(1, 1) == fence:sub(1, 1) and #f >= #fence then fence = nil end
                elseif not fence and line:find("![", 1, true) then
                    for s, url, e in line:gmatch("()!%[[^%]]*%]%(%s*<?([^%s<>%)]+)>?[^%)]*%)()") do
                        found[#found + 1] = { url = url, range = { start_row = i - 1, start_col = s - 1, end_row = i - 1, end_col = e - 1 } }
                    end
                end
            end
            return found
        end
    end
    local sixel = require("image/backends/sixel")
    local flush, flush_slot = upvalue(sixel.render, "schedule_flush")
    local execute = upvalue(flush, "execute_flush")
    local paint = upvalue(execute, "paint_frame")
    local _, slot = upvalue(paint, "send_sixel")
    if slot and vim.api.nvim_ui_send and not vim.env.TMUX then
        debug.setupvalue(paint, slot, function(data, x, y)
            if not data then return false end
            if not (data:match("^\27P") or data:match("^\155")) then data = "\27P0;1;0q" .. data end
            if not (data:match("\27\\$") or data:match("\156$")) then data = data .. "\27\\" end
            vim.api.nvim_ui_send(("\27[s\27[%d;%dH%s\27[u"):format(y + 1, x + 1, data))
            return true
        end)
    end
    local create = upvalue(require("image/image").from_file, "createImage")
    local Image = create and upvalue(create, "Image")
    if Image and Image.clear and Image.get_extmark_id and not Image.paste_image_patched then
        local clear = Image.clear
        Image.paste_image_patched = true
        function Image:clear(shallow)
            local id = self.inline and self.buffer and self:get_extmark_id()
            clear(self, shallow)
            if id and id ~= self.internal_id and vim.api.nvim_buf_is_valid(self.buffer) then
                pcall(vim.api.nvim_buf_del_extmark, self.buffer, self.global_state.extmarks_namespace, id)
            end
        end
    end

    local state = upvalue(image.get_images, "state")
    if not (state and flush_slot and execute and Image) or Image.calm_patched then return end
    Image.calm_patched = true
    local IDLE = 300
    local queued, deferred, last = {}, {}, 0
    local timer = vim.uv.new_timer()
    local function still()
        return vim.api.nvim_get_mode().mode == "n" and vim.fn.pumvisible() == 0 and vim.uv.now() - last >= IDLE - 10
    end
    local function settle()
        if not still() then return end
        local q = queued
        queued = {}
        for _, cb in pairs(q) do pcall(cb) end
        local d = deferred
        deferred = {}
        for _, img in pairs(d) do pcall(img.render, img) end
    end
    local function poke()
        last = vim.uv.now()
        timer:stop()
        timer:start(IDLE, 0, vim.schedule_wrap(settle))
    end
    require("image/utils/render_scheduler").schedule = function(key, cb)
        queued[key] = cb
        poke()
    end
    local render = Image.render
    function Image:render(geometry)
        if still() then return render(self, geometry) end
        if geometry then self.geometry = vim.tbl_deep_extend("force", self.geometry, geometry) end
        deferred[self.id or self] = self
        poke()
    end
    local clear_now = Image.clear
    function Image:clear(shallow)
        local k = self.id or self
        if not shallow and deferred[k] == self then deferred[k] = nil end
        return clear_now(self, shallow)
    end
    local function dirty() return upvalue(execute, "frame_version") ~= upvalue(execute, "last_painted_version") end
    local waited, waiting = 0, false
    local function resizing()
        for _, img in pairs(state.images) do
            if img.pending_transform_key then return true end
        end
    end
    local function calm_flush()
        if waiting or not dirty() then return end
        if resizing() and waited < 10 then
            waited, waiting = waited + 1, true
            return vim.defer_fn(function()
                waiting = false
                calm_flush()
            end, 100)
        end
        waited = 0
        flush()
    end
    debug.setupvalue(sixel.render, flush_slot, calm_flush)
    local _, delay_slot = upvalue(flush, "FLUSH_DELAY_MS")
    if delay_slot then debug.setupvalue(flush, delay_slot, 150) end
    local function hide(wins)
        local hid = false
        for _, img in pairs(state.images) do
            if img.is_rendered and (not wins or wins[img.window]) then
                sixel.clear(img.id, true)
                deferred[img.id] = img
                hid = true
            end
        end
        if hid then upvalue(sixel.render, "schedule_flush")() end
    end
    local calm = vim.api.nvim_create_augroup("paste-image-calm", { clear = true })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "TextChanged", "TextChangedI", "ModeChanged" }, {
        group = calm, callback = poke,
    })
    vim.api.nvim_create_autocmd("InsertEnter", { group = calm, callback = function() hide() poke() end })
    vim.api.nvim_create_autocmd("WinScrolled", {
        group = calm,
        callback = function()
            local wins = {}
            for k, v in pairs(vim.v.event) do
                local w = tonumber(k)
                if w and (v.topline ~= 0 or v.height ~= 0 or v.width ~= 0 or v.leftcol ~= 0) then wins[w] = true end
            end
            hide(wins)
            poke()
        end,
    })
end

local function wayland()
    return vim.env.WAYLAND_DISPLAY ~= nil and vim.fn.executable("wl-paste") == 1
end

local function clipboard_types()
    local out
    if wayland() then
        out = vim.fn.systemlist({ "wl-paste", "--list-types" })
    elseif vim.fn.executable("xclip") == 1 then
        out = vim.fn.systemlist({ "xclip", "-selection", "clipboard", "-t", "TARGETS", "-o" })
    else
        return {}
    end
    if vim.v.shell_error ~= 0 then return {} end
    local types = {}
    for _, t in ipairs(out) do types[vim.trim(t)] = true end
    return types
end

local function clipboard_get(mime)
    if wayland() then
        return vim.fn.system({ "wl-paste", "--no-newline", "--type", mime })
    end
    return vim.fn.system({ "xclip", "-selection", "clipboard", "-t", mime, "-o" })
end

local function image_type(types)
    for _, t in ipairs(TYPES) do
        if types[t] then return t end
    end
end

local function clipboard_image()
    local types = clipboard_types()
    if types["text/uri-list"] then
        local first = vim.split(clipboard_get("text/uri-list"), "\n", { trimempty = true })[1] or ""
        local path = first:gsub("\r$", ""):match("^file://(.+)$")
        if path then
            path = path:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
            local ext = (path:match("%.([%w]+)$") or ""):lower()
            if IMAGE_FILE[ext] and vim.fn.filereadable(path) == 1 then return "file", path end
        end
    end
    local img = image_type(types)
    if types["text/plain"] or types["UTF8_STRING"] or types["text/plain;charset=utf-8"] then
        if not img then return nil end
        local text = vim.trim(clipboard_get("text/plain"))
        if text ~= "" and not text:match("^%a[%w+.-]*://%S+$") then return nil end
    end
    return img
end

local function relative(from_dir, to)
    local a = vim.split(vim.fn.fnamemodify(from_dir, ":p"):gsub("/$", ""), "/", { trimempty = true })
    local b = vim.split(vim.fn.fnamemodify(to, ":p"), "/", { trimempty = true })
    local i = 1
    while i <= #a and i <= #b and a[i] == b[i] do i = i + 1 end
    local parts = {}
    for _ = i, #a do table.insert(parts, "..") end
    for j = i, #b do table.insert(parts, b[j]) end
    return table.concat(parts, "/")
end

local function slug(s)
    s = s:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
    return s:sub(1, 40)
end

local function buf_dir(buf)
    local file = vim.api.nvim_buf_get_name(buf)
    return file ~= "" and vim.fn.fnamemodify(file, ":p:h") or vim.fn.getcwd()
end

local function link_for(path, alt)
    local ft = vim.bo.filetype
    if MARKDOWN[ft] then
        return string.format("![%s](%s)", alt, path)
    elseif ft == "tex" or ft == "plaintex" then
        return string.format("\\includegraphics[width=\\linewidth]{%s}", path)
    elseif ft == "html" then
        return string.format('<img src="%s" alt="%s">', path, alt)
    end
    return path
end

local ns = vim.api.nvim_create_namespace("paste-image")
local function link_hl() vim.api.nvim_set_hl(0, "PasteImageLink", { link = "Comment", default = true }) end
link_hl()

local function picture_exists(dir, url)
    if url:match("^%a[%w+.-]*:") then return false end
    local path = url:sub(1, 1) == "/" and url
        or url:sub(1, 1) == "~" and vim.fn.fnamemodify(url, ":p")
        or dir .. "/" .. url
    return vim.uv.fs_stat(path) ~= nil
end

local function mark(buf)
    if not vim.api.nvim_buf_is_loaded(buf) then return end
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    local ft = vim.bo[buf].filetype
    if not SHOWN[ft] then return end
    local pattern = ft == "html" and "()<img%s[^>]-src%s*=%s*[\"']([^\"']+)[\"'][^>]*>()"
        or "()!%[[^%]]*%]%(%s*<?([^%s<>%)]+)>?[^%)]*%)()"
    local needle = ft == "html" and "<img" or "!["
    local dir, found = buf_dir(buf), false
    for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        if line:find(needle, 1, true) then
            for s, url, e in line:gmatch(pattern) do
                if picture_exists(dir, url) then
                    found = true
                    vim.api.nvim_buf_set_extmark(buf, ns, i - 1, s - 1, {
                        end_col = e - 1, conceal = "", hl_group = "PasteImageLink", priority = 200,
                    })
                end
            end
        end
    end
    if found then
        for _, win in ipairs(vim.fn.win_findbuf(buf)) do
            if vim.wo[win].conceallevel < 2 then vim.wo[win][0].conceallevel = 2 end
        end
    end
end

vim.api.nvim_create_autocmd({ "CursorMoved", "BufWinEnter", "ModeChanged" }, {
    group = vim.api.nvim_create_augroup("paste-image-cursorline", { clear = true }),
    callback = function(ev)
        if not SHOWN[vim.bo[ev.buf].filetype] then return end
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        local on = #vim.api.nvim_buf_get_extmarks(ev.buf, ns, { row, 0 }, { row, -1 }, { limit = 1 }) > 0
        local want = on and "n" or ""
        if vim.wo.concealcursor ~= want then vim.wo[0][0].concealcursor = want end
    end,
})

local function show(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    mark(buf)
    if not SHOWN[vim.bo[buf].filetype] then return end
    if snacks_on then
        return pcall(Snacks.image.doc.attach, buf)
    end
    local group = vim.bo[buf].filetype == "html" and "image.nvim:html" or "image.nvim:markdown"
    pcall(vim.api.nvim_exec_autocmds, "BufWinEnter", { group = group, buffer = buf })
end

local swept = false
local function sweep()
    if swept then return end
    swept = true
    for name, kind in vim.fs.dir(ROOT) do
        local pid = tonumber(name)
        if kind == "directory" and pid and pid ~= vim.fn.getpid() then
            local ok, err = vim.uv.kill(pid, 0)
            if not ok and tostring(err):find("ESRCH") then vim.fn.delete(ROOT .. "/" .. name, "rf") end
        end
    end
end

local function save_to_cache(kind, src)
    vim.fn.mkdir(CACHE, "p")
    sweep()
    local ext = kind == "file" and ((src:match("%.([%w]+)$") or "png"):lower()) or EXT[kind]
    local stamp = os.date("%Y%m%d-%H%M%S")
    local n, base = 1, stamp
    while vim.uv.fs_lstat(CACHE .. "/" .. base .. "." .. ext) do
        n = n + 1
        base = stamp .. "-" .. n
    end
    local target = CACHE .. "/" .. base .. "." .. ext
    if kind == "file" then
        vim.uv.fs_copyfile(src, target)
    elseif wayland() then
        vim.fn.system({ "sh", "-c", 'wl-paste --no-newline --type "$1" > "$2"', "sh", kind, target })
    else
        vim.fn.system({ "sh", "-c", 'xclip -selection clipboard -t "$1" -o > "$2"', "sh", kind, target })
    end
    if vim.fn.getfsize(target) <= 0 then
        vim.fn.delete(target)
        vim.notify("Couldn't save the picture", vim.log.levels.ERROR)
        return nil
    end
    return target
end

local function paste(kind, src, above, name, insert)
    local buf = vim.api.nvim_get_current_buf()
    local cached = save_to_cache(kind, src)
    if not cached then return end
    pending[cached] = { buf = buf, name = name ~= "" and name or nil }
    if vim.bo.filetype == "" or vim.bo.filetype == "text" then vim.bo.filetype = "markdown" end

    local link = link_for(short(cached), name or "")
    local row = vim.api.nvim_win_get_cursor(0)[1]
    if insert then
        local at = vim.api.nvim_get_current_line():match("^%s*$") and row - 1 or row
        vim.api.nvim_buf_set_lines(buf, at, row, false, { link, "" })
        vim.api.nvim_win_set_cursor(0, { at + 2, 0 })
    else
        local at = above and row - 1 or row
        vim.api.nvim_buf_set_lines(buf, at, at, false, { link })
        vim.api.nvim_win_set_cursor(0, { at + 1, 0 })
    end
    show(buf)
end

local queued
function M.run(above, insert)
    local q = queued
    queued = nil
    if q then paste(q[1], q[2], above, nil, insert) end
end

local function usable()
    return vim.bo.buftype == "" and vim.bo.modifiable
end

local function from_clipboard()
    local reg = vim.v.register
    return reg == "+" or reg == "*" or (reg == '"' and vim.o.clipboard:find("unnamed", 1, true) ~= nil)
end

local function map_paste(key, above)
    vim.keymap.set("n", key, function()
        if usable() and from_clipboard() then
            local kind, src = clipboard_image()
            if kind then
                queued = { kind, src }
                return ("<Cmd>lua require('paste-image').run(%s, false)<CR>"):format(tostring(above))
            end
        end
        return key
    end, { expr = true, desc = "Paste (a picture when the clipboard holds one)" })
end
map_paste("p", false)
map_paste("P", true)

vim.keymap.set("i", "<C-v>", function()
    if usable() then
        local kind, src = clipboard_image()
        if kind then
            queued = { kind, src }
            return "<Cmd>lua require('paste-image').run(false, true)<CR>"
        end
    end
    return "<C-v>"
end, { expr = true, desc = "Insert literally (or paste a picture)" })

function M.paste_text()
    local text = vim.fn.getreg("+")
    if text == "" then return end
    vim.paste(vim.split(text:gsub("\r\n", "\n"), "\n", { plain = true }), -1)
end
vim.keymap.set({ "n", "i", "x", "c", "t" }, "<M-v>", function()
    local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
    if (mode == "n" or mode == "i") and usable() then
        local kind, src = clipboard_image()
        if kind then
            queued = { kind, src }
            return ("<Cmd>lua require('paste-image').run(false, %s)<CR>"):format(tostring(mode == "i"))
        end
    end
    return "<Cmd>lua require('paste-image').paste_text()<CR>"
end, { expr = true, desc = "Paste (a picture when the clipboard holds one)" })
if KITTY and not vim.tbl_contains(vim.v.argv, "--headless") then
    local function in_editor(on)
        pcall(vim.fn.chansend, vim.v.stderr, "\27]1337;SetUserVar=in_editor" .. (on and "=MQ==" or "") .. "\7")
    end
    local g = vim.api.nvim_create_augroup("paste-image-in-editor", { clear = true })
    vim.api.nvim_create_autocmd({ "VimEnter", "VimResume" }, { group = g, callback = function() in_editor(true) end })
    vim.api.nvim_create_autocmd({ "VimLeavePre", "VimSuspend" }, { group = g, callback = function() in_editor(false) end })
    if vim.v.vim_did_enter == 1 then in_editor(true) end
end

vim.api.nvim_create_user_command("PasteImage", function(o)
    if not usable() then return vim.notify("Can't paste into this buffer") end
    local kind, src = clipboard_image()
    if not kind then return vim.notify("There's no picture on the clipboard") end
    paste(kind, src, false, o.args, false)
end, { nargs = "?" })

local function images_dir(file)
    local dir = vim.fn.fnamemodify(file, ":p:h")
    return vim.fn.resolve(WIKI) .. "/images", vim.fn.resolve(dir)
end

local function free_name(images, base, stamp, ext)
    local target = string.format("%s/%s-%s.%s", images, base, stamp, ext)
    local n = 1
    while vim.uv.fs_lstat(target) do
        n = n + 1
        target = string.format("%s/%s-%s-%d.%s", images, base, stamp, n, ext)
    end
    return target
end

local function settle(cached, file, images)
    if moved[cached] and vim.uv.fs_stat(moved[cached]) then return moved[cached] end
    local name, ext = cached:match("([^/]+)%.(%w+)$")
    local stamp = name:match("^%d+%-%d+") or name
    if not vim.uv.fs_stat(cached) then
        return vim.fn.glob(images .. "/*-" .. name .. "." .. ext, false, true)[1]
            or vim.fn.glob(images .. "/*-" .. stamp .. "." .. ext, false, true)[1]
    end
    local info = pending[cached]
    local base = slug(info and info.name or vim.fn.fnamemodify(file, ":t:r"))
    if base == "" then base = "image" end
    vim.fn.mkdir(images, "p")
    local target = free_name(images, base, stamp, ext)
    local src = vim.fn.resolve(cached)
    if info and vim.uv.fs_rename(cached, target) then
        vim.uv.fs_symlink(target, cached)
    elseif not vim.uv.fs_copyfile(src, target) then
        return nil
    elseif info then
        os.remove(cached)
        vim.uv.fs_symlink(target, cached)
    end
    pending[cached], moved[cached] = nil, target
    return target
end

local function before_write(args)
    local buf = args.buf
    local file = vim.fn.fnamemodify(args.match, ":p")
    local images, dir = images_dir(file)
    local changes = {}
    for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        if line:find(SHORT, 1, true) or line:find(ROOT, 1, true) then
            for _, pattern in ipairs(CACHE_LINKS) do
                for s, link, e in line:gmatch(pattern) do
                    local target = settle(vim.fn.fnamemodify(link, ":p"), file, images)
                    if target then table.insert(changes, { i - 1, s - 1, e - 1, relative(dir, target) }) end
                end
            end
        end
    end
    if #changes == 0 then return end
    vim.cmd("silent! undojoin")
    table.sort(changes, function(a, b) return a[1] > b[1] or (a[1] == b[1] and a[2] > b[2]) end)
    for _, c in ipairs(changes) do
        vim.api.nvim_buf_set_text(buf, c[1], c[2], c[1], c[3], { c[4] })
    end
end

local function linked_elsewhere(cached, buf)
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if b ~= buf and vim.api.nvim_buf_is_loaded(b) then
            for _, line in ipairs(vim.api.nvim_buf_get_lines(b, 0, -1, false)) do
                if line:find(short(cached), 1, true) or line:find(cached, 1, true) then return b end
            end
        end
    end
end

local copied = {}

local function without_pictures(lines)
    local out, changed = {}, false
    for _, line in ipairs(lines) do
        local s = line:gsub("!%[[^%]]*%]%([^%)]*%)", ""):gsub("<img%s[^>]*>", "")
        if s ~= line then
            changed = true
            if s:match("^%s*$") then
                s = nil
                if #out > 0 and out[#out] == "" then out[#out] = nil end
            end
        end
        if s then table.insert(out, s) end
    end
    return changed and out or nil
end

local function clip_copy(reg)
    return function(lines, regtype)
        local send = lines
        if SHOWN[vim.bo.filetype] then send = without_pictures(lines) or lines end
        local text = table.concat(send, "\n") .. (regtype == "V" and "\n" or "")
        copied[reg] = send ~= lines and { text = text, lines = lines, regtype = regtype } or nil
        local cmd = { "wl-copy", "--type", "text/plain;charset=utf-8" }
        if reg == "*" then table.insert(cmd, 2, "--primary") end
        vim.system(cmd, { stdin = text, detach = true })
    end
end

local function clip_paste(reg)
    return function()
        local cmd = { "wl-paste", "--no-newline", "--type", "text" }
        if reg == "*" then table.insert(cmd, 2, "--primary") end
        local r = vim.system(cmd, { text = true }):wait(2000)
        local text = r.code == 0 and r.stdout or ""
        local c = copied[reg]
        if c and (text == c.text or text .. "\n" == c.text) then return { c.lines, c.regtype } end
        return vim.split(text, "\n", { plain = true })
    end
end

if wayland() and vim.fn.executable("wl-copy") == 1 then
    vim.g.clipboard = {
        name = "wl-clipboard (notes leave their pictures behind)",
        copy = { ["+"] = clip_copy("+"), ["*"] = clip_copy("*") },
        paste = { ["+"] = clip_paste("+"), ["*"] = clip_paste("*") },
        cache_enabled = false,
    }
end

local group = vim.api.nvim_create_augroup("paste-image", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = link_hl })
vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(args)
        if MARKDOWN[args.match] or args.match == "html" then load_image() end
        if SHOWN[args.match] then vim.schedule(function() show(args.buf) end) end
    end,
})
vim.api.nvim_create_autocmd("BufReadPre", { group = group, pattern = HIJACK, callback = function() load_image() end })
vim.api.nvim_create_autocmd({ "BufWinEnter", "TextChanged", "InsertLeave", "BufWritePost" }, {
    group = group,
    callback = function(args)
        if SHOWN[vim.bo[args.buf].filetype] then mark(args.buf) end
    end,
})
vim.api.nvim_create_autocmd("BufWritePre", { group = group, callback = before_write })
vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
        vim.schedule(function()
            if vim.api.nvim_buf_is_valid(args.buf) then return end
            for cached, info in pairs(pending) do
                if info.buf == args.buf then
                    local other = linked_elsewhere(cached, args.buf)
                    if other then
                        info.buf = other
                    else
                        os.remove(cached)
                        pending[cached] = nil
                    end
                end
            end
        end)
    end,
})
vim.api.nvim_create_autocmd("VimLeave", {
    group = group,
    callback = function() vim.fn.delete(CACHE, "rf") end,
})

if KITTY and not vim.tbl_contains(vim.v.argv, "--headless") then load_image() end
