-- Closing the window from outside (Super+q) saves your writing; text with no file name is thrown away,
-- a file that can't be written is kept in ~/.local/state/nvim/rescued
local FOCUSED = (vim.env.XDG_RUNTIME_DIR or "/tmp") .. "/nvim-focused"
local RESCUE = vim.fn.stdpath("state") .. "/rescued"

local function writable(b)
    local bt = vim.bo[b].buftype
    return (bt == "" or bt == "acwrite") and vim.api.nvim_buf_get_name(b) ~= ""
end

local function rescue(b)
    local lines = vim.api.nvim_buf_get_lines(b, 0, -1, false)
    if #lines == 1 and lines[1]:match("^%s*$") then return nil end
    vim.fn.mkdir(RESCUE, "p")
    local base = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":t")
    local file = ("%s/%s-%d-%s"):format(RESCUE, os.date("%Y%m%d-%H%M%S"), b, base)
    if vim.fn.writefile(lines, file) ~= 0 then return nil end
    return file
end

local function save_all()
    local saved, rescued = 0, {}
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].modified and vim.bo[b].buftype ~= "terminal" then
            if writable(b) and not vim.bo[b].readonly then
                vim.api.nvim_buf_call(b, function() vim.cmd("silent! keepalt keepjumps update") end)
            end
            if not vim.bo[b].modified then
                saved = saved + 1
            elseif (vim.bo[b].buftype == "" or vim.bo[b].buftype == "acwrite") and vim.api.nvim_buf_get_name(b) ~= "" then
                rescued[#rescued + 1] = rescue(b)
            end
        end
    end
    if #rescued > 0 then
        vim.system({ "notify-send", "--app-name=Neovim", "Unsaved text kept", table.concat(rescued, "\n") }, { detach = true })
    end
    return saved, rescued
end

function _G.SaveQuit()
    vim.g.wiki_goyo = 0
    local saved, rescued = save_all()
    vim.schedule(function() vim.cmd("silent! qall!") end)
    return ("saved %d%s"):format(saved, #rescued > 0 and (", rescued " .. #rescued) or "")
end

vim.api.nvim_create_user_command("SaveQuit", function() _G.SaveQuit() end,
    { desc = "Save every changed file and quit without asking" })

local function claim()
    if vim.v.servername == "" or #vim.api.nvim_list_uis() == 0 or vim.v.exiting ~= vim.NIL then return end
    local tmp = FOCUSED .. "." .. vim.fn.getpid()
    if vim.fn.writefile({ vim.v.servername }, tmp, "b") == 0 then vim.uv.fs_rename(tmp, FOCUSED) end
end
local function release()
    local f = io.open(FOCUSED, "r")
    if not f then return end
    local who = f:read("*a")
    f:close()
    if who == vim.v.servername then os.remove(FOCUSED) end
end
local group = vim.api.nvim_create_augroup("SaveQuit", { clear = true })
vim.api.nvim_create_autocmd({ "UIEnter", "FocusGained" }, { group = group, callback = claim })
vim.api.nvim_create_autocmd({ "FocusLost", "VimLeavePre" }, { group = group, callback = release })
vim.api.nvim_create_autocmd("UILeave", { group = group, callback = function()
    if vim.v.exiting == vim.NIL and #vim.api.nvim_list_uis() == 0 then save_all() end
end })
