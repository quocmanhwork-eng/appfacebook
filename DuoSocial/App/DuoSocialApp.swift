import SwiftUI
import UserNotifications

@main
struct DuoSocialApp: App {
    @State private var model: AppModel

    init() {
        // Đặt sớm để bắt được cả thông báo đã mở app từ trạng thái tắt.
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        _model = State(initialValue: AppModel())
    }

    var body: some Scene {
        WindowGroup {
            if Self.isRunningUnitTests {
                // Không tải Facebook khi app chỉ làm "host" cho unit test.
                Color.clear
            } else {
                RootView()
                    .environment(model)
            }
        }
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
