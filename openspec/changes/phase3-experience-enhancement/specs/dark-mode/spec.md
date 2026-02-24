## ADDED Requirements

### Requirement: 应用级深色模式
系统 SHALL 支持三种外观模式：跟随系统（默认）、始终浅色、始终深色。

#### Scenario: 跟随系统
- **WHEN** 外观设置为"跟随系统"且系统切换到深色模式
- **THEN** 应用 SHALL 自动切换到深色外观

#### Scenario: 手动切换
- **WHEN** 用户在设置页选择"始终深色"
- **THEN** 应用 SHALL 立即切换到深色外观，不受系统设置影响

### Requirement: PDF 阅读器独立暗色模式
PDF 阅读器 SHALL 提供独立的暗色模式开关，与应用级外观设置分离。

#### Scenario: PDF 暗色模式
- **WHEN** 用户在 PDF 阅读器中开启暗色模式
- **THEN** 系统 SHALL 通过反色处理将 PDF 内容显示为暗色背景+浅色文字

#### Scenario: 独立于应用外观
- **WHEN** 应用为浅色模式但 PDF 暗色模式已开启
- **THEN** PDF 阅读器 SHALL 保持暗色显示
