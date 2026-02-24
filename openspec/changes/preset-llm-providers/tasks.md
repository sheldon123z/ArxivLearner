## 1. 数据模型层

- [x] 1.1 创建 `PresetProvider` 和 `PresetModel` 结构体（`Core/LLM/PresetProvider.swift`）
- [x] 1.2 创建 `LLMProviderRegistry`，定义 7 个预置服务商的静态数据（`Core/LLM/LLMProviderRegistry.swift`）
- [x] 1.3 为 `LLMProviderConfig` 新增 `providerId: String?` 可选字段，确保旧数据向后兼容

## 2. OpenRouter 模型发现

- [x] 2.1 创建 `OpenRouterModelService`，实现 `fetchModels() async throws -> [PresetModel]`（`Core/LLM/OpenRouterModelService.swift`）
- [x] 2.2 定义 OpenRouter API 响应解析结构体（`OpenRouterModelsResponse`）
- [x] 2.3 实现 fallback 模型列表，获取失败时返回预置热门模型

## 3. Settings UI 重构

- [x] 3.1 重构 SettingsView LLM 配置区域：添加服务商 Picker
- [x] 3.2 添加模型选择 Picker，联动服务商切换
- [x] 3.3 实现自定义服务商模式：选择"自定义"时显示手动输入字段
- [x] 3.4 实现 OpenRouter 专属"获取模型列表"按钮及 loading 状态
- [x] 3.5 实现配置恢复逻辑：打开设置页时根据 providerId 恢复 Picker 选中状态
- [x] 3.6 更新保存逻辑：预置模式下将 providerId 写入配置

## 4. 测试

- [x] 4.1 编写 `LLMProviderRegistry` 单元测试（服务商数量、按 ID 查找、模型列表非空）
- [x] 4.2 编写 `OpenRouterModelService` 单元测试（成功解析、网络错误 fallback）
- [x] 4.3 编写 `LLMProviderConfig` 序列化兼容性测试（旧数据反序列化、新字段存在性）
