extends SceneTree

func _init():
    var cl = CanvasLayer.new()
    root.add_child(cl)
    
    var shop = Control.new()
    shop.name = "ShopPanel"
    cl.add_child(shop)
    shop.set_anchors_preset(Control.PRESET_FULL_RECT)
    
    var bg = ColorRect.new()
    shop.add_child(bg)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    
    var vbox = VBoxContainer.new()
    shop.add_child(vbox)
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    
    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(scroll)
    
    var m = MarginContainer.new()
    m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(m)
    
    var c = ColorRect.new()
    c.custom_minimum_size = Vector2(0, 210)
    m.add_child(c)
    
    # Wait a frame for layout
    await root.get_tree().process_frame
    await root.get_tree().process_frame
    
    print("Viewport size: ", root.get_viewport().size)
    print("ShopPanel size: ", shop.size)
    print("bg size: ", bg.size)
    print("vbox size: ", vbox.size)
    print("scroll size: ", scroll.size)
    print("m size: ", m.size)
    print("c size: ", c.size)
    
    quit()
