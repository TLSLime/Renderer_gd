# Godot Live2D 渲染器

一个基于Godot 4.5 Mono版本的Live2D桌面宠物渲染器，支持鼠标穿透、动态参数调整和性能优化。

## 项目概述

本项目使用Godot引擎和Live2D Cubism SDK实现了一个高性能的桌面宠物渲染模块，支持：

- Live2D模型渲染和动画
- 完整的眼动追踪系统（眼球、头部、身体跟随鼠标）
- 鼠标穿透功能（点击穿透到桌面）
- 动态参数调整（表情、动作、缩放等）
- 实时渲染设置控制面板
- JSON配置系统（支持类型验证和自动转换）
- 模块化架构（管理器模式，职责分离）
- 性能监控和优化

## 系统要求

- Windows 10/11
- Godot 4.x
- .NET 6.0 或更高版本
- 支持OpenGL的显卡

## 项目结构

```
renderer/
├── src/                    # 源代码目录
│   ├── main.gd            # 主脚本（场景管理和初始化）
│   ├── models.gd          # 模型基础脚本
│   ├── sub_viewport.gd    # 子视口管理
│   ├── ControlPanel.gd    # 控制面板脚本
│   ├── ControlPanelManager.gd  # 控制面板管理器
│   ├── ConfigManager.gd   # 配置管理器
│   ├── EyeTrackingManager.gd   # 眼动追踪管理器
│   ├── ModelManager.gd    # 模型管理器
│   ├── AnimationManager.gd     # 动画管理器
│   ├── HitAreaManager.gd  # 点击区域管理器
│   ├── MouseDetection.cs  # 鼠标检测（C#）
│   └── ApiManager.cs      # Windows API管理（C#）
├── scenes/                # 场景文件
│   ├── L2D.tscn          # 主Live2D场景
│   └── ControlPanel.tscn  # 控制面板UI场景
├── addons/               # 插件目录
│   └── gd_cubism/        # Live2D Cubism插件
└── Live2D/              # Live2D模型资源
    └── models/
```

## 安装和配置

### 1. 环境准备

1. 安装Godot 4.x
2. 确保已安装.NET 6.0或更高版本

### 2. 项目设置

1. 克隆或下载项目到本地
2. 使用Godot打开`project.godot`文件
3. 确保C#支持已启用

### 3. 模型配置

1. 将Live2D模型文件放置在`Live2D/models/`目录下
2. 模型应包含以下文件：
   - `.model3.json` - 模型配置文件
   - `.moc3` - 模型数据文件
   - `.physics3.json` - 物理配置文件
   - `.pose3.json` - 姿态配置文件
   - `texture_*.png` - 纹理文件
   - `motions/` - 动作文件夹
   - `expressions/` - 表情文件夹

## 使用方法

### 基本操作

1. **启动应用**：运行Godot项目或导出的可执行文件
2. **打开控制面板**：按F1键打开渲染设置控制面板
3. **调整设置**：在控制面板中调整各种渲染参数
4. **关闭控制面板**：再次按F1键或点击关闭按钮

### 控制面板功能

#### 渲染设置
- **缩放控制**：调整Live2D模型的显示大小
- **分辨率设置**：设置渲染分辨率（512-4096像素）
- **HDR开关**：启用/禁用高动态范围渲染
- **LOD阈值**：调整细节层次距离阈值

#### 抗锯齿设置
- **SMAA阈值**：子像素形态抗锯齿阈值
- **去条带**：启用/禁用去条带处理
- **Mipmap**：启用/禁用纹理Mipmap

#### 预设管理
- **保存预设**：将当前设置保存为预设
- **加载预设**：快速应用已保存的预设
- **重置设置**：恢复默认设置

### 鼠标穿透功能

应用启动后会自动检测鼠标位置：
- 当鼠标悬停在Live2D模型上时，窗口变为可点击状态
- 当鼠标离开模型区域时，窗口变为穿透状态（点击穿透到桌面）

## 开发指南

### 添加新的Live2D参数

