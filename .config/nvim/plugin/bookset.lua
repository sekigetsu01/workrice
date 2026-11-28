-- In a wiki note: Space B links it to a book and its audiobook, Space O opens them (bookset does the work)
local WIKI = vim.fn.resolve(vim.fn.expand("~/sync/notes/vimwiki"))
local BOOKSET = vim.fn.expand("~/.local/bin/bookset")

local function note()
  local path = vim.fn.resolve(vim.fn.expand("%:p"))
  if path:sub(1, #WIKI + 1) ~= WIKI .. "/" or path:sub(-3) ~= ".md" then
    vim.notify("Not a wiki note", vim.log.levels.WARN)
    return nil
  end
  return path
end

vim.keymap.set("n", "<leader>B", function()
  local path = note()
  if path then
    vim.system({ BOOKSET, "link", "note", path }, { detach = true })
  end
end, { desc = "Link this note to a book and audiobook" })

vim.keymap.set("n", "<leader>O", function()
  local path = note()
  if path then
    vim.system({ BOOKSET, "open", "note", path, "--ask", "--this-window" }, { detach = true })
  end
end, { desc = "Open this note's book and audiobook (asks which)" })
