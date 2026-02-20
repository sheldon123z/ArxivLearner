import Foundation
import Observation

@Observable
final class InsightViewModel {
    var insight: String = ""
    var isGenerating = false
    var errorMessage: String?

    private var llmService: LLMServiceProtocol?

    func configure(config: LLMProviderConfig) {
        self.llmService = OpenAICompatibleService(config: config)
    }

    func generateInsight(for paper: Paper) async {
        guard let service = llmService else {
            errorMessage = "请先配置 LLM 服务"
            return
        }

        isGenerating = true
        errorMessage = nil
        insight = ""

        let paperContext = ContextBuilder.PaperContext(
            title: paper.title,
            abstractText: paper.abstractText,
            markdownContent: paper.markdownContent,
            fullText: nil
        )

        let messages: [LLMMessage] = [
            LLMMessage(role: "system", content: ContextBuilder.insightSystemPrompt()),
            LLMMessage(role: "user", content: ContextBuilder.buildContext(for: paperContext)),
        ]

        do {
            for try await chunk in service.completeStream(messages: messages) {
                insight += chunk
            }
            // Save to paper
            paper.llmInsight = insight
        } catch {
            errorMessage = "生成失败: \(error.localizedDescription)"
        }

        isGenerating = false
    }

    func regenerate(for paper: Paper) async {
        insight = ""
        paper.llmInsight = nil
        await generateInsight(for: paper)
    }
}
