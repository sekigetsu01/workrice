" Neovim: its settings, plugins and keys (Space is the leader); the files in plugin/ add more and load by themselves
let mapleader =" "

augroup init
	autocmd!
augroup END

let g:loaded_node_provider = 0
let g:loaded_perl_provider = 0
let g:loaded_python3_provider = 0
let g:loaded_ruby_provider = 0
let g:surround_no_mappings = 1
let g:AutoPairsMapCh = 0
let g:AutoPairsMapCR = 0
let g:vimwiki_global_ext = 0
let g:vimwiki_map_prefix = '<leader>W'
let g:vimwiki_list = [{'path': '~/sync/notes/vimwiki', 'syntax': 'markdown', 'ext': '.md', 'diary_rel_path': 'journal/', 'diary_index': 'journal'}]
let g:user_emmet_install_global = 0
let g:user_emmet_leader_key = ','

lua << EOF
vim.loader.enable()
local argv = vim.v.argv
local scripted = vim.tbl_contains(argv, '--headless') and not vim.tbl_contains(argv, '--embed')

local function blink_lib(wait)
    local done = false
    local ok = pcall(function()
        require('blink.cmp.fuzzy.download').ensure_downloaded(function() done = true end)
    end)
    if ok and wait then vim.wait(120000, function() return done end, 100) end
end

vim.api.nvim_create_autocmd('PackChanged', {
    group = vim.api.nvim_create_augroup('UserPack', { clear = true }),
    callback = function(ev)
        local name = ev.data.spec.name
        if ev.data.kind ~= 'update' or (name ~= 'nvim-treesitter' and name ~= 'blink.cmp') then return end
        if not ev.data.active then vim.cmd.packadd(name) end
        if name == 'blink.cmp' then
            blink_lib(scripted)
        elseif vim.fn.executable('tree-sitter') == 1 then
            local task = require('nvim-treesitter').update()
            if scripted then task:pwait(600000) end
        end
    end,
})

local function gh(repo) return 'https://github.com/' .. repo end
local ok, err = pcall(vim.pack.add, {
    gh('tpope/vim-surround'),
    gh('lukas-reineke/indent-blankline.nvim'),
    gh('HiPhish/rainbow-delimiters.nvim'),
    gh('junegunn/goyo.vim'),
    gh('vimwiki/vimwiki'),
    gh('jiangmiao/auto-pairs'),
    gh('ap/vim-css-color'),
    gh('mattn/emmet-vim'),
    { src = gh('AlphaTechnolog/pywal.nvim'), name = 'pywal' },
    { src = gh('nvim-treesitter/nvim-treesitter'), version = 'main' },
    gh('nvim-lualine/lualine.nvim'),
    gh('stevearc/conform.nvim'),
    gh('ibhagwan/fzf-lua'),
    { src = gh('saghen/blink.cmp'), version = vim.version.range('1') },
    gh('mason-org/mason.nvim'),
    gh('mason-org/mason-lspconfig.nvim'),
    gh('neovim/nvim-lspconfig'),
    gh('lewis6991/gitsigns.nvim'),
    gh('folke/which-key.nvim'),
    gh('folke/flash.nvim'),
    gh('3rd/image.nvim'),
    gh('goolord/alpha-nvim'),
    gh('folke/snacks.nvim'),
}, { confirm = false })
if not ok then
    vim.g.pack_err = err
    vim.schedule(function() vim.notify(err, vim.log.levels.ERROR) end)
end
if scripted then blink_lib(true) end

-- :PackUpdate updates all plugins and drops unlisted ones
vim.api.nvim_create_user_command('PackUpdate', function()
    local gone = vim.iter(vim.pack.get(nil, { info = false }))
        :filter(function(p) return not p.active end)
        :map(function(p) return p.spec.name end)
        :totable()
    if #gone > 0 then vim.pack.del(gone) end
    if not scripted then return vim.pack.update() end
    local log = vim.fn.stdpath('log') .. '/nvim-pack.log'
    local seen = vim.fn.filereadable(log) == 1 and #vim.fn.readfile(log) or 0
    vim.pack.update(nil, { force = true })
    local new = vim.list_slice(vim.fn.readfile(log), seen + 1)
    if vim.g.pack_err or vim.iter(new):any(function(l) return l:find('^# Error') ~= nil end) then
        vim.cmd.cquit()
    end
end, { desc = 'Update plugins' })

local function exe(...)
    for _, c in ipairs({ ... }) do
        if vim.fn.executable(c) == 1 then return c end
    end
end

