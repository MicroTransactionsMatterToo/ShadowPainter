class_name BrushManagerC
var script_class = "tool"

const LOG_LEVEL = 4
const SHADER_DIR = "shaders/brush_shaders/"

class BrushManager extends Node:
    var Global

    var color: Color setget set_color, get_color
    var _color: Color

    var size: float setget set_size, get_size
    var _size: float = 150

    var endcap setget set_endcap, get_endcap
    var _endcap = Line2D.LINE_CAP_NONE

    var current_brush setget set_brush, get_brush
    var _current_brush_name: String
    

    var _brushes := {}
    var available_brushes = [
        PencilBrush,
        TextureBrush,
        ShadowBrush,
        EraserBrush
    ]

    signal brush_size_changed(new_size)
    signal brush_color_changed(new_color)
    signal brush_changed()
    signal endcap_style_changed(mode)

    # ===== LOGGING =====
    const LOG_LEVEL = 4

    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <BrushManager>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <BrushManager>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <BrushManager>: " % OS.get_ticks_msec())
            print(msg)
        else:
            pass

    # ===== BUILTINS =====

    func _init(global).() -> void:
        logv("init")
        self.Global = global


        for brush_class in self.available_brushes:
            logv("Adding brush %s to available brushes" % brush_class)
            var instance = brush_class.new(self.Global, self)
            logv("Brush Instance %s" % instance)

            self._brushes[instance.brush_name] = instance
            self.add_child(instance)

        self._current_brush_name = self._brushes.values()[0].brush_name
        
        var prefs = Global.World.get_meta("painter_config")
        self.set_size(int(prefs.get_c_val("def_size_val")))
        self.set_color(Color(prefs.get_c_val("def_brush_col")))
        

            

    func name() -> String:
        return "BrushManager"

    func _to_string():
        return "[BrushManager <Current: %s, NumBrushes: %d]" % [
            self._current_brush_name,
            len(self.available_brushes)
        ]

    func _exit_tree():
        self.queue_free()

    func queue_free() -> void:
        logv("Freeing")
        .queue_free()
    
    # ===== GETTERS/SETTERS =====

    # ---- self.current_brush set/get
    func set_brush(brush_name: String) -> void:
        if self._current_brush_name == brush_name: return
        if self._brushes.has(brush_name):
            self._current_brush_name = brush_name
            self.emit_signal("brush_changed")
        else:
            logd("Brush with name %s not found, ignoring" % brush_name)
    
    func get_brush():
        return self._brushes.get(self._current_brush_name)

    # ---- self.color set/get
    func set_color(color) -> void:
        logv("set_color to %s" % color)
        if color == null: return
        self._color = color
        self.emit_signal("brush_color_changed", self._color)
    
    func get_color() -> Color:
        return self._color

    # ---- self.size set/get
    func set_size(size) -> void:
        logv("set_size to %s" % size)
        if size == null: return
        self._size = size
        Global.World.UI.CursorRadius = self._size
        self.emit_signal("brush_size_changed", self._size)

    func get_size() -> float:
        return self._size

    # ---- self.endcap set/get
    func set_endcap(mode) -> void:
        logv("set endcap to %s" % mode)
        if mode == null: return
        self._endcap = mode
        self.emit_signal("endcap_style_changed", self._endcap)

    func get_endcap():
        return self._endcap

