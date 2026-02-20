import SwiftUI

struct SettingsView: View {
    // LLM
    @AppStorage("llm_name") private var llmName = "OpenAI"
    @AppStorage("llm_base_url") private var llmBaseURL = "https://api.openai.com/v1"
    @AppStorage("llm_model_id") private var llmModelId = "gpt-4o"
    @State private var llmApiKey = ""

    // doc2x
    @AppStorage("doc2x_base_url") private var doc2xBaseURL = "https://v2.doc2x.noedgeai.com"
    @State private var doc2xApiKey = ""

    // Cache
    @State private var cacheSize: String = "计算中..."
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                // LLM Section
                Section("LLM 服务") {
                    TextField("服务商名称", text: $llmName)
                    TextField("Base URL", text: $llmBaseURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                    SecureField("API Key", text: $llmApiKey)
                    TextField("Model ID", text: $llmModelId)
                        .autocapitalization(.none)
                    Button("保存并测试") { saveLLMConfig() }
                        .foregroundStyle(AppTheme.primary)
                }

                // doc2x Section
                Section("文档转换 (doc2x)") {
                    TextField("服务端点", text: $doc2xBaseURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                    SecureField("API Key", text: $doc2xApiKey)
                    Button("保存") { saveDoc2xConfig() }
                        .foregroundStyle(AppTheme.primary)
                }

                // Cache Section
                Section("存储") {
                    HStack {
                        Text("PDF 缓存")
                        Spacer()
                        Text(cacheSize)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Button("清除缓存", role: .destructive) {
                        showClearConfirm = true
                    }
                }

                // About
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0 (MVP)")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .navigationTitle("设置")
            .onAppear { loadKeys(); calculateCacheSize() }
            .alert("确认清除", isPresented: $showClearConfirm) {
                Button("清除", role: .destructive) {
                    PDFCacheManager.shared.clearCache()
                    calculateCacheSize()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将删除所有已下载的 PDF 文件")
            }
        }
    }

    private func loadKeys() {
        llmApiKey = (try? KeychainService.shared.retrieve(key: "llm_api_key")) ?? ""
        doc2xApiKey = (try? KeychainService.shared.retrieve(key: "doc2x_api_key")) ?? ""
    }

    private func saveLLMConfig() {
        try? KeychainService.shared.save(key: "llm_api_key", value: llmApiKey)
        let config = LLMProviderConfig(
            name: llmName,
            baseURL: llmBaseURL,
            apiKey: llmApiKey,
            modelId: llmModelId
        )
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "llm_config")
        }
    }

    private func saveDoc2xConfig() {
        try? KeychainService.shared.save(key: "doc2x_api_key", value: doc2xApiKey)
        UserDefaults.standard.set(doc2xBaseURL, forKey: "doc2x_base_url")
    }

    private func calculateCacheSize() {
        let bytes = PDFCacheManager.shared.totalCacheSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        cacheSize = formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    SettingsView()
}
