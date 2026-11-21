extends Node3D

const LEVELS := 10
const BALL_COLORS := [Color(1,0.28,0.35), Color(0.25,0.8,1), Color(1,0.84,0.2), Color(0.65,0.35,1), Color(0.3,0.95,0.55), Color(1,0.48,0.12), Color(0.95,0.45,0.85)]
var level := 1
var score := 0
var coins := 0
var shots := 0
var stars_total := 0
var ball_index := 0
var power_shots := 3
var highest_level := 1
var unlocked_balls := [0, 1, 2, 3, 4]
var targets: Array[Node3D] = []
var camera: Camera3D
var hud: CanvasLayer
var status_label: Label
var level_label: Label
var score_label: Label
var coins_label: Label
var help_label: Label
var field_root: Node3D
var projectile_root: Node3D
var is_dragging := false
var audio_player: AudioStreamPlayer
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()
    _build_camera()
    _build_lighting()
    _build_audio()
    _load_progress()
    _build_hud()
    _build_level()
    _show_main_menu()

func _build_camera() -> void:
    camera = Camera3D.new()
    add_child(camera)
    camera.position = Vector3(11, 13, 15)
    camera.look_at(Vector3(0, 0, 0), Vector3.UP)
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 23.0
    camera.current = true

func _build_lighting() -> void:
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -35, 0)
    sun.light_energy = 1.25
    add_child(sun)
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_SKY
    e.sky = Sky.new()
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.78, 0.86, 0.98)
    e.ambient_light_energy = 0.7
    env.environment = e
    add_child(env)

func _mat(color: Color, rough := 0.85) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    return m

func _mesh(parent: Node3D, shape: PrimitiveMesh, pos: Vector3, material: Material) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    n.mesh = shape
    n.position = pos
    n.material_override = material
    parent.add_child(n)
    return n

func _sphere(parent: Node3D, pos: Vector3, scale_v: Vector3, color: Color) -> MeshInstance3D:
    var s := SphereMesh.new()
    s.radius = 0.5
    s.height = 1.0
    var n := _mesh(parent, s, pos, _mat(color))
    n.scale = scale_v
    return n

func _build_audio() -> void:
    audio_player = AudioStreamPlayer.new()
    add_child(audio_player)

func _tone(freq: float, duration: float, volume := 0.16) -> void:
    var rate := 22050
    var frames := int(rate * duration)
    var data := PackedByteArray()
    for i in range(frames):
        var fade := 1.0 - float(i) / frames
        var sample := sin(TAU * freq * float(i) / rate) * fade * volume
        var value := int(clamp(sample, -1.0, 1.0) * 32767.0)
        data.append(value & 255)
        data.append((value >> 8) & 255)
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = rate
    stream.stereo = false
    stream.data = data
    audio_player.stream = stream
    audio_player.play()