local conform_ok, conform = pcall(require, "conform")
if conform_ok then
    local on_save = { javascript = true, css = true, html = true, qml = true }
    local pkg = { prettier = "prettier", shfmt = "shfmt", qmlformat = "qt6-declarative" }
    conform.setup({
        formatters_by_ft = {
            javascript = { "prettier" },
            typescript = { "prettier" },
            css        = { "prettier" },
            html       = { "prettier" },
            json       = { "prettier" },
            yaml       = { "prettier" },
            qml        = { "qmlformat" },
            sh         = { "shfmt" },
            bash       = { "shfmt" },
        },
        formatters = {
            qmlformat = { command = exe("qmlformat", "/usr/lib/qt6/bin/qmlformat", "qmlformat6") or "qmlformat" },
            shfmt = {
                args = function(_, ctx)
                    local args = { "-filename", "$FILENAME" }
                    if vim.fs.find(".editorconfig", { path = ctx.dirname, upward = true })[1] then return args end
                    local ind, opener = 4, false
                    for _, l in ipairs(vim.api.nvim_buf_get_lines(ctx.buf, 0, 1000, false)) do
                        if l:match("^\t") then ind = 0 break end
                        local sp = l:match("^( +)%S")
                        if sp and opener then ind = #sp break end
                        opener = l:match("[{(]%s*$") or l:match("%f[%w]then%s*$") or l:match("%f[%w]do%s*$")
                            or l:match("^%s*else%s*$")
                    end
                    return vim.list_extend(args, { "-i", tostring(ind) })
                end,
            },
        },
        default_format_opts = { lsp_format = "fallback" },
        format_on_save = function(buf)
            if on_save[vim.bo[buf].filetype] then return { timeout_ms = 1000, lsp_format = "never" } end
        end,
    })

    vim.keymap.set({ "n", "x" }, "<leader>f", function()
        local ft = vim.bo.filetype
        local run, lsp = conform.list_formatters_to_run(0)
        if #run == 0 then
            local need = {}
            for _, name in ipairs(conform.list_formatters_for_buffer(0)) do
                need[#need + 1] = pkg[name] or name
            end
            if #need > 0 then
                return vim.notify("Install " .. table.concat(need, " or ") .. " to format " .. ft .. " files", vim.log.levels.WARN)
            elseif not lsp then
                return vim.notify("No formatter for " .. (ft == "" and "this" or ft) .. " files", vim.log.levels.WARN)
            end
        end
        local by = #run > 0 and table.concat(vim.tbl_map(function(f) return f.name end, run), ", ") or "the language server"
        conform.format({ async = true }, function(err, edited)
            if not err then vim.notify(edited and "Formatted with " .. by or "Already formatted (" .. by .. ")") end
        end)
    end, { desc = "Format file" })
end

-- Space s: shellcheck the buffer
vim.keymap.set("n", "<leader>s", function()
    local ft, buf = vim.bo.filetype, vim.api.nvim_get_current_buf()
    if ft ~= "sh" and ft ~= "bash" then
        return vim.notify("shellcheck checks sh and bash scripts, not " .. (ft == "" and "this file" or ft), vim.log.levels.WARN)
    elseif not exe("shellcheck") then
        return vim.notify("Install shellcheck to check scripts", vim.log.levels.WARN)
    end
    local dir = vim.fn.expand("%:p:h")
    vim.system({ "shellcheck", "-x", "-f", "gcc", "-" }, {
        stdin = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n",
        cwd = vim.fn.isdirectory(dir) == 1 and dir or nil,
        text = true,
    }, vim.schedule_wrap(function(r)
        local items = {}
        for l in r.stdout:gmatch("[^\n]+") do
            local file, lnum, col, kind, text = l:match("^(.-):(%d+):(%d+): (%a+): (.*)$")
            if file then
                items[#items + 1] = {
                    bufnr = file == "-" and buf or nil, filename = file ~= "-" and file or nil,
                    lnum = tonumber(lnum), col = tonumber(col), type = kind:sub(1, 1):upper(), text = text,
                }
            end
        end
        if #items == 0 and r.code ~= 0 then
            return vim.notify("shellcheck failed: " .. vim.trim(r.stderr), vim.log.levels.ERROR)
        end
        local win = vim.fn.bufwinid(buf)
        if win == -1 then return end
        vim.fn.setloclist(win, {}, " ", { title = "shellcheck", items = items })
        vim.api.nvim_win_call(win, function() vim.cmd(#items > 0 and "lopen" or "lclose") end)
        vim.notify(#items > 0 and ("shellcheck: %d problem%s"):format(#items, #items == 1 and "" or "s") or "shellcheck: no problems")
    end))
end, { desc = "shellcheck this script" })

package.preload['fzf-lua'] = function()
    package.preload['fzf-lua'] = nil
    local fzf = dofile(vim.api.nvim_get_runtime_file('lua/fzf-lua/init.lua', false)[1])
    package.loaded['fzf-lua'] = fzf
    fzf.setup({
        keymap = { fzf = { true, ['ctrl-j'] = 'down', ['ctrl-k'] = 'up' } },
        files = {
            fd_opts   = [[--color=never --type f --type l --exclude .git --exclude node_modules]],
            rg_opts   = [[--color=never --files -g '!.git' -g '!node_modules']],
            find_opts = [[-type f \! -path '*/.git/*' \! -path '*/node_modules/*']],
        },
        grep = {
            rg_opts = [[--hidden -g '!.git' -g '!node_modules' --column --line-number --no-heading --color=always --smart-case --max-columns=4096 -e]],
        },
    })
    return fzf
end

local function wal(name, fallback) return vim.g[name] or fallback end

local blink_ok, blink = pcall(require, 'blink.cmp')
if blink_ok then
    local function pairs_return()
        if not vim.b.autopairs_enabled or vim.fn.exists('*AutoPairsReturn') == 0 then return end
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, 'i')) do
            if m.lhs == '<CR>' and not (m.desc or ''):find('^blink') then return end
        end
        vim.api.nvim_feedkeys(vim.keycode("<Cmd>call feedkeys(AutoPairsReturn(), 'n')<CR>"), 'n', false)
    end
    local function pum(key)
        return function() if vim.fn.pumvisible() == 1 then return vim.keycode(key) end end
    end
    blink.setup({
        keymap = {
            preset      = 'none',
            ['<C-Space>'] = { 'show' },
            ['<C-e>']     = { 'cancel', 'fallback' },
            ['<CR>']      = { 'accept', pairs_return, 'fallback' },
            ['<C-y>']     = { 'accept', 'fallback' },
            ['<Tab>']     = { 'select_next', 'fallback' },
            ['<S-Tab>']   = { 'select_prev', 'fallback' },
            ['<C-n>']     = { 'select_next', 'show' },
            ['<C-p>']     = { 'select_prev', 'show' },
            ['<C-j>']     = { pum('<C-n>'), 'select_next', 'fallback' },
            ['<C-k>']     = { pum('<C-p>'), 'select_prev', 'fallback' },
            ['<Down>']    = { 'select_next', 'fallback' },
            ['<Up>']      = { 'select_prev', 'fallback' },
        },
        completion = {
            list          = { selection = { preselect = false } },
            trigger       = { show_on_trigger_character = false },
            accept        = { auto_brackets = { enabled = false } },
            menu          = {
                border = 'rounded',
                min_width = 1,
                winblend = 0,
                winhighlight = 'Normal:BlinkCmpMenu,FloatBorder:BlinkCmpMenuBorder,CursorLine:BlinkCmpMenuSelection,Search:None',
                draw = { padding = { 1, 1 }, gap = 2, columns = { { 'label' } } },
            },
            documentation = {
                auto_show = false,
                window = {
                    border = 'rounded',
                    winblend = 0,
                    winhighlight = 'Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,EndOfBuffer:BlinkCmpDoc,Search:None',
                },
            },
        },
        -- completion: only words from the file you're in
        sources = {
            min_keyword_length = 1,
            default = { 'buffer' },
            providers = { buffer = { opts = { get_bufnrs = function() return { vim.api.nvim_get_current_buf() } end } } },
        },
        cmdline = { enabled = false },
    })
    local function rgb(hex)
        hex = tostring(hex):gsub('#', '')
        return tonumber(hex:sub(1, 2), 16) or 0, tonumber(hex:sub(3, 4), 16) or 0, tonumber(hex:sub(5, 6), 16) or 0
    end
    local function mix(a, b, t)
        local r1, g1, b1 = rgb(a)
        local r2, g2, b2 = rgb(b)
        local function m(x, y) return math.floor(x + (y - x) * t + 0.5) end
        return ('#%02x%02x%02x'):format(m(r1, r2), m(g1, g2), m(b1, b2))
    end
    local function cmp_colours()
        for blink_hl, cmp_hl in pairs({ BlinkCmpLabel = 'CmpItemAbbr', BlinkCmpLabelMatch = 'CmpItemAbbrMatch',
            BlinkCmpLabelDeprecated = 'CmpItemAbbrDeprecated', BlinkCmpKind = 'CmpItemKind' }) do
            local h = vim.api.nvim_get_hl(0, { name = cmp_hl, link = false })
            vim.api.nvim_set_hl(0, blink_hl, { fg = h.fg })
        end
        local bg, fg = wal('background', '#1c1c1c'), wal('foreground', '#c0c0c0')
        local box = mix(bg, '#000000', 0.5)
        local sel = mix(box, wal('color4', '#5f87af'), 0.45)
        local edge = wal('color8', '#6c6c6c')
        local set = vim.api.nvim_set_hl
        set(0, 'BlinkCmpMenu', { fg = fg, bg = box })
        set(0, 'BlinkCmpMenuBorder', { fg = edge, bg = box })
        set(0, 'BlinkCmpMenuSelection', { fg = fg, bg = sel, bold = true })
        set(0, 'BlinkCmpDoc', { fg = fg, bg = box })
        set(0, 'BlinkCmpDocBorder', { fg = edge, bg = box })
        set(0, 'BlinkCmpDocSeparator', { fg = edge, bg = box })
        set(0, 'BlinkCmpScrollBarThumb', { bg = edge })
        set(0, 'BlinkCmpScrollBarGutter', { bg = box })
        set(0, 'Pmenu', { fg = fg, bg = box })
        set(0, 'PmenuSel', { fg = fg, bg = sel, bold = true })
        set(0, 'PmenuSbar', { bg = box })
        set(0, 'PmenuThumb', { bg = edge })
    end
    cmp_colours()
    vim.api.nvim_create_autocmd('ColorScheme', { group = vim.api.nvim_create_augroup('UserBlinkCmpColours', { clear = true }), callback = cmp_colours })
end

local ts_ok, ts = pcall(require, 'nvim-treesitter')
if ts_ok then
    local can_build = vim.fn.executable('tree-sitter') == 1
        and (vim.fn.executable('cc') == 1 or vim.fn.executable('gcc') == 1 or vim.fn.executable('clang') == 1)
    if not can_build then
        vim.schedule(function()
            vim.notify('Treesitter: install tree-sitter-cli and gcc to build parsers', vim.log.levels.WARN)
        end)
    elseif scripted then
        local done, task = pcall(ts.install, {
            "bash", "c", "cpp", "css", "html", "javascript", "json", "lua", "markdown",
            "python", "rust", "toml", "typescript", "vim", "vimdoc", "yaml",
        })
        if done then task:pwait(600000) end
    end

    local light_md = false
    local function lighten_markdown()
        light_md = true
        local src = {}
        for _, f in ipairs(vim.treesitter.query.get_files('markdown', 'highlights')) do
            src[#src + 1] = table.concat(vim.fn.readfile(f), '\n')
        end
        local q = table.concat(src, '\n')
        if q:find('conceal_lines', 1, true) then
            pcall(vim.treesitter.query.set, 'markdown', 'highlights', (q:gsub('%(#set! conceal_lines ""%)', '')))
        end
    end

    local available
    vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('UserTreesitter', { clear = true }),
        callback = function(args)
            if args.match == 'vimwiki' then return end
            local lang = vim.treesitter.language.get_lang(args.match)
            if not lang then return end
            if lang == 'markdown' and not light_md then
                lighten_markdown()
                local hl = vim.treesitter.highlighter.active[args.buf]
                if hl then hl._queries, hl._conceal_line, hl._conceal_checked = {}, nil, {} end
            end
            if pcall(vim.treesitter.start, args.buf, lang) then
                vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                return
            end
            if not available then
                available = {}
                for _, l in ipairs(ts.get_available()) do available[l] = true end
            end
            if can_build and available[lang] then
                ts.install({ lang }):await(function()
                    vim.schedule(function()
                        if vim.api.nvim_buf_is_valid(args.buf) then pcall(vim.treesitter.start, args.buf, lang) end
                    end)
                end)
            end
        end,
    })
end

local ll_ok, lualine = pcall(require, 'lualine')
if ll_ok then
    local function theme()
        local c = {
            bg     = 'NONE',
            fg     = wal('foreground', '#c0c0c0'),
            red    = wal('color1', '#E06C75'),
            orange = wal('color7', '#D19A66'),
            yellow = wal('color3', '#E5C07B'),
            green  = wal('color2', '#98C379'),
            violet = wal('color5', '#C678DD'),
            gray   = wal('color8', '#504945'),
        }
        local function mode(col)
            return { a = { fg = c.bg, bg = col, gui = 'bold' }, b = { fg = c.fg, bg = c.gray }, c = { fg = c.fg, bg = c.bg } }
        end
        local dim = { fg = c.gray, bg = c.bg }
        return {
            normal = mode(c.red), insert = mode(c.green), visual = mode(c.violet),
            replace = mode(c.orange), command = mode(c.yellow),
            inactive = { a = dim, b = dim, c = dim },
        }
    end

    local wc_cache = {}
    local function commas(n)
        local s, k = tostring(n), 1
        while k > 0 do s, k = s:gsub('^(%d+)(%d%d%d)', '%1,%2') end
        return s
    end
    local function words()
        if vim.bo.buftype ~= '' then return '' end
        if vim.fn.mode():find('[vV\22]') then
            local n = vim.fn.wordcount().visual_words or 0
            return commas(n) .. (n == 1 and ' word selected' or ' words selected')
        end
        local b, t = vim.api.nvim_get_current_buf(), vim.b.changedtick
        local e = wc_cache[b]
        local typing = e and vim.fn.mode() == 'i' and vim.uv.now() - e.at < 1000
        if not e or (e.t ~= t and not typing) then
            local n = vim.fn.wordcount().words
            local min = math.floor(n / 238 + 0.5)
            e = { t = t, at = vim.uv.now(), s = commas(n) .. (n == 1 and ' word' or ' words') .. (min >= 1 and (' · ' .. min .. ' min') or '') }
            wc_cache[b] = e
        end
        return e.s
    end
    vim.api.nvim_create_autocmd('BufWipeout', {
        group = vim.api.nvim_create_augroup('UserWordCount', { clear = true }),
        callback = function(a) wc_cache[a.buf] = nil end,
    })

    local ll_opts = {
        options = {
            theme = theme(),
            component_separators = { left = '│', right = '│' },
            section_separators   = { left = '',  right = '' },
            globalstatus         = true,
        },
        sections = {
            lualine_a = { 'mode' },
            lualine_b = { 'branch', 'diff' },
            lualine_c = { { 'filename', path = 1 } },
            lualine_x = { 'searchcount', 'selectioncount', words, 'filetype' },
            lualine_y = { 'progress' },
            lualine_z = { 'location' },
        },
    }
    lualine.setup(ll_opts)
    vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('UserLualineWal', { clear = true }),
        callback = function()
            ll_opts.options.theme = theme()
            lualine.setup(ll_opts)
        end,
    })

    local grp = vim.api.nvim_create_augroup('UserGoyoLualine', { clear = true })
    local hidden = false
    local function show_status()
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do vim.wo[w].statusline = hidden and ' ' or '' end
    end
    vim.keymap.set('n', '<leader>h', function()
        hidden = not hidden
        lualine.hide({ place = { 'statusline' }, unhide = not hidden })
        vim.o.laststatus = hidden and 0 or 3
        if vim.fn.exists('#goyo') == 1 then show_status() end
    end, { desc = 'Hide / show the status line' })
    vim.api.nvim_create_autocmd('User', { group = grp, pattern = 'GoyoEnter', callback = function()
        vim.o.laststatus = hidden and 0 or 3
        show_status()
        vim.api.nvim_create_autocmd({ 'WinEnter', 'WinLeave', 'BufWinEnter' }, {
            group = vim.api.nvim_create_augroup('UserGoyoStatus', { clear = true }),
            callback = show_status,
        })
    end })
    vim.api.nvim_create_autocmd('User', { group = grp, pattern = 'GoyoLeave', callback = function()
        pcall(vim.api.nvim_del_augroup_by_name, 'UserGoyoStatus')
    end })
