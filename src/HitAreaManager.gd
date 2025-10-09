extends Node
class_name HitAreaManager

# 节点引用
var gd_cubism_hit_area: GDCubismEffectHitArea = null
var main_scene: Node2D = null

func _ready():
	# 获取主场景引用
	main_scene = get_parent()
	if not main_scene:
		print("错误：HitAreaManager需要作为主场景的子节点")
		return

# 查找HitArea节点
func find_hit_area_node():
	# 在GDCubismUserModel的子节点中查找
	var gd_cubism_user_model = main_scene.get_node("Sprite2D/SubViewport/GDCubismUserModel")
	if gd_cubism_user_model:
		for child in gd_cubism_user_model.get_children():
			if child is GDCubismEffectHitArea:
				gd_cubism_hit_area = child
				# 安全连接信号
				connect_hit_area_signals()
				return
	
	# 在整个场景中查找
	var hit_areas = get_tree().get_nodes_in_group("hit_area")
	if hit_areas.size() > 0:
		gd_cubism_hit_area = hit_areas[0]
		# 安全连接信号
		connect_hit_area_signals()

# 安全连接HitArea信号
func connect_hit_area_signals():
	if not gd_cubism_hit_area:
		return
	
	# 先断开可能存在的连接
	if gd_cubism_hit_area.hit_area_entered.is_connected(_on_hit_area_entered):
		gd_cubism_hit_area.hit_area_entered.disconnect(_on_hit_area_entered)
	if gd_cubism_hit_area.hit_area_exited.is_connected(_on_hit_area_exited):
		gd_cubism_hit_area.hit_area_exited.disconnect(_on_hit_area_exited)
	
	# 重新连接信号
	gd_cubism_hit_area.hit_area_entered.connect(_on_hit_area_entered)
	gd_cubism_hit_area.hit_area_exited.connect(_on_hit_area_exited)

# HitArea进入信号处理
func _on_hit_area_entered(_model: GDCubismUserModel, _id: String):
	# 通知动画管理器处理点击
	var animation_mgr = main_scene.get_node("AnimationManager")
	if animation_mgr:
		animation_mgr.valid_click_pending = true
		animation_mgr.trigger_random_animation()
		animation_mgr.valid_click_pending = false

# HitArea退出信号处理
func _on_hit_area_exited(_model: GDCubismUserModel, _id: String):
	pass

# 清理HitArea连接
func cleanup_hit_area_connections():
	if gd_cubism_hit_area:
		if gd_cubism_hit_area.hit_area_entered.is_connected(_on_hit_area_entered):
			gd_cubism_hit_area.hit_area_entered.disconnect(_on_hit_area_entered)
		if gd_cubism_hit_area.hit_area_exited.is_connected(_on_hit_area_exited):
			gd_cubism_hit_area.hit_area_exited.disconnect(_on_hit_area_exited)
		gd_cubism_hit_area = null
