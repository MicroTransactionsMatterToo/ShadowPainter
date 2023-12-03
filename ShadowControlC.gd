class_name ShadowControlC
var script_class = "tool"


class ShadowControl extends Control:
    var Global

    # +++++ External Classes +++++

    var ShadowLayerC
    var ShadowLayer

    var ToolPanelUIC
    var ShadowToolpanel

    var LayerUIC
    var LayerPanel

    # +++++ Other Components +++++

    var brushmgr
    var layerm

    # +++++ UI ++++++
    var layerui: PanelContainer
    var toolpanel
    var toolpanelui

    # +++++ World Tree Items +++++

    var viewport: Viewport
    var viewport_tex: ViewportTexture
    var viewport_render: Sprite
    var viewport_cont: Node2D

    var level_layer_cont: LevelLayerContainer

    var pen: Node2D

    # +++++ State ++++++
    var history_queue: FIFOQueue
    
    var active_layer setget set_active_layer, get_active_layer
    var _active_layer

    var layer_texture_history := []

    var curr_level_id setget , get_current_level_id
    var _curr_level_id
    var _prev_level_id

    var is_painting := false
    var stroke_finished := false
    var should_paint := false

    var erase_mode := false

    var prev_mouse_pos
    

    # +++++ Rendering Resources +++++
    var transparent_image := Image.new()

    # +++++ Signals +++++
    signal stroke_finished(position)
    signal stroke_started(position)

    signal level_changed(level)
    signal active_layer_changed(layer)

    # +++++ Constants +++++
    const LOG_LEVEL = 4
    const NUM_UNDO_STATES = 10
    const RENDER_SCALE = 2


    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <ShadowControl>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <ShadowControl>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <ShadowControl>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    # ===== BUILTINS =====
    func _init(global, layerm, brushmgr, toolpanel).():
        logv("ShadowControl _init")
        self.Global = global
        self.layerm = layerm

        self.brushmgr = brushmgr
        self.add_child(self.brushmgr)

        self.toolpanel = toolpanel

        self.history_queue = FIFOQueue.new(NUM_UNDO_STATES)

        self.mouse_filter = MOUSE_FILTER_PASS

        self.size_flags_horizontal = SIZE_EXPAND
        self.size_flags_vertical = SIZE_EXPAND

        self.transparent_image.create(
            Global.World.WorldRect.size.x / RENDER_SCALE,
            Global.World.WorldRect.size.y / RENDER_SCALE,
            false,
            Image.FORMAT_RGBA8
        )
        self.transparent_image.fill(Color(1, 1, 1, 0))

        # Class Imports
        ShadowLayerC    = ResourceLoader.load(Global.Root + "ShadowLayerC.gd", "GDScript", true)
        ShadowLayer     = load(Global.Root + "ShadowLayerC.gd").ShadowLayer
        ToolPanelUIC    = ResourceLoader.load(Global.Root + "ToolPanelUIC.gd", "GDScript", true)
        ShadowToolpanel = load(Global.Root + "ToolPanelUIC.gd").ShadowToolpanel
        print("TEST: " + str(ShadowToolpanel))
        LayerUIC        = ResourceLoader.load(Global.Root + "LayerUIC.gd", "GDScript", true)
        LayerPanel      = load(Global.Root + "LayerUIC.gd").LayerPanel

        logv("_init finished")
    
    func _ready():
        self.level_layer_cont = LevelLayerContainer.new(Global, self.layerm, self)

        self._bootstrap_pen()
        self._bootstrap_viewport()
        self._bootstrap_viewport_render()

        self.viewport_cont.add_child(self.viewport_render)
        self.add_child(self.viewport_cont)
        logv("viewport_cont populated")
        
        self.add_child(self.level_layer_cont)
        logv("level_layer_cont added as child")

        self.viewport.add_child(self.pen)
        self.add_child(self.viewport)
        logv("viewport populated")

        
        
        self._bootstrap_active_layer()
        self.add_child(self._active_layer)
        logv("active_layer added")
        
        self._bootstrap_toolpanelui()
        logv("toolpanelui setup")

        self._bootstrap_layerui()
        logv("layerpanel setup")

    # ===== BOOTSTRAP =====
    func _bootstrap_active_layer():
        self._curr_level_id = self.layerm.get_level_id(Global.World.Level)
        logv("bootstraped _curr_level_id")

        var level_layers = self.layerm.get_layers_in_level(self.curr_level_id)
        var new_active_layer
        if len(level_layers) == 0:
            logd("No layers found, creating a new one")
            new_active_layer = ShadowLayer.new(Global)
            new_active_layer.create_new(
                self.curr_level_id,
                -1,
                "New Layer"
            )
            self.layerm.add_layer(new_active_layer)
        else:
            new_active_layer = level_layers[0]
        
        new_active_layer.set_meta("active_layer", true)
        self._active_layer = new_active_layer
        logv("active_layer bootstrapped")

    func _bootstrap_toolpanelui():
        self.toolpanelui = ShadowToolpanel.new(
            Global,
            self.layerm,
            self,
            self.brushmgr
        )
        logv("toolpanelui created %s" % self.toolpanelui)
        self.toolpanel.add_child(self.toolpanelui)
        logv("toolpanel bootstrapped")

    func _bootstrap_layerui():
        self.layerui = LayerPanel.new(
            Global,
            self.layerm,
            self
        )

        self.layerui.visible = false

        var layerpanel_root = Global.Editor.ObjectLibraryPanel.get_parent()
        layerpanel_root.add_child(self.layerui)
        logv("layerui bootstrapped")

    func _bootstrap_pen():
        logv("Creating pen")
        self.pen = Node2D.new()
        self.pen.name = "Pen"
        self.pen.connect("draw", self, "_on_draw")
        logv("pen bootstrapped")

    func _bootstrap_viewport():
        logv("Creating viewport")
        self.viewport = Viewport.new()
        self.viewport.name = "DrawingViewport"
        logv("viewport created")
        
        self.viewport.size = Global.World.WorldRect.size / RENDER_SCALE
        self.viewport.size_override_stretch = true
        self.viewport.set_size_override(
            true,
            Global.World.WorldRect.size
        )
        logv("viewport size set")

        self.viewport.usage = Viewport.USAGE_3D
        self.viewport.disable_3d = true
        self.viewport.hdr = false
        self.viewport.transparent_bg = true
        self.viewport.render_target_v_flip = true

        self.viewport.gui_disable_input = true
        logv("viewport configured")

        self.viewport_tex = self.viewport.get_texture()
        logv("viewport_tex set")

        self.viewport_cont = Node2D.new()
        logv("viewport_cont set")

    func _bootstrap_viewport_render():
        logv("Creating viewport_render")
        var vp_rend := Sprite.new()
        vp_rend.scale = Vector2(RENDER_SCALE, RENDER_SCALE)
        vp_rend.rect_scale = Vector2(RENDER_SCALE, RENDER_SCALE)
        vp_rend.centered = false
        vp_rend.name = "ViewportRender"

        logv("viewport_render created")

        var vp_rend_mat = CanvasItemMaterial.new()
        vp_rend_mat.blend_mode = CanvasItem.BLEND_MODE_PREMULT_ALPHA
        logv("viewport_render material created")

        vp_rend.material = vp_rend_mat
        vp_rend.set_texture(self.viewport_tex)
        self.viewport_render = vp_rend
        logv("viewport_render set")

    # ===== INPUT =====
    func _process(delta):
        if Global.Header.data == null:
            if self.layerm.get_level_id(Global.World.Level) != self.curr_level_id:
                self._on_level_change()

        self.viewport_render.update()

    func _on_tool_input(event: InputEvent) -> void:
        if event is InputEventMouseButton:
            match [event.button_index, event.pressed]:
                [BUTTON_LEFT, true]:
                    self.should_paint = true
                    self.pen.update()
                [BUTTON_LEFT, false]:
                    self.should_paint = false
                    self.prev_mouse_pos = null
                    self.pen.update()
                _:
                    self.should_paint = false
                    self.prev_mouse_pos = null
                    self.pen.update()
        if self.should_paint:
            self.pen.update()

    func _on_draw() -> void:
        var mouse_pos = self.get_local_mouse_position()

        if self.brushmgr.current_brush == null: return

        if self.should_paint:
            if !self.is_painting:
                logv("Stroke Started at %s" % mouse_pos)
                self.emit_signal("stroke_started", mouse_pos)
                self.prev_mouse_pos = mouse_pos
            self.is_painting = true
            self.brushmgr.current_brush.paint(
                self.pen,
                mouse_pos,
                self.prev_mouse_pos if self.prev_mouse_pos != null else mouse_pos
            )
        else:
            if self.is_painting:
                logv("Stroke finished at %s" % mouse_pos)
                self.emit_signal("stroke_finished", mouse_pos)
                self._on_stroke_finished()
                self.stroke_finished = true
                self.is_painting = false

        self.prev_mouse_pos = mouse_pos

    # ===== SIGNAL/EVENT HANDLERS =====
    func _on_level_change():
        logd("Layer changed from %s to %s" % [
            self.curr_level_id,
            self.layerm.get_level_id(Global.World.Level)
        ])
        self._curr_level_id = self.layerm.get_level_id(Global.World.Level)
        logv("new layer id %s" % self._curr_level_id)

        var level_layers = self.layerm.get_layers_in_level(self.curr_level_id)
        logv("Level layers: %s" % level_layers)
        var new_active_layer = null
        for layer in level_layers:
            if layer.has_meta("active_layer"):
                new_active_layer = layer
                break

        if new_active_layer == null and len(level_layers) == 0:
            logd("No layers found, creating a new one")
            new_active_layer = ShadowLayer.new(Global)
            new_active_layer.create_new(
                self.curr_level_id,
                -1,
                "New Layer"
            )
            self.layerm.add_layer(new_active_layer)
            self.active_layer = new_active_layer
        else:
            logd("No layers flagged as active found, setting active to first one")
            self.active_layer = level_layers[0]

    # ===== RENDERING =====

    func _on_stroke_finished() -> void:
        logv("Appending to history")
        var current_state = self.active_layer.texture.duplicate()
        self.history_queue.push(current_state)

        logv("Blending stroke into layer %s" % self.active_layer)
        var viewport_image := self.viewport_tex.get_data()
        var updated_region := viewport_image.get_used_rect()

        var layer_image = self.active_layer.texture.get_data()
        if self.erase_mode:
            logv("erase flag set, using alpha mask")
            layer_image.blit_rect_mask(
                self.transparent_image,
                viewport_image,
                updated_region,
                updated_region.position
            )
        else:
            layer_image.blend_rect(
                viewport_image,
                updated_region,
                updated_region.position
            )

        self.active_layer.texture.set_data(layer_image)
        self.brushmgr.current_brush.on_stroke_end()

    # ===== GETTERS/SETTERS =====
    # ---- self.active_layer setter/getter
    func set_active_layer(layer) -> void:
        logv("setting _active_layer from %s to %s" % [self._active_layer, layer])
        self._active_layer.remove_meta("active_layer")
        self.remove_child(self._active_layer)

        
        layer.get_parent().remove_child(layer)
        layer.set_meta("active_layer", true)
        self.add_child(layer)
        self._active_layer = layer

        self.pen.z_index = self._active_layer.z_index
        self.viewport_cont.z_index = self._active_layer.z_index + 1


        self.emit_signal("active_layer_changed", self._active_layer)

    func get_active_layer():
        return self._active_layer

    # ---- self.curr_level_id getter
    func get_current_level_id():
        return self._curr_level_id


