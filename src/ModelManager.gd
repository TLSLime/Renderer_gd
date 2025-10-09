extends Node
class_name ModelManager

# 模型切换相关变量
var available_models: Array = []
var current_model_index: int = 0
var model_base_path: String = "res://Live2D/models/"

# 节点引用
var gd_cubism_user_model: GDCubismUserModel = null
var main_scene: Node2D = null

# 信号
signal model_switched(model_index: int)
signal models_loaded(available_models: Array)

func _ready():
	# 获取主场景引用
	main_scene = get_parent()
	if not main_scene:
		print("错误：ModelManager需要作为主场景的子节点")
		return
	
	# 获取GDCubismUserModel引用
	gd_cubism_user_model = main_scene.get_node("Sprite2D/SubViewport/GDCubismUserModel")
	if not gd_cubism_user_model:
		print("错误：无法找到GDCubismUserModel节点")
		return
	
	# 扫描可用模型
	scan_available_models()

# 扫描可用模型
func scan_available_models():
	print("扫描可用模型...")
	available_models.clear()
	
	var dir = DirAccess.open(model_base_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if dir.current_is_dir() and file_name != "." and file_name != "..":
				# 检查目录中是否有model3.json文件
				var model_path = model_base_path + file_name + "/runtime/"
				var model_file = model_path + file_name + ".model3.json"
				
				# 如果标准路径不存在，尝试其他可能的路径
				if not FileAccess.file_exists(model_file):
					# 尝试不同的文件名格式
					var alternative_files = [
						model_path + "mao_pro.model3.json",  # mao_pro_zh 模型
						model_path + "hiyori_pro_t11.model3.json",  # hiyori_pro_zh 模型
						model_path + file_name.replace("_zh", "") + ".model3.json"
					]
					
					for alt_file in alternative_files:
						if FileAccess.file_exists(alt_file):
							model_file = alt_file
							break
				
				if FileAccess.file_exists(model_file):
					available_models.append({
						"name": file_name,
						"path": model_file,
						"display_name": file_name.replace("_", " ").capitalize()
					})
					print("找到模型: %s" % file_name)
			
			file_name = dir.get_next()
	
	print("总共找到 %d 个模型" % available_models.size())
	
	# 设置默认模型
	if available_models.size() > 0:
		current_model_index = 0
		print("当前模型: %s" % available_models[current_model_index]["name"])
	
	# 发送信号
	models_loaded.emit(available_models)

# 通用的模型切换函数
func _switch_model_internal(model_index: int, reload_motions: bool = true, reset_eye_tracking: bool = false, silent: bool = false):
	if model_index < 0 or model_index >= available_models.size():
		print("错误：无效的模型索引")
		return
	
	current_model_index = model_index
	var model_info = available_models[current_model_index]
	
	if not silent:
		print("切换到模型: %s" % model_info["name"])
	
	# 停止当前动画
	stop_current_animation()
	
	# 加载新模型
	load_model(model_info["path"])
	
	# 等待模型加载完成
	await get_tree().create_timer(2.0).timeout
	
	# 强制更新模型状态（GDCubismUserModel没有update方法，跳过）
	# if gd_cubism_user_model:
	#	gd_cubism_user_model.update()  # 此方法不存在
	#	print("模型状态已强制更新")
	
	# 重新加载动作和表情（如果需要）
	if reload_motions:
		# 通知动画管理器重新加载
		var animation_mgr = main_scene.get_node("AnimationManager")
		if animation_mgr:
			animation_mgr.load_motions_and_expressions()
	
	# 重新查找HitArea节点
	var hit_area_mgr = main_scene.get_node("HitAreaManager")
	if hit_area_mgr:
		hit_area_mgr.find_hit_area_node()
	
	# 重置眼动追踪（如果需要）
	if reset_eye_tracking:
		var eye_tracker_reset = main_scene.get_node("EyeTrackingManager")
		if eye_tracker_reset:
			eye_tracker_reset.reset_eye_tracking_state()
	
	# 重新获取眼动追踪节点引用
	var eye_tracker_refresh = main_scene.get_node("EyeTrackingManager")
	if eye_tracker_refresh:
		eye_tracker_refresh.refresh_eye_tracking_node()
	
	# 发送信号
	model_switched.emit(model_index)

# 停止当前动画的通用函数
func stop_current_animation():
	if gd_cubism_user_model:
		gd_cubism_user_model.start_expression("")
		gd_cubism_user_model.anim_motion = ""
		# 通知动画管理器停止动画
		var animation_mgr = main_scene.get_node("AnimationManager")
		if animation_mgr:
			animation_mgr.stop_current_animation()

# 切换模型（完整版本）
func switch_model(model_index: int):
	_switch_model_internal(model_index, true, false, false)

# 仅切换模型，不触发配置保存（用于配置加载）
func apply_model_switch_only(model_index: int):
	_switch_model_internal(model_index, true, false, true)  # 静默模式
	print("模型切换完成，眼动追踪已重新启用")

# 配置加载时的模型切换（不重新初始化眼动追踪）
func apply_model_switch_for_config(model_index: int):
	if model_index < 0 or model_index >= available_models.size():
		print("错误：无效的模型索引")
		return
	
	current_model_index = model_index
	var model_info = available_models[current_model_index]
	
	print("配置加载切换到模型: %s" % model_info["name"])
	
	# 停止当前动画
	stop_current_animation()
	
	# 加载新模型
	load_model(model_info["path"])
	
	# 等待模型加载完成，减少等待时间
	await get_tree().create_timer(1.0).timeout
	
	# 不在这里重新加载动作和表情，避免重复加载
	# 动作和表情会在main.gd的load_config_and_model()中统一加载
	
	# 重新查找HitArea节点
	var hit_area_mgr = main_scene.get_node("HitAreaManager")
	if hit_area_mgr:
		hit_area_mgr.find_hit_area_node()
	
	# 不重新初始化眼动追踪，保持现有状态
	print("配置加载模型切换完成，眼动追踪状态保持")

# 轻量级模型切换（用于控制面板，避免重复加载动作和表情）
func switch_model_lightweight(model_index: int):
	if model_index < 0 or model_index >= available_models.size():
		print("错误：无效的模型索引")
		return
	
	# 保存当前眼动追踪状态
	var eye_tracker = main_scene.get_node("EyeTrackingManager")
	var saved_target_position = Vector2.ZERO
	var saved_current_position = Vector2.ZERO
	if eye_tracker:
		saved_target_position = eye_tracker.target_position
		saved_current_position = eye_tracker.current_position
		print("保存眼动追踪状态 - 目标: %s, 当前: %s" % [saved_target_position, saved_current_position])
	
	# 执行模型切换
	_switch_model_internal(model_index, true, false, false)
	
	# 恢复眼动追踪状态
	if eye_tracker:
		# 等待模型加载完成
		await get_tree().create_timer(1.0).timeout
		
		# 恢复眼动追踪状态
		eye_tracker.target_position = saved_target_position
		eye_tracker.current_position = saved_current_position
		print("恢复眼动追踪状态 - 目标: %s, 当前: %s" % [saved_target_position, saved_current_position])
	
	print("轻量级模型切换完成，眼动追踪状态已恢复")

# 加载模型
func load_model(model_path: String):
	if not gd_cubism_user_model:
		print("错误：GDCubismUserModel未初始化")
		return
	
	# 设置模型资源路径
	gd_cubism_user_model.assets = model_path
	
	# 重新加载模型（不需要调用initialize，设置assets后会自动重新加载）
	print("模型加载完成: %s" % model_path)

# 获取当前模型信息
func get_current_model_info():
	if available_models.size() > 0 and current_model_index < available_models.size():
		return available_models[current_model_index]
	return null

# 获取下一个模型
func get_next_model():
	if available_models.size() <= 1:
		return current_model_index
	
	var next_index = (current_model_index + 1) % available_models.size()
	return next_index

# 获取上一个模型
func get_previous_model():
	if available_models.size() <= 1:
		return current_model_index
	
	var prev_index = current_model_index - 1
	if prev_index < 0:
		prev_index = available_models.size() - 1
	return prev_index

# 供控制面板调用的函数
func get_available_models():
	return available_models

func get_current_model_index():
	return current_model_index

# 完整的模型重新加载（已移除，避免重复调用）
