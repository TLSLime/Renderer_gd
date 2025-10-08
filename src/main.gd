extends Node2D

@onready var gd_cubism_user_model: GDCubismUserModel = %GDCubismUserModel
@onready var gd_cubism_target_point: GDCubismEffectTargetPoint = %GDCubismEffectTargetPoint
var gd_cubism_hit_area: GDCubismEffectHitArea = null

# 控制面板相关
var control_panel: Control = null

# 眼动追踪相关变量
var target_position: Vector2 = Vector2(0, 0)
var current_position: Vector2 = Vector2(0, 0)
var smooth_factor: float = 0.1  # 平滑系数，值越小越平滑
var max_distance: float = 0.8   # 最大跟踪距离
var idle_timer: float = 0.0
var idle_threshold: float = 2.0  # 空闲时间阈值（秒）

# 动作和表情相关变量
var available_motions: Dictionary = {}
var available_expressions: Array = []
var click_cooldown: float = 0.0
var click_cooldown_time: float = 0.3  # 点击冷却时间（秒）
var valid_click_pending: bool = false  # 标记是否有有效的点击等待处理

# 自动恢复相关变量
var auto_reset_timer: float = 0.0
var auto_reset_duration: float = 5.0  # 5秒后恢复默认表情
var is_playing_animation: bool = false  # 是否正在播放动画

# 窗口拖动相关变量
var relaty: Vector2 = Vector2.ZERO
var is_dragging: bool = false


func _ready() -> void:
	# 保持鼠标模式为可见，但启用鼠标移动检测
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	print("自动眼动追踪已启用")
	
	# 控制面板将在按F1键时创建
	
	# 尝试查找HitArea节点
	find_hit_area_node()
	
	# 等待模型加载完成后获取动作和表情信息
	await get_tree().process_frame
	load_motions_and_expressions()
	

func _input(event):
	# 控制面板快捷键
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			toggle_control_panel()
		elif event.keycode == KEY_ESCAPE and control_panel and control_panel.visible:
			control_panel.visible = false
	
	# 鼠标移动处理
	if event is InputEventMouseMotion:
		if event.button_mask == MOUSE_BUTTON_MASK_MIDDLE:
			# 处理窗口拖动
			get_tree().root.position = Vector2i(relaty + Vector2(DisplayServer.mouse_get_position()))
		else:
			# 获取鼠标在屏幕上的绝对位置
			var mouse_pos = event.position
			
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
			
			# 限制目标位置在合理范围内
			target_position.x = clamp(normalized_pos.x, -max_distance, max_distance)
			target_position.y = clamp(normalized_pos.y, -max_distance, max_distance)
			
			# 重置空闲计时器
			idle_timer = 0.0
			
			# 更新眼动追踪
			update_eye_tracking()
	
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == 1:
			if click_cooldown <= 0.0:
				handle_click_with_hitarea(event.position)
			# 初始化拖动偏移量
			var drag_mouse_pos = Vector2(DisplayServer.mouse_get_position())
			var root_pos = Vector2(get_tree().root.position)
			relaty = root_pos - drag_mouse_pos
			print("开始拖动 - 偏移: ", relaty)
	
	elif event is InputEventKey and event.pressed:
		if event.keycode == 32:  # KEY_SPACE
			# 空格键重置眼动追踪
			target_position = Vector2(0, 0)
			current_position = Vector2(0, 0)
			print("眼动追踪已重置")
		elif event.keycode == 49:  # KEY_1
			# 数字键1触发随机动作
			trigger_random_motion()
		elif event.keycode == 50:  # KEY_2
			# 数字键2触发随机表情
			trigger_random_expression()
		elif event.keycode == 51:  # KEY_3
			# 数字键3手动恢复默认表情（测试用）
			reset_to_default_expression()

func _process(delta: float):
	# 更新空闲计时器
	idle_timer += delta
	
	# 更新点击冷却时间
	if click_cooldown > 0.0:
		click_cooldown -= delta
	
	# 更新自动恢复计时器
	if is_playing_animation:
		auto_reset_timer += delta
		if auto_reset_timer >= auto_reset_duration:
			reset_to_default_expression()
			is_playing_animation = false
			auto_reset_timer = 0.0
	
	# 持续检测鼠标位置（即使移出窗口）
	var mouse_pos = get_global_mouse_position()
	var screen_size = get_viewport().get_visible_rect().size
	
	# 将鼠标位置转换为相对于屏幕中心的坐标
	var center = screen_size * 0.5
	var relative_pos = mouse_pos - center
	
	# 将坐标标准化到-1到1的范围，Y轴取反
	var normalized_pos = Vector2(
		relative_pos.x / (screen_size.x * 0.5),
		-relative_pos.y / (screen_size.y * 0.5)  # Y轴取反
	)
	
	# 限制目标位置在合理范围内
	target_position.x = clamp(normalized_pos.x, -max_distance, max_distance)
	target_position.y = clamp(normalized_pos.y, -max_distance, max_distance)
	
	# 如果鼠标在窗口内，重置空闲计时器
	if mouse_pos.x >= 0 and mouse_pos.x <= screen_size.x and mouse_pos.y >= 0 and mouse_pos.y <= screen_size.y:
		idle_timer = 0.0
	# 如果空闲时间超过阈值，逐渐回到中心位置
	elif idle_timer > idle_threshold:
		target_position = target_position.lerp(Vector2(0, 0), 0.02)
	
	# 平滑更新眼动追踪
	update_eye_tracking()

