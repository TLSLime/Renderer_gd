extends Node2D

# 管理器引用
var eye_tracking_manager: Node
var model_manager: Node
var animation_manager: Node
var hit_area_manager: Node
var config_manager: Node
var control_panel_manager: Node

# 窗口拖动相关变量
var relaty: Vector2 = Vector2.ZERO
var is_dragging: bool = false


func _ready() -> void:
	# 保持鼠标模式为可见，但启用鼠标移动检测
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# 添加到组中，供控制面板查找
	add_to_group("main_scene")
	add_to_group("main")
	
	# 初始化各个管理器
	initialize_managers()
	
	# 立即开始一次性加载配置和模型，减少启动延迟
	await load_config_and_model()
	

# 一次性加载配置和模型
func load_config_and_model():
	# 直接加载配置并等待模型完全加载完成
	await config_manager.load_saved_config_and_wait_complete()
	
	# 模型加载完成后立即获取动作和表情信息
	animation_manager.load_motions_and_expressions()

# 初始化各个管理器
func initialize_managers():
	# 创建各个管理器节点
	eye_tracking_manager = preload("res://src/EyeTrackingManager.gd").new()
	model_manager = preload("res://src/ModelManager.gd").new()
	animation_manager = preload("res://src/AnimationManager.gd").new()
	hit_area_manager = preload("res://src/HitAreaManager.gd").new()
	config_manager = preload("res://src/ConfigManager.gd").new()
	control_panel_manager = preload("res://src/ControlPanelManager.gd").new()
	
	# 添加为子节点并设置名称
	add_child(eye_tracking_manager)
	eye_tracking_manager.name = "EyeTrackingManager"
	
	add_child(model_manager)
	model_manager.name = "ModelManager"
	
	add_child(animation_manager)
	animation_manager.name = "AnimationManager"
	
	add_child(hit_area_manager)
	hit_area_manager.name = "HitAreaManager"
	
	add_child(config_manager)
	config_manager.name = "ConfigManager"
	
	add_child(control_panel_manager)
	control_panel_manager.name = "ControlPanelManager"
	
	

func _input(event):
	# 控制面板快捷键
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			control_panel_manager.toggle_control_panel()
		elif event.keycode == KEY_ESCAPE and control_panel_manager.control_panel and control_panel_manager.control_panel.visible:
			control_panel_manager.control_panel.visible = false
	
	# 鼠标移动处理
	if event is InputEventMouseMotion:
		if event.button_mask == MOUSE_BUTTON_MASK_MIDDLE:
			# 处理窗口拖动
			get_tree().root.position = Vector2i(relaty + Vector2(DisplayServer.mouse_get_position()))
		else:
			# 委托给眼动追踪管理器处理
			eye_tracking_manager.handle_mouse_motion(event.position)
	
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == 1:
			# 委托给动画管理器处理点击
			animation_manager.handle_click_with_hitarea(event.position)
		elif event.pressed and event.button_index == 2:
			# 中键按下，初始化拖动偏移量
			var drag_mouse_pos = Vector2(DisplayServer.mouse_get_position())
			var root_pos = Vector2(get_tree().root.position)
			relaty = root_pos - drag_mouse_pos
	


# _process函数已移除，各个管理器自己处理自己的更新逻辑

# 供控制面板调用的接口函数
func get_available_models():
	return model_manager.get_available_models()

func get_current_model_index():
	return model_manager.get_current_model_index()

func switch_model(model_index: int):
	model_manager.switch_model(model_index)

func switch_model_lightweight(model_index: int):
	model_manager.switch_model_lightweight(model_index)

func apply_model_switch_only(model_index: int):
	model_manager.apply_model_switch_only(model_index)

func clear_control_panel_reference():
	control_panel_manager.clear_control_panel_reference()
