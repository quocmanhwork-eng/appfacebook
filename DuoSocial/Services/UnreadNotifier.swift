import Foundation
import UserNotifications

/// Gửi thông báo cục bộ khi một tài khoản có thêm tin/thông báo chưa đọc và cập nhật số trên biểu tượng app.
@MainActor
final class UnreadNotifier {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func notifyUnread(for account: Account, count: Int) {
        let content = UNMutableNotificationContent()
        content.title = account.name
        if account.kind == .messenger {
            content.body = "Bạn có \(count) cuộc trò chuyện chưa đọc"
        } else {
            content.body = "Bạn có \(count) thông báo mới"
        }
        content.sound = .default
        content.threadIdentifier = account.id.uuidString
        content.userInfo = [NotificationRouter.accountIDKey: account.id.uuidString]

        // Cùng một identifier cho mỗi tài khoản để thông báo mới thay thế thông báo cũ.
        let request = UNNotificationRequest(identifier: "unread-\(account.id.uuidString)", content: content, trigger: nil)
        center.add(request) { _ in }
    }

    func setBadge(_ count: Int) {
        center.setBadgeCount(count) { _ in }
    }
}

/// Nhận sự kiện từ trung tâm thông báo: hiện banner khi app đang mở và mở đúng tài khoản khi người dùng chạm vào.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()
    static let accountIDKey = "accountID"

    @MainActor var onOpenAccount: ((UUID) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let accountID = (userInfo[Self.accountIDKey] as? String).flatMap(UUID.init(uuidString:))
        completionHandler()
        guard let accountID else { return }
        Task { @MainActor in
            NotificationRouter.shared.onOpenAccount?(accountID)
        }
    }
}