func _build_hud() -> void:
    hud = CanvasLayer.new()
    add_child(hud)
    var panel := PanelContainer.new()
    panel.position = Vector2(18, 16)
    panel.custom_minimum_size = Vector2(365, 164)
    hud.add_child(panel)
    var box := VBoxContainer.new()
    panel.add_child(box)
    level_label = Label.new()
    level_label.add_theme_font_size_override("font_size", 22)
    box.add_child(level_label)
    score_label = Label.new()
    score_label.add_theme_font_size_override("font_size", 18)
    box.add_child(score_label)
    coins_label = Label.new()
    coins_label.add_theme_font_size_override("font_size", 18)
    box.add_child(coins_label)
    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 16)
    box.add_child(status_label)
    help_label = Label.new()
    help_label.text = "Коснись поля, чтобы выстрелить. Попади рядом со зверьком!"
    help_label.position = Vector2(18, 674)
    help_label.add_theme_font_size_override("font_size", 17)
    hud.add_child(help_label)

    var next_btn := Button.new()
    next_btn.text = "Следующий уровень ▶"
    next_btn.position = Vector2(1015, 20)
    next_btn.custom_minimum_size = Vector2(245, 48)
    next_btn.pressed.connect(_next_level)
    hud.add_child(next_btn)

    var map_btn := Button.new()
    map_btn.text = "🗺 Карта уровней"
    map_btn.position = Vector2(1015, 76)
    map_btn.custom_minimum_size = Vector2(245, 44)
    map_btn.pressed.connect(_show_level_map)
    hud.add_child(map_btn)

    var ball_btn := Button.new()
    ball_btn.text = "🎨 Сменить шарик"
    ball_btn.position = Vector2(1015, 128)
    ball_btn.custom_minimum_size = Vector2(245, 44)
    ball_btn.pressed.connect(_change_ball)
    hud.add_child(ball_btn)

    var boost_btn := Button.new()
    boost_btn.text = "⚡ Мощный выстрел (3)"
    boost_btn.position = Vector2(1015, 180)
    boost_btn.custom_minimum_size = Vector2(245, 44)
    boost_btn.pressed.connect(_use_power_shot)
    hud.add_child(boost_btn)

    var shop_btn := Button.new()
    shop_btn.text = "🛍 Магазин"
    shop_btn.position = Vector2(1015, 284)
    shop_btn.custom_minimum_size = Vector2(245, 42)
    shop_btn.pressed.connect(_show_shop)
    hud.add_child(shop_btn)

    var menu_btn := Button.new()
    menu_btn.text = "⌂ Главное меню"
    menu_btn.position = Vector2(1015, 336)
    menu_btn.custom_minimum_size = Vector2(245, 42)
    menu_btn.pressed.connect(_show_main_menu)
    hud.add_child(menu_btn)

    var reset_btn := Button.new()
    reset_btn.text = "↻ Повторить"
    reset_btn.position = Vector2(1015, 232)
    reset_btn.custom_minimum_size = Vector2(245, 42)
    reset_btn.pressed.connect(_build_level)
    hud.add_child(reset_btn)

func _build_level() -> void:
    if is_instance_valid(field_root):
        field_root.queue_free()
    if is_instance_valid(projectile_root):
        projectile_root.queue_free()
    field_root = Node3D.new()
    add_child(field_root)
    projectile_root = Node3D.new()
    add_child(projectile_root)
    targets.clear()
    shots = 0
    power_shots = 3
    _make_landscape()
    _make_launcher()
    if level == 10:
        _make_creature(Vector3(0, 1.0, -4.0), 9, true)
        status_label.text = "БОСС ВОЛШЕБНОГО ОСТРОВА! Нужно 3 попадания!"
    else:
        var count := mini(3 + level, 14)
        for i in range(count):
            var x := -5.5 + float(i % 5) * 2.7
            var z := -4.0 - float(i / 5) * 2.5
            _make_creature(Vector3(x, 0.75, z), i)
    _update_hud()
    _save_progress()

func _make_landscape() -> void:
    var ground := BoxMesh.new()
    ground.size = Vector3(22, 0.5, 20)
    _mesh(field_root, ground, Vector3(0, -0.3, -2), _mat(_biome_ground()))
    for i in range(52):
        var x := rng.randf_range(-10, 10)
        var z := rng.randf_range(-10, 7)
        if abs(x) < 1.8 and z > 3: continue
        var rock := SphereMesh.new()
        rock.radius = rng.randf_range(0.12, 0.3)
        rock.height = rock.radius * 1.5
        var c := _biome_detail(i)
        _mesh(field_root, rock, Vector3(x, -0.02, z), _mat(c))
    for i in range(5):
        var trunk := CylinderMesh.new()
        trunk.top_radius = 0.16
        trunk.bottom_radius = 0.23
        trunk.height = 1.5
        var x := -9.0 + i * 4.5
        _mesh(field_root, trunk, Vector3(x, 0.55, -9), _mat(Color(0.40,0.23,0.12)))
        var canopy := Color(0.18,0.52,0.23)
        if level >= 4 and level <= 6: canopy = Color(0.65,0.48,0.25)
        elif level >= 7: canopy = Color(0.82,0.9,0.98)
        _sphere(field_root, Vector3(x, 1.65, -9), Vector3(1.5,1.6,1.5), canopy)
    for i in range(6):
        _sphere(field_root, Vector3(-12 + i*5, 0.0, -12.0), Vector3(4.5,2.2,2.5), _biome_ground().darkened(0.12))
    # Little flowers make each meadow feel lively.
    for i in range(26):
        var flower_pos := Vector3(rng.randf_range(-9,9), 0.08, rng.randf_range(-8,5))
        if abs(flower_pos.x) < 1.7 and flower_pos.z > 3: continue
        _sphere(field_root, flower_pos, Vector3(0.12,0.08,0.12), [Color(1,0.55,0.7),Color(1,0.9,0.3),Color(0.8,0.75,1)][i%3])