class Brush extends Node2D:
    var Global
    var brushmanager

    var brush_name := "Generic Brush"
    var tooltip := ""
    var icon: Texture

    var ui: Node
    var template: PackedScene

    # ===== LOGGING =====
    const LOG_LEVEL = 4

    func logv(msg):
        if LOG_LEVEL > 3:
            printraw("(%d) [V] <%s>: " % [OS.get_ticks_msec(), self.brush_name])
            print(msg)
        else:
            pass

    func logd(msg):
        if LOG_LEVEL > 2:
            printraw("(%d) [D] <%s>: " % [OS.get_ticks_msec(), self.brush_name])
            print(msg)
        else:
            pass
    
    func logi(msg):
        if LOG_LEVEL >= 1:
            printraw("(%d) [I] <%s>: " % [OS.get_ticks_msec(), self.brush_name])
            print(msg)
        else:
            pass

    # ===== BUILTINS ======

    func _init(global, brush_manager).():
        logv("init")
        self.Global = global
        self.brushmanager = brush_manager
        self.brushmanager.connect("brush_size_changed", self, "set_size")
        self.brushmanager.connect("brush_color_changed", self, "set_color")

    func queue_free():
        if self.ui != null: self.ui.queue_free()
        .queue_free()
    
    func _to_string() -> String:
        return "[Brush \"%s\"]" % self.brush_name

    func get_name() -> String:
        return "%s @ %d" % [self.brush_name, self.get_instance_id()]

    # ===== BRUSH STUFF =====
    func paint(pen, mouse_pos, prev_mouse_pos) -> void:
        pass

    func on_stroke_end() -> void:
        pass

    func on_selected() -> void:
        pass

    # ===== BRUSH UI =====

    func brush_ui():
        logv("Brush default brush_ui called")
        return null

    func hide_ui():
        logv("Default hide_ui called")
        if self.ui != null: self.ui.visible = false

    func show_ui():
        logv("Default show_ui called")
        if self.ui != null: self.ui.visible = true

    # ===== SETTERS =====

    func set_color(color: Color) -> void:
        print("BASE SET COLOR")

    func set_size(size: float) -> void:
        pass

    # ==== UTILS ====
    
    ## ui_config
    # Called to determine which parts of the default brush UI should be shown
    func ui_config() -> Dictionary:
        return {
            "size": true,
            "color": true
        }


### LineBrush
# Base class for any brush that primarily uses `Line2D` for stroke drawing
class LineBrush extends Brush:
    var stroke_line: Line2D = Line2D.new()
    var stroke_shader
    
    var shader_param = null

    var previous_point_drawn: Vector2

    var was_drawing_straight = false

    const STROKE_THRESHOLD: float = 60.0
    const INTERPOLATE_THRESHOLD: float = 120.0

    func _init(global, brush_manager).(global, brush_manager):
        self.brushmanager.connect(
            "endcap_style_changed", 
            self,
            "set_endcap"
        )
        return

    # ===== OVERRIDES =====
    func paint(pen, mouse_pos, prev_mouse_pos) -> void:
        if !self.stroke_line.get_parent() == pen:
            logv("Added stroke_line to pen")
            pen.add_child(self.stroke_line)
        
        if len(self.stroke_line.points) == 0:
            logv("No points in stroke line, ignoring any modifiers")
            self.add_stroke_point(mouse_pos)
        
        if Input.is_key_pressed(KEY_SHIFT):
            logv("SHIFT is pressed, making a straight line")
            if len(self.stroke_line.points) == 1: self.add_stroke_point(mouse_pos)
            else: 
                self.stroke_line.set_point_position(self.stroke_line.points.size(), mouse_pos)
                self.previous_point_drawn = mouse_pos
            
            self.was_drawing_straight = true
            return

        if self.was_drawing_straight:
            self.previous_point_drawn = self.stroke_line.points[-1]

        if self.should_add_point(mouse_pos) or self.was_drawing_straight:
            self.was_drawing_straight = false
            self.add_stroke_point(mouse_pos)
        else:
            self.stroke_line.set_point_position(self.stroke_line.points.size() -1, mouse_pos)
        
    func set_color(color: Color) -> void:
        self.stroke_line.default_color = Color(
            color.r,
            color.g,
            color.b,
            1.0
        )

        if self.shader_param != null:
            self.stroke_line.material.set_shader_param(self.shader_param, color.a)
    
    func set_size(size: float) -> void:
        if size < 1.0: return
        self.stroke_line.width = size * 2.0

    func set_endcap(mode):
        logv("endcap_set: %s" % mode)
        if mode in [0, 1, 2]:
            self.stroke_line.begin_cap_mode = mode
            self.stroke_line.end_cap_mode = mode

    func on_stroke_end() -> void:
        self.stroke_line.clear_points()

    # ===== BRUSH UI =====

    func brush_ui():
        logv("Brush default brush_ui called")
        return null

    func hide_ui():
        logv("Default hide_ui called")
        if self.ui != null: self.ui.visible = false

    func show_ui():
        logv("Default show_ui called")
        if self.ui != null: self.ui.visible = true

    func on_selected() -> void:
        logv("on_selected, cursor_mode: %s" % Global.World.UI.CursorMode)
        Global.World.UI.CursorMode = 5
        Global.World.UI.CursorRadius = self.brushmanager.size

    func ui_config() -> Dictionary:
        return .ui_config()

    # ===== BRUSH SPECIFIC =====
    func add_stroke_point(position: Vector2):
        var points = []
        var point_distance = self.previous_point_drawn.distance_to(position)
        if point_distance > INTERPOLATE_THRESHOLD and self.stroke_line.points.size() != 0:
            var num_interp_points = point_distance / INTERPOLATE_THRESHOLD
            logv("distance too short, interpolating points: %d" % num_interp_points)
            for i in range(0, num_interp_points):
                var weight = (1.0 / (num_interp_points + 1)) * (i + 1)
                var new_point = self.previous_point_drawn.linear_interpolate(
                    position,
                    weight
                )
                self.stroke_line.add_point(new_point)
            
                
        self.stroke_line.add_point(position)
        self.previous_point_drawn = position

    func should_add_point(position: Vector2) -> bool:
        return self.previous_point_drawn.distance_to(position) > STROKE_THRESHOLD

