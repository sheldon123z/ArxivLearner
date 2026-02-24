## ADDED Requirements

### Requirement: 场景级模型绑定
系统 SHALL 支持为每个 Prompt 场景绑定默认模型，包括：默认见解模型、默认对话模型、公式解析模型、翻译模型。

#### Scenario: 设置场景默认模型
- **WHEN** 用户在"模型分配"设置页为某场景选择默认模型
- **THEN** 该场景的所有 LLM 请求 SHALL 使用该模型，除非被 Prompt 级绑定覆盖

#### Scenario: 未设置场景默认
- **WHEN** 某场景未设置默认模型
- **THEN** 系统 SHALL 使用全局默认模型

### Requirement: Prompt 级模型绑定
每个 PromptTemplate SHALL 支持绑定特定模型（boundModel 字段），优先级高于场景默认。

#### Scenario: Prompt 绑定覆盖场景默认
- **WHEN** 一个 PromptTemplate 设置了 boundModel
- **THEN** 使用该模板时 SHALL 使用 boundModel，忽略场景默认模型

#### Scenario: Prompt 未绑定模型
- **WHEN** 一个 PromptTemplate 的 boundModel 为 nil
- **THEN** 系统 SHALL 回退到场景默认模型，再回退到全局默认模型

### Requirement: 模型选择优先级
系统 SHALL 按以下优先级选择模型：Prompt 绑定模型 > 场景默认模型 > 全局默认模型。

#### Scenario: 优先级解析
- **WHEN** 系统需要为一个 insightGeneration 请求选择模型
- **THEN** 系统 SHALL 按优先级查找：该 Prompt 的 boundModel → insightGeneration 场景默认模型 → 全局默认模型
