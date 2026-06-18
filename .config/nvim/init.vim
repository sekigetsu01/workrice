let mapleader =" "

if ! filereadable(system('echo -n "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/autoload/plug.vim"'))
	echo "Downloading junegunn/vim-plug to manage plugins..."
	silent !mkdir -p ${XDG_CONFIG_HOME:-$HOME/.config}/nvim/autoload/
	silent !curl "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim" > ${XDG_CONFIG_HOME:-$HOME/.config}/nvim/autoload/plug.vim
	autocmd VimEnter * PlugInstall
endif

call plug#begin(system('echo -n "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/plugged"'))
Plug 'tpope/vim-surround'
Plug 'lukas-reineke/indent-blankline.nvim'
Plug 'HiPhish/rainbow-delimiters.nvim'
Plug 'preservim/nerdtree'
Plug 'junegunn/goyo.vim'
Plug 'jreybert/vimagit'
Plug 'vimwiki/vimwiki'
Plug 'tpope/vim-commentary'
Plug 'jiangmiao/auto-pairs'
Plug 'ap/vim-css-color'
Plug 'mattn/emmet-vim'
Plug 'AlphaTechnolog/pywal.nvim', { 'as': 'pywal' }
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-lualine/lualine.nvim'
Plug 'goolord/alpha-nvim'
Plug 'stevearc/conform.nvim'
" Telescope
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }
" Completion + snippets
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'L3MON4D3/LuaSnip'
Plug 'saadparwaiz1/cmp_luasnip'
Plug 'rafamadriz/friendly-snippets'
call plug#end()

set title
set wrap
set linebreak
set spell spelllang=en_us
set textwidth=0
set bg=dark
set mouse=a
set nohlsearch
set clipboard+=unnamedplus
set noshowmode
set noruler
set laststatus=2
set noshowcmd
set timeoutlen=300
colorscheme pywal

" Transparency: clear backgrounds after colorscheme loads
autocmd ColorScheme * highlight Normal       guibg=NONE ctermbg=NONE
autocmd ColorScheme * highlight NormalNC     guibg=NONE ctermbg=NONE
autocmd ColorScheme * highlight NormalFloat  guibg=NONE ctermbg=NONE
autocmd ColorScheme * highlight SignColumn   guibg=NONE ctermbg=NONE
autocmd ColorScheme * highlight LineNr       guibg=NONE ctermbg=NONE
autocmd ColorScheme * highlight CursorLineNr guibg=NONE ctermbg=NONE
autocmd ColorScheme * highlight EndOfBuffer  guibg=NONE ctermbg=NONE
autocmd ColorScheme * highlight FoldColumn   guibg=NONE ctermbg=NONE

" Apply immediately for current session
highlight Normal       guibg=NONE ctermbg=NONE
highlight NormalNC     guibg=NONE ctermbg=NONE
highlight NormalFloat  guibg=NONE ctermbg=NONE
highlight SignColumn   guibg=NONE ctermbg=NONE
highlight LineNr       guibg=NONE ctermbg=NONE
highlight CursorLineNr guibg=NONE ctermbg=NONE
highlight EndOfBuffer  guibg=NONE ctermbg=NONE
highlight FoldColumn   guibg=NONE ctermbg=NONE

" n/N keep match centred and open folds
nnoremap <silent> n nzzzv
nnoremap <silent> N Nzzzv

" Place line above and below
nnoremap <leader>j o<Esc>
nnoremap <leader>k O<Esc>

" xdg-open current file
nnoremap <silent> <leader>x :silent !xdg-open "%:p" &<CR>

" Terminal pane in current file's directory
nnoremap <silent> <leader>w :let $NVIM_TERM_DIR=expand('%:p:h')<CR>
    \:split<CR>
    \:terminal<CR>
    \:startinsert<CR>
autocmd TermOpen * if !empty($NVIM_TERM_DIR) |
    \ call feedkeys("cd " . $NVIM_TERM_DIR . "\<CR>", 'n') | endif
tnoremap <Esc> <C-\><C-n>

" Zoom current pane to fullscreen and back
nnoremap <silent> <leader>z :call ToggleZoom()<CR>

function! ToggleZoom()
    if winnr('$') == 1
        return
    endif
    if exists('t:zoom_restore')
        execute t:zoom_restore
        unlet t:zoom_restore
    else
        let t:zoom_restore = winrestcmd()
        wincmd |
        wincmd _
    endif
