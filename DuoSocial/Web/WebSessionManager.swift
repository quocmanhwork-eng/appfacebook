import Foundation
import Observation
import WebKit

/// Trạng thái hiển thị của trang web thuộc một tài khoản.
struct PageState: Equatable {
    var title = ""
    var unreadCount = 0
    var isLoading = false
    var progress: Double = 0
    var canGoBack = false
    /// `nil` khi chưa kiểm tra (trang chưa tải xong lần nào).
    var isLoggedIn: Bool?
    var userID: String?
    var loadError: String?
    var url: URL?
    /// Tab dưới cùng đang được tô sáng (giữ nguyên khi mở trang không thuộc tab nào, vd. trang cá nhân).
    var activeTab: PageTab?
    /// Trang đã tải xong ít nhất một lần (trước đó app hiện màn hình chờ thay cho trang trắng).
    var hasLoadedOnce = false
}

/// Quản lý các web view của tài khoản và kho dữ liệu (phiên đăng nhập) tương ứng.
@Observable
@MainActor
final class WebSessionManager {
    private(set) var sessions: [UUID: WebSession] = [:]
    private(set) var pageStates: [UUID: PageState] = [:]

    /// Gọi mỗi khi đọc được số chưa đọc từ tiêu đề trang: (accountID, số chưa đọc, trang đang tải/ổn định).
    @ObservationIgnored var onUnreadObserved: ((UUID, Int, Bool) -> Void)?
    @ObservationIgnored private var dataStores: [UUID: WKWebsiteDataStore] = [:]

    /// Ẩn thanh tab của chính trang Facebook (app đã có thanh tab riêng). Đổi giá trị cần tạo lại web view.
    @ObservationIgnored var hideWebTabBar = true

    /// Các giá trị mà khi thay đổi thì web view của tài khoản phải được tạo lại.
    func signature(for account: Account) -> String {
        account.sessionSignature + "|webTabBar:" + (hideWebTabBar ? "hidden" : "shown")
    }

    func session(for accountID: UUID) -> WebSession? {
        sessions[accountID]
    }

    func state(for accountID: UUID) -> PageState {
        pageStates[accountID] ?? PageState()
    }

    /// Tạo (nếu chưa có) web view cho tài khoản và bắt đầu tải trang.
    @discardableResult
    func ensureSession(for account: Account) -> WebSession {
        let expectedSignature = signature(for: account)
        if let existing = sessions[account.id], existing.signature == expectedSignature {
            return existing
        }
        sessions[account.id]?.tearDown()
        let session = WebSession(
            account: account,
            dataStore: dataStore(for: account.sessionID),
            signature: expectedSignature,
            hideWebTabBar: hideWebTabBar,
            manager: self
        )
        sessions[account.id] = session
        pageStates[account.id] = PageState()
        session.loadStart()
        return session
    }

    /// Tạo lại web view nếu người dùng đổi phiên, giao diện hoặc trang khởi động.
    func refreshSessionIfNeeded(for account: Account) {
        guard let existing = sessions[account.id], existing.signature != signature(for: account) else { return }
        ensureSession(for: account)
    }

    func discardSession(for accountID: UUID) {
        sessions.removeValue(forKey: accountID)?.tearDown()
        pageStates.removeValue(forKey: accountID)
    }

    /// Kho dữ liệu bền vững, tách biệt theo mã phiên (iOS 17+). Đây là thứ cho phép đăng nhập nhiều tài khoản cùng lúc.
    func dataStore(for sessionID: UUID) -> WKWebsiteDataStore {
        if let store = dataStores[sessionID] {
            return store
        }
        let store = WKWebsiteDataStore(forIdentifier: sessionID)
        dataStores[sessionID] = store
        return store
    }

    /// Xóa cookie và mọi dữ liệu web của một phiên (= đăng xuất).
    func eraseData(forSessionID sessionID: UUID) async {
        let store = dataStore(for: sessionID)
        await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
    }

    /// Xóa hẳn kho dữ liệu khi không còn tài khoản nào dùng.
    func destroyDataStore(_ sessionID: UUID) async {
        await eraseData(forSessionID: sessionID)
        dataStores.removeValue(forKey: sessionID)
        // Có thể thất bại nếu web view cũ chưa kịp giải phóng; dữ liệu đã được xóa ở trên nên bỏ qua lỗi.
        try? await WKWebsiteDataStore.remove(forIdentifier: sessionID)
    }

    func update(from session: WebSession, _ mutate: (inout PageState) -> Void) {
        // Bỏ qua cập nhật từ web view cũ đã bị thay thế.
        guard sessions[session.accountID] === session else { return }

        let previous = pageStates[session.accountID] ?? PageState()
        var next = previous
        mutate(&next)
        guard next != previous else { return }
        pageStates[session.accountID] = next
    }

    func unreadObserved(from session: WebSession, count: Int) {
        guard sessions[session.accountID] === session else { return }
        update(from: session) { $0.unreadCount = count }
        onUnreadObserved?(session.accountID, count, session.isSettling)
    }

    /// Chờ tới khi mọi trang tải xong và tiêu đề kịp cập nhật số chưa đọc (dùng khi chạy nền).
    func waitUntilSettled(timeout: Duration) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            try? await Task.sleep(for: .seconds(1))
            if sessions.values.allSatisfy({ !$0.isSettling }) {
                return
            }
        }
    }
}
