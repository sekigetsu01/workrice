-- swayimg, the picture viewer: the wallpaper's colours, Vim-style keys, and keys to copy, delete, draw on a picture
-- or make it the wallpaper
local wal = {}
local function read_colors()
  local colors = io.open((os.getenv("XDG_CACHE_HOME") or os.getenv("HOME") .. "/.cache") .. "/wal/colors")
  if not colors then return end
  wal = {}
  for line in colors:lines() do wal[#wal + 1] = 0xff000000 + (tonumber(line:sub(2), 16) or 0) end
  colors:close()
end
read_colors()

swayimg.decoration = false
swayimg.imagelist.adjacent = true
swayimg.format_conf = { ttf = { enable = false } }

local function sh_quote(s)
  return "'" .. (s:gsub("'", "'\\''")) .. "'"
end

local function notify(title, body)
  os.execute("notify-send -a swayimg -t 1500 " .. sh_quote(title) .. " " .. sh_quote(body) .. " >/dev/null 2>&1 &")
end

local function basename(path)
  return path:match("[^/]+$") or path
end

local function delete(image)
  if not image then return end
  if os.remove(image.path) then
    swayimg.imagelist.remove(image.path)
    notify("Deleted", basename(image.path))
  else
    notify("Couldn't delete", basename(image.path))
  end
end

local function copy(image)
  if not image then return end
  os.execute("sh -c 'wl-copy --type \"$(file -b --mime-type -- \"$1\")\" < \"$1\"' _ " .. sh_quote(image.path) .. " >/dev/null 2>&1 &")
  notify("Copied to clipboard", basename(image.path))
end

local function wallpaper(image)
  if not image then return end
  os.execute("wallpaper " .. sh_quote(image.path) .. " >/dev/null 2>&1 &")
end

local pid = 0
local stat = io.open("/proc/self/stat")
if stat then pid = stat:read("*n") or 0; stat:close() end
local drawn_file = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/qs_edit_" .. pid

local function draw(image)
  if not image then return end
  os.execute("qs ipc call screenshotter editFor " .. sh_quote(image.path) .. " " .. pid .. " >/dev/null 2>&1 &")
end

local function drawn()
  local f = io.open(drawn_file)
  if not f then return end
  local path = f:read("*l")
  f:close()
  os.remove(drawn_file)
  return path
end

local function watermark(image)
  if not image then return end
  os.execute("watermark " .. sh_quote(image.path) .. " " .. pid .. " >/dev/null 2>&1 &")
end

local function copy_path(image)
  if not image then return end
  os.execute("wl-copy -- " .. sh_quote(image.path) .. " >/dev/null 2>&1 &")
  notify("Path copied", image.path)
end

local function changed()
  return drawn()
end

swayimg.slideshow.timeout = 4
swayimg.slideshow.default_scale = "fit"
swayimg.slideshow.bind_reset()
swayimg.slideshow.on_key("s",      function() swayimg.mode = "viewer" end)
swayimg.slideshow.on_key("Escape", function() swayimg.mode = "viewer" end)
swayimg.slideshow.on_key("h",      function() swayimg.slideshow.open("prev") end)
swayimg.slideshow.on_key("Left",   function() swayimg.slideshow.open("prev") end)
swayimg.slideshow.on_key("l",      function() swayimg.slideshow.open("next") end)
swayimg.slideshow.on_key("Right",  function() swayimg.slideshow.open("next") end)
swayimg.slideshow.on_key("f",      function() swayimg.fullscreen = not swayimg.fullscreen end)

local function pan(dx, dy)
  local pos = swayimg.viewer.get_position()
  local wnd = swayimg.get_window_size()
  swayimg.viewer.set_abs_position(pos.x + dx * math.floor(wnd.width / 10),
                                  pos.y + dy * math.floor(wnd.height / 10))
end

local HOME = os.getenv("HOME") or ""
local to_gallery

local start = nil
local function up(image)
  if not image then return end
  if not start then
    start = image.path:match("^(.*)/[^/]+$")
    swayimg.imagelist.recursive = true
    swayimg.imagelist.add(start)
  end
  to_gallery()
  swayimg.gallery.select_path(image.path)
end

swayimg.viewer.default_scale = "fit"

local viewer_info = false
local gallery_info = false
swayimg.text.visible = false
swayimg.text.timeout = 0

function to_gallery()
  swayimg.mode = "gallery"
  swayimg.text.visible = gallery_info
end

local function to_viewer()
  swayimg.mode = "viewer"
  swayimg.text.visible = viewer_info
end
swayimg.viewer.text = {
  topleft = { "File:\t{name}" },
  topright = { "{list.index} of {list.total}" },
  bottomleft = { "{frame.width}x{frame.height}  {sizehr}  {scale}" },
  bottomright = {},
}

swayimg.viewer.bind_reset()
swayimg.viewer.on_key("h",       function() swayimg.viewer.open("prev") end)
swayimg.viewer.on_key("Left",    function() swayimg.viewer.open("prev") end)
swayimg.viewer.on_key("l",       function() swayimg.viewer.open("next") end)
swayimg.viewer.on_key("Right",   function() swayimg.viewer.open("next") end)
swayimg.viewer.on_key("k",       function() swayimg.viewer.open("prev") end)
swayimg.viewer.on_key("Up",      function() swayimg.viewer.open("prev") end)
swayimg.viewer.on_key("j",       function() swayimg.viewer.open("next") end)
swayimg.viewer.on_key("Down",    function() swayimg.viewer.open("next") end)
swayimg.viewer.on_key("Shift-h", function() pan(1, 0) end)
swayimg.viewer.on_key("Shift-Left", function() pan(1, 0) end)
swayimg.viewer.on_key("Shift-l", function() pan(-1, 0) end)
swayimg.viewer.on_key("Shift-Right", function() pan(-1, 0) end)
swayimg.viewer.on_key("Shift-j", function() pan(0, -1) end)
swayimg.viewer.on_key("Shift-Down", function() pan(0, -1) end)
swayimg.viewer.on_key("Shift-k", function() pan(0, 1) end)
swayimg.viewer.on_key("Shift-Up", function() pan(0, 1) end)
swayimg.viewer.on_key("bracketleft",  function() swayimg.viewer.open("prev_dir") end)
swayimg.viewer.on_key("bracketright", function() swayimg.viewer.open("next_dir") end)
swayimg.viewer.on_key("g",       function() swayimg.viewer.open("first") end)
swayimg.viewer.on_key("Shift-g", function() swayimg.viewer.open("last") end)
swayimg.viewer.on_key("x",          function() swayimg.viewer.set_abs_scale(swayimg.viewer.scale * 1.1) end)
swayimg.viewer.on_key("z",          function() swayimg.viewer.set_abs_scale(swayimg.viewer.scale * 0.9) end)
swayimg.viewer.on_key("Shift-plus", function() swayimg.viewer.set_abs_scale(swayimg.viewer.scale * 1.1) end)
swayimg.viewer.on_key("KP_Add",     function() swayimg.viewer.set_abs_scale(swayimg.viewer.scale * 1.1) end)
swayimg.viewer.on_key("minus",      function() swayimg.viewer.set_abs_scale(swayimg.viewer.scale * 0.9) end)
swayimg.viewer.on_key("KP_Subtract", function() swayimg.viewer.set_abs_scale(swayimg.viewer.scale * 0.9) end)
swayimg.viewer.on_key("equal",   function() swayimg.viewer.set_abs_scale(1.0) end)
swayimg.viewer.on_key("0",       function() swayimg.viewer.set_fix_scale("fit") end)
swayimg.viewer.on_key("f",       function() swayimg.fullscreen = not swayimg.fullscreen end)
swayimg.viewer.on_key("r",       function() swayimg.viewer.rotate(90) end)
swayimg.viewer.on_key("Shift-r", function() swayimg.viewer.rotate(270) end)
swayimg.viewer.on_key("m",       function() swayimg.viewer.flip_vertical() end)
swayimg.viewer.on_key("Shift-m", function() swayimg.viewer.flip_horizontal() end)
swayimg.viewer.on_key("i",       function() viewer_info = not viewer_info; swayimg.text.visible = viewer_info end)
swayimg.viewer.on_key("y",       function() copy(swayimg.viewer.get_image()) end)
swayimg.viewer.on_key("b",       function() wallpaper(swayimg.viewer.get_image()) end)
swayimg.viewer.on_key("Shift-d", function() delete(swayimg.viewer.get_image()) end)
swayimg.viewer.on_key("e",       function() draw(swayimg.viewer.get_image()) end)
swayimg.viewer.on_key("w",       function() watermark(swayimg.viewer.get_image()) end)
swayimg.viewer.on_key("c",       function() copy_path(swayimg.viewer.get_image()) end)
swayimg.viewer.on_key("s",       function() swayimg.mode = "slideshow" end)
swayimg.viewer.on_key("Tab",     to_gallery)
swayimg.viewer.on_key("q",       function() up(swayimg.viewer.get_image()) end)
swayimg.viewer.on_key("Escape",  function() up(swayimg.viewer.get_image()) end)

swayimg.gallery.padding_size = 4
swayimg.gallery.border_size = 2
swayimg.gallery.preload = true
swayimg.gallery.pstore = true

swayimg.gallery.bind_reset()
swayimg.gallery.on_key("h",       function() swayimg.gallery.select("left") end)
swayimg.gallery.on_key("Left",    function() swayimg.gallery.select("left") end)
swayimg.gallery.on_key("l",       function() swayimg.gallery.select("right") end)
swayimg.gallery.on_key("Right",   function() swayimg.gallery.select("right") end)
swayimg.gallery.on_key("j",       function() swayimg.gallery.select("down") end)
swayimg.gallery.on_key("Down",    function() swayimg.gallery.select("down") end)
swayimg.gallery.on_key("k",       function() swayimg.gallery.select("up") end)
swayimg.gallery.on_key("Up",      function() swayimg.gallery.select("up") end)
swayimg.gallery.on_key("g",       function() swayimg.gallery.select("first") end)
swayimg.gallery.on_key("Shift-g", function() swayimg.gallery.select("last") end)
swayimg.gallery.on_key("Ctrl-f",  function() swayimg.gallery.select("pgdown") end)
swayimg.gallery.on_key("Ctrl-b",  function() swayimg.gallery.select("pgup") end)
swayimg.gallery.on_key("Ctrl-d",  function() swayimg.gallery.select("pgdown") end)
swayimg.gallery.on_key("Ctrl-u",  function() swayimg.gallery.select("pgup") end)
swayimg.gallery.on_key("f",       function() swayimg.fullscreen = not swayimg.fullscreen end)
swayimg.gallery.on_key("y",       function() copy(swayimg.gallery.get_image()) end)
swayimg.gallery.on_key("b",       function() wallpaper(swayimg.gallery.get_image()) end)
swayimg.gallery.on_key("i",       function() gallery_info = not gallery_info; swayimg.text.visible = gallery_info end)
swayimg.gallery.on_key("Shift-d", function() delete(swayimg.gallery.get_image()) end)
swayimg.gallery.on_key("e",       function() draw(swayimg.gallery.get_image()) end)
swayimg.gallery.on_key("w",       function() watermark(swayimg.gallery.get_image()) end)
swayimg.gallery.on_key("c",       function() copy_path(swayimg.gallery.get_image()) end)
swayimg.gallery.on_key("s",       function() to_viewer(); swayimg.mode = "slideshow" end)
swayimg.gallery.text = {
  topleft = { "File:\t{name}", "Folder:\t{dir}" },
  topright = { "{list.index} of {list.total}" },
}
swayimg.gallery.on_key("q",       function() up(swayimg.gallery.get_image()) end)
swayimg.gallery.on_key("Escape",  function() up(swayimg.gallery.get_image()) end)
swayimg.gallery.on_key("Return",  to_viewer)
swayimg.gallery.on_key("space",   to_viewer)
swayimg.gallery.on_mouse("MouseLeft", function()
  local pos = swayimg.get_mouse_pos()
  swayimg.gallery.select_at(pos.x, pos.y)
  to_viewer()
end)

local function apply_colors(redraw)
  if wal[1] then swayimg.viewer.set_window_background(wal[1]) end
  if wal[9] then
    swayimg.gallery.border_color = wal[4]
    swayimg.gallery.selected_color = wal[9]
    swayimg.gallery.unselected_color = wal[1]
    swayimg.gallery.window_color = wal[1]
  end
  if not redraw then return end
  if swayimg.mode == "gallery" then
    local image = swayimg.gallery.get_image()
    if image then swayimg.gallery.select_path(image.path) end
  elseif swayimg.mode == "viewer" then
    local pos = swayimg.viewer.get_position()
    if pos then swayimg.viewer.set_abs_position(pos.x, pos.y) end
  end
end
apply_colors(false)
local function recolour() read_colors(); apply_colors(true) end

local CACHE = (os.getenv("XDG_CACHE_HOME") or HOME .. "/.cache") .. "/swayimg"
swayimg.viewer.on_signal("USR1", function()
  local p = changed()
  if not p then return recolour() end
  local cur = swayimg.viewer.get_image()
  if cur and cur.path == p then swayimg.viewer.reload() else swayimg.viewer.open_path(p) end
end)
swayimg.gallery.on_signal("USR1", function()
  local p = changed()
  if not p then return recolour() end
  os.remove(CACHE .. p)
  swayimg.imagelist.remove(p)
  swayimg.imagelist.add(p)
  swayimg.gallery.select_path(p)
end)
swayimg.slideshow.on_signal("USR1", recolour)
