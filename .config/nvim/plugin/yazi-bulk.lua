-- yazi bulk rename: save and quit to rename (no y/N prompt), quit without saving to cancel
if not vim.env.YAZI_ID then return end

local list, saved

vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = "*bulk-rename*",
    callback = function(a) list = vim.api.nvim_buf_get_name(a.buf) end,
})
vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*bulk-rename*",
    callback = function() saved = true end,
})
vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
        if not list then return end
        local cmd = { "ya", "emit", "bulk_exit", list }
        if saved then cmd[#cmd + 1] = "--accept" end
        vim.fn.system(cmd)
    end,
})
