import Foundation
import Observation

/// Tùy chọn của người dùng, lưu trong UserDefaults.
@Observable
final class AppSettings {
    private enum Keys {
        static let lockEnabled = "duosocial.settings.lockEnabled"
        static let notificationsEnabled = "duosocial.settings.notificationsEnabled"
        static let preloadAllAccounts = "duosocial.settings.preloadAllAccounts"
        static let backgroundRefreshEnabled = "duosocial.settings.backgroundRefreshEnabled"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Keys.preloadAllAccounts: true, Keys.backgroundRefreshEnabled: true])
    }

    /// Khóa ứng dụng bằng Face ID / Touch ID / mật mã khi quay lại app.
    var lockEnabled: Bool {
        get {
            access(keyPath: \.lockEnabled)
            return defaults.bool(forKey: Keys.lockEnabled)
        }
        set {
            withMutation(keyPath: \.lockEnabled) {
                defaults.set(newValue, forKey: Keys.lockEnabled)
            }
        }
    }

    /// Gửi thông báo khi số tin/thông báo chưa đọc của một tài khoản tăng lên.
    var notificationsEnabled: Bool {
        get {
            access(keyPath: \.notificationsEnabled)
            return defaults.bool(forKey: Keys.notificationsEnabled)
        }
        set {
            withMutation(keyPath: \.notificationsEnabled) {
                defaults.set(newValue, forKey: Keys.notificationsEnabled)
            }
        }
    }

    /// Nhờ iOS thỉnh thoảng đánh thức app ở chế độ nền để kiểm tra tin mới (cần bật thông báo).
    var backgroundRefreshEnabled: Bool {
        get {
            access(keyPath: \.backgroundRefreshEnabled)
            return defaults.bool(forKey: Keys.backgroundRefreshEnabled)
        }
        set {
            withMutation(keyPath: \.backgroundRefreshEnabled) {
                defaults.set(newValue, forKey: Keys.backgroundRefreshEnabled)
            }
        }
    }

    /// Mở sẵn tất cả tài khoản khi khởi động để nhận số tin chưa đọc của cả 4 tài khoản.
    var preloadAllAccounts: Bool {
        get {
            access(keyPath: \.preloadAllAccounts)
            return defaults.bool(forKey: Keys.preloadAllAccounts)
        }
        set {
            withMutation(keyPath: \.preloadAllAccounts) {
                defaults.set(newValue, forKey: Keys.preloadAllAccounts)
            }
        }
    }
}