endfunction

lua << EOF

-- ── conform.nvim: auto-format on save ────────────────────────────────
local conform_ok, conform = pcall(require, "conform")
if conform_ok then
    conform.setup({
        formatters_by_ft = {
            javascript = { "prettier" },
            css        = { "prettier" },
            html       = { "prettier" },
            qml        = { "qmlformat" },
        },
        format_on_save = {
            timeout_ms = 1000,
            lsp_format = "never",
        },
    })

    vim.keymap.set({ "n", "v" }, "<leader>f", function()
        conform.format({ async = true, lsp_format = "never" })
    end, { desc = "Format file" })
end

-- ── Telescope ─────────────────────────────────────────────────────────
local tel_ok, telescope = pcall(require, 'telescope')
if tel_ok then
    telescope.setup({
        defaults = {
            prompt_prefix        = "   ",
            selection_caret      = "  ",
            path_display         = { "truncate" },
            file_ignore_patterns = { "node_modules", ".git/" },
        },
        pickers = {
            find_files = { hidden = true },
            live_grep  = { additional_args = function() return { "--hidden" } end },
        },
    })
    pcall(telescope.load_extension, 'fzf')
end

-- ── nvim-cmp + LuaSnip ───────────────────────────────────────────────
local cmp_ok, cmp         = pcall(require, 'cmp')
local luasnip_ok, luasnip = pcall(require, 'luasnip')

if cmp_ok and luasnip_ok then
    require('luasnip.loaders.from_vscode').lazy_load()

    cmp.setup({
        snippet = {
            expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
            ['<C-Space>'] = cmp.mapping.complete(),
            ['<C-e>']     = cmp.mapping.abort(),
            ['<CR>']      = cmp.mapping.confirm({ select = false }),
            ['<Tab>']     = cmp.mapping(function(fallback)
                if cmp.visible() then
                    cmp.select_next_item()
                elseif luasnip.expand_or_jumpable() then
                    luasnip.expand_or_jump()
                else
                    fallback()
                end
            end, { 'i', 's' }),
            ['<S-Tab>']   = cmp.mapping(function(fallback)
                if cmp.visible() then
                    cmp.select_prev_item()
                elseif luasnip.jumpable(-1) then
                    luasnip.jump(-1)
                else
                    fallback()
                end
            end, { 'i', 's' }),
        }),
        sources = cmp.config.sources({
            { name = 'luasnip' },
            { name = 'buffer' },
            { name = 'path' },
        }),
        window = {
            completion    = cmp.config.window.bordered(),
            documentation = cmp.config.window.bordered(),
        },
    })
end

-- ── Treesitter ────────────────────────────────────────────────────────
local ts_ok, treesitter = pcall(require, 'nvim-treesitter.configs')
if ts_ok then
    treesitter.setup({
        ensure_installed = {
            "bash", "c", "cpp", "css", "html", "javascript", "json",
            "lua", "markdown", "python", "rust", "toml", "typescript",
            "vim", "vimdoc", "yaml",
        },
        auto_install = true,
        highlight = {
            enable = true,
            additional_vim_regex_highlighting = false,
        },
        indent = { enable = true },
    })
end