class LevelLayerContainer extends Node2D:
    var Global
    var layerm
    var scontrol

    const LOG_LEVEL = 4

    # ===== LOGGING =====
    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <LevelLayerContainer>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <LevelLayerContainer>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <LevelLayerContainer>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func _init(global, layerm, scontrol).():
        logv("init")
        self.Global = global
        self.layerm = layerm
        self.scontrol = scontrol

        self.layerm.connect("layer_modified", self, "on_layer_modified")
        self.layerm.connect("layer_added", self, "on_layer_modified")
        self.scontrol.connect("active_layer_changed", self, "on_layer_modified")

    func on_layer_modified(val):
        yield(get_tree(), "idle_frame")
        self.update_children()

    func update_children():
        print("MEMES")
        for child in self.get_children():
            self.remove_child(child)

        var rval = []
        var level_layers = self.layerm.get_layers_in_level(
            self.layerm.get_level_id(Global.World.Level)
        )

        for layer in level_layers:
            if not layer.has_meta("active_layer"): rval.append(layer)
        
        for item in rval:
            self.add_child(item)
            if item.has_meta("visibility"):
                item.visible = item.get_meta("visibility")


class FIFOQueue extends Object:
    var _backing_array := []
    var _max_depth: int

    func _init(max_depth = 10):
        self._max_depth = max_depth

    func push(item: Object):
        self._backing_array.push_back(item)
        if len(self._backing_array) > self._max_depth: self._backing_array.pop_front()
    
    func pop() -> Object:
        return self._backing_array.pop_back()