end

local function lines_map(lhs, fn, desc)
    vim.keymap.set('n', lhs, function() fn(1, vim.api.nvim_buf_line_count(0)) end, { desc = desc })
    vim.keymap.set('x', lhs, function()
        local a, b = vim.fn.line('v'), vim.fn.line('.')
        vim.api.nvim_feedkeys(vim.keycode('<Esc>'), 'nx', false)
        fn(math.min(a, b), math.max(a, b))
    end, { desc = desc })
end

-- Space y: copy as flowing text (wrapped lines joined)
local function unwrap_lines(lines)
    local out, para, in_code, in_list, pic = {}, nil, false, false, false
    local function flush()
        if para then table.insert(out, para); para = nil end
    end
    for _, raw in ipairs(lines) do
        local line = raw:gsub('%s+$', '')
        local text = in_code and line or line:gsub('!%[[^%]]*%]%([^%)]*%)', ''):gsub('<img%s[^>]*>', '')
        if text ~= line then line = text:gsub('(%S)%s%s+', '%1 '):gsub('%s+$', '') end
        if line:match('^%s*```') then
            flush(); table.insert(out, line); in_code = not in_code
        elseif in_code then
            table.insert(out, raw)
        elseif line == '' and text ~= raw:gsub('%s+$', '') then
            flush(); pic = true
        elseif line == '' then
            flush()
            if not (pic and (#out == 0 or out[#out] == '')) then table.insert(out, '') end
        elseif line:match('^%s*#+%s') or line:match('^%s*#+$') then
            flush(); table.insert(out, line)
        elseif line:match('^%s*[-*+] ') or line:match('^%s*%d+[.)] ') then
            flush(); para, in_list = line, true
        elseif line:match('^%s*|') then
            flush(); table.insert(out, line); in_list = false
        elseif line:match('^%s*#') or line:match('^%s*>') then
            flush(); para, in_list = line, false
        elseif para and not (in_list and not line:match('^%s')) then
            para = para .. ' ' .. line:gsub('^%s+', '')
        else
            flush(); para, in_list = line, false
        end
        if line ~= '' then pic = false end
    end
    flush()
    return out
end

lines_map('<leader>y', function(first, last)
    local text = table.concat(unwrap_lines(vim.api.nvim_buf_get_lines(0, first - 1, last, false)), '\n')
    vim.fn.setreg('+', text)
    vim.fn.setreg('"', text)
    vim.notify(('Copied %d lines as flowing text'):format(last - first + 1))
end, 'Copy as flowing text')

vim.diagnostic.config({
    virtual_text  = true,
    severity_sort = true,
    float         = { border = 'rounded' },
})

vim.schedule(function()
    vim.lsp.config('lua_ls', {
        settings = { Lua = {
            runtime   = { version = 'LuaJIT' },
            workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
        } },
    })
    local qmlls = exe('qmlls', '/usr/lib/qt6/bin/qmlls', 'qmlls6')
    if qmlls then
        vim.lsp.config('qmlls', { cmd = { qmlls }, filetypes = { 'qml' }, root_markers = { '.qmlls.ini', '.git' } })
        vim.lsp.enable('qmlls')
    end
    local mason_ok, mason = pcall(require, 'mason')
    local mlsp_ok, mlsp = pcall(require, 'mason-lspconfig')
    if mason_ok then mason.setup({ ui = { border = 'rounded' } }) end
    if mason_ok and mlsp_ok then
        mlsp.setup({ ensure_installed = { 'bashls', 'lua_ls', 'pyright', 'jsonls', 'cssls', 'html' } })
    end
    pcall(vim.cmd.doautoall, 'nvim.lsp.enable FileType')
end)

local gs_ok, gitsigns = pcall(require, 'gitsigns')
if gs_ok then
    gitsigns.setup({})
end

local flash_ok, flash = pcall(require, 'flash')
if flash_ok then
    flash.setup({})
    vim.keymap.set({ 'n', 'x', 'o' }, 's',  flash.jump,       { desc = 'Flash: jump' })
    vim.keymap.set({ 'n', 'x', 'o' }, 'gs', flash.treesitter, { desc = 'Flash: select block' })
    vim.keymap.set('o', 'r', flash.remote, { desc = 'Flash: remote' })
    vim.keymap.set('c', '<C-s>', flash.toggle, { desc = 'Flash: labels in search' })
end

local wk_ok, wk = pcall(require, 'which-key')
if wk_ok then
    -- Space ? lists the Space keys
    wk.setup({ triggers = {}, plugins = { marks = false, registers = false } })
    wk.add({
        { '<leader>?', function() wk.show({ keys = '<leader>' }) end, desc = 'List the Space keys' },
    })
end

local alpha_ok, alpha = pcall(require, 'alpha')
if alpha_ok then
    local dashboard = require('alpha.themes.dashboard')
    dashboard.section.header.val = {
        "                                                     ",
        "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
        "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
        "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
        "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
        "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
        "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
        "                                                     ",
    }
    dashboard.section.buttons.val = {
        dashboard.button("e", "  new file",     "<cmd>enew<CR>"),
        dashboard.button("f", "  find file",    "<cmd>FzfLua files<CR>"),
        dashboard.button("g", "  grep",         "<cmd>FzfLua live_grep<CR>"),
        dashboard.button("r", "  recent files", "<cmd>FzfLua oldfiles<CR>"),
        dashboard.button("n", "  notes",        "<cmd>VimwikiIndex<CR>"),
        dashboard.button("c", "  config",       "<cmd>e $MYVIMRC<CR>"),
        dashboard.button("q", "  quit",         "<cmd>qa<CR>"),
    }
    local v = vim.version()
    dashboard.section.footer.val = "v" .. v.major .. "." .. v.minor .. "." .. v.patch
    dashboard.section.header.opts.hl  = "Keyword"
    dashboard.section.footer.opts.hl  = "Comment"
    dashboard.section.buttons.opts.hl = "Function"
    dashboard.opts.opts.noautocmd = true
    alpha.setup(dashboard.opts)
end

local ibl_ok, ibl = pcall(require, "ibl")
if ibl_ok then
    local hooks = require("ibl.hooks")
    local glow = {
        GlowRed = { "color1", "#ff6e7a" }, GlowOrange = { "color7", "#ffaa5e" }, GlowYellow = { "color3", "#ffe066" },
        GlowGreen = { "color2", "#aaee88" }, GlowCyan = { "color6", "#66e8e8" }, GlowBlue = { "color4", "#88c8ff" },
        GlowViolet = { "color5", "#dd99ff" },
    }
    local highlight = { "GlowRed", "GlowOrange", "GlowYellow", "GlowGreen", "GlowCyan", "GlowBlue", "GlowViolet" }
    hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        for name, w in pairs(glow) do vim.api.nvim_set_hl(0, name, { fg = wal(w[1], w[2]), bold = true }) end
    end)
    vim.g.rainbow_delimiters = { highlight = highlight }
    ibl.setup({ indent = { char = "│", highlight = highlight }, scope = { enabled = false },
        exclude = { filetypes = { "alpha" } } })
    hooks.register(hooks.type.WHITESPACE, hooks.builtin.hide_first_space_indent_level)
    hooks.register(hooks.type.SKIP_LINE, function(_, bufnr, row)
        local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
        local s = line:match("^%s*(.*)")
        return s:match("^//") ~= nil or s:match("^#") ~= nil or s:match("^%-%-") ~= nil
            or s:match("^/?%*") ~= nil
    end)
end

-- Space b: define the word (or the selected words) in the browser
local function define(text)
    text = vim.trim((text:gsub('%s+', ' ')))
    if text == '' then return end
    local url = 'https://duckduckgo.com/?q={searchTerms}'
    local ok, lines = pcall(vim.fn.readfile, vim.fn.expand('~/.config/glide/search.js'))
    if ok then url = table.concat(lines, '\n'):match('"(https?://[^"]-{searchTerms}[^"]-)"') or url end
    local q = vim.uri_encode('define ' .. text, 'rfc3986')
    vim.ui.open((url:gsub('{searchTerms}', function() return q end)))
    vim.fn.jobstart({ vim.fn.expand('~/.config/mango/scripts/mm'), 'focus', 'glide' }, { detach = true })
end
vim.keymap.set('n', '<leader>b', function() define(vim.fn.expand('<cword>')) end,
    { desc = 'Define this word (browser)' })
vim.keymap.set('x', '<leader>b', function()
    local text = table.concat(vim.fn.getregion(vim.fn.getpos('v'), vim.fn.getpos('.'), { type = vim.fn.mode() }), ' ')
    vim.api.nvim_feedkeys(vim.keycode('<Esc>'), 'nx', false)
    define(text)
end, { desc = 'Define the selection (browser)' })

-- S: rename every match of the word under the cursor, or of the selection
local function is_kw(c) return c ~= '' and vim.fn.match(c, [[\k]]) == 0 end
local function rename(text, lb, rb)
    local keys = ':%s//g'
    if text ~= '' then
        local pat = vim.fn.escape(text, [[\/]]):gsub('\n', [[\n]])
        local rep = vim.fn.escape(text, [[\/]]):gsub('\n', [[\r]])
        keys = ':%sno/\\V\\C' .. (lb and [[\<]] or '') .. pat .. (rb and [[\>]] or '') .. '/' .. rep .. '/g'
    end
    vim.api.nvim_feedkeys(keys .. vim.keycode('<Left><Left>'), 'in', false)
end
vim.keymap.set('n', 'S', function()
    local line, col = vim.api.nvim_get_current_line(), vim.fn.col('.')
    local ch = vim.fn.strcharpart(line:sub(col), 0, 1)
    if is_kw(ch) then return rename(vim.fn.expand('<cword>'), true, true) end
    if not ch:match('%S') then return rename('') end
    local s, e = col, col
    while s > 1 and not is_kw(line:sub(s - 1, s - 1)) and line:sub(s - 1, s - 1):match('%S') do s = s - 1 end
    while e < #line and not is_kw(line:sub(e + 1, e + 1)) and line:sub(e + 1, e + 1):match('%S') do e = e + 1 end
    rename(line:sub(s, e), false, false)
end, { desc = 'Rename every match of the word or symbol under the cursor' })
vim.keymap.set('x', 'S', function()
    local saved, kind = vim.fn.getreg('z'), vim.fn.getregtype('z')
    vim.cmd('noautocmd normal! "zy')
    local text = vim.fn.getreg('z')
    vim.fn.setreg('z', saved, kind)
    local a, b = vim.fn.getpos("'<"), vim.fn.getpos("'>")
    local first, last = vim.fn.getline(a[2]), vim.fn.getline(b[2])
    local lb = is_kw(text:sub(1, 1)) and not is_kw(first:sub(a[3] - 1, a[3] - 1))
    local rb = is_kw(text:sub(-1)) and not is_kw(last:sub(b[3] + 1, b[3] + 1))
    rename(text, lb, rb)
end, { desc = 'Rename every match of the selection' })

require('prosepad').setup()
EOF

autocmd init FileType html,css,htmldjango,xml,svelte,vue silent! EmmetInstall

nmap ds  <Plug>Dsurround
nmap cs  <Plug>Csurround
nmap cS  <Plug>CSurround
nmap ys  <Plug>Ysurround
nmap yS  <Plug>YSurround
nmap yss <Plug>Yssurround
nmap ySs <Plug>YSsurround
nmap ySS <Plug>YSsurround
xmap gS  <Plug>VgSurround
imap <C-S>  <Plug>Isurround
imap <C-G>s <Plug>Isurround
imap <C-G>S <Plug>ISurround

set title linebreak noshowmode noruler noshowcmd nohlsearch undofile
set spell spelllang=en_us
set bg=dark
set mouse=a
set clipboard+=unnamedplus
set laststatus=3
set timeoutlen=300
set ignorecase smartcase
set scrolloff=8
set number relativenumber
set wildmode=longest,list,full
set splitbelow splitright
set noswapfile
set shortmess+=aAI
set display=lastline
let &fillchars = join(filter([&fillchars, 'lastline: '], '!empty(v:val)'), ',')
" private and temporary files: no undo file and no history
function! s:Private() abort
	setlocal noundofile
	if &shadafile ==# 'NONE' | return | endif
	execute 'set shada+=r' . escape(expand('<afile>:p:h'), ' ,\') . '/'
	if v:vim_did_enter | wshada | endif
	set shadafile=NONE
endfunction
augroup private_files
	autocmd!
	autocmd BufReadPre,BufNewFile */private/*,/tmp/*,/dev/shm/*,/run/user/* call s:Private()
augroup END
autocmd init FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o
autocmd init VimEnter,FocusGained * let g:focused_at = luaeval('vim.uv.hrtime()')

function! WalReload() abort
	if !filereadable($HOME . '/.cache/wal/colors-wal.vim') | return | endif
	silent! colorscheme pywal
	let g:colors_name = 'pywal'
endfunction
call WalReload()

function! s:ClearBg() abort
	for group in ['Normal', 'NormalNC', 'NormalFloat', 'SignColumn', 'LineNr', 'CursorLineNr', 'EndOfBuffer', 'FoldColumn']
		execute 'highlight' group 'guibg=NONE ctermbg=NONE'
	endfor
	if &diff | highlight! link DiffText MatchParen | endif
endfunction
autocmd init ColorScheme * call s:ClearBg()
call s:ClearBg()

nnoremap <expr> j v:count ? 'j' : 'gj'
nnoremap <expr> k v:count ? 'k' : 'gk'
xnoremap <expr> j v:count ? 'j' : 'gj'
xnoremap <expr> k v:count ? 'k' : 'gk'
nnoremap <silent> n nzzzv
nnoremap <silent> N Nzzzv
nnoremap c "_c
xnoremap . :normal .<CR>
nnoremap Q gq
xnoremap Q gq
onoremap Q gq
nnoremap ZA <cmd>w<CR>
inoremap <C-BS> <C-w>
inoremap <C-h> <C-w>
cnoremap <C-BS> <C-w>
cnoremap <C-h> <C-w>

nnoremap <leader>j o<Esc>
nnoremap <leader>k O<Esc>
" Space x: open the file with its default app
function! s:OpenFile() abort
	if empty(expand('%')) | echo 'Save it first' | return | endif
	if &modified | silent update | endif
	call jobstart(['xdg-open', expand('%:p')], {'detach': 1})
endfunction
nnoremap <leader>x <cmd>call <SID>OpenFile()<CR>
function! s:Centre() abort
	let g:centred = !get(g:, 'centred', 1)
	call luaeval("require'prosepad'.set(_A)", g:centred ? v:true : v:false)
	if !g:centred
		if exists('#goyo') | Goyo! | endif
	elseif !exists('#goyo')
		call s:WikiGoyo()
		if !exists('#goyo') | Goyo | endif
	endif
endfunction
nnoremap <leader>G <cmd>call <SID>Centre()<CR>
nnoremap <leader>o <cmd>setlocal spell!<CR>
nnoremap <leader>N <cmd>if &l:number \|\| &l:relativenumber \| setlocal nonumber norelativenumber \| else \| setlocal number relativenumber \| endif<CR>
nnoremap <leader>c <cmd>silent %yank +<Bar>echo 'Copied ' . line('$') . ' lines'<CR>
nnoremap <leader>v <cmd>VimwikiIndex<CR>

" Space w: a shell in a split, in the file's folder
nnoremap <leader>w <cmd>call <SID>TermHere()<CR>
function! s:TermHere() abort
	let dir = expand('%:p:h')
	if empty(dir) || !isdirectory(dir) | let dir = getcwd() | endif
	split | enew
	call jobstart([&shell], {'term': v:true, 'cwd': dir})
	startinsert
endfunction
" Esc leaves insert mode in a shell terminal
autocmd init TermOpen * if fnamemodify(matchstr(bufname(), '//\d\+:\zs\S*'), ':t') ==# fnamemodify(&shell, ':t')
	\ | tnoremap <buffer> <Esc> <C-\><C-n>| endif

nnoremap <leader>z <cmd>call <SID>ToggleZoom()<CR>
function! s:ToggleZoom() abort
	if luaeval("require'prosepad'.count()") == 1 | return | endif
	if exists('t:zoom_restore')
		execute t:zoom_restore
		unlet t:zoom_restore
	else
		let t:zoom_restore = winrestcmd()
		wincmd |
		wincmd _
	endif
endfunction

" Space d: this file as a Word document (doc); Space D: and a PDF
function! s:DocDone(out, err, code) abort
	if a:code | echohl ErrorMsg | echo join(a:out + a:err, ' ') | echohl None
	else | echo 'Saved ' . join(map(copy(a:out), 'fnamemodify(v:val, ":t")'), ', ')
		\ . (empty(a:err) ? '' : ' (' . join(a:err, ' ') . ')') | endif
endfunction
function! s:Doc(pdf) abort
	if empty(expand('%')) | echo 'Save the file first' | return | endif
	silent update
	echo 'Making ' . (a:pdf ? 'Word + PDF' : 'Word') . '…'
	let l:out = []
	let l:err = []
	call jobstart(['doc'] + (a:pdf ? ['-p'] : []) + [expand('%:p')], {
		\ 'stdout_buffered': 1, 'stderr_buffered': 1,
		\ 'on_stdout': {_, d, __ -> extend(l:out, filter(d, 'v:val != ""'))},
		\ 'on_stderr': {_, d, __ -> extend(l:err, filter(d, 'v:val != ""'))},
		\ 'on_exit': {_, code, __ -> s:DocDone(l:out, l:err, code)}})
endfunction
nnoremap <leader>d <cmd>call <SID>Doc(0)<CR>
nnoremap <leader>D <cmd>call <SID>Doc(1)<CR>

let s:wiki = resolve(expand('~/sync/notes/vimwiki')) . '/'
let s:cmd = ''      " the command line being run
let s:force = -1    " ZZ (0) or ZQ (1) being run
let s:quit = {}     " the quit under way in a Goyo note, until Goyo has closed
function! s:WikiGoyo() abort
	let f = resolve(expand('%:p'))
	if exists('#goyo') || !get(g:, 'centred', 1) || stridx(f, s:wiki) != 0 | return | endif
	Goyo
	let g:wiki_goyo = 1
endfunction
function! s:ShowErr(msg) abort
	echohl ErrorMsg | echomsg substitute(a:msg, '^Vim(\a\+):', '', '') | echohl None
endfunction
function! s:Parse(line) abort
	return luaeval('(function(l) local ok, c = pcall(vim.api.nvim_parse_cmd, l, {}) '
		\ . 'if ok then return { c.cmd, c.bang } end return { "", false } end)(_A)', a:line)
endfunction
function! s:Forget(what) abort
	execute 'let s:' . a:what . ' = ' . (a:what ==# 'cmd' ? '""' : '{}')
endfunction
function! s:CmdLeave() abort
	if v:event.cmdtype !=# ':' || v:event.abort | return | endif
	let s:cmd = getcmdline()
	call timer_start(0, {-> s:Forget('cmd')})
	if get(g:, 'wiki_goyo') && exists('#goyo') && &modified && s:Parse(s:cmd) == ['quit', v:false]
		let v:event.abort = v:true
		call timer_start(0, {-> s:ShowErr('E37: No write since last change (add ! to override)')})
	endif
endfunction
function! s:QuitPre() abort
	if !get(g:, 'wiki_goyo') | return | endif
	let [name, bang] = s:Parse(s:cmd)
	let force = s:force >= 0 ? s:force : bang && (name ==# 'quit' || name ==# 'qall')
	let s:quit = {'force': force, 'buf': str2nr(expand('<abuf>')), 'view': winsaveview()}
	call timer_start(0, {-> s:Forget('quit')})
endfunction
function! s:GoyoLeave() abort
	let q = get(g:, 'wiki_goyo') ? s:quit : {}
	let g:wiki_goyo = 0
	let s:quit = {}
	if empty(q) | return | endif
	if q.force | call setbufvar(q.buf, '&modified', 0) | endif
	try
		qall
	catch /^Vim(qall):E/
		let err = v:exception
		call timer_start(0, {-> s:QuitFailed(q, err)})
	endtry
endfunction
function! s:QuitFailed(q, err) abort
	if a:q.force
		let other = filter(getbufinfo({'bufmodified': 1}), 'v:val.listed && v:val.bufnr != a:q.buf')
		if !empty(other) | execute 'buffer' other[0].bufnr | endif
		execute 'silent! bunload!' a:q.buf
	else
		if bufexists(a:q.buf) && bufnr() != a:q.buf | execute 'buffer' a:q.buf | endif
		call s:WikiGoyo()
		call winrestview(a:q.view)
	endif
	call s:ShowErr(a:err)
endfunction
function! s:ZQuit(force) abort
	let s:force = a:force
	try
		execute a:force ? 'quit!' : 'xit'
	catch /^Vim(\a\+):E/
		call s:ShowErr(v:exception)
	finally
		let s:force = -1
	endtry
endfunction
nnoremap <silent> ZZ <cmd>call <SID>ZQuit(0)<CR>
nnoremap <silent> ZQ <cmd>call <SID>ZQuit(1)<CR>
autocmd init BufWinEnter *.md call timer_start(0, {-> s:WikiGoyo()})
" the journal: journal/journal.md lists the years, journal/YEAR.md that year's days (the calendar writes each day to
" journal/YEAR/YEAR-MM-DD.md); both pages are remade each time they're opened (a link, or Space W i)
function! s:JournalDays(dir, y) abort
	let days = filter(glob(a:dir . a:y . '/' . a:y . '-[0-9][0-9]-[0-9][0-9].md', 0, 1), 'getfsize(v:val) > 0')
	return reverse(sort(map(days, 'fnamemodify(v:val, ":t:r")')))   " newest first
endfunction
function! s:JournalPage() abort
	let dir = s:wiki . 'journal/'
	let f = resolve(expand('%:p'))
	if stridx(f, dir) != 0 | return | endif
	let name = f[len(dir):]
	if name ==# 'journal.md'
		let years = reverse(sort(map(glob(dir . '[0-9][0-9][0-9][0-9]', 0, 1), 'fnamemodify(v:val, ":t")')))   " newest first
		let links = map(filter(years, {_, y -> !empty(s:JournalDays(dir, y))}), {_, y -> '[--' . y . '--](' . y . ')'})
	elseif name =~# '^\d\{4}\.md$'
		let y = name[:3]
		let links = map(s:JournalDays(dir, y), {_, d -> '[--' . d . '--](' . y . '/' . d . ')'})
	else
		return
	endif
	setlocal concealcursor=nc   " only the day or year shows, also on the cursor's line (these pages aren't edited)
	let out = []
	for l in links | let out += [l, ''] | endfor
	if !empty(out) | call remove(out, -1) | endif
	if empty(out) || getline(1, '$') ==# out | return | endif
	silent %delete _
	call setline(1, out)
	silent update
endfunction
autocmd init BufWinEnter *.md call s:JournalPage()
" deleting a line on a journal page and saving deletes what it pointed to: that day's entry, or that whole year
function! s:JournalDelete() abort
	let dir = s:wiki . 'journal/'
	let f = resolve(expand('%:p'))
	if stridx(f, dir) != 0 | return | endif
	let name = f[len(dir):]
	let kept = map(filter(getline(1, '$'), 'v:val =~# "]("'), 'matchstr(v:val, "](\\zs[^)]*\\ze)")')
	if name ==# 'journal.md'
		for y in map(glob(dir . '[0-9][0-9][0-9][0-9]', 0, 1), 'fnamemodify(v:val, ":t")')
			if index(kept, y) < 0
				call delete(dir . y, 'rf')
				call delete(dir . y . '.md')
			endif
		endfor
	elseif name =~# '^\d\{4}\.md$'
		let y = name[:3]
		for d in glob(dir . y . '/' . y . '-[0-9][0-9]-[0-9][0-9].md', 0, 1)
			if index(kept, y . '/' . fnamemodify(d, ':t:r')) < 0 | call delete(d) | endif
		endfor
		if empty(glob(dir . y . '/*', 0, 1))
			call delete(dir . y, 'd')
			call delete(f)
		endif
	endif
endfunction
autocmd init BufWritePost *.md call s:JournalDelete()
autocmd init CmdlineLeave * call s:CmdLeave()
autocmd init QuitPre * call s:QuitPre()
autocmd init User GoyoLeave nested call s:GoyoLeave()
autocmd init User GoyoEnter let b:goyo_seen = 1
autocmd init BufWinEnter * if exists('#goyo') | let b:goyo_seen = 1
	\ | elseif get(b:, 'goyo_seen') | setlocal number< relativenumber< colorcolumn< | unlet b:goyo_seen | endif

" :w!! saves a root-owned file
function! s:SudoWrite() abort
	let file = expand('%:p')
	if empty(file)
		echohl ErrorMsg | echo 'No file name: use :w {file} first' | echohl None
		return
	endif
	let tmp = tempname()
	execute 'keepalt silent write' fnameescape(tmp)
	let lines = readfile(tmp, 'b')
	call delete(tmp)
	call system(['sudo', '-n', 'true'])
	if !v:shell_error
		let cmd = 'sudo -n tee -- "$1" >/dev/null'
	else
		let pw = inputsecret('[sudo] password: ')
		if empty(pw) | echo 'Not saved' | return | endif
		call system(['sudo', '-S', '-p', '', '-v'], pw . "\n")
		if v:shell_error
			echohl ErrorMsg | echo 'Wrong sudo password: not saved' | echohl None
			return
		endif
		let cmd = 'sudo -k -S -p "" tee -- "$1" >/dev/null'
		let lines = [pw] + lines
	endif
	let out = system(['sh', '-c', cmd, 'sh', file], lines)
	if v:shell_error
		echohl ErrorMsg | echo 'sudo write failed, not saved: ' . trim(out) | echohl None
	else
		edit!
	endif
endfunction
command! SudoWrite call s:SudoWrite()
cnoreabbrev <expr> w!! getcmdtype() == ':' && getcmdline() ==# 'w!!' ? 'SudoWrite' : 'w!!'

" on save: trailing spaces (not in markdown) and blank end lines go
function! s:TrimOnSave() abort
	if &buftype ==# 'terminal' || !&modifiable | return | endif
	let pos = getpos('.')
	if index(['markdown', 'vimwiki'], &filetype) < 0 | keeppatterns %s/\s\+$//e | endif
	keeppatterns %s/\n\+\%$//e
	call cursor(pos[1], pos[2])
endfunction
autocmd init BufWritePre * call s:TrimOnSave()
