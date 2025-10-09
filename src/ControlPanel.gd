extends Control

# UI节点引用
@onready var prev_model_button = $MainPanel/VBoxContainer/ModelGroup/ModelContainer/PrevModelButton
@onready var model_option_button = $MainPanel/VBoxContainer/ModelGroup/ModelContainer/ModelOptionButton
@onready var next_model_button = $MainPanel/VBoxContainer/ModelGroup/ModelContainer/NextModelButton

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

# 模型切换相关变量
var main_scene: Node = null
var available_models: Array = []
var current_model_index: int = 0

# 配置文件路径
var config_file_path = "user://settings.json"
var backup_config_path = "user://settings.json.backup"

# 默认配置
# 注意：缩放范围已更新为 0.001 - 1.0，支持更精细的缩放控制
var default_config = {
	"model_index": 0,
	"smaa": 0.10,
	"debanding": true,
	"mipmap": true,
	"zoom": 0.44,
	"resolution": 2048,
	"hdr": true,
	"lod": 0.6
}

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

# 目标节点引用
var target_camera: Camera2D
var target_viewport: SubViewport

func _ready():
	# 等待一帧确保所有节点都准备好
	await get_tree().process_frame
	
	setup_ui()
	setup_connections()
	# 不在这里加载设置，避免重复读取配置
	# load_settings()
	
	# 查找目标节点
	find_target_camera_and_viewport()
	
	# 设置模型切换功能
	setup_model_switching()

func setup_ui():
	# 设置分辨率选项
	resolution_option.add_item("1024x1024", 1024)
	resolution_option.add_item("1536x1536", 1536)
	resolution_option.add_item("2048x2048", 2048)
	resolution_option.add_item("4096x4096", 4096)
	resolution_option.selected = 2  # 默认2048

func setup_connections():
	# 连接信号 - 添加空值检查
	if prev_model_button:
		prev_model_button.pressed.connect(_on_prev_model_pressed)
	if model_option_button:
		model_option_button.item_selected.connect(_on_model_selected)
	if next_model_button:
		next_model_button.pressed.connect(_on_next_model_pressed)
	
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
	var scene = get_tree().get_first_node_in_group("main_scene")
	if scene:
		target_camera = scene.get_node("Sprite2D/SubViewport/Camera2D")
		target_viewport = scene.get_node("Sprite2D/SubViewport")
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
	# 不自动保存，避免频繁保存

# SubViewport设置
func _on_resolution_changed(index: int):
	var resolution = resolution_option.get_item_id(index)
	if target_viewport:
		target_viewport.size = Vector2i(resolution, resolution)
	# 不自动保存，避免频繁保存

func _on_hdr_toggled(enabled: bool):
	if target_viewport:
		target_viewport.use_hdr_2d = enabled
	# 不自动保存，避免频繁保存

func _on_lod_changed(value: float):
	lod_value_label.text = "%.1f" % value
	if target_viewport:
		target_viewport.mesh_lod_threshold = value
	# 不自动保存，避免频繁保存

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
		var scene = get_tree().get_first_node_in_group("main_scene")
		if scene and scene.has_method("clear_control_panel_reference"):
			scene.clear_control_panel_reference()
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
	
	# 应用模型索引
	if config.has("model_index"):
		current_model_index = config["model_index"]
		if model_option_button and current_model_index < available_models.size():
			model_option_button.selected = current_model_index
	
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
	
	# 更新模型选择
	if config.has("model_index"):
		current_model_index = config["model_index"]
		if model_option_button and current_model_index < available_models.size():
			model_option_button.selected = current_model_index
	
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
		"model_index": current_model_index,
		"smaa": smaa_slider.value if smaa_slider else 0.10,
		"zoom": zoom_slider.value if zoom_slider else 0.44,
		"hdr": hdr_check.button_pressed if hdr_check else true,
		"lod": lod_slider.value if lod_slider else 0.6,
		"resolution": resolution_option.get_item_id(resolution_option.selected) if resolution_option else 2048,
		"debanding": debanding_check.button_pressed if debanding_check else true,
		"mipmap": mipmap_check.button_pressed if mipmap_check else true
	}
	
	# 使用ConfigManager来保存配置，避免重复逻辑
	var scene = get_tree().get_first_node_in_group("main_scene")
	if scene:
		var config_manager = scene.get_node("ConfigManager")
		if config_manager and config_manager.has_method("save_config"):
			var success = config_manager.save_config(config)
			if success:
				print("设置已通过ConfigManager保存")
			else:
				print("警告：ConfigManager保存失败，使用备用方法")
				# 备用保存方法
				backup_save_config(config)
		else:
			print("警告：找不到ConfigManager，使用备用保存方法")
			backup_save_config(config)
	else:
		print("警告：找不到主场景，使用备用保存方法")
		backup_save_config(config)

