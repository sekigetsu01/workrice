-- Prose in a centred column: Markdown, wiki, text, mail and commit messages sit in the middle of the window, 80 wide,
-- with empty pads either side. Space G turns it off and on (init.vim); Ctrl+h/j/k/l and Ctrl+w w skip the pads
local M = {
    width = 80,
    on = true,
    filetypes = { markdown = true, vimwiki = true, text = true, mail = true, gitcommit = true, tex = true },
}
local api = vim.api
local pads = {}
local FCS, WHL = 'vert: ', 'WinSeparator:Normal'
local PAD = {
    number = false, relativenumber = false, signcolumn = 'no', foldcolumn = '0', statuscolumn = '',
    spell = false, list = false, cursorline = false, cursorcolumn = false, colorcolumn = '', winbar = '',
    winfixwidth = true, winfixbuf = true, winhighlight = WHL,
    fillchars = 'eob: ,vert: ,horiz: ,horizup: ,horizdown: ,vertleft: ,vertright: ,verthoriz: ',
}

local function setlocal(w, name, v) api.nvim_set_option_value(name, v, { win = w, scope = 'local' }) end
local function getlocal(w, name) return api.nvim_get_option_value(name, { win = w, scope = 'local' }) end
local function float(w) return api.nvim_win_get_config(w).relative ~= '' end

local function is_pad(w)
    return api.nvim_win_is_valid(w) and vim.b[api.nvim_win_get_buf(w)].prosepad == true
end

local function owner(w)
    for o, p in pairs(pads) do
        if p[1] == w or p[2] == w then return o end
    end
end

local function wins(tab)
    return vim.tbl_filter(function(w) return not float(w) and not is_pad(w) end, api.nvim_tabpage_list_wins(tab))
end
function M.count() return #wins(0) end

local function wants(w)
    local b = api.nvim_win_get_buf(w)
    return M.filetypes[vim.bo[b].filetype] and vim.bo[b].buftype == '' and not vim.wo[w].diff
end

local function parent(node, w, up)
    if node[1] == 'leaf' then
        if node[2] == w then return up or false end
        return nil
    end
    for _, c in ipairs(node[2]) do
        local r = parent(c, w, node)
        if r ~= nil then return r end
    end
end

