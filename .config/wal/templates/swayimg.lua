-- ── general ───────────────────────────────────────────────────────────────────
swayimg.enable_antialiasing(true)
swayimg.enable_decoration(false)
swayimg.imagelist.enable_adjacent(true)

swayimg.on_initialized(function()
  if swayimg.imagelist.size() == 1 then
    swayimg.set_mode("viewer")
  else
    swayimg.set_mode("gallery")
  end
end)

-- ── text / metadata ───────────────────────────────────────────────────────────
swayimg.text.hide()

-- ── viewer ────────────────────────────────────────────────────────────────────
swayimg.viewer.set_default_scale("fit")
swayimg.viewer.set_window_background(0xff{color0.strip})
swayimg.viewer.enable_loop(true)

swayimg.viewer.set_text("topleft",    {})
swayimg.viewer.set_text("topright",   {})
swayimg.viewer.set_text("bottomleft", {})

-- vim bindings — viewer
swayimg.viewer.bind_reset()
swayimg.viewer.on_key("h",       function() swayimg.viewer.switch_image("prev") end)
swayimg.viewer.on_key("l",       function() swayimg.viewer.switch_image("next") end)
swayimg.viewer.on_key("k",       function() swayimg.viewer.switch_image("prev") end)
swayimg.viewer.on_key("j",       function() swayimg.viewer.switch_image("next") end)
swayimg.viewer.on_key("g",       function() swayimg.viewer.switch_image("first") end)
swayimg.viewer.on_key("Shift-g", function() swayimg.viewer.switch_image("last") end)
swayimg.viewer.on_key("Shift-j", function() swayimg.viewer.set_abs_scale(swayimg.viewer.get_scale() * 1.1) end)
swayimg.viewer.on_key("Shift-k", function() swayimg.viewer.set_abs_scale(swayimg.viewer.get_scale() * 0.9) end)
swayimg.viewer.on_key("plus",    function() swayimg.viewer.set_abs_scale(swayimg.viewer.get_scale() * 1.1) end)
swayimg.viewer.on_key("minus",   function() swayimg.viewer.set_abs_scale(swayimg.viewer.get_scale() * 0.9) end)
swayimg.viewer.on_key("equal",   function() swayimg.viewer.set_abs_scale(1.0) end)
swayimg.viewer.on_key("0",       function() swayimg.viewer.set_fix_scale("fit") end)
swayimg.viewer.on_key("f",       function() swayimg.toggle_fullscreen() end)
swayimg.viewer.on_key("r",       function() swayimg.viewer.rotate(90) end)
swayimg.viewer.on_key("R",       function() swayimg.viewer.rotate(270) end)
swayimg.viewer.on_key("i",       function() swayimg.text.show() end)
swayimg.viewer.on_key("Tab",     function() swayimg.set_mode("gallery") end)
swayimg.viewer.on_key("Escape",  function() swayimg.set_mode("gallery") end)
swayimg.viewer.on_key("q",       function() swayimg.exit(0) end)
swayimg.viewer.set_drag_button("MouseLeft")

-- ── gallery ───────────────────────────────────────────────────────────────────
swayimg.gallery.set_thumb_size(200)
swayimg.gallery.set_padding_size(4)
swayimg.gallery.set_border_size(2)

swayimg.gallery.set_border_color(0xff{color3.strip})
swayimg.gallery.set_selected_color(0xff{color0.strip})
swayimg.gallery.set_unselected_color(0xff{color8.strip})
swayimg.gallery.set_window_color(0xff{color0.strip})

swayimg.gallery.set_aspect("fill")
swayimg.gallery.enable_preload(true)
swayimg.gallery.enable_pstore(true)

-- vim bindings — gallery
swayimg.gallery.bind_reset()
swayimg.gallery.on_key("h",       function() swayimg.gallery.switch_image("left") end)
swayimg.gallery.on_key("l",       function() swayimg.gallery.switch_image("right") end)
swayimg.gallery.on_key("j",       function() swayimg.gallery.switch_image("down") end)
swayimg.gallery.on_key("k",       function() swayimg.gallery.switch_image("up") end)
swayimg.gallery.on_key("g",       function() swayimg.gallery.switch_image("first") end)
swayimg.gallery.on_key("Shift-g", function() swayimg.gallery.switch_image("last") end)
swayimg.gallery.on_key("Ctrl-f",  function() swayimg.gallery.switch_image("pgdown") end)
swayimg.gallery.on_key("Ctrl-b",  function() swayimg.gallery.switch_image("pgup") end)
swayimg.gallery.on_key("f",       function() swayimg.toggle_fullscreen() end)
swayimg.gallery.on_key("Return",  function() swayimg.set_mode("viewer") end)
swayimg.gallery.on_key("space",   function() swayimg.set_mode("viewer") end)
swayimg.gallery.on_key("q",       function() swayimg.exit(0) end)
swayimg.gallery.on_mouse("MouseLeft", function() swayimg.set_mode("viewer") end)
