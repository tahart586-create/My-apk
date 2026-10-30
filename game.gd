extends Node3D

const MOVE_SPEED := 4.5
const SERVE_RANGE := 2.4
const KITCHEN_POS := Vector3(-9.5, 0, 0)
const TIME_LIMIT := 120.0
const GUEST_COUNT := 8
const PLATES_PER_TRIP := 3

var player: Node3D
var tray: Node3D
var camera: Camera3D
var overlay: Control
var status: Label
var banner: Label
var guests: Array = []
var carrying := 0
var served := 0
var time_left := TIME_LIMIT
var game_over := false
var flash_time := 0.0

# حالة اللمس
var joy_touch := -1
var joy_center := Vector2.ZERO
var joy_dir := Vector2.ZERO
var act_touch := -1
var act_tap := false


func _ready() -> void:
	randomize()
	_build_environment()
	_build_room()
	_build_guests()
	_build_player()
	_build_camera()
	_build_hud()
	_update_hud()


# ---------- أدوات بناء ----------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m


func _add(parent: Node, mesh: Mesh, pos: Vector3, c: Color, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _box(parent: Node, sz: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = sz
	return _add(parent, m, pos, c)


func _cyl(parent: Node, r: float, h: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	return _add(parent, m, pos, c)


func _sph(parent: Node, r: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	return _add(parent, m, pos, c)


# ---------- الإضاءة والبيئة ----------

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.95, 0.8, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.85, 0.65)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.4
	we.environment = env
	add_child(we)

	# شمس دافئة قادمة من النافذة
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.8, 0.5)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55, -35, 0)
	add_child(sun)

	# مصابيح دافئة داخل القاعة
	for p in [Vector3(-6, 3, -3), Vector3(6, 3, 3), Vector3(0, 3, 0)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.7, 0.35)
		lamp.light_energy = 1.5
		lamp.omni_range = 9.0
		lamp.position = p
		add_child(lamp)


# ---------- الغرفة ----------

func _build_room() -> void:
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(26, 26)
	_add(self, floor_mesh, Vector3.ZERO, Color(0.87, 0.72, 0.52))

	# الجدران
	var wall := Color(0.95, 0.82, 0.62)
	_box(self, Vector3(26, 5, 0.6), Vector3(0, 2.5, -13), wall)
	_box(self, Vector3(0.6, 5, 26), Vector3(-13, 2.5, 0), wall)
	_box(self, Vector3(0.6, 5, 26), Vector3(13, 2.5, 0), wall)

	# الأعمدة
	for x in [-11.0, 11.0]:
		for z in [-11.0, 11.0]:
			_cyl(self, 0.4, 5, Vector3(x, 2.5, z), Color(0.8, 0.55, 0.35))

	# عوارض السقف
	for x in [-10.0, -6.0, -2.0, 2.0, 6.0, 10.0]:
		_box(self, Vector3(0.4, 0.4, 26), Vector3(x, 5, 0), Color(0.55, 0.35, 0.2))

	# السجاجيد الدائرية
	_cyl(self, 7.5, 0.04, Vector3(0, 0.02, 0), Color(0.85, 0.6, 0.25))
	_cyl(self, 5.8, 0.05, Vector3(0, 0.03, 0), Color(0.7, 0.2, 0.15))
	_cyl(self, 2.5, 0.06, Vector3(0, 0.04, 0), Color(0.1, 0.45, 0.5))

	# صينية الوليمة في المنتصف
	_cyl(self, 1.6, 0.15, Vector3(0, 0.3, 0), Color(0.9, 0.75, 0.4))
	_box(self, Vector3(1.4, 0.2, 1.4), Vector3(0, 0.5, 0), Color(0.5, 0.25, 0.12))

	# المطبخ
	_box(self, Vector3(2.0, 1.2, 3.0), Vector3(KITCHEN_POS.x, 0.6, 0), Color(0.65, 0.45, 0.3))
	_cyl(self, 0.7, 0.1, Vector3(KITCHEN_POS.x, 1.25, 0), Color(0.9, 0.75, 0.4))
	_box(self, Vector3(0.9, 0.3, 0.6), Vector3(KITCHEN_POS.x, 1.45, 0), Color(0.45, 0.2, 0.1))

	# سلة التمر
	_cyl(self, 1.0, 0.8, Vector3(9, 0.4, -8), Color(0.75, 0.55, 0.3))
	for i in 8:
		_sph(self, 0.14, Vector3(9 + randf_range(-0.6, 0.6), 0.9, -8 + randf_range(-0.6, 0.6)), Color(0.4, 0.2, 0.08))

	# جرار فخارية
	for p in [Vector3(-11, 0, -7), Vector3(11, 0, 6), Vector3(-6, 0, 11)]:
		_cyl(self, 0.45, 1.2, p + Vector3(0, 0.6, 0), Color(0.75, 0.45, 0.25))


# ---------- الشخصيات ----------

func _build_person(root: Node3D, turban: Color, robe: Color) -> void:
	var body := CapsuleMesh.new()
	body.radius = 0.35
	body.height = 1.1
	_add(root, body, Vector3(0, 0.75, 0), robe)
	_sph(root, 0.28, Vector3(0, 1.55, 0), Color(0.78, 0.55, 0.38))
	var tur := SphereMesh.new()
	tur.radius = 0.31
	tur.height = 0.5
	_add(root, tur, Vector3(0, 1.8, 0), turban)


func _build_guests() -> void:
	var robes := [Color(0.85, 0.15, 0.15), Color(0.1, 0.5, 0.6), Color(0.9, 0.7, 0.2), Color(0.3, 0.6, 0.25)]
	for i in GUEST_COUNT:
		var a := TAU * float(i) / float(GUEST_COUNT)
		var pos := Vector3(cos(a) * 5.5, 0, sin(a) * 5.5)

		var root := Node3D.new()
		root.position = pos
		root.rotation.y = atan2(pos.x, pos.z)  # يواجه المنتصف
		add_child(root)

		_cyl(root, 0.5, 0.15, Vector3(0, 0.08, 0), Color(0.6, 0.15, 0.1))  # وسادة

		var pose := Node3D.new()
		pose.scale = Vector3(1, 0.7, 1)  # وضعية الجلوس
		root.add_child(pose)
		var turban := Color(1, 1, 1) if i % 2 == 0 else Color(0.85, 0.3, 0.2)
		_build_person(pose, turban, robes[i % robes.size()])

		var mk := _sph(root, 0.18, Vector3(0, 2.4, 0), Color(1, 0.85, 0.2))  # علامة الجوع
		guests.append({"root": root, "marker": mk, "hungry": true})


func _build_player() -> void:
	player = Node3D.new()
	player.position = Vector3(0, 0, 9)
	add_child(player)
	_build_person(player, Color(1, 1, 1), Color(0.95, 0.95, 0.92))
	_box(player, Vector3(0.72, 0.08, 0.5), Vector3(0, 1.0, 0.2), Color(0.8, 0.15, 0.1))  # حزام

	# الصينية التي يحملها اللاعب
	tray = Node3D.new()
	tray.position = Vector3(0.45, 1.05, -0.45)
	tray.visible = false
	player.add_child(tray)
	_cyl(tray, 0.45, 0.06, Vector3.ZERO, Color(0.9, 0.75, 0.4))
	_box(tray, Vector3(0.5, 0.12, 0.4), Vector3(0, 0.1, 0), Color(0.55, 0.25, 0.1))


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 50
	add_child(camera)
	camera.current = true
	camera.global_position = player.global_position + Vector3(0, 10, 9)
	camera.look_at(player.global_position + Vector3(0, 1, 0), Vector3.UP)


# ---------- واجهة اللمس والنص ----------

func _action_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x - 130.0, vp.y - 130.0)