func update_eye_tracking():
	# 平滑插值到目标位置
	current_position = current_position.lerp(target_position, smooth_factor)
	
	# 设置目标点
	gd_cubism_target_point.set_target(current_position)

# 加载动作和表情信息
func load_motions_and_expressions():
	# 获取可用动作
	available_motions = gd_cubism_user_model.get_motions()
	print("可用动作:")
	for group in available_motions.keys():
		var motions_in_group = available_motions[group]
		print("  group: %s, type: %s, value: %s" % [group, typeof(motions_in_group), motions_in_group])
		if motions_in_group is Array:
			for no in motions_in_group:
				print("    no: %d" % no)
		else:
			print("    no: %d" % motions_in_group)
	
	# 获取可用表情
	available_expressions = gd_cubism_user_model.get_expressions()
	print("可用表情:")
	for expression in available_expressions:
		print("  expression: %s" % expression)

# 使用HitArea处理鼠标点击（简化版，依赖alpha通道检测）
func handle_click_with_hitarea(click_pos: Vector2):
	print("处理点击: ", click_pos)
	
	# 将屏幕坐标转换为Live2D模型的本地坐标
	var local_pos = gd_cubism_user_model.to_local(click_pos)
	print("本地坐标: ", local_pos)
	
	# 获取Live2D模型的画布信息
	var canvas_info = gd_cubism_user_model.get_canvas_info()
	if canvas_info.is_empty():
		print("无法获取画布信息")
		return
	
	var model_size = canvas_info["size_in_pixels"]
	print("模型尺寸: ", model_size)
	
	# 标记这是一个有效的点击（让HitArea的alpha通道检测来决定是否触发）
	valid_click_pending = true
	
	# 如果有HitArea节点，使用HitArea的alpha通道检测
	if gd_cubism_hit_area:
		print("HitArea节点: ", gd_cubism_hit_area.name)
		
		# 将坐标标准化到-1到1的范围
		var normalized_pos = Vector2(
			(local_pos.x / model_size.x) * 2.0 - 1.0,
			-(local_pos.y / model_size.y) * 2.0 + 1.0  # Y轴取反
		)
		print("标准化坐标: ", normalized_pos)
		
		# 设置HitArea的目标点（alpha通道检测会自动处理空白区域穿透）
		gd_cubism_hit_area.set_target(normalized_pos)
		print("已设置HitArea目标点，等待alpha通道检测结果")
	else:
		print("没有HitArea节点，直接触发动作")
		# 直接触发动作或表情
		var rand = randf()
		if rand < 0.7:  # 70%概率触发动作
			trigger_random_motion()
		else:  # 30%概率触发表情
			trigger_random_expression()
		
		# 重置标志
		valid_click_pending = false
	
	# 设置点击冷却时间
	click_cooldown = click_cooldown_time

# HitArea进入信号处理（简化版，依赖alpha通道检测）
func _on_hit_area_entered(_model: GDCubismUserModel, id: String):
	print("点击在HitArea上: ", id, " 有效点击: ", valid_click_pending)
	
	# 如果HitArea检测到点击（说明alpha通道不为0），就触发动作
	if valid_click_pending:
		# 随机触发动作或表情
		var rand = randf()
		if rand < 0.7:  # 70%概率触发动作
			trigger_random_motion()
		else:  # 30%概率触发表情
			trigger_random_expression()
		
		# 重置标志
		valid_click_pending = false
		print("动作/表情已触发")
	else:
		print("点击在空白区域，不触发动作")

# HitArea退出信号处理
func _on_hit_area_exited(_model: GDCubismUserModel, id: String):
	print("离开HitArea: ", id)

# 查找HitArea节点
func find_hit_area_node():
	print("正在查找HitArea节点...")
	
	# 在GDCubismUserModel的子节点中查找
	if gd_cubism_user_model:
		for child in gd_cubism_user_model.get_children():
			print("子节点: ", child.name, " 类型: ", child.get_class())
			if child is GDCubismEffectHitArea:
				print("找到HitArea节点: ", child.name)
				gd_cubism_hit_area = child
				gd_cubism_hit_area.hit_area_entered.connect(_on_hit_area_entered)
				gd_cubism_hit_area.hit_area_exited.connect(_on_hit_area_exited)
				print("HitArea信号已连接")
				return
	
	# 在整个场景中查找
	var hit_areas = get_tree().get_nodes_in_group("hit_area")
	if hit_areas.size() > 0:
		print("在组中找到HitArea: ", hit_areas[0].name)
		gd_cubism_hit_area = hit_areas[0]
		gd_cubism_hit_area.hit_area_entered.connect(_on_hit_area_entered)
		gd_cubism_hit_area.hit_area_exited.connect(_on_hit_area_exited)
		return
	
	print("未找到HitArea节点，将使用简化的点击检测")