# 备用配置保存方法
func backup_save_config(config: Dictionary):
	# 先备份现有配置文件
	backup_config_file()
	
	# 保存到独立配置文件
	var file = FileAccess.open(config_file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(config, "\t")  # 使用缩进格式化
		file.store_string(json_string)
		file.close()
		print("设置已通过备用方法保存到配置文件: %s" % config_file_path)
		print("配置内容: %s" % json_string)
	else:
		print("错误：无法保存配置文件，错误代码: %s" % FileAccess.get_open_error())
		# 尝试从备份恢复
		restore_config_from_backup()

# 应用设置到主场景
func apply_settings_to_main_scene(config: Dictionary):
	if not main_scene:
		return
	
	# 切换模型
	if config.has("model_index") and main_scene.has_method("switch_model"):
		var model_index = config["model_index"]
		if model_index >= 0 and model_index < available_models.size():
			main_scene.switch_model(model_index)
	
	# 应用缩放设置
	if config.has("zoom") and target_camera:
		target_camera.zoom = Vector2(config["zoom"], config["zoom"])
	
	# 应用视口设置
	if config.has("resolution") and target_viewport:
		var resolution = config["resolution"]
		target_viewport.size = Vector2i(resolution, resolution)
	
	if config.has("hdr") and target_viewport:
		target_viewport.use_hdr_2d = config["hdr"]
	
	if config.has("lod") and target_viewport:
		target_viewport.mesh_lod_threshold = config["lod"]

func load_settings():
	var file = FileAccess.open(config_file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		print("读取配置文件内容: %s" % json_string)
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var config = json.data
			print("配置文件解析成功: %s" % config)
			apply_config(config)
			update_ui_from_config(config)
			print("设置已从配置文件加载: %s" % config_file_path)
		else:
			print("配置文件解析失败，错误: %s，使用默认设置" % json.get_error_message())
			apply_config(default_config)
			update_ui_from_config(default_config)
	else:
		print("配置文件不存在，错误代码: %s，使用默认设置" % FileAccess.get_open_error())
		apply_config(default_config)
		update_ui_from_config(default_config)

# 备份配置文件
func backup_config_file():
	if FileAccess.file_exists(config_file_path):
		var source_file = FileAccess.open(config_file_path, FileAccess.READ)
		var backup_file = FileAccess.open(backup_config_path, FileAccess.WRITE)
		if source_file and backup_file:
			backup_file.store_string(source_file.get_as_text())
			source_file.close()
			backup_file.close()
			print("配置文件已备份到: %s" % backup_config_path)

# 从备份恢复配置文件
func restore_config_from_backup():
	if FileAccess.file_exists(backup_config_path):
		var backup_file = FileAccess.open(backup_config_path, FileAccess.READ)
		var main_file = FileAccess.open(config_file_path, FileAccess.WRITE)
		if backup_file and main_file:
			main_file.store_string(backup_file.get_as_text())
			backup_file.close()
			main_file.close()
			print("已从备份恢复配置文件")
		else:
			print("无法从备份恢复配置文件")

# 测试配置文件格式
func test_config_format():
	print("=== 测试配置文件格式 ===")
	
	# 创建测试配置
	var test_config = {
		"model_index": 0,
		"smaa": 0.10,
		"debanding": true,
		"mipmap": true,
		"zoom": 0.44,
		"resolution": 2048,
		"hdr": true,
		"lod": 0.6
	}
	
	# 测试JSON序列化
	var json_string = JSON.stringify(test_config, "\t")
	print("测试JSON序列化: %s" % json_string)
	
	# 测试JSON反序列化
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result == OK:
		var parsed_config = json.data
		print("测试JSON反序列化成功: %s" % parsed_config)
		print("配置类型验证:")
		print("  model_index: %s (类型: %s)" % [parsed_config["model_index"], typeof(parsed_config["model_index"])])
		print("  zoom: %s (类型: %s)" % [parsed_config["zoom"], typeof(parsed_config["zoom"])])
		print("  hdr: %s (类型: %s)" % [parsed_config["hdr"], typeof(parsed_config["hdr"])])
	else:
		print("测试JSON反序列化失败: %s" % json.get_error_message())

# 输入处理
func _input(event):
	if event.is_action_pressed("ui_cancel") and visible:
		visible = false

# 模型切换相关函数
func setup_model_switching():
	# 获取主场景引用
	main_scene = get_tree().get_first_node_in_group("main_scene")
	if not main_scene:
		# 如果没找到，尝试通过路径获取
		main_scene = get_tree().get_first_node_in_group("main")
	
	if main_scene and main_scene.has_method("get_available_models"):
		available_models = main_scene.get_available_models()
		current_model_index = main_scene.get_current_model_index()
		update_model_ui()
		print("模型切换功能已初始化，找到 %d 个模型" % available_models.size())
	else:
		print("警告：无法获取主场景或模型信息")
		# 如果无法获取模型信息，禁用模型切换控件
		if prev_model_button:
			prev_model_button.disabled = true
		if next_model_button:
			next_model_button.disabled = true
		if model_option_button:
			model_option_button.disabled = true

func update_model_ui():
	# 清空选项按钮
	if model_option_button:
		model_option_button.clear()
	
	# 添加模型选项
	for i in range(available_models.size()):
		var model = available_models[i]
		if model_option_button:
			model_option_button.add_item(model["display_name"], i)
		print("添加模型选项: %s" % model["display_name"])
	
	# 设置当前选中的模型
	if current_model_index < available_models.size() and model_option_button:
		model_option_button.selected = current_model_index
		print("当前选中模型: %s" % available_models[current_model_index]["display_name"])

func _on_prev_model_pressed():
	if available_models.size() <= 1:
		return
	
	var prev_index = main_scene.get_previous_model() if main_scene else 0
	switch_to_model(prev_index)

func _on_next_model_pressed():
	if available_models.size() <= 1:
		return
	
	var next_index = main_scene.get_next_model() if main_scene else 0
	switch_to_model(next_index)

func _on_model_selected(index: int):
	switch_to_model(index)

func switch_to_model(model_index: int):
	if not main_scene or model_index < 0 or model_index >= available_models.size():
		return
	
	# 更新UI
	current_model_index = model_index
	model_option_button.selected = model_index
	
	# 调用主场景的轻量级切换模型函数，避免重新加载动作和表情
	if main_scene.has_method("switch_model_lightweight"):
		main_scene.switch_model_lightweight(model_index)
		print("切换到模型: %s" % available_models[model_index]["display_name"])
		
		# 只保存配置，不重新加载
		save_settings()
	else:
		print("错误：主场景不支持模型切换功能")