func _build_hud() -> void:
	var vp := get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	add_child(layer)

	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_touch_ui)
	layer.add_child(overlay)

	status = Label.new()
	status.position = Vector2(20, 16)
	status.add_theme_font_size_override("font_size", 28)
	layer.add_child(status)

	banner = Label.new()
	banner.position = Vector2(vp.x * 0.5 - 250, vp.y * 0.22)
	banner.custom_minimum_size = Vector2(500, 0)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 36)
	layer.add_child(banner)


func _draw_touch_ui() -> void:
	var vp := get_viewport().get_visible_rect().size
	var base := joy_center if joy_touch != -1 else Vector2(140, vp.y - 140)
	var knob := base + joy_dir * 60.0
	overlay.draw_circle(base, 85.0, Color(1, 1, 1, 0.12))
	overlay.draw_circle(knob, 36.0, Color(1, 0.85, 0.5, 0.55))
	var ac := _action_center()
	overlay.draw_circle(ac, 72.0, Color(0.95, 0.45, 0.2, 0.8 if act_touch != -1 else 0.45))


func _input(event: InputEvent) -> void:
	var vp := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < vp.x * 0.5 and joy_touch == -1:
				joy_touch = event.index
				joy_center = event.position
				joy_dir = Vector2.ZERO
			elif act_touch == -1 and event.position.distance_to(_action_center()) < 90.0:
				act_touch = event.index
				act_tap = true
		else:
			if event.index == joy_touch:
				joy_touch = -1
				joy_dir = Vector2.ZERO
			elif event.index == act_touch:
				act_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == joy_touch:
			joy_dir = ((event.position - joy_center) / 80.0).limit_length(1.0)