1. 在`main.gd`中添加参数引用：
```gdscript
var param_eye_l_open: GDCubismParameterCS
var param_mouth_a: GDCubismParameterCS
```

2. 在`_ready()`中初始化参数：
```gdscript
param_eye_l_open = user_model.get_parameter("ParamEyeLOpen")
param_mouth_a = user_model.get_parameter("ParamMouthA")
```

3. 创建控制函数：
```gdscript
func set_eye_open(value: float):
    if param_eye_l_open:
        param_eye_l_open.value = value
```

### 自定义控制面板

1. 编辑`scenes/ControlPanel.tscn`添加新的UI控件
2. 在`ControlPanel.gd`中添加对应的处理函数
3. 在`setup_connections()`中连接信号

### 性能优化建议

1. **渲染设置**：
   - 使用合适的缩放值避免过度放大
   - 根据硬件性能调整分辨率
   - 启用HDR提升视觉效果

2. **内存管理**：
   - 定期清理不需要的资源
   - 使用对象池管理频繁创建的对象

3. **CPU优化**：
   - 避免在`_process()`中进行复杂计算
   - 使用`_physics_process()`处理物理相关逻辑

## 故障排除

### 常见问题

1. **模型不显示**：
   - 检查模型文件路径是否正确
   - 确认模型文件完整性
   - 查看控制台错误信息

2. **鼠标穿透不工作**：
   - 确认Windows版本支持
   - 检查管理员权限
   - 查看C#脚本编译是否成功

3. **控制面板无法打开**：
   - 按F1键打开
   - 检查场景树中是否存在控制面板节点
   - 查看控制台错误信息

4. **性能问题**：
   - 降低渲染分辨率
   - 调整LOD阈值
   - 关闭不必要的特效

### 调试信息

启用调试模式查看详细日志：
- 在Godot编辑器中运行项目
- 查看输出面板的调试信息
- 检查C#脚本的控制台输出

## 技术特性

- **渲染引擎**：Godot 4.x + OpenGL兼容模式
- **Live2D支持**：Cubism SDK 4.x
- **编程语言**：GDScript + C#
- **平台支持**：Windows 10/11
- **窗口管理**：Windows API集成
- **眼动追踪**：完整的鼠标跟随系统（眼球、头部、身体）
- **配置管理**：JSON格式配置文件，支持类型验证和自动转换
- **模块化架构**：管理器模式，职责分离，易于维护和扩展
- **性能优化**：一次性加载，减少启动卡顿，优化调试输出

## 许可证

本项目基于GPL3.0许可证开源。详见LICENSE文件。

## 贡献指南

欢迎提交Issue和Pull Request来改进项目：

1. Fork项目
2. 创建功能分支
3. 提交更改
4. 发起Pull Request

## 更新日志

### v0.0.8 (最新版本)
- **重大修复**：
  - 修复眼动追踪功能
  - 修复模型切换后眼动追踪失效问题
  - 实现眼球、头部、身体的完整跟随效果
  - 优化眼动追踪参数范围和敏感度
- **配置系统优化**：
  - 改进JSON配置文件的类型转换处理
  - 修复int/float类型转换导致的配置加载失败
  - 实现配置验证和自动类型转换
- **代码架构重构**：
  - 将main.gd的职责分散到专门的管理器
  - 新增EyeTrackingManager、ModelManager、AnimationManager等
  - 提高代码可维护性和模块化程度
- **启动流程优化**：
  - 实现配置和模型的一次性加载
  - 减少启动时的卡顿感
  - 保持眼动追踪状态的连续性
- **调试信息优化**：
  - 大幅减少控制台输出冗余信息
  - 保留核心错误和警告信息
  - 提高调试效率

### v0.0.6
- 基础Live2D渲染功能
- 鼠标穿透支持
- 动态参数调整
- 控制面板UI
- 性能优化设置

## 联系方式

如有问题或建议，请通过以下方式联系：
- 提交GitHub Issue
- 发送邮件至项目维护者

---

**注意**：本项目仍在开发测试阶段，仅供学习和研究使用，请遵守Live2D Cubism SDK的使用条款。