func _biome_ground() -> Color:
    if level <= 3:
        return Color(0.35, 0.68, 0.30) # meadow
    if level <= 6:
        return Color(0.82, 0.67, 0.38) # desert
    if level <= 9:
        return Color(0.72, 0.86, 0.94) # snowy mountains
    return Color(0.25, 0.58, 0.57) # magical island

func _biome_detail(i: int) -> Color:
    if level <= 3:
        return [Color(0.54,0.57,0.43), Color(0.9,0.72,0.28), Color(0.95,0.88,0.65)][i % 3]
    if level <= 6:
        return [Color(0.65,0.39,0.18), Color(0.95,0.78,0.34), Color(0.8,0.58,0.31)][i % 3]
    if level <= 9:
        return [Color(0.82,0.9,0.98), Color(0.55,0.7,0.82), Color(0.96,0.98,1.0)][i % 3]
    return [Color(0.2,0.32,0.38), Color(0.16,0.72,0.62), Color(0.95,0.68,0.24)][i % 3]

func _make_launcher() -> void:
    var base := CylinderMesh.new()
    base.top_radius = 0.65
    base.bottom_radius = 0.8
    base.height = 0.5
    _mesh(field_root, base, Vector3(0, 0.15, 6), _mat(Color(0.26,0.31,0.39)))
    var barrel := CylinderMesh.new()
    barrel.top_radius = 0.28
    barrel.bottom_radius = 0.42
    barrel.height = 1.35
    var b := _mesh(field_root, barrel, Vector3(0, 0.75, 5.6), _mat(Color(0.98,0.56,0.16)))
    b.rotation.x = PI / 2.5
    _sphere(field_root, Vector3(0, 1.25, 5.0), Vector3(0.48,0.48,0.48), BALL_COLORS[ball_index])

