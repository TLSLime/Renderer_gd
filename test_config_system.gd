extends Node

# 测试配置系统是否正常工作
func _ready():
	print("=== 开始测试配置系统 ===")
	
	# 等待一帧确保所有节点都准备好
	await get_tree().process_frame
	
	# 获取主场景和ConfigManager
	var main_scene = get_tree().get_first_node_in_group("main_scene")
	if not main_scene:
		print("错误：找不到主场景")
		return
	
	var config_manager = main_scene.get_node("ConfigManager")
	if not config_manager:
		print("错误：找不到ConfigManager")
		return
	
	# 测试1：检查配置文件是否有效
	print("测试1：检查配置文件有效性")
	var is_valid = config_manager.is_config_valid()
	print("配置文件有效: %s" % is_valid)
	
	# 测试2：获取当前配置
	print("测试2：获取当前配置")
	var current_config = config_manager.get_current_config()
	print("当前配置: %s" % current_config)
	
	# 测试3：测试配置保存
	print("测试3：测试配置保存")
	var test_config = {
		"model_index": 1,
		"smaa": 0.15,
		"debanding": false,
		"mipmap": false,
		"zoom": 0.5,
		"resolution": 1024,
		"hdr": false,
		"lod": 0.8
	}
	
	var save_success = config_manager.save_config(test_config)
	print("配置保存成功: %s" % save_success)
	
	# 测试4：测试配置加载
	print("测试4：测试配置加载")
	config_manager.load_saved_config()
	
	# 测试5：验证配置是否正确应用
	print("测试5：验证配置应用")
	var camera = main_scene.get_node("Sprite2D/SubViewport/Camera2D")
	if camera:
		print("当前缩放: %s" % camera.zoom)
	
	var viewport = main_scene.get_node("Sprite2D/SubViewport")
	if viewport:
		print("当前分辨率: %s" % viewport.size)
		print("HDR启用: %s" % viewport.use_hdr_2d)
		print("LOD阈值: %s" % viewport.mesh_lod_threshold)
	
	print("=== 配置系统测试完成 ===")
	
	# 延迟5秒后删除测试节点
	await get_tree().create_timer(5.0).timeout
	queue_free()