### PencilBrush
# Brush for solid colors
class PencilBrush extends LineBrush:
    func _init(global, brush_manager).(global, brush_manager):
        self.icon = load("res://ui/icons/tools/path_tool.png")
        self.brush_name = "PencilBrush"
        self.tooltip = "Pencil"

        self.stroke_line.texture_mode           = Line2D.LINE_TEXTURE_TILE
        self.stroke_line.joint_mode             = Line2D.LINE_JOINT_ROUND
        self.stroke_line.begin_cap_mode         = Line2D.LINE_CAP_ROUND
        self.stroke_line.end_cap_mode           = Line2D.LINE_CAP_ROUND
        self.stroke_line.round_precision        = 20
        self.stroke_line.antialiased            = false
        self.stroke_line.name                   = "PencilStroke"

        self.stroke_shader = ResourceLoader.load(
            Global.Root + SHADER_DIR + "PencilBrush.shader", 
            "Shader", 
            true
        ).duplicate(false)
        self.stroke_line.material = ShaderMaterial.new()
        self.stroke_line.material.shader = self.stroke_shader

        self.shader_param = "override_alpha"

    func ui_config() -> Dictionary:
        return {
            "size": true,
            "color": true,
            "palette": "pencilbrush_palette",
            "endcaps": true
        }

