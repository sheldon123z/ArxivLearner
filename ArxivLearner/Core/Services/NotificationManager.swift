import Foundation
import UserNotifications

// MARK: - NotificationManager

final class NotificationManager {

    static let shared = NotificationManager()

    private init() {}

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if let error {
                print("[NotificationManager] 权限请求失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Send Notification

    /// 发送新论文通知
    /// - Parameters:
    ///   - searchName: 保存的搜索名称
    ///   - newCount: 新发现的论文数量
    func sendNewPapersNotification(searchName: String, newCount: Int) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = "ArxivLearner"
            content.body = "\(searchName) 发现 \(newCount) 篇新论文"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let identifier = "new-papers-\(searchName)-\(Date().timeIntervalSince1970)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    print("[NotificationManager] 通知发送失败: \(error.localizedDescription)")
                }
            }
        }
    }
}