# 触发随机动作
func trigger_random_motion():
	if available_motions.is_empty():
		print("没有可用的动作")
		return
	
	# 随机选择一个动作组
	var groups = available_motions.keys()
	var random_group = groups[randi() % groups.size()]
	var motions_in_group = available_motions[random_group]
	
	# 检查motions_in_group的类型
	if motions_in_group is Array:
		# 如果是数组，随机选择其中一个动作
		var random_motion_no = motions_in_group[randi() % motions_in_group.size()]
		# 播放动作
		gd_cubism_user_model.start_motion(random_group, random_motion_no, gd_cubism_user_model.PRIORITY_NORMAL)
		print("播放动作: group=%s, no=%d" % [random_group, random_motion_no])
	else:
		# 如果是单个数字，直接使用
		gd_cubism_user_model.start_motion(random_group, motions_in_group, gd_cubism_user_model.PRIORITY_NORMAL)
		print("播放动作: group=%s, no=%d" % [random_group, motions_in_group])

# 触发随机表情
func trigger_random_expression():
	if available_expressions.is_empty():
		print("没有可用的表情")
		return
	
	# 随机选择一个表情
	var random_expression = available_expressions[randi() % available_expressions.size()]
	
	# 播放表情
	gd_cubism_user_model.start_expression(random_expression)
	print("播放表情: %s" % random_expression)
	
	# 开始5秒恢复计时
	is_playing_animation = true
	auto_reset_timer = 0.0
	print("表情将在5秒后自动恢复")

# 恢复默认表情
func reset_to_default_expression():
	if gd_cubism_user_model:
		# 方法1：尝试停止当前表情
		gd_cubism_user_model.start_expression("")
		print("已停止当前表情")
		
		# 方法2：如果停止无效，尝试播放中性表情
		# 等待一帧后检查是否需要播放默认表情
		await get_tree().process_frame

# 控制面板相关函数
func setup_control_panel():
	# 加载控制面板场景
	var control_panel_scene = preload("res://scenes/ControlPanel.tscn")
	control_panel = control_panel_scene.instantiate()
	
	# 创建独立窗口
	var window = Window.new()
	window.add_child(control_panel)
	
	# 设置窗口属性
	window.always_on_top = true
	window.transparent = false
	window.borderless = false  # 恢复标题栏
	window.size = Vector2i(450, 500)  # 增大窗口尺寸
	window.position = Vector2i(50, 50)
	window.title = "Live2D 渲染控制"
	window.min_size = Vector2i(400, 450)  # 调整最小尺寸
	window.max_size = Vector2i(700, 800)  # 调整最大尺寸
	
	# 禁用窗口调整大小和最小化最大化
	window.unresizable = true
	window.minimize_disabled = true
	window.maximize_disabled = true
	
	# 连接窗口关闭信号
	window.close_requested.connect(_on_control_panel_window_close_requested)
	
	# 使用call_deferred延迟添加窗口
	get_tree().root.call_deferred("add_child", window)
	
	# 添加主场景组标识，方便控制面板查找
	add_to_group("main_scene")
	
	# 显示窗口
	window.visible = true
	
	print("控制面板已创建并显示")

func toggle_control_panel():
	if control_panel and is_instance_valid(control_panel):
		var window = control_panel.get_parent()
		if window and is_instance_valid(window):
			# 窗口存在且有效，切换可见性
			window.visible = !window.visible
			if window.visible:
				print("控制面板已打开")
			else:
				print("控制面板已关闭")
		else:
			# 窗口被关闭了，重新创建
			print("控制面板窗口已关闭，重新创建...")
			control_panel = null  # 清空引用
			setup_control_panel()
	else:
		# 控制面板不存在，创建并显示
		print("创建控制面板...")
		control_panel = null  # 确保引用为空
		setup_control_panel()


func clear_control_panel_reference():
	# 清空控制面板引用，供控制面板关闭时调用
	print("清空控制面板引用")
	control_panel = null

func _on_control_panel_window_close_requested():
	# 当用户通过标题栏X按钮关闭窗口时
	print("控制面板窗口通过标题栏关闭")
	# 先获取窗口引用，再清空控制面板引用
	if control_panel and is_instance_valid(control_panel):
		var window = control_panel.get_parent()
		if window and is_instance_valid(window):
			# 清空控制面板引用
			control_panel = null
			# 关闭窗口
			window.queue_free()
			print("控制面板窗口已关闭")
		else:
			control_panel = null
	else:
		control_panel = null
