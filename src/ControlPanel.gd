extends Control

# UI节点引用
@onready var smaa_slider = $MainPanel/VBoxContainer/AntiAliasingGroup/SMAAContainer/SMAASlider
@onready var smaa_value_label = $MainPanel/VBoxContainer/AntiAliasingGroup/SMAAContainer/SMAALabelValue
@onready var debanding_check = $MainPanel/VBoxContainer/AntiAliasingGroup/DebandingCheck
@onready var mipmap_check = $MainPanel/VBoxContainer/AntiAliasingGroup/MipmapCheck

@onready var zoom_slider = $MainPanel/VBoxContainer/ScalingGroup/ZoomContainer/ZoomSlider
@onready var zoom_value_label = $MainPanel/VBoxContainer/ScalingGroup/ZoomContainer/ZoomLabelValue

@onready var resolution_option = $MainPanel/VBoxContainer/ViewportGroup/ResolutionContainer/ResolutionOption
@onready var hdr_check = $MainPanel/VBoxContainer/ViewportGroup/HDRCheck
@onready var lod_slider = $MainPanel/VBoxContainer/ViewportGroup/LODContainer/LODSlider
@onready var lod_value_label = $MainPanel/VBoxContainer/ViewportGroup/LODContainer/LODLabelValue

# 移除性能监控相关的UI引用

@onready var preset_button = $MainPanel/VBoxContainer/ButtonContainer/PresetButton
@onready var reset_button = $MainPanel/VBoxContainer/ButtonContainer/ResetButton
@onready var save_button = $MainPanel/VBoxContainer/ButtonContainer/SaveButton
@onready var close_button = $MainPanel/VBoxContainer/CloseButton

# 添加重启按钮
@onready var restart_button = $MainPanel/VBoxContainer/ButtonContainer/RestartButton

# 预设配置
var presets = {
	"性能优先": {
		"smaa": 0.15,
		"zoom": 0.5,
		"hdr": false,
		"lod": 0.8,
		"resolution": 1024
	},
	"质量优先": {
		"smaa": 0.08,
		"zoom": 0.44,
		"hdr": true,
		"lod": 0.3,
		"resolution": 2048
	},
	"平衡": {
		"smaa": 0.10,
		"zoom": 0.44,
		"hdr": true,
		"lod": 0.6,
		"resolution": 1536
	}
}

# 默认配置
var default_config = {
	"smaa": 0.10,
	"zoom": 0.44,
	"hdr": true,
	"lod": 0.6,
	"resolution": 2048,
	"debanding": true,
	"mipmap": true
}

# 目标节点引用
var target_camera: Camera2D
var target_viewport: SubViewport

func _ready():
	# 等待一帧确保所有节点都准备好
	await get_tree().process_frame
	
	setup_ui()
	setup_connections()
	load_settings()
	
	# 查找目标节点
	find_target_camera_and_viewport()

func setup_ui():
	# 设置分辨率选项
	resolution_option.add_item("1024x1024", 1024)
	resolution_option.add_item("1536x1536", 1536)
	resolution_option.add_item("2048x2048", 2048)
	resolution_option.add_item("4096x4096", 4096)
	resolution_option.selected = 2  # 默认2048

func setup_connections():
	# 连接信号 - 添加空值检查
	if smaa_slider:
		smaa_slider.value_changed.connect(_on_smaa_changed)
	if debanding_check:
		debanding_check.toggled.connect(_on_debanding_toggled)
	if mipmap_check:
		mipmap_check.toggled.connect(_on_mipmap_toggled)
	
	if zoom_slider:
		zoom_slider.value_changed.connect(_on_zoom_changed)
	
	if resolution_option:
		resolution_option.item_selected.connect(_on_resolution_changed)
	if hdr_check:
		hdr_check.toggled.connect(_on_hdr_toggled)
	if lod_slider:
		lod_slider.value_changed.connect(_on_lod_changed)
	
	if preset_button:
		preset_button.pressed.connect(_on_preset_pressed)
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

func find_target_camera_and_viewport():
	# 查找Live2D场景中的Camera2D和SubViewport
	var main_scene = get_tree().get_first_node_in_group("main_scene")
	if main_scene:
		target_camera = main_scene.get_node("Sprite2D/SubViewport/Camera2D")
		target_viewport = main_scene.get_node("Sprite2D/SubViewport")
	else:
		# 备用查找方法
		target_camera = get_viewport().get_node("L2d/Sprite2D/SubViewport/Camera2D")
		target_viewport = get_viewport().get_node("L2d/Sprite2D/SubViewport")
	
	if not target_camera:
		print("ControlPanel: 无法找到目标Camera2D节点")
	if not target_viewport:
		print("ControlPanel: 无法找到目标SubViewport节点")

# 抗锯齿设置
func _on_smaa_changed(value: float):
	smaa_value_label.text = "%.2f" % value
	# 注意：在运行时修改抗锯齿设置需要重启项目才能生效
	# 这里只是更新UI显示，实际效果需要重启
	print("SMAA阈值已设置为: ", value, " (需要重启项目生效)")
	# 自动保存设置
	save_settings()