-- ── Lualine ───────────────────────────────────────────────────────────
local ll_ok, lualine = pcall(require, 'lualine')
if ll_ok then
    local colors = {
        bg     = 'NONE',
        fg     = '#c0c0c0',
        red    = '#E06C75',
        orange = '#D19A66',
        yellow = '#E5C07B',
        green  = '#98C379',
        cyan   = '#56B6C2',
        blue   = '#61AFEF',
        violet = '#C678DD',
        gray   = '#504945',
    }

    local theme = {
        normal   = { a = { fg = colors.bg, bg = colors.red,    gui = 'bold' }, b = { fg = colors.fg, bg = colors.gray }, c = { fg = colors.fg, bg = colors.bg } },
        insert   = { a = { fg = colors.bg, bg = colors.green,  gui = 'bold' }, b = { fg = colors.fg, bg = colors.gray }, c = { fg = colors.fg, bg = colors.bg } },
        visual   = { a = { fg = colors.bg, bg = colors.violet, gui = 'bold' }, b = { fg = colors.fg, bg = colors.gray }, c = { fg = colors.fg, bg = colors.bg } },
        replace  = { a = { fg = colors.bg, bg = colors.orange, gui = 'bold' }, b = { fg = colors.fg, bg = colors.gray }, c = { fg = colors.fg, bg = colors.bg } },
        command  = { a = { fg = colors.bg, bg = colors.yellow, gui = 'bold' }, b = { fg = colors.fg, bg = colors.gray }, c = { fg = colors.fg, bg = colors.bg } },
        inactive = { a = { fg = colors.gray, bg = colors.bg },  b = { fg = colors.gray, bg = colors.bg },               c = { fg = colors.gray, bg = colors.bg } },
    }

    lualine.setup({
        options = {
            theme                = theme,
            component_separators = { left = '│', right = '│' },
            section_separators   = { left = '',  right = '' },
            globalstatus         = true,
        },
        sections = {
            lualine_a = { 'mode' },
            lualine_b = { 'branch', 'diff' },
            lualine_c = { { 'filename', path = 1 } },
            lualine_x = { 'searchcount', 'selectioncount', 'filetype' },
            lualine_y = { 'progress' },
            lualine_z = { 'location' },
        },
        inactive_sections = {
            lualine_c = { { 'filename', path = 1 } },
            lualine_x = { 'location' },
        },
    })
end

-- ── Dashboard ─────────────────────────────────────────────────────────
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
        dashboard.button("e", "  new file",     ":enew<CR>"),
        dashboard.button("f", "  find file",    ":Telescope find_files<CR>"),
        dashboard.button("g", "  grep",         ":Telescope live_grep<CR>"),
        dashboard.button("r", "  recent files", ":Telescope oldfiles<CR>"),
        dashboard.button("n", "  notes",        ":VimwikiIndex<CR>"),
        dashboard.button("c", "  config",       ":e $MYVIMRC<CR>"),
        dashboard.button("q", "  quit",         ":qa<CR>"),
    }

    local version = vim.version()
    dashboard.section.footer.val = "v" .. version.major .. "." .. version.minor .. "." .. version.patch

    dashboard.section.header.opts.hl  = "Keyword"
    dashboard.section.footer.opts.hl  = "Comment"
    dashboard.section.buttons.opts.hl = "Function"
    dashboard.opts.opts.noautocmd = true
    alpha.setup(dashboard.opts)
end

-- ── indent-blankline: glowing rainbow lines ───────────────────────────
local ibl_ok, ibl = pcall(require, "ibl")
local hooks_ok, hooks = pcall(require, "ibl.hooks")

if ibl_ok and hooks_ok then
    local highlight = {
        "GlowRed", "GlowOrange", "GlowYellow", "GlowGreen",
        "GlowCyan", "GlowBlue", "GlowViolet",
    }

    hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        vim.api.nvim_set_hl(0, "GlowRed",    { fg = "#ff6e7a", bold = true })
        vim.api.nvim_set_hl(0, "GlowOrange", { fg = "#ffaa5e", bold = true })
        vim.api.nvim_set_hl(0, "GlowYellow", { fg = "#ffe066", bold = true })
        vim.api.nvim_set_hl(0, "GlowGreen",  { fg = "#aaee88", bold = true })
        vim.api.nvim_set_hl(0, "GlowCyan",   { fg = "#66e8e8", bold = true })
        vim.api.nvim_set_hl(0, "GlowBlue",   { fg = "#88c8ff", bold = true })
        vim.api.nvim_set_hl(0, "GlowViolet", { fg = "#dd99ff", bold = true })
    end)

    local rd_ok, _ = pcall(require, "rainbow-delimiters")
    if rd_ok then
        vim.g.rainbow_delimiters = { highlight = highlight }
    end

    ibl.setup({
        indent = { char = "│", highlight = highlight },
        scope  = { enabled = false },
        exclude = {
            filetypes = {
                "help", "dashboard", "alpha", "NvimTree", "Trouble",
                "lazy", "mason", "notify", "toggleterm",
            },
        },
    })

    hooks.register(hooks.type.WHITESPACE, hooks.builtin.hide_first_space_indent_level)

    hooks.register(hooks.type.SKIP_LINE, function(_, bufnr, row, _)
        local lines = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)
        if not lines or not lines[1] then return false end
        local stripped = lines[1]:match("^%s*(.*)")
        if not stripped then return false end
        return stripped:match("^//") ~= nil
            or stripped:match("^#")  ~= nil
            or stripped:match("^%-%-") ~= nil
            or stripped:match("^/%*") ~= nil
            or stripped:match("^%*")  ~= nil
    end)