# ---------- المنطق ----------

func _process(delta: float) -> void:
	overlay.queue_redraw()

	if flash_time > 0.0:
		flash_time -= delta
		if flash_time <= 0.0 and not game_over:
			banner.text = ""

	if act_tap or Input.is_action_just_pressed("ui_accept"):
		act_tap = false
		_on_action()

	if not game_over:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			_end(false)
		_move(delta)

	# علامات الجوع تتحرك للأعلى والأسفل
	var bob := sin(Time.get_ticks_msec() / 250.0) * 0.12
	for g in guests:
		if g["hungry"]:
			g["marker"].position.y = 2.4 + bob

	camera.global_position = camera.global_position.lerp(
		player.global_position + Vector3(0, 10, 9), clampf(6.0 * delta, 0.0, 1.0))
	camera.look_at(player.global_position + Vector3(0, 1, 0), Vector3.UP)
	_update_hud()


func _move(delta: float) -> void:
	var dir := Vector3(joy_dir.x, 0, joy_dir.y)
	dir.x += Input.get_axis("ui_left", "ui_right")
	dir.z += Input.get_axis("ui_up", "ui_down")
	if dir.length() > 1.0:
		dir = dir.normalized()
	if dir.length() < 0.05:
		return
	player.global_position += dir * MOVE_SPEED * delta
	player.global_position.x = clampf(player.global_position.x, -11.0, 11.0)
	player.global_position.z = clampf(player.global_position.z, -11.0, 11.0)
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-dir.x, -dir.z), clampf(12.0 * delta, 0.0, 1.0))


func _on_action() -> void:
	if game_over:
		get_tree().reload_current_scene()
		return

	# قرب المطبخ: تحميل الأطباق
	if player.global_position.distance_to(KITCHEN_POS) < 2.5:
		carrying = PLATES_PER_TRIP
		_flash("Plates loaded!")
		return

	# البحث عن أقرب ضيف جائع
	var best := -1
	var best_d := SERVE_RANGE
	for i in guests.size():
		var g: Dictionary = guests[i]
		if g["hungry"]:
			var d: float = player.global_position.distance_to(g["root"].global_position)
			if d < best_d:
				best_d = d
				best = i

	if best == -1:
		_flash("No hungry guest nearby")
		return
	if carrying <= 0:
		_flash("Get plates from the kitchen first")
		return
	_serve(best)


func _serve(i: int) -> void:
	var g: Dictionary = guests[i]
	g["hungry"] = false
	g["marker"].material_override = _mat(Color(0.3, 0.9, 0.3))
	g["marker"].position.y = 2.4
	carrying -= 1
	served += 1
	_flash("Served! %d/%d" % [served, GUEST_COUNT])
	if served >= GUEST_COUNT:
		_end(true)


func _flash(t: String) -> void:
	banner.text = t
	flash_time = 1.8


func _end(won: bool) -> void:
	game_over = true
	if won:
		banner.text = "Everyone is fed! Tap to play again"
	else:
		banner.text = "Time's up! Tap to retry"


func _update_hud() -> void:
	status.text = "Plates: %d   Guests: %d/%d   Time: %d" % [carrying, served, GUEST_COUNT, int(ceil(time_left))]
	tray.visible = carrying > 0
