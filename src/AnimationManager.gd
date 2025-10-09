extends Node
class_name AnimationManager

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

# 节点引用
var gd_cubism_user_model: GDCubismUserModel = null
var main_scene: Node2D = null

func _ready():
	# 获取主场景引用
	main_scene = get_parent()
	if not main_scene:
		print("错误：AnimationManager需要作为主场景的子节点")
		return
	
	# 获取GDCubismUserModel引用
	gd_cubism_user_model = main_scene.get_node("Sprite2D/SubViewport/GDCubismUserModel")
	if not gd_cubism_user_model:
		print("错误：无法找到GDCubismUserModel节点")
		return

func _process(delta: float):
	# 更新点击冷却时间
	if click_cooldown > 0.0:
		click_cooldown -= delta
	
	# 更新自动恢复计时器
	if is_playing_animation:
		auto_reset_timer += delta
		if auto_reset_timer >= auto_reset_duration:
			await reset_to_default_expression()
			is_playing_animation = false
			auto_reset_timer = 0.0

# 加载动作和表情信息
func load_motions_and_expressions():
	print("开始加载动作和表情...")
	
	# 检查模型是否已加载
	if not gd_cubism_user_model:
		print("错误：GDCubismUserModel未初始化")
		return
	
	# 获取可用动作
	available_motions = gd_cubism_user_model.get_motions()
	print("可用动作数量: %d" % available_motions.size())
	
	if available_motions.is_empty():
		print("警告：没有找到可用的动作")
	else:
		print("动作详情:")
		for group in available_motions.keys():
			var motions_in_group = available_motions[group]
			print("  组: %s, 类型: %s, 值: %s" % [group, typeof(motions_in_group), motions_in_group])
			
			# 智能显示动作信息
			if motions_in_group is Array:
				print("    动作编号数组: ", motions_in_group)
			elif motions_in_group is int:
				print("    动作数量: %d (编号范围: 0-%d)" % [motions_in_group, motions_in_group-1])
			elif motions_in_group is float:
				print("    动作数量: %.0f (编号范围: 0-%.0f)" % [motions_in_group, motions_in_group-1])
			elif motions_in_group is String:
				var int_value = motions_in_group.to_int()
				if int_value > 0:
					print("    动作数量: %s (编号范围: 0-%d)" % [motions_in_group, int_value-1])
				else:
					print("    动作数量: %s (无效值)" % motions_in_group)
			else:
				print("    未知数据类型: %s" % typeof(motions_in_group))
	
	# 获取可用表情
	available_expressions = gd_cubism_user_model.get_expressions()
	print("可用表情数量: %d" % available_expressions.size())
	
	if available_expressions.is_empty():
		print("警告：没有找到可用的表情")
	else:
		print("表情详情:")
		for expression in available_expressions:
			print("  表情: %s" % expression)
	
	# 总结
	var total_animations = available_motions.size() + available_expressions.size()
	print("总计可用动画: %d (动作: %d, 表情: %d)" % [total_animations, available_motions.size(), available_expressions.size()])
	
	if total_animations == 0:
		print("警告：模型中没有找到任何动作或表情，点击将不会触发任何动画")
	else:
		print("模型加载完成，点击Live2D模型将触发随机动画")

# 处理鼠标点击
func handle_click_with_hitarea(_click_pos: Vector2):
	# 检查是否有可用的动画
	if available_motions.is_empty() and available_expressions.is_empty():
		return
	
	# 直接触发动作，不依赖HitArea检测
	trigger_random_animation()
	
	# 设置点击冷却时间
	click_cooldown = click_cooldown_time

# 触发随机动画（动作或表情）
func trigger_random_animation():
	# 随机选择触发动作或表情（50%概率）
	var has_motions = not available_motions.is_empty()
	var has_expressions = not available_expressions.is_empty()
	
	if has_motions and has_expressions:
		# 如果两者都有，随机选择
		if randi() % 2 == 0:
			trigger_random_motion()
		else:
			trigger_random_expression()
	elif has_motions:
		trigger_random_motion()
	elif has_expressions:
		trigger_random_expression()
	else:
		print("AnimationManager: 没有可用的动作或表情")

