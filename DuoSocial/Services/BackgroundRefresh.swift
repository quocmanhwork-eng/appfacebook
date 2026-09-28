import BackgroundTasks
import Foundation

/// Lên lịch "Làm mới ứng dụng trong nền" để kiểm tra tin mới khi app không mở.
///
/// iOS tự quyết định khi nào chạy (thường vài chục phút tới vài giờ một lần, tùy thói quen dùng máy),
/// nên thông báo sẽ đến chậm hơn app chính thức.
enum BackgroundRefresh {
    /// Phải trùng với `BGTaskSchedulerPermittedIdentifiers` trong Info.plist.
    static var taskIdentifier: String {
        (Bundle.main.bundleIdentifier ?? "com.duosocial.app") + ".refresh"
    }

    /// Khoảng cách tối thiểu giữa hai lần kiểm tra mà app xin iOS.
    static let minimumInterval: TimeInterval = 15 * 60

    /// Thời gian tối đa chờ các trang tải xong trong một lần chạy nền (iOS cho khoảng 30 giây).
    static let pageLoadTimeout: Duration = .seconds(22)

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: minimumInterval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Simulator hoặc người dùng tắt "Làm mới ứng dụng trong nền": không có gì để làm.
        }
    }

    static func cancel() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
    }
}