end

EOF

" Some basics:
	nnoremap c "_c
	filetype plugin on
	set encoding=utf-8
	set number relativenumber
" Enable autocompletion:
	set wildmode=longest,list,full
" Disables automatic commenting on newline:
	autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o
" Perform dot commands over visual blocks:
	vnoremap . :normal .<CR>
" Goyo — prose writing mode:
	map <leader>G :Goyo \| set bg=dark \| set linebreak<CR>
" Spell-check set to <leader>o, 'o' for 'orthography':
	nnoremap <silent> <leader>o :setlocal spell!<CR>
" Splits open at the bottom and right
	set splitbelow splitright

" Nerd tree
	map <leader>n :NERDTreeToggle<CR>
	autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
	let NERDTreeBookmarksFile = stdpath('data') . '/NERDTreeBookmarks'

" Telescope keymaps
	nnoremap <leader>t  <cmd>Telescope find_files<CR>
	nnoremap <leader>T  <cmd>Telescope live_grep<CR>
	nnoremap <leader>tb <cmd>Telescope buffers<CR>
	nnoremap <leader>th <cmd>Telescope help_tags<CR>

" emmet shortcuts
	let g:user_emmet_leader_key=','

" Shortcutting split navigation, saving a keypress:
	map <C-h> <C-w>h
	map <C-j> <C-w>j
	map <C-k> <C-w>k
	map <C-l> <C-w>l

" Replace ex mode with gq
	map Q gq

" Check file in shellcheck:
	map <leader>s :!clear && shellcheck -x %<CR>

" Open my bibliography file in split
	map <leader>b :vsp<space>$BIB<CR>
	map <leader>r :vsp<space>$REFER<CR>

" Replace all is aliased to S.
	nnoremap S :%s//g<Left><Left>

" Shortcut ZA to :w
	nnoremap ZA :w<CR>

" Compile document, be it markdown/etc.
	map <leader>c :w! \| !compiler "%:p"<CR>

" Open corresponding .pdf/.html or preview
	map <leader>p :!opout "%:p"<CR>

" Ensure files are read as what I want:
	let g:vimwiki_ext2syntax = {'.Rmd': 'markdown', '.rmd': 'markdown','.md': 'markdown', '.markdown': 'markdown', '.mdown': 'markdown'}
	map <leader>v :VimwikiIndex<CR>
	let g:vimwiki_list = [{'path': '~/sync/notes/vimwiki', 'syntax': 'markdown', 'ext': '.md'}]
	autocmd BufRead,BufNewFile /tmp/calcurse*,~/.calcurse/notes/* set filetype=markdown

" Save file as sudo on files that require root permission
	cabbrev w!! execute 'silent! write !sudo tee % >/dev/null' <bar> edit!

" Automatically deletes all trailing whitespace and newlines at end of file on save.
	autocmd BufWritePre * if &buftype != 'terminal' | let currPos = getpos(".") | endif
	autocmd BufWritePre * if &buftype != 'terminal' | %s/\s\+$//e | endif
	autocmd BufWritePre * if &buftype != 'terminal' | %s/\n\+\%$//e | endif
	autocmd BufWritePre * if &buftype != 'terminal' | cal cursor(currPos[1], currPos[2]) | endif

" When shortcut files are updated, renew bash and ranger configs with new material:
	autocmd BufWritePost bm-files,bm-dirs !shortcuts

" Turns off highlighting on the bits of code that are changed
if &diff
    highlight! link DiffText MatchParen
endif

" Function for toggling the bottom statusbar:
let s:hidden_all = 0
function! ToggleHiddenAll()
    if s:hidden_all  == 0
        let s:hidden_all = 1
        set noshowmode
        set noruler
        set laststatus=0
        set noshowcmd
    else
        let s:hidden_all = 0
        set showmode
        set ruler
        set laststatus=2
        set showcmd
    endif
endfunction
nnoremap <leader>h :call ToggleHiddenAll()<CR>

" Load command shortcuts generated from bm-dirs and bm-files via shortcuts script.
silent! source ${XDG_CONFIG_HOME:-$HOME/.config}/nvim/shortcuts.vim