func _on_debanding_toggled(enabled: bool):
	# 注意：在运行时修改抗锯齿设置需要重启项目才能生效
	print("去条带已", "启用" if enabled else "禁用", " (需要重启项目生效)")
	# 自动保存设置
	save_settings()

func _on_mipmap_toggled(enabled: bool):
	# 注意：在运行时修改抗锯齿设置需要重启项目才能生效
	print("Mipmap已", "启用" if enabled else "禁用", " (需要重启项目生效)")
	# 自动保存设置
	save_settings()

# 缩放控制
func _on_zoom_changed(value: float):
	zoom_value_label.text = "%.2f" % value
	if target_camera:
		target_camera.zoom = Vector2(value, value)
	# 自动保存设置
	save_settings()

# SubViewport设置
func _on_resolution_changed(index: int):
	var resolution = resolution_option.get_item_id(index)
	if target_viewport:
		target_viewport.size = Vector2i(resolution, resolution)
	# 自动保存设置
	save_settings()

func _on_hdr_toggled(enabled: bool):
	if target_viewport:
		target_viewport.use_hdr_2d = enabled
	# 自动保存设置
	save_settings()

func _on_lod_changed(value: float):
	lod_value_label.text = "%.1f" % value
	if target_viewport:
		target_viewport.mesh_lod_threshold = value
	# 自动保存设置
	save_settings()

# 按钮功能
func _on_preset_pressed():
	show_preset_menu()

func _on_reset_pressed():
	apply_config(default_config)
	update_ui_from_config(default_config)

func _on_save_pressed():
	save_settings()

func _on_restart_pressed():
	# 保存当前设置
	save_settings()
	# 重启项目
	get_tree().quit()
	# 注意：在发布版本中，这需要外部脚本来重启应用

func _on_close_pressed():
	# 关闭整个窗口
	print("控制面板关闭按钮被点击")
	var window = get_window()
	if window:
		print("正在关闭控制面板窗口...")
		# 通知主场景清空控制面板引用
		var main_scene = get_tree().get_first_node_in_group("main_scene")
		if main_scene and main_scene.has_method("clear_control_panel_reference"):
			main_scene.clear_control_panel_reference()
		window.queue_free()
	else:
		print("无法找到窗口对象")

func show_preset_menu():
	# 创建简单的预设选择菜单
	var popup = PopupMenu.new()
	add_child(popup)
	
	for preset_name in presets.keys():
		popup.add_item(preset_name)
	
	popup.id_pressed.connect(func(id):
		var preset_name = presets.keys()[id]
		apply_preset(preset_name)
		popup.queue_free()
	)
	
	popup.popup_centered()

func apply_preset(preset_name: String):
	var preset = presets[preset_name]
	apply_config(preset)
	update_ui_from_config(preset)

func apply_config(config: Dictionary):
	# 注意：抗锯齿设置在运行时无法直接修改，需要重启项目
	# 这里只更新UI显示，实际效果需要重启项目
	print("应用配置: ", config)
	
	# 应用Camera2D缩放
	if target_camera:
		target_camera.zoom = Vector2(config.get("zoom", 0.44), config.get("zoom", 0.44))
	
	# 应用SubViewport设置
	if target_viewport:
		var resolution = config.get("resolution", 2048)
		target_viewport.size = Vector2i(resolution, resolution)
		target_viewport.use_hdr_2d = config.get("hdr", true)
		target_viewport.mesh_lod_threshold = config.get("lod", 0.6)

func update_ui_from_config(config: Dictionary):
	# 更新UI显示
	smaa_slider.value = config.get("smaa", 0.10)
	smaa_value_label.text = "%.2f" % smaa_slider.value
	
	debanding_check.button_pressed = config.get("debanding", true)
	mipmap_check.button_pressed = config.get("mipmap", true)
	
	zoom_slider.value = config.get("zoom", 0.44)
	zoom_value_label.text = "%.2f" % zoom_slider.value
	
	var resolution = config.get("resolution", 2048)
	for i in range(resolution_option.get_item_count()):
		if resolution_option.get_item_id(i) == resolution:
			resolution_option.selected = i
			break
	
	hdr_check.button_pressed = config.get("hdr", true)
	lod_slider.value = config.get("lod", 0.6)
	lod_value_label.text = "%.1f" % lod_slider.value

# 性能监控已移除

# 配置保存/加载
func save_settings():
	var config = {
		"smaa": smaa_slider.value,
		"zoom": zoom_slider.value,
		"hdr": hdr_check.button_pressed,
		"lod": lod_slider.value,
		"resolution": resolution_option.get_item_id(resolution_option.selected),
		"debanding": debanding_check.button_pressed,
		"mipmap": mipmap_check.button_pressed
	}
	
	# 保存到用户设置文件
	var file = FileAccess.open("user://render_settings.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config))
		file.close()
		print("设置已保存到用户文件")
	
	# 注意：抗锯齿设置需要在项目设置中手动配置，运行时无法修改
	print("注意：抗锯齿设置需要在项目设置中手动配置才能生效")

func load_settings():
	var file = FileAccess.open("user://render_settings.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var config = json.data
			apply_config(config)
			update_ui_from_config(config)
			print("设置已加载")

# 输入处理
func _input(event):
	if event.is_action_pressed("ui_cancel") and visible:
		visible = false
