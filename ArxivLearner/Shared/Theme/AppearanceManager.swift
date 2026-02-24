import SwiftUI
import Observation

@Observable
final class AppearanceManager {
    static let shared = AppearanceManager()

    var mode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "appearance_mode")
        }
    }

    var pdfDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(pdfDarkMode, forKey: "pdf_dark_mode")
        }
    }

    var colorScheme: ColorScheme? {
        switch mode {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: "appearance_mode") ?? AppearanceMode.system.rawValue
        self.mode = AppearanceMode(rawValue: raw) ?? .system
        self.pdfDarkMode = UserDefaults.standard.bool(forKey: "pdf_dark_mode")
    }
}
