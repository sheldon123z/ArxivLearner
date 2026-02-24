## ADDED Requirements

### Requirement: 下载后自动转换
系统 SHALL 支持 PDF 下载完成后自动提交 doc2x 转换，可在设置中配置为"下载后自动"、"仅手动"或"关闭"。

#### Scenario: 自动转换触发
- **WHEN** PDF 下载完成且自动转换设置为"下载后自动"
- **THEN** 系统 SHALL 自动将 PDF 提交给 doc2x 服务进行转换

#### Scenario: 手动模式
- **WHEN** 自动转换设置为"仅手动"
- **THEN** 系统 SHALL 不自动触发转换，用户需手动点击"转MD"按钮

#### Scenario: 设置自动转换模式
- **WHEN** 用户在设置页修改自动转换选项
- **THEN** 系统 SHALL 立即生效，影响后续所有 PDF 下载行为

### Requirement: Markdown 预览
系统 SHALL 支持查看 doc2x 转换后的 Markdown 内容。

#### Scenario: 查看 Markdown 预览
- **WHEN** 论文已完成 doc2x 转换且 markdownContent 非空
- **THEN** 系统 SHALL 提供 Markdown 渲染预览页面，正确渲染 LaTeX 公式、表格、标题等

#### Scenario: 未转换时提示
- **WHEN** 用户尝试查看 Markdown 预览但论文未转换
- **THEN** 系统 SHALL 提示"尚未转换"并提供"立即转换"按钮

### Requirement: 公式解析联动
系统 SHALL 支持从 Markdown 内容中提取 LaTeX 公式块，作为公式解析功能的输入。

#### Scenario: 提取 LaTeX 公式
- **WHEN** 用户触发公式解析且论文有 Markdown 内容
- **THEN** 系统 SHALL 从 Markdown 中提取所有 `$...$` 和 `$$...$$` 公式块，作为 LLM 分析的输入上下文
