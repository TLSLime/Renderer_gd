extends Node
class_name EyeTrackingManager

# 眼动追踪相关变量
var target_position: Vector2 = Vector2(0, 0)
var current_position: Vector2 = Vector2(0, 0)
var smooth_factor: float = 0.08  # 平滑系数，值越小越平滑（平衡平滑度和响应速度）
var max_distance: float = 0.8   # 最大跟踪距离
var idle_timer: float = 0.0
var idle_threshold: float = 2.0  # 空闲时间阈值（秒）
var last_mouse_pos: Vector2 = Vector2.ZERO  # 缓存上次鼠标位置，避免重复计算
var last_debug_second: int = -1  # 用于调试输出控制

# 节点引用
var gd_cubism_target_point: GDCubismEffectTargetPoint = null
var main_scene: Node2D = null

func _ready():
	# 获取主场景引用
	main_scene = get_parent()
	if not main_scene:
		print("错误：EyeTrackingManager需要作为主场景的子节点")
		return
	
	# 查找眼动追踪节点
	find_eye_tracking_node()

func _process(delta: float):
	# 更新空闲计时器
	idle_timer += delta
	
	# 持续检测鼠标位置（即使移出窗口）
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport().get_visible_rect().size
	
	# 更新鼠标位置（使用缓存优化）
	update_mouse_position(mouse_pos, false)
	
	# 如果鼠标在窗口内，重置空闲计时器
	if mouse_pos.x >= 0 and mouse_pos.x <= screen_size.x and mouse_pos.y >= 0 and mouse_pos.y <= screen_size.y:
		idle_timer = 0.0
	# 如果空闲时间超过阈值，逐渐回到中心位置
	elif idle_timer > idle_threshold:
		target_position = target_position.lerp(Vector2(0, 0), 0.02)
	
	# 平滑更新眼动追踪
	update_eye_tracking()

# 统一的鼠标位置处理函数
func update_mouse_position(mouse_pos: Vector2, force_update: bool = false):
	# 如果位置没有变化且不是强制更新，跳过计算（增加死区）
	if not force_update and mouse_pos.distance_to(last_mouse_pos) < 5.0:
		return
	
	last_mouse_pos = mouse_pos
	
	# 获取屏幕尺寸
	var screen_size = get_viewport().get_visible_rect().size
	
	# 将鼠标位置转换为相对于屏幕中心的坐标
	var center = screen_size * 0.5
	var relative_pos = mouse_pos - center
	
	# 将坐标标准化到-1到1的范围，Y轴取反
	var normalized_pos = Vector2(
		relative_pos.x / (screen_size.x * 0.5),
		-relative_pos.y / (screen_size.y * 0.5)  # Y轴取反
	)
	
	# 调试信息：检查坐标转换
	# print("鼠标位置转换 - 原始: %s, 相对: %s, 标准化: %s" % [mouse_pos, relative_pos, normalized_pos])
	
	# 限制目标位置在合理范围内
	target_position.x = clamp(normalized_pos.x, -max_distance, max_distance)
	target_position.y = clamp(normalized_pos.y, -max_distance, max_distance)
	
	# 添加最小变化阈值，避免微小变化导致抽搐
	var min_change = 0.01
	if abs(target_position.x - current_position.x) < min_change:
		target_position.x = current_position.x
	if abs(target_position.y - current_position.y) < min_change:
		target_position.y = current_position.y
	
	# 重置空闲计时器
	idle_timer = 0.0

func update_eye_tracking():
	# 检查眼动追踪节点是否有效
	if not gd_cubism_target_point:
		# 尝试重新获取节点引用
		refresh_eye_tracking_node()
		if not gd_cubism_target_point:
			return  # 如果仍然无效，跳过本次更新
	
	# 平滑插值到目标位置
	current_position = current_position.lerp(target_position, smooth_factor)
	
	# 设置目标点（确保参数在有效范围内）
	var clamped_position = Vector2(
		clamp(current_position.x, -1.0, 1.0),
		clamp(current_position.y, -1.0, 1.0)
	)
	gd_cubism_target_point.set_target(clamped_position)
	
		
	# 使用双重保障：GDCubismEffectTargetPoint + 强制参数设置
	if gd_cubism_target_point:
		var model = gd_cubism_target_point.get_parent()
		if model:
			# 强制设置参数作为备用保障
			force_set_eye_tracking_parameters()
	
	# 调试信息（可以注释掉）
	# print("眼动追踪 - 目标位置: ", target_position, " 当前位置: ", current_position)
	