func _make_creature(pos: Vector3, idx: int, is_boss := false) -> void:
    var creature := Node3D.new()
    creature.position = pos
    creature.set_meta("boss", is_boss)
    creature.set_meta("hp", 3 if is_boss else 1)
    field_root.add_child(creature)
    var palette := [Color(0.98,0.56,0.47), Color(0.92,0.75,0.34), Color(0.49,0.72,0.95), Color(0.68,0.53,0.85), Color(0.55,0.82,0.56)]
    var body_color: Color = palette[(idx + level) % palette.size()]
    _sphere(creature, Vector3(0,0.0,0), Vector3(1.15,1.05,0.9), body_color)
    _sphere(creature, Vector3(0,0.62,0.08), Vector3(0.78,0.78,0.72), body_color.lightened(0.08))
    var variant := (idx + level) % 5
    if variant == 0:
        _sphere(creature, Vector3(-0.55,1.12,0), Vector3(0.28,0.72,0.22), body_color.darkened(0.08))
        _sphere(creature, Vector3(0.55,1.12,0), Vector3(0.28,0.72,0.22), body_color.darkened(0.08))
    elif variant == 1:
        _cone(creature, Vector3(-0.3,1.25,0), 0.22, 0.65, Color(0.96,0.91,0.65))
        _cone(creature, Vector3(0.3,1.25,0), 0.22, 0.65, Color(0.96,0.91,0.65))
    elif variant == 2:
        _sphere(creature, Vector3(-0.75,0.55,0), Vector3(0.55,0.22,0.45), body_color.lightened(0.2))
        _sphere(creature, Vector3(0.75,0.55,0), Vector3(0.55,0.22,0.45), body_color.lightened(0.2))
    elif variant == 3:
        _cone(creature, Vector3(0.0,1.25,0), 0.32, 0.75, Color(0.94,0.56,0.27))
        _sphere(creature, Vector3(0.0,0.05,0.75), Vector3(0.28,0.28,0.7), body_color.darkened(0.1))
    else:
        _sphere(creature, Vector3(-0.52,1.05,0), Vector3(0.45,0.3,0.28), Color(0.98,0.82,0.77))
        _sphere(creature, Vector3(0.52,1.05,0), Vector3(0.45,0.3,0.28), Color(0.98,0.82,0.77))
    _sphere(creature, Vector3(-0.22,0.72,0.62), Vector3(0.12,0.14,0.09), Color(0.08,0.10,0.15))
    _sphere(creature, Vector3(0.22,0.72,0.62), Vector3(0.12,0.14,0.09), Color(0.08,0.10,0.15))
    _sphere(creature, Vector3(0,0.42,0.76), Vector3(0.25,0.18,0.12), Color(1.0,0.78,0.75))
    if is_boss:
        creature.scale = Vector3(2.2, 2.2, 2.2)
        _cone(creature, Vector3(-0.42,1.35,0), 0.34, 0.95, Color(0.98,0.72,0.12))
        _cone(creature, Vector3(0.42,1.35,0), 0.34, 0.95, Color(0.98,0.72,0.12))
    # Friendly idle bobbing animation.
    var idle := create_tween().set_loops()
    idle.tween_property(creature, "position:y", pos.y + 0.16, 0.8).set_trans(Tween.TRANS_SINE)
    idle.tween_property(creature, "position:y", pos.y, 0.8).set_trans(Tween.TRANS_SINE)
    targets.append(creature)

