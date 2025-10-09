extends Node
class_name ControlPanelManager

# 控制面板相关
var control_panel: Control = null

# 节点引用
var main_scene: Node2D = null

func _ready():
	# 获取主场景引用
	main_scene = get_parent()
	if not main_scene:
		print("错误：ControlPanelManager需要作为主场景的子节点")
		return

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
	window.size = Vector2i(499, 699)  # 与MainPanel大小完全匹配
	window.position = Vector2i(50, 50)
	window.title = "Live2D 渲染控制"
	window.min_size = Vector2i(499, 699)  # 最小尺寸与MainPanel匹配
	window.max_size = Vector2i(499, 699)  # 最大尺寸与MainPanel匹配
	
	# 禁用窗口调整大小和最小化最大化
	window.unresizable = true
	window.minimize_disabled = true
	window.maximize_disabled = true
	
	# 连接窗口关闭信号
	window.close_requested.connect(_on_control_panel_window_close_requested)
	
	# 使用call_deferred延迟添加窗口
	get_tree().root.call_deferred("add_child", window)
	
	# 显示窗口
	window.visible = true
	
	# 延迟应用配置，等待UI节点完全初始化
	await get_tree().create_timer(0.1).timeout
	apply_current_config_to_panel()
	
	print("控制面板已创建并显示")

# 从主场景获取当前配置并应用到控制面板
func apply_current_config_to_panel():
	if not control_panel:
		return
	
	# 检查控制面板是否完全初始化
	if not control_panel.smaa_slider:
		print("控制面板UI节点尚未完全初始化，跳过配置同步")
		return
	
	# 获取主场景的当前配置
	var parent_scene = get_parent()
	if not parent_scene:
		return
	
	# 构建当前配置字典
	var current_config = {}
	
	# 获取当前模型索引
	var model_manager = parent_scene.get_node("ModelManager")
	if model_manager:
		current_config["model_index"] = model_manager.get_current_model_index()
	
	# 获取当前缩放设置
	var camera = parent_scene.get_node("Sprite2D/SubViewport/Camera2D")
	if camera:
		current_config["zoom"] = camera.zoom.x
	
	# 获取当前视口设置
	var viewport = parent_scene.get_node("Sprite2D/SubViewport")
	if viewport:
		current_config["resolution"] = viewport.size.x
		current_config["hdr"] = viewport.use_hdr_2d
		current_config["lod"] = viewport.mesh_lod_threshold
		current_config["debanding"] = viewport.use_debanding
		current_config["mipmap"] = viewport.texture_mipmap_bias != 0.0
	
	# 设置默认值
	current_config["smaa"] = 0.1
	
	# 使用ControlPanel的update_ui_from_config方法
	control_panel.update_ui_from_config(current_config)
	
	print("控制面板配置已从主场景同步")

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