### TextureBrush
# Brush for drawing lines of any loaded asset
class TextureBrush extends LineBrush:
    var path_grid_menu = null
    
    func _init(global, brush_manager).(global, brush_manager):
        self.icon = load("res://ui/icons/tools/material_brush.png")
        self.brush_name = "TextureBrush"
        self.tooltip = "Texture Brush"

        self.stroke_line.texture_mode           = Line2D.LINE_TEXTURE_TILE
        self.stroke_line.joint_mode             = Line2D.LINE_JOINT_ROUND
        self.stroke_line.antialiased            = false
        self.stroke_line.name                   = "TextureStroke"

        self.stroke_shader = ResourceLoader.load(
            Global.Root + SHADER_DIR + "TextureBrush.shader", 
            "Shader", 
            true
        ).duplicate(false)
        self.stroke_line.material = ShaderMaterial.new()
        self.stroke_line.material.shader = self.stroke_shader

        self.shader_param = "alpha_mult"

    # ===== BRUSH SPECIFIC ======
    func set_texture(texture: Texture) -> void:
        self.stroke_line.texture = texture

    func on_texture_selected(idx):
        self.set_texture(self.path_grid_menu.Selected)

    # ===== UI =====
    func brush_ui():
        logv("TextureBrush ui called")
        if self.ui == null:
            self.ui = VBoxContainer.new()
            (self.ui as VBoxContainer).size_flags_vertical = VBoxContainer.SIZE_EXPAND_FILL
            (self.ui as VBoxContainer).size_flags_horizontal = VBoxContainer.SIZE_EXPAND_FILL
            logv("TextureBrush create UI")

        if self.path_grid_menu == null:
            var GridMenu = load("res://scripts/ui/elements/GridMenu.cs")

            self.path_grid_menu = GridMenu.new()
            self.path_grid_menu.Load("Paths")

            self.path_grid_menu.max_columns = 1
            self.path_grid_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            self.path_grid_menu.size_flags_vertical = Control.SIZE_EXPAND_FILL
            self.path_grid_menu.ShowsPreview = true

            self.path_grid_menu.connect(
                "item_selected",
                self,
                "on_texture_selected"
            )

            self.path_grid_menu.rect_size = Vector2(100, 300)

            self.path_grid_menu.select(0, true)
            
            self.ui.add_child(self.path_grid_menu)
            logv("TextureBrush grid menu")

            self.set_texture(self.path_grid_menu.Selected)
        
        return self.ui

    func ui_config() -> Dictionary:
        return {
            "size": true,
            "color": false,
            "endcaps": true
        }