# 查找眼动追踪节点
func find_eye_tracking_node():
	gd_cubism_target_point = main_scene.get_node("Sprite2D/SubViewport/GDCubismUserModel/GDCubismEffectTargetPoint")
	if gd_cubism_target_point:
		print("眼动追踪节点找到")
		
		# 配置GDCubismEffectTargetPoint的重要属性
		gd_cubism_target_point.eyes_range = 1.5  # 眼球移动敏感度（增加50%）
		gd_cubism_target_point.head_range = 45.0  # 头部移动敏感度（增加50%）
		gd_cubism_target_point.body_range = 20.0  # 身体移动敏感度（增加100%）
		print("眼动追踪范围设置 - 眼球: %f, 头部: %f, 身体: %f" % [gd_cubism_target_point.eyes_range, gd_cubism_target_point.head_range, gd_cubism_target_point.body_range])
		
		# 设置初始目标位置
		gd_cubism_target_point.set_target(Vector2(0, 0))
	else:
		print("警告：无法找到眼动追踪节点")

# 重新获取眼动追踪节点引用
func refresh_eye_tracking_node():
	# 等待一帧确保节点完全加载
	await get_tree().process_frame
	
	# 尝试获取眼动追踪节点
	gd_cubism_target_point = main_scene.get_node("Sprite2D/SubViewport/GDCubismUserModel/GDCubismEffectTargetPoint")
	
	if gd_cubism_target_point:
		print("眼动追踪节点重新获取成功")
		# 保持当前的眼动追踪状态，不重置位置
		# 只重置空闲计时器
		idle_timer = 0.0
		
		# 配置GDCubismEffectTargetPoint的重要属性
		gd_cubism_target_point.eyes_range = 1.5  # 眼球移动敏感度（增加50%）
		gd_cubism_target_point.head_range = 45.0  # 头部移动敏感度（增加50%）
		gd_cubism_target_point.body_range = 20.0  # 身体移动敏感度（增加100%）
		print("眼动追踪范围设置 - 眼球: %f, 头部: %f, 身体: %f" % [gd_cubism_target_point.eyes_range, gd_cubism_target_point.head_range, gd_cubism_target_point.body_range])
		
		# 强制设置一次目标位置，确保眼动追踪正常工作
		gd_cubism_target_point.set_target(current_position)
		
		# 检查眼动追踪参数是否正确设置
		print("眼动追踪节点已重新获取，当前位置: %s, 目标位置: %s" % [current_position, target_position])
		print("眼动追踪状态保持连续性，避免抽搐")
		
		# 检查Live2D模型的眼动追踪参数
		if main_scene:
			var model = main_scene.get_node("Sprite2D/SubViewport/GDCubismUserModel")
			if model:
				# 检查眼动追踪相关参数
				var eye_params = []
				var params = model.get_parameters()
				for param in params:
					var param_name = param.get_id()
					if "eye" in param_name.to_lower() or "angle" in param_name.to_lower():
						eye_params.append(param_name)
				
				if eye_params.size() > 0:
					print("找到眼动追踪参数: ", eye_params)
				else:
					print("警告：未找到眼动追踪相关参数")
		
		# 立即更新一次眼动追踪，确保连续性
		update_eye_tracking()
		
		return true
	else:
		print("警告：无法重新获取眼动追踪节点")
		return false

# 重置眼动追踪状态
func reset_eye_tracking_state():
	target_position = Vector2(0, 0)
	current_position = Vector2(0, 0)
	idle_timer = 0.0

