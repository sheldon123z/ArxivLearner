## ADDED Requirements

### Requirement: 请求级用量记录
系统 SHALL 在每次 LLM 请求完成后记录一条 UsageRecord，包含：模型信息、日期、inputTokens、outputTokens、estimatedCost、requestType。

#### Scenario: 记录用量
- **WHEN** 一次 LLM 请求完成（见解生成/论文问答/翻译/公式解析等）
- **THEN** 系统 SHALL 创建一条 UsageRecord，token 数取自 API 返回的 usage 字段，费用根据模型定价计算

#### Scenario: 流式请求用量
- **WHEN** 流式请求完成
- **THEN** 系统 SHALL 从最后一个 chunk 或单独的 usage 响应中提取 token 用量

### Requirement: 按模型统计
系统 SHALL 支持按模型维度查看 token 消耗和费用汇总。

#### Scenario: 查看按模型统计
- **WHEN** 用户在"用量统计"页面选择"按模型"视图
- **THEN** 系统 SHALL 显示每个模型的总 inputTokens、outputTokens、estimatedCost，按费用降序排列

### Requirement: 按场景统计
系统 SHALL 支持按请求场景（requestType）维度查看用量分布。

#### Scenario: 查看按场景统计
- **WHEN** 用户在"用量统计"页面选择"按场景"视图
- **THEN** 系统 SHALL 显示各场景（见解/问答/翻译/公式/摘要）的占比，以图表形式呈现

### Requirement: 时间趋势
系统 SHALL 支持按日/周/月维度查看用量和费用趋势。

#### Scenario: 查看月度趋势
- **WHEN** 用户在"用量统计"页面选择"时间趋势"视图
- **THEN** 系统 SHALL 显示过去 30 天每日的 token 用量和费用趋势折线图

### Requirement: 月度费用预警
系统 SHALL 支持设置月度费用预算上限，当当月费用接近或超过预算时发出提醒。

#### Scenario: 设置预算
- **WHEN** 用户在设置页输入月度预算金额
- **THEN** 系统 SHALL 保存预算设置

#### Scenario: 费用预警
- **WHEN** 当月累计费用达到预算的 80%
- **THEN** 系统 SHALL 在用量统计页面显示黄色警告提示

#### Scenario: 超预算提醒
- **WHEN** 当月累计费用超过预算
- **THEN** 系统 SHALL 在用量统计页面显示红色超预算警告，但不阻止用户继续使用