class ShadowBrush extends LineBrush:
    var transition_in: HSlider
    var transition_out: HSlider
    var offset: HSlider
    var alpha_invert: CheckButton
    var preview_control: Control
    var preview_line: Line2D


    func _init(global, brush_manager).(global, brush_manager) -> void:
        self.icon = load("res://ui/icons/tools/light_tool.png")
        self.brush_name = "ShadowBrush"
        self.tooltip = "Dynamic Shadow Brush"

        self.stroke_line.texture_mode           = Line2D.LINE_TEXTURE_STRETCH
        self.stroke_line.joint_mode             = Line2D.LINE_JOINT_ROUND
        # self.stroke_line.begin_cap_mode         = Line2D.LINE_CAP_BOX
        # self.stroke_line.end_cap_mode           = Line2D.LINE_CAP_BOX
        self.stroke_line.round_precision        = 20
        self.stroke_line.antialiased            = false
        self.stroke_line.name               = "ShadowBrushLine2D"

        self.stroke_shader = ResourceLoader.load(
            Global.Root + SHADER_DIR + "ShadowBrush.shader", 
            "Shader", 
            true
        ).duplicate(false)

        self.stroke_line.material = ShaderMaterial.new()
        self.stroke_line.material.shader = self.stroke_shader

        self.shader_param = "alpha_mult"

    func brush_ui():
        logv("ShadowBrush UI called")
        if self.ui == null:
            var template = ResourceLoader.load(Global.Root + "ui/brushes/shadow_brush_ui.tscn", "", true)

            self.ui = template.instance()

            self.preview_control = self.ui.get_node("LinePreview")
            self.preview_line = self.stroke_line.duplicate(true)
            self.preview_line.width = 50
            var preview_center = self.preview_control.rect_size / 2
            var preview_transform = self.preview_control.get_canvas_transform()
            var preview_coords = [
                Vector2(0.0, preview_center.y),
                Vector2(self.preview_control.rect_size.x, preview_center.y)
            ]
            logv("Container Size: %s" % self.preview_control.rect_size)
            logv("Mid X,Y: %d, %d" % [preview_center, self.preview_control.rect_size.x / 2])
            self.preview_control.add_child(self.preview_line)
            self.preview_line.add_point(preview_coords[0])
            self.preview_line.add_point(preview_coords[1])

            # self.preview_line.material = self.stroke_line.material


            self.transition_in = self.ui.get_node("Transition/In/InSlider")
            self.transition_in.connect(
                "value_changed",
                self,
                "_on_transition_in_val"
            )
            self.ui.get_node("Transition/In/InBox").share(self.transition_in)

            self.transition_out = self.ui.get_node("Transition/Out/OutSlider")
            self.transition_out.connect(
                "value_changed",
                self,
                "_on_transition_out_val"
            )
            self.ui.get_node("Transition/Out/OutBox").share(self.transition_out)

            self.offset = self.ui.get_node("Offset/OffsetVal")
            self.offset.connect(
                "value_changed",
                self,
                "_on_y_offset_val"
            )

            self.alpha_invert = self.ui.get_node("FlipAlpha/CheckButton")
            self.alpha_invert.connect(
                "toggled",
                self,
                "_on_flip_alpha"
            )


        return self.ui

    func show_ui():
        .show_ui()

        yield(get_tree(), "idle_frame")
        logv("updating shadow preview")
        var updated_x_end = self.preview_control.rect_size.x
        var updated_y_center = self.preview_control.rect_size.y / 2
        self.preview_line.set_point_position(0, Vector2(0, updated_y_center))
        self.preview_line.set_point_position(1, Vector2(updated_x_end, updated_y_center))

    func paint(pen, mouse_pos, prev_mouse_pos):
        self.stroke_line.texture_mode           = Line2D.LINE_TEXTURE_STRETCH
        .paint(pen, mouse_pos, prev_mouse_pos)

    func on_stroke_end():
        logv(self.stroke_line.points)
        .on_stroke_end()
        

    func ui_config() -> Dictionary:
        return {
            "size": true,
            "color": true,
            "endcaps": true
        }

    func _on_transition_in_val(val: float):
        logv("transition_in val changed %d" % val)
        self.stroke_line.material.set_shader_param("transition_in_start", val)
        self.stroke_line.material.set_shader_param("transition_in", val != 0.0)

    func _on_transition_out_val(val: float):
        logv("transition_out val changed %d" % val)
        self.stroke_line.material.set_shader_param("transition_out_start", val)
        self.stroke_line.material.set_shader_param("transition_out", val != 1.0)

    func _on_flip_alpha(val: bool):
        logv("invert_alpha val changed: %d" % val)
        self.stroke_line.material.set_shader_param("invert_alpha", val)
    
    func _on_y_offset_val(val: float):
        logv("y_offset val changed: %d" % val)
        self.stroke_line.material.set_shader_param("y_offset", val)


class EraserBrush extends LineBrush:
    func _init(global, brush_manager).(global, brush_manager):
        var icon = ImageTexture.new()
        icon.load(Global.Root + "icons/eraser.png")
        self.icon = icon
        self.brush_name = "EraserBrush"

        self.stroke_line.texture_mode           = Line2D.LINE_TEXTURE_TILE
        self.stroke_line.joint_mode             = Line2D.LINE_JOINT_ROUND
        self.stroke_line.end_cap_mode           = Line2D.LINE_CAP_ROUND
        self.stroke_line.begin_cap_mode         = Line2D.LINE_CAP_ROUND
        self.stroke_line.antialiased            = false
        self.stroke_line.name                   = "EraserStroke"

        var background_texture := ImageTexture.new()
        background_texture.load(Global.Root + "icons/preview_background.png")
        self.stroke_line.texture = background_texture
        self.stroke_line.default_color = Color(1, 1, 1, 0.75)


        self.stroke_shader = ResourceLoader.load(
            Global.Root + SHADER_DIR + "EraserBrush.shader", 
            "Shader", 
            true
        ).duplicate(false)
        self.stroke_line.material = ShaderMaterial.new()
        self.stroke_line.material.shader = self.stroke_shader

    func paint(pen, mouse_pos, prev_mouse_pos):
        .paint(pen, mouse_pos, prev_mouse_pos)

    func set_color(color):
        pass

    func ui_config() -> Dictionary:
        return {
            "size": true,
            "color": false,
            "endcaps": true
        }