# 触发随机动作
func trigger_random_motion():
	if available_motions.is_empty():
		print("AnimationManager: 没有可用的动作")
		return
	
	# 随机选择一个动作组
	var groups = available_motions.keys()
	var random_group = groups[randi() % groups.size()]
	var motions_in_group = available_motions[random_group]
	
	# print("AnimationManager: 选择动作组: %s, 数据: %s (类型: %s)" % [random_group, motions_in_group, typeof(motions_in_group)])  # 注释掉频繁输出
	
	# 智能处理不同类型的动作数据
	var random_motion_no = get_random_motion_number(motions_in_group)
	
	# print("AnimationManager: 选择动作编号: %d" % random_motion_no)  # 注释掉频繁输出
	
	# 检查动作编号是否有效
	if random_motion_no < 0:
		print("AnimationManager: 无效的动作编号，跳过播放")
		return
	
	# 播放动作
	var success = gd_cubism_user_model.start_motion(random_group, random_motion_no, gd_cubism_user_model.PRIORITY_NORMAL)
	
	if success:
		# print("AnimationManager: 动作播放成功 - 组: %s, 编号: %d" % [random_group, random_motion_no])  # 注释掉频繁输出
		# 设置动画属性
		gd_cubism_user_model.anim_motion = random_group
		
		# 开始5秒恢复计时
		is_playing_animation = true
		auto_reset_timer = 0.0
	else:
		print("AnimationManager: 动作播放失败 - 组: %s, 编号: %d" % [random_group, random_motion_no])
		
		# 尝试其他方法播放动作
		print("AnimationManager: 尝试备用播放方法...")
		gd_cubism_user_model.anim_motion = random_group
		
		# 尝试使用不同的优先级
		var alt_success = gd_cubism_user_model.start_motion(random_group, random_motion_no, gd_cubism_user_model.PRIORITY_FORCE)
		if alt_success:
			# print("AnimationManager: 备用方法播放成功")  # 注释掉频繁输出
			is_playing_animation = true
			auto_reset_timer = 0.0

# 智能获取随机动作编号
func get_random_motion_number(motions_data):
	# 处理不同类型的数据
	if motions_data is Array:
		# 数组类型：直接随机选择
		if motions_data.size() > 0:
			return motions_data[randi() % motions_data.size()]
		else:
			return 0
	elif motions_data is int:
		# 整数类型：随机选择0到该数字-1之间的动作
		if motions_data > 0:
			return randi() % motions_data
		else:
			return 0
	elif motions_data is float:
		# 浮点数类型：转换为整数后处理
		var int_value = int(motions_data)
		if int_value > 0:
			return randi() % int_value
		else:
			return 0
	elif motions_data is String:
		# 字符串类型：尝试转换为整数
		var int_value = motions_data.to_int()
		if int_value > 0:
			return randi() % int_value
		else:
			# 尝试解析为浮点数
			var float_value = motions_data.to_float()
			if float_value > 0:
				return randi() % int(float_value)
			else:
				return 0
	elif motions_data is bool:
		# 布尔类型：true表示有1个动作，false表示没有动作
		return 0 if motions_data else -1
	elif motions_data is Dictionary:
		# 字典类型：尝试获取count或size字段
		if motions_data.has("count"):
			var count = motions_data["count"]
			if count is int and count > 0:
				return randi() % count
		elif motions_data.has("size"):
			var size = motions_data["size"]
			if size is int and size > 0:
				return randi() % size
		return 0
	else:
		# 其他类型：尝试转换为字符串再处理
		var str_value = str(motions_data)
		var int_value = str_value.to_int()
		if int_value > 0:
			return randi() % int_value
		else:
			print("警告：无法处理的动作数据类型: ", typeof(motions_data), " 值: ", motions_data)
			return 0

# 触发随机表情
func trigger_random_expression():
	if available_expressions.is_empty():
		print("AnimationManager: 没有可用的表情")
		return
	
	# 随机选择一个表情
	var random_expression = available_expressions[randi() % available_expressions.size()]
	
	# print("AnimationManager: 选择表情: %s" % random_expression)  # 注释掉频繁输出
	
	# 播放表情
	gd_cubism_user_model.start_expression(random_expression)
	
	# print("AnimationManager: 表情播放请求 - %s" % random_expression)  # 注释掉频繁输出
	# 开始5秒恢复计时
	is_playing_animation = true
	auto_reset_timer = 0.0

# 恢复默认状态
func reset_to_default_expression():
	if gd_cubism_user_model:
		# 停止当前表情
		gd_cubism_user_model.start_expression("")
		
		# 播放默认的Idle动作，实现平滑过渡
		if available_motions.has("Idle"):
			# 智能选择Idle动作
			var idle_motions = available_motions["Idle"]
			var idle_motion_no = get_random_motion_number(idle_motions)
			
			# 播放Idle动作，使用正常优先级实现平滑过渡
			gd_cubism_user_model.start_motion("Idle", idle_motion_no, gd_cubism_user_model.PRIORITY_NORMAL)
			gd_cubism_user_model.anim_motion = "Idle"
		else:
			# 如果没有Idle动作，则停止当前动作
			gd_cubism_user_model.anim_motion = ""
		
		# 等待一帧后检查状态
		await get_tree().process_frame

# 停止当前动画
func stop_current_animation():
	is_playing_animation = false
	auto_reset_timer = 0.0
