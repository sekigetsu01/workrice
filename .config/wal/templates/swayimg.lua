swayimg.antialiasing = true
swayimg.decoration = false
swayimg.imagelist.adjacent = true
swayimg.on_initialized(function()
  if swayimg.imagelist.size == 1 then
    swayimg.mode = "viewer"
  else
    swayimg.mode = "gallery"
  end
end)
swayimg.text.visible = false
swayimg.viewer.default_scale = "fit"
swayimg.viewer.set_window_background(0xff{color0.strip})
swayimg.viewer.loop = true
swayimg.viewer.set_text("topleft",    {})
swayimg.viewer.set_text("topright",   {})
swayimg.viewer.set_text("bottomleft", {})
swayimg.viewer.drag_button = "MouseLeft"
swayimg.viewer.bind_reset()
swayimg.viewer.on_key("h",       function() swayimg.viewer.open("prev") end)
swayimg.viewer.on_key("l",       function() swayimg.viewer.open("next") end)
swayimg.viewer.on_key("k",       function() swayimg.viewer.open("prev") end)
swayimg.viewer.on_key("j",       function() swayimg.viewer.open("next") end)
swayimg.viewer.on_key("g",       function() swayimg.viewer.open("first") end)
swayimg.viewer.on_key("Shift-g", function() swayimg.viewer.open("last") end)
swayimg.viewer.on_key("Shift-j", function() swayimg.viewer.set_abs_scale(swayimg.viewer.get_scale() * 1.1) end)
swayimg.viewer.on_key("Shift-k", function() swayimg.viewer.set_abs_scale(swayimg.viewer.get_scale() * 0.9) end)
swayimg.viewer.on_key("plus",    function() swayimg.viewer.set_abs_scale(swayimg.viewer.get_scale() * 1.1) end)
swayimg.viewer.on_key("minus",   function() swayimg.viewer.set_abs_scale(swayimg.viewer.get_scale() * 0.9) end)
swayimg.viewer.on_key("equal",   function() swayimg.viewer.set_abs_scale(1.0) end)
swayimg.viewer.on_key("0",       function() swayimg.viewer.set_fix_scale("fit") end)
swayimg.viewer.on_key("f",       function() swayimg.set_fullscreen() end)
swayimg.viewer.on_key("r",       function() swayimg.viewer.rotate(90) end)
swayimg.viewer.on_key("R",       function() swayimg.viewer.rotate(270) end)
swayimg.viewer.on_key("i",       function() swayimg.text.show() end)
swayimg.viewer.on_key("Tab",     function() swayimg.mode = "gallery" end)
swayimg.viewer.on_key("Escape",  function() swayimg.mode = "gallery" end)
swayimg.viewer.on_key("q",       function() swayimg.exit(0) end)
swayimg.gallery.thumb_size = 200
swayimg.gallery.padding_size = 4
swayimg.gallery.border_size = 2
swayimg.gallery.border_color = 0xff{color3.strip}
swayimg.gallery.selected_color = 0xff{color0.strip}
swayimg.gallery.unselected_color = 0xff{color8.strip}
swayimg.gallery.window_color = 0xff{color0.strip}
swayimg.gallery.aspect = "fill"
swayimg.gallery.preload = true
swayimg.gallery.pstore = true
swayimg.gallery.bind_reset()
swayimg.gallery.on_key("h",       function() swayimg.gallery.select("left") end)
swayimg.gallery.on_key("l",       function() swayimg.gallery.select("right") end)
swayimg.gallery.on_key("j",       function() swayimg.gallery.select("down") end)
swayimg.gallery.on_key("k",       function() swayimg.gallery.select("up") end)
swayimg.gallery.on_key("g",       function() swayimg.gallery.select("first") end)
swayimg.gallery.on_key("Shift-g", function() swayimg.gallery.select("last") end)
swayimg.gallery.on_key("Ctrl-f",  function() swayimg.gallery.select("pgdown") end)
swayimg.gallery.on_key("Ctrl-b",  function() swayimg.gallery.select("pgup") end)
swayimg.gallery.on_key("f",       function() swayimg.set_fullscreen() end)
swayimg.gallery.on_key("Return",  function() swayimg.mode = "viewer" end)
swayimg.gallery.on_key("space",   function() swayimg.mode = "viewer" end)
swayimg.gallery.on_key("q",       function() swayimg.exit(0) end)
swayimg.gallery.on_mouse("MouseLeft", function() swayimg.mode = "viewer" end)