func _cone(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> void:
    var c := CylinderMesh.new()
    c.top_radius = 0.015
    c.bottom_radius = radius
    c.height = height
    _mesh(parent, c, pos, _mat(color))

func _update_hud() -> void:
    level_label.text = "УРОВЕНЬ %d / %d" % [level, LEVELS]
    score_label.text = "⭐ Счёт: %d     Выстрелов: %d" % [score, shots]
    coins_label.text = "🪙 Монетки: %d     ⚡ Бонусы: %d" % [coins, power_shots]
    if targets.is_empty():
        status_label.text = "Все зверята спасены! Уровень пройден 🎉"
    elif level == 10:
        status_label.text = "БОСС ОСТРОВА — целься в него! (3 попадания)"
    else:
        status_label.text = "Целей на поляне: %d" % targets.size()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            is_dragging = true
        else:
            if is_dragging: _shoot(event.position)
            is_dragging = false
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            is_dragging = true
        else:
            if is_dragging: _shoot(event.position)
            is_dragging = false
    elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
        _shoot(get_viewport().get_visible_rect().size * 0.5)

func _shoot(screen_pos: Vector2) -> void:
    if targets.is_empty(): return
    var from := camera.project_ray_origin(screen_pos)
    var dir := camera.project_ray_normal(screen_pos)
    var plane := Plane(Vector3.UP, 0.5)
    var hit = plane.intersects_ray(from, dir)
    var aim := Vector3(0,0,-4)
    if hit is Vector3: aim = hit
    aim.y = 0.6
    var ball := _sphere(projectile_root, Vector3(0,1.25,5.0), Vector3(0.42,0.42,0.42), BALL_COLORS[ball_index])
    _tone(440.0 + ball_index * 80.0, 0.10)
    var tween := create_tween()
    var landing := Vector3(aim.x, 0.5, aim.z)
    tween.tween_property(ball, "position", landing, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_callback(func():
        if not is_instance_valid(ball): return
        _burst(landing, BALL_COLORS[ball_index])
        ball.queue_free()
        _try_hit(landing)
    )
    shots += 1
    _update_hud()

func _burst(pos: Vector3, color: Color) -> void:
    for i in range(9):
        var bit := _sphere(projectile_root, pos, Vector3(0.13,0.13,0.13), color.lightened(rng.randf_range(0,0.4)))
        var destination := pos + Vector3(rng.randf_range(-1.0,1.0), rng.randf_range(0.3,1.4), rng.randf_range(-1.0,1.0))
        var tw := create_tween()
        tw.tween_property(bit, "position", destination, 0.32)
        tw.parallel().tween_property(bit, "scale", Vector3.ZERO, 0.32)
        tw.tween_callback(bit.queue_free)

func _try_hit(p: Vector3) -> void:
    var nearest: Node3D = null
    var dist := 2.2
    for t in targets:
        if not is_instance_valid(t): continue
        var d := Vector2(t.global_position.x-p.x, t.global_position.z-p.z).length()
        if d < dist:
            dist = d
            nearest = t
    if nearest:
        score += 100
        coins += 5
        _tone(880.0, 0.18)
        _coin_popup(nearest.global_position + Vector3(0,1.8,0))
        if bool(nearest.get_meta("boss", false)):
            var hp: int = int(nearest.get_meta("hp")) - 1
            nearest.set_meta("hp", hp)
            if hp > 0:
                status_label.text = "Босс получил урон! Осталось попаданий: %d" % hp
                var hit_tween := create_tween()
                hit_tween.tween_property(nearest, "scale", Vector3(2.45,2.45,2.45), 0.1)
                hit_tween.tween_property(nearest, "scale", Vector3(2.2,2.2,2.2), 0.12)
            else:
                _defeat_target(nearest)
        else:
            _defeat_target(nearest)
        if targets.is_empty():
            var earned := maxi(1, 3 - int(shots / 5))
            stars_total += earned
            coins += 20
            highest_level = maxi(highest_level, mini(level + 1, LEVELS))
            if level == LEVELS:
                status_label.text = "БОСС ПОБЕЖДЁН! Волшебный остров спасён! 🎉"
            else:
                status_label.text = "Уровень пройден! +20 монет • %d звезды" % earned
            _tone(1100.0, 0.35)
            _save_progress()
    else:
        status_label.text = "Мимо! Попробуй попасть ближе к зверёнку."
    _update_hud()

func _defeat_target(target: Node3D) -> void:
    targets.erase(target)
    var pop := create_tween()
    pop.tween_property(target, "scale", Vector3.ZERO, 0.2)
    pop.tween_callback(target.queue_free)

func _coin_popup(pos: Vector3) -> void:
    var coin := _sphere(projectile_root, pos, Vector3(0.2,0.2,0.08), Color(1.0,0.78,0.12))
    var tw := create_tween()
    tw.tween_property(coin, "position:y", pos.y + 1.0, 0.45)
    tw.parallel().tween_property(coin, "scale", Vector3.ZERO, 0.45)
    tw.tween_callback(coin.queue_free)

func _change_ball() -> void:
    var current_pos := unlocked_balls.find(ball_index)
    current_pos = (current_pos + 1) % unlocked_balls.size()
    ball_index = unlocked_balls[current_pos]
    _tone(600.0 + ball_index * 90.0, 0.12)
    _save_progress()
    _update_hud()

func _use_power_shot() -> void:
    if power_shots <= 0:
        status_label.text = "Мощные выстрелы закончились. На новом уровне будет 3!"
        return
    power_shots -= 1
    _tone(260.0, 0.22)
    # A bonus blast clears the closest remaining target to the launcher.
    if not targets.is_empty():
        var nearest := targets[0]
        for t in targets:
            if t.global_position.distance_to(Vector3(0,0,5)) < nearest.global_position.distance_to(Vector3(0,0,5)):
                nearest = t
        _burst(nearest.global_position, Color(1.0,0.9,0.25))
        _try_hit(nearest.global_position)
    _update_hud()

func _show_level_map() -> void:
    # Compact level selector buttons in a popup-like grid.
    var popup := PopupPanel.new()
    var grid := GridContainer.new()
    grid.columns = 5
    for i in range(1, LEVELS + 1):
        var btn := Button.new()
        btn.text = "Уровень %d" % i
        btn.custom_minimum_size = Vector2(105, 48)
        btn.disabled = i > highest_level
        btn.pressed.connect(func():
            level = i
            popup.hide()
            popup.queue_free()
            _build_level()
        )
        grid.add_child(btn)
    popup.add_child(grid)
    hud.add_child(popup)
    popup.popup_centered(Vector2i(580, 150))

func _show_main_menu() -> void:
    var panel := AcceptDialog.new()
    panel.title = "Animal Ball Blaster"
    panel.dialog_text = "Добро пожаловать в мир зверят!\\n\\nОткрыт уровень: %d / 10\\nМонетки: %d\\nЗвёзды: %d\\n\\nНажми кнопку, чтобы продолжить приключение." % [highest_level, coins, stars_total]
    panel.ok_button_text = "Начать приключение!"
    hud.add_child(panel)
    panel.confirmed.connect(func(): panel.queue_free())
    panel.close_requested.connect(func(): panel.queue_free())
    panel.popup_centered(Vector2i(440, 260))

func _show_shop() -> void:
    var popup := AcceptDialog.new()
    popup.title = "Магазин шариков"
    popup.dialog_text = "Монетки: %d — выбери новый цвет!" % coins
    popup.ok_button_text = "Закрыть"
    var rows := VBoxContainer.new()
    for i in range(BALL_COLORS.size()):
        var line := HBoxContainer.new()
        var swatch := ColorRect.new()
        swatch.color = BALL_COLORS[i]
        swatch.custom_minimum_size = Vector2(28, 28)
        line.add_child(swatch)
        var b := Button.new()
        var price := 0 if i < 5 else (35 if i == 5 else 60)
        if unlocked_balls.has(i):
            b.text = "Выбрать цвет %d" % (i + 1)
            b.pressed.connect(func():
                ball_index = i
                _save_progress()
                _update_hud()
                popup.queue_free()
            )
        else:
            b.text = "Купить цвет %d — %d монет" % [i + 1, price]
            b.pressed.connect(func():
                if coins >= price:
                    coins -= price
                    unlocked_balls.append(i)
                    ball_index = i
                    _save_progress()
                    _update_hud()
                    popup.queue_free()
                    _show_shop()
                else:
                    status_label.text = "Пока не хватает монеток!"
            )
        line.add_child(b)
        rows.add_child(line)
    popup.add_child(rows)
    hud.add_child(popup)
    popup.popup_centered(Vector2i(420, 360))

func _save_progress() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("progress", "coins", coins)
    cfg.set_value("progress", "score", score)
    cfg.set_value("progress", "stars", stars_total)
    cfg.set_value("progress", "highest_level", highest_level)
    cfg.set_value("progress", "ball_index", ball_index)
    cfg.set_value("progress", "unlocked_balls", unlocked_balls)
    cfg.save("user://animal_ball_blaster.cfg")

func _load_progress() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://animal_ball_blaster.cfg") != OK:
        return
    coins = int(cfg.get_value("progress", "coins", 0))
    score = int(cfg.get_value("progress", "score", 0))
    stars_total = int(cfg.get_value("progress", "stars", 0))
    highest_level = int(cfg.get_value("progress", "highest_level", 1))
    ball_index = int(cfg.get_value("progress", "ball_index", 0))
    unlocked_balls = cfg.get_value("progress", "unlocked_balls", [0,1,2,3,4])
    if not unlocked_balls.has(ball_index):
        ball_index = 0

func _next_level() -> void:
    if not targets.is_empty():
        status_label.text = "Сначала спаси всех зверят на этом уровне!"
        return
    if level < LEVELS:
        level += 1
    else:
        level = 1
        score = 0
    highest_level = maxi(highest_level, level)
    _save_progress()
    _build_level()