# 强制设置眼动追踪参数
func force_set_eye_tracking_parameters():
	if not main_scene:
		return
		
	var model = main_scene.get_node("Sprite2D/SubViewport/GDCubismUserModel")
	if not model:
		return
	
	# 直接设置眼动追踪参数
	var params = model.get_parameters()
	var set_params = []
	for param in params:
		var param_name = param.get_id()
		if param_name == "ParamEyeBallX":
			# 眼球X轴：-1到1的范围
			var value = clamp(current_position.x, -1.0, 1.0)
			param.set_value(value)
			set_params.append("ParamEyeBallX: %.3f" % value)
		elif param_name == "ParamEyeBallY":
			# 眼球Y轴：-1到1的范围
			var value = clamp(current_position.y, -1.0, 1.0)
			param.set_value(value)
			set_params.append("ParamEyeBallY: %.3f" % value)
		elif param_name == "ParamAngleX":
			# 头部左右转动：-25到25度（增加范围，更明显）
			var value = clamp(current_position.x * 25.0, -25.0, 25.0)
			param.set_value(value)
			set_params.append("ParamAngleX: %.3f" % value)
		elif param_name == "ParamAngleY":
			# 头部上下转动：-25到25度（增加范围，更明显）
			var value = clamp(current_position.y * 25.0, -25.0, 25.0)
			param.set_value(value)
			set_params.append("ParamAngleY: %.3f" % value)
		elif param_name == "ParamAngleZ":
			# 头部倾斜：-8到8度（增加范围，更明显）
			var value = clamp(current_position.x * current_position.y * 8.0, -8.0, 8.0)
			param.set_value(value)
			set_params.append("ParamAngleZ: %.3f" % value)
		elif param_name == "ParamBodyAngleX":
			# 身体左右转动：-15到15度（增加范围，更明显）
			var value = clamp(current_position.x * 15.0, -15.0, 15.0)
			param.set_value(value)
			set_params.append("ParamBodyAngleX: %.3f" % value)
		elif param_name == "ParamBodyAngleY":
			# 身体上下转动：-15到15度（增加范围，更明显）
			var value = clamp(current_position.y * 15.0, -15.0, 15.0)
			param.set_value(value)
			set_params.append("ParamBodyAngleY: %.3f" % value)
		elif param_name == "ParamBodyAngleZ":
			# 身体倾斜：-6到6度（增加范围，更明显）
			var value = clamp(current_position.x * current_position.y * 6.0, -6.0, 6.0)
			param.set_value(value)
			set_params.append("ParamBodyAngleZ: %.3f" % value)
	

# 完整的眼动追踪重新加载
func complete_eye_tracking_reload():
	# 1. 重置所有眼动追踪状态
	reset_eye_tracking_state()
	
	# 2. 等待模型完全加载
	await get_tree().create_timer(2.0).timeout
	
	# 3. 重新获取眼动追踪节点
	gd_cubism_target_point = main_scene.get_node("Sprite2D/SubViewport/GDCubismUserModel/GDCubismEffectTargetPoint")
	if not gd_cubism_target_point:
		print("错误：无法重新获取眼动追踪节点")
		return
	
	print("眼动追踪节点重新获取成功")
	
	# 4. 重新设置节点参数（GDCubismEffectTargetPoint不支持直接设置这些属性）
	# gd_cubism_target_point.smooth_factor = smooth_factor  # 不支持
	# gd_cubism_target_point.max_distance = max_distance    # 不支持
	print("眼动追踪节点参数已在场景文件中设置")
	
	# 5. 注释掉强制参数设置，避免与GDCubismEffectTargetPoint冲突
	# force_set_eye_tracking_parameters()
	# print("眼动追踪参数已强制设置")
	
	# 6. 等待一帧后再次确认
	await get_tree().process_frame
	# force_set_eye_tracking_parameters()
	# print("眼动追踪参数二次确认完成")
	
	# 7. 重新设置目标位置
	gd_cubism_target_point.set_target(current_position)
	print("眼动追踪目标位置已重新设置")
	
	print("眼动追踪完整重新加载完成！")

# 处理鼠标移动事件（从主场景调用）
func handle_mouse_motion(mouse_pos: Vector2):
	# 只更新鼠标位置，让_process函数处理眼动追踪
	update_mouse_position(mouse_pos, true)  # 强制更新
