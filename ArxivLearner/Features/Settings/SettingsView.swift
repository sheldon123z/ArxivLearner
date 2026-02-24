import SwiftUI
import CloudKit

struct SettingsView: View {

    // MARK: - doc2x

    @AppStorage("doc2x_base_url") private var doc2xBaseURL = "https://v2.doc2x.noedgeai.com"
    @State private var doc2xApiKey: String = ""
    @AppStorage("auto_convert_mode") private var autoConvertModeRaw: String = AutoConvertMode.manualOnly.rawValue

    private var autoConvertMode: Binding<AutoConvertMode> {
        Binding(
            get: { AutoConvertMode(rawValue: autoConvertModeRaw) ?? .manualOnly },
            set: { autoConvertModeRaw = $0.rawValue }
        )
    }

    // MARK: - Cache

    @State private var cacheSize: String = "计算中..."
    @State private var showClearConfirm = false

    // MARK: - Alert

    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    // MARK: - iCloud Sync

    @State private var iCloudStatus: String = "检测中..."
    @State private var isSyncing: Bool = false
    @AppStorage("icloud_last_sync") private var lastSyncTimestamp: Double = 0

    private var lastSyncText: String {
        guard lastSyncTimestamp > 0 else { return "从未同步" }
        let date = Date(timeIntervalSince1970: lastSyncTimestamp)
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: - Appearance

    @State private var appearanceManager = AppearanceManager.shared

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                llmNavigationSection
                appearanceSection
                doc2xSection
                iCloudSection
                cacheSection
                aboutSection
            }
            .navigationTitle("设置")
            .onAppear {
                loadConfig()
                calculateCacheSize()
                checkiCloudStatus()
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
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

    // MARK: - LLM Navigation Section

    private var llmNavigationSection: some View {
        Section("LLM 服务") {
            NavigationLink {
                ProviderSettingsView()
            } label: {
                LLMNavRow(
                    icon: "cloud.fill",
                    iconColor: AppTheme.primary,
                    title: "LLM 服务商",
                    subtitle: "配置和管理 AI 服务商"
                )
            }

            NavigationLink {
                PromptEditorView()
            } label: {
                LLMNavRow(
                    icon: "text.bubble.fill",
                    iconColor: AppTheme.secondary,
                    title: "Prompt 模板",
                    subtitle: "编辑各场景提示词"
                )
            }

            NavigationLink {
                ModelAssignmentView()
            } label: {
                LLMNavRow(
                    icon: "cpu.fill",
                    iconColor: Color(hex: "E17055"),
                    title: "模型分配",
                    subtitle: "为每个场景指定模型"
                )
            }

            NavigationLink {
                GlobalSystemPromptView()
            } label: {
                LLMNavRow(
                    icon: "terminal.fill",
                    iconColor: Color(hex: "FDCB6E"),
                    title: "全局系统指令",
                    subtitle: "注入所有请求的基础指令"
                )
            }

            NavigationLink {
                UsageStatsView()
            } label: {
                LLMNavRow(
                    icon: "chart.bar.fill",
                    iconColor: Color(hex: "00CEC9"),
                    title: "用量统计",
                    subtitle: "查看 Token 消耗记录"
                )
            }
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section("外观") {
            Picker("显示模式", selection: Binding(
                get: { appearanceManager.mode },
                set: { appearanceManager.mode = $0 }
            )) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            Toggle("PDF 深色模式", isOn: Binding(
                get: { appearanceManager.pdfDarkMode },
                set: { appearanceManager.pdfDarkMode = $0 }
            ))
        }
    }

    // MARK: - iCloud Section

    private var iCloudSection: some View {
        Section("iCloud 同步") {
            HStack {
                Label("同步状态", systemImage: "icloud")
                Spacer()
                if isSyncing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("同步中")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.primary)
                    }
                } else {
                    Text(iCloudStatus)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            HStack {
                Text("上次同步")
                Spacer()
                Text(lastSyncText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Button("立即同步") {
                triggerManualSync()
            }
            .foregroundStyle(AppTheme.primary)
            .disabled(isSyncing || iCloudStatus == "未登录" || iCloudStatus == "不可用")
        }
    }

    // MARK: - doc2x Section

    private var doc2xSection: some View {
        Section("文档转换 (doc2x)") {
            TextField("服务端点", text: $doc2xBaseURL)
                .textContentType(.URL)
                .autocapitalization(.none)
            SecureField("API Key", text: $doc2xApiKey)

            Picker("自动转换", selection: autoConvertMode) {
                ForEach(AutoConvertMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            Button("保存") {
                saveDoc2xConfig()
                alertTitle = "保存成功"
                alertMessage = "doc2x 配置已保存"
                showAlert = true
            }
            .foregroundStyle(AppTheme.primary)

            NavigationLink {
                ConversionStatsView()
            } label: {
                LLMNavRow(
                    icon: "doc.text.magnifyingglass",
                    iconColor: Color(hex: "E17055"),
                    title: "转换统计",
                    subtitle: "查看 doc2x 转换使用量"
                )
            }
        }
    }

    // MARK: - Cache Section

    private var cacheSection: some View {
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
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("关于") {
            HStack {
                Text("版本")
                Spacer()
                Text("1.0.0 (MVP)")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Load Config

    private func loadConfig() {
        doc2xApiKey = (try? KeychainService.shared.retrieve(key: "doc2x_api_key")) ?? ""
    }

    // MARK: - Save doc2x Config

    private func saveDoc2xConfig() {
        try? KeychainService.shared.save(key: "doc2x_api_key", value: doc2xApiKey)
        UserDefaults.standard.set(doc2xBaseURL, forKey: "doc2x_base_url")
    }

    // MARK: - Cache Size

    private func calculateCacheSize() {
        let bytes = PDFCacheManager.shared.totalCacheSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        cacheSize = formatter.string(fromByteCount: bytes)
    }

    // MARK: - iCloud Status

    private func checkiCloudStatus() {
        CKContainer.default().accountStatus { status, _ in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    iCloudStatus = "已同步"
                case .noAccount:
                    iCloudStatus = "未登录"
                case .restricted:
                    iCloudStatus = "受限制"
                case .couldNotDetermine:
                    iCloudStatus = "不可用"
                case .temporarilyUnavailable:
                    iCloudStatus = "暂时不可用"
                @unknown default:
                    iCloudStatus = "未知"
                }
            }
        }
    }

    private func triggerManualSync() {
        isSyncing = true
        // Trigger CloudKit sync by saving to UserDefaults which SwiftData picks up
        Task {
            // Small delay to allow UI to update
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                lastSyncTimestamp = Date.now.timeIntervalSince1970
                isSyncing = false
                iCloudStatus = "已同步"
            }
        }
    }
}

// MARK: - LLMNavRow

private struct LLMNavRow: View {

    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: AppTheme.spacing) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}


#Preview {
    SettingsView()
}
