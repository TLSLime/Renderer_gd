extends Node
class_name ConfigManager

# 配置文件路径
var config_file_path = "user://settings.json"
var backup_config_path = "user://settings.json.backup"

# 默认配置
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

# 节点引用
var main_scene: Node2D = null

func _ready():
	# 获取主场景引用
	main_scene = get_parent()
	if not main_scene:
		print("错误：ConfigManager需要作为主场景的子节点")
		return

# 加载保存的配置
func load_saved_config():
	# 检查配置文件是否存在
	if not FileAccess.file_exists(config_file_path):
		print("配置文件不存在，使用默认配置")
		apply_saved_config(default_config)
		return
	
	var file = FileAccess.open(config_file_path, FileAccess.READ)
	if not file:
		print("无法打开配置文件，错误代码: %s" % FileAccess.get_open_error())
		apply_saved_config(default_config)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	# 检查文件内容是否为空
	if json_string.strip_edges().is_empty():
		print("配置文件为空，使用默认配置")
		apply_saved_config(default_config)
		return
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("JSON解析失败，错误: %s" % json.get_error_message())
		print("尝试从备份恢复...")
		restore_config_from_backup()
		return
	
	var config = json.data
	if not config is Dictionary:
		print("配置文件格式错误，不是有效的字典")
		apply_saved_config(default_config)
		return
	
	# 验证配置数据完整性
	var validated_config = validate_and_merge_config(config)
	apply_saved_config(validated_config)

# 加载配置并等待模型完全加载完成（用于启动时一次性加载）
func load_saved_config_and_wait_complete():
	# 先加载配置
	load_saved_config()
	
	# 等待一帧确保配置应用完成
	await get_tree().process_frame
	
	# 等待模型完全加载完成（根据配置中的模型索引）
	var model_manager = main_scene.get_node("ModelManager")
	if model_manager:
		# 智能等待模型加载完成，检查模型是否真的加载完成
		var max_wait_time = 2.0  # 最大等待时间
		var check_interval = 0.1  # 检查间隔
		var waited_time = 0.0
		
		while waited_time < max_wait_time:
			await get_tree().create_timer(check_interval).timeout
			waited_time += check_interval
			
			# 检查模型是否加载完成（通过检查GDCubismUserModel节点是否存在且有效）
			var gd_cubism_user_model = main_scene.get_node("Sprite2D/SubViewport/GDCubismUserModel")
			if gd_cubism_user_model and gd_cubism_user_model.is_inside_tree():
				# 额外检查：确保模型有有效的资源
				if gd_cubism_user_model.get("model") != null:
					break

# 验证并合并配置数据
func validate_and_merge_config(config: Dictionary) -> Dictionary:
	var validated_config = default_config.duplicate()
	
	# 验证每个配置项
	for key in config.keys():
		if key in default_config:
			var value = config[key]
			var expected_type = typeof(default_config[key])
			var actual_type = typeof(value)
			
			# 类型检查和转换
			var converted_value = value
			var type_valid = false
			
			# 特殊处理数字类型转换
			if expected_type == TYPE_INT and actual_type == TYPE_FLOAT:
				converted_value = int(value)
				type_valid = true
			elif expected_type == TYPE_FLOAT and actual_type == TYPE_INT:
				converted_value = float(value)
				type_valid = true
			elif actual_type == expected_type:
				type_valid = true
			
			if type_valid:
				validated_config[key] = converted_value
			else:
				print("配置项 %s 类型错误，期望 %s，实际 %s，使用默认值 %s" % [key, expected_type, actual_type, default_config[key]])
		else:
			print("未知配置项 %s，忽略" % key)
	
	return validated_config

# 应用保存的配置
func apply_saved_config(config: Dictionary):
	# 验证配置数据
	if not config is Dictionary:
		print("错误：配置数据不是字典类型")
		return
	
	# 切换模型（不触发配置保存，不重新初始化眼动追踪）
	if config.has("model_index") and config["model_index"] is int:
		var model_index = config["model_index"]
		var model_manager = main_scene.get_node("ModelManager")
		if model_manager and model_index >= 0 and model_index < model_manager.available_models.size():
			# 使用专门的配置加载函数，不重新初始化眼动追踪
			await model_manager.apply_model_switch_for_config(model_index)
		else:
			print("警告：模型索引超出范围: %s" % model_index)
	
	# 应用缩放设置 - 正确的节点路径
	if config.has("zoom") and config["zoom"] is float:
		var camera = main_scene.get_node("Sprite2D/SubViewport/Camera2D")
		if camera:
			var zoom_value = clamp(config["zoom"], 0.001, 1.0)  # 限制缩放范围
			camera.zoom = Vector2(zoom_value, zoom_value)
		else:
			print("警告：找不到 Camera2D 节点")
	
	# 应用视口设置 - 正确的节点路径
	var viewport = main_scene.get_node("Sprite2D/SubViewport")
	if viewport:
		if config.has("resolution") and config["resolution"] is int:
			var resolution = config["resolution"]
			viewport.size = Vector2i(resolution, resolution)
		
		if config.has("hdr") and config["hdr"] is bool:
			viewport.use_hdr_2d = config["hdr"]
		
		if config.has("lod") and config["lod"] is float:
			viewport.mesh_lod_threshold = config["lod"]
	else:
		print("警告：找不到 SubViewport 节点")

# 保存配置
func save_config(config: Dictionary):
	
	# 验证配置数据
	if not config is Dictionary:
		print("错误：配置数据不是字典类型")
		return false
	
	# 先备份现有配置文件
	backup_config_file()
	
	# 验证并合并配置
	var validated_config = validate_and_merge_config(config)
	
	# 保存到独立配置文件
	var file = FileAccess.open(config_file_path, FileAccess.WRITE)
	if not file:
		print("错误：无法创建配置文件，错误代码: %s" % FileAccess.get_open_error())
		# 尝试从备份恢复
		restore_config_from_backup()
		return false
	
	var json_string = JSON.stringify(validated_config, "\t")  # 使用缩进格式化
	file.store_string(json_string)
	file.close()
	
	# 验证保存是否成功
	if FileAccess.file_exists(config_file_path):
		return true
	else:
		print("错误：配置文件保存后不存在")
		restore_config_from_backup()
		return false

# 备份配置文件
func backup_config_file():
	if FileAccess.file_exists(config_file_path):
		var source_file = FileAccess.open(config_file_path, FileAccess.READ)
		var backup_file = FileAccess.open(backup_config_path, FileAccess.WRITE)
		if source_file and backup_file:
			backup_file.store_string(source_file.get_as_text())
			source_file.close()
			backup_file.close()

# 从备份恢复配置文件
func restore_config_from_backup():
	if FileAccess.file_exists(backup_config_path):
		var backup_file = FileAccess.open(backup_config_path, FileAccess.READ)
		var main_file = FileAccess.open(config_file_path, FileAccess.WRITE)
		if backup_file and main_file:
			main_file.store_string(backup_file.get_as_text())
			backup_file.close()
			main_file.close()
		else:
			print("无法从备份恢复配置文件")

# 重置配置为默认值
func reset_to_default_config():
	apply_saved_config(default_config)
	save_config(default_config)

# 获取当前配置
func get_current_config() -> Dictionary:
	return default_config.duplicate()

# 检查配置文件是否有效
func is_config_valid() -> bool:
	if not FileAccess.file_exists(config_file_path):
		return false
	
	var file = FileAccess.open(config_file_path, FileAccess.READ)
	if not file:
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	if json_string.strip_edges().is_empty():
		return false
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	return parse_result == OK and json.data is Dictionary