local function decorate(w)
    for name, add in pairs({ fillchars = FCS, winhighlight = WHL }) do
        local v = getlocal(w, name)
        if v:sub(-#add) ~= add then
            if v == '' then v = api.nvim_get_option_value(name, { win = w }) end
            setlocal(w, name, (v == '' and '' or v .. ',') .. add)
        end
    end
end
local function undecorate(w)
    for name, add in pairs({ fillchars = FCS, winhighlight = WHL }) do
        local v = getlocal(w, name)
        if v:sub(-#add) == add then setlocal(w, name, (v:sub(1, -#add - 1):gsub(',$', ''))) end
    end
end

local function sizes(o, total)
    local side = total - M.width - vim.fn.getwininfo(o)[1].textoff - 2
    if side < 4 then return end
    local l = math.floor(side / 2)
    return l, side - l
end

local function unpad(o)
    local p = pads[o]
    pads[o] = nil
    for _, w in ipairs(p) do
        if api.nvim_win_is_valid(w) then pcall(api.nvim_win_close, w, true) end
    end
    if api.nvim_win_is_valid(o) then undecorate(o) end
end

local function pad(o, side, width)
    local b = api.nvim_create_buf(false, true)
    vim.b[b].prosepad = true
    vim.bo[b].bufhidden = 'wipe'
    vim.bo[b].modifiable = false
    local w = api.nvim_open_win(b, false, { split = side, win = o, width = width, noautocmd = true })
    for k, v in pairs(PAD) do setlocal(w, k, v) end
    return w
end

local function reuse(w)
    local best
    for _, b in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
        if not best or b.lastused > best.lastused then best = b end
    end
    setlocal(w, 'winfixbuf', false)
    api.nvim_win_call(w, function()
        if best then vim.cmd.buffer(best.bufnr) else vim.cmd.enew() end
        vim.cmd('setlocal ' .. table.concat(vim.tbl_map(function(k) return k .. '<' end, vim.tbl_keys(PAD)), ' '))
    end)
end

local function refresh()
    if not M.on then
        for o in pairs(pads) do unpad(o) end
        return
    end
    if vim.fn.exists('#goyo') == 1 or vim.t.goyo_pads then return end
    local tab = api.nvim_get_current_tabpage()
    local layout = vim.fn.winlayout()
    for o, p in pairs(pads) do
        if not api.nvim_win_is_valid(o) then
            unpad(o)
        elseif api.nvim_win_get_tabpage(o) == tab then
            local par = parent(layout, o)
            local ok = wants(o) and is_pad(p[1]) and is_pad(p[2]) and par and par[1] == 'row' and #par[2] == 3
                and par[2][1][2] == p[1] and par[2][2][2] == o and par[2][3][2] == p[2]
            if not ok then unpad(o) end
        end
    end
    local known = {}
    for _, p in pairs(pads) do known[p[1]], known[p[2]] = true, true end
    for _, w in ipairs(api.nvim_tabpage_list_wins(tab)) do
        if is_pad(w) and not known[w] and not pcall(api.nvim_win_close, w, true) then reuse(w) end
    end
    if not api.nvim_tabpage_is_valid(tab) then return end
    layout = vim.fn.winlayout()
    for _, w in ipairs(wins(tab)) do
        if pads[w] then
            local p = pads[w]
            local l, r = sizes(w, api.nvim_win_get_width(p[1]) + api.nvim_win_get_width(w) + api.nvim_win_get_width(p[2]) + 2)
            if not l then
                unpad(w)
            else
                if api.nvim_win_get_width(p[1]) ~= l then api.nvim_win_set_width(p[1], l) end
                if api.nvim_win_get_width(p[2]) ~= r then api.nvim_win_set_width(p[2], r) end
                decorate(w)
            end
        else
            local par = parent(layout, w)
            local l, r = sizes(w, api.nvim_win_get_width(w))
            if l and wants(w) and (par == false or par and par[1] == 'col') then
                pads[w] = { pad(w, 'left', l), pad(w, 'right', r) }
                decorate(w)
            else
                undecorate(w)
            end
        end
    end
end

local queued = false
local function queue()
    if queued then return end
    queued = true
    vim.schedule(function()
        queued = false
        refresh()
    end)
end

function M.set(on)
    M.on = on
    queue()
end

function M.nav(dir)
    local start = api.nvim_get_current_win()
    local w = start
    for _ = 1, 3 do
        local n = vim.fn.win_getid(api.nvim_win_call(w, function() return vim.fn.winnr(dir) end))
        if n == 0 or n == w then break end
        w = n
        if not is_pad(w) then break end
        if dir == 'j' or dir == 'k' then
            w = owner(w) or start
            break
        end
    end
    if is_pad(w) then w = start end
    if w ~= start then api.nvim_set_current_win(w) end
end

function M.cycle(back)
    if vim.v.count > 0 then return vim.cmd(vim.v.count .. 'wincmd ' .. (back and 'W' or 'w')) end
    local ids, cur = {}, api.nvim_get_current_win()
    for i = 1, vim.fn.winnr('$') do
        local w = vim.fn.win_getid(i)
        if not is_pad(w) then ids[#ids + 1] = w end
    end
    for i, w in ipairs(ids) do
        if w == cur then return api.nvim_set_current_win(ids[(i - 1 + (back and -1 or 1)) % #ids + 1]) end
    end
end

function M.setup()
    local g = api.nvim_create_augroup('ProsePad', { clear = true })
    local au = function(ev, cb, pat) api.nvim_create_autocmd(ev, { group = g, callback = cb, pattern = pat }) end
    au({ 'BufWinEnter', 'FileType', 'VimResized', 'TabEnter' }, queue)
    au('User', function()
        local v = vim.go.fillchars
        if v:sub(-#FCS) == FCS then vim.go.fillchars = (v:sub(1, -#FCS - 1):gsub(",$", "")) end
        queue()
    end, 'GoyoLeave')
    au('OptionSet', queue, 'diff')
    au('WinNew', function() if not float(0) then queue() end end)
    au('WinClosed', function(ev)
        local w = tonumber(ev.match)
        if not (w and api.nvim_win_is_valid(w) and float(w)) then queue() end
    end)
    au('WinResized', function()
        for _, w in ipairs(vim.v.event.windows) do
            if api.nvim_win_is_valid(w) and not float(w) then return queue() end
        end
    end)
    au('WinEnter', function()
        if not is_pad(0) then return end
        vim.schedule(function()
            local w = api.nvim_get_current_win()
            local o = is_pad(w) and owner(w)
            if o and api.nvim_win_is_valid(o) then api.nvim_set_current_win(o) else queue() end
        end)
    end)
    au('QuitPre', function()
        local w = api.nvim_get_current_win()
        if pads[w] and #wins(0) == 1 then unpad(w) end
        queue()
    end)
    for _, k in ipairs({ 'h', 'j', 'k', 'l' }) do
        vim.keymap.set({ 'n', 'x' }, '<C-' .. k .. '>', function() M.nav(k) end, { desc = 'Window ' .. k })
    end
    vim.keymap.set('n', '<C-w>w', function() M.cycle(false) end, { desc = 'Next window' })
    vim.keymap.set('n', '<C-w><C-w>', function() M.cycle(false) end, { desc = 'Next window' })
    vim.keymap.set('n', '<C-w>W', function() M.cycle(true) end, { desc = 'Previous window' })
end

return M
