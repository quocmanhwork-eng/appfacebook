import Observation
import SwiftUI
import UIKit

/// Trạng thái gốc của ứng dụng: tài khoản, web view, cài đặt, khóa và thông báo.
@Observable
@MainActor
final class AppModel {
    let accounts: AccountStore
    let settings: AppSettings
    let web: WebSessionManager
    let lock: AppLock
    private let notifier: UnreadNotifier
    private let defaults: UserDefaults

    private(set) var selectedAccountID: UUID?
    var isShowingSettings = false
    var settingsPath: [UUID] = []

    @ObservationIgnored private var isSceneActive = true
    @ObservationIgnored private var didBootstrap = false

    private static let selectedAccountKey = "duosocial.selectedAccountID"

    init(defaults: UserDefaults = .standard) {
        let accounts = AccountStore(defaults: defaults)
        let settings = AppSettings(defaults: defaults)
        let savedID = defaults.string(forKey: Self.selectedAccountKey).flatMap(UUID.init(uuidString:))

        self.accounts = accounts
        self.settings = settings
        self.web = WebSessionManager()
        self.lock = AppLock()
        self.notifier = UnreadNotifier()
        self.defaults = defaults
        self.selectedAccountID = savedID.flatMap { accounts.account(with: $0)?.id } ?? accounts.accounts.first?.id

        web.onUnreadChange = { [weak self] accountID, oldValue, newValue, isInitialLoad in
            self?.handleUnreadChange(accountID: accountID, from: oldValue, to: newValue, isInitialLoad: isInitialLoad)
        }
        NotificationRouter.shared.onOpenAccount = { [weak self] accountID in
            self?.isShowingSettings = false
            self?.select(accountID)
        }
        if settings.lockEnabled {
            lock.lock()
        }
    }

    var selectedAccount: Account? {
        selectedAccountID.flatMap { accounts.account(with: $0) }
    }

    var totalUnread: Int {
        accounts.accounts.reduce(0) { $0 + web.state(for: $1.id).unreadCount }
    }

    // MARK: - Khởi động & chuyển tài khoản

    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true

        if let selectedAccountID {
            activate(selectedAccountID)
        }
        if settings.preloadAllAccounts {
            // Ưu tiên tài khoản đang xem, các tài khoản còn lại tải sau một chút.
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.5))
                self?.preloadAllAccounts()
            }
        }
    }

    func preloadAllAccounts() {
        for account in accounts.accounts {
            web.ensureSession(for: account)
        }
    }

    func select(_ accountID: UUID) {
        guard accounts.account(with: accountID) != nil else { return }
        if selectedAccountID != accountID {
            dismissKeyboard()
        }
        selectedAccountID = accountID
        defaults.set(accountID.uuidString, forKey: Self.selectedAccountKey)
        activate(accountID)
    }

    /// Chạm vào một tài khoản trên thanh dưới cùng.
    func tapAccount(_ accountID: UUID) {
        if selectedAccountID == accountID {
            web.session(for: accountID)?.handleReselect()
        } else {
            select(accountID)
        }
    }

    func goHome(_ account: Account) {
        select(account.id)
        web.session(for: account.id)?.loadStart()
    }

    func reload(_ account: Account) {
        if let session = web.session(for: account.id) {
            session.reloadPage()
        } else {
            select(account.id)
        }
    }

    func openSettings(editing accountID: UUID? = nil) {
        settingsPath = accountID.map { [$0] } ?? []
        isShowingSettings = true
    }

    // MARK: - Quản lý tài khoản

    @discardableResult
    func addAccount(kind: AccountKind) -> Account {
        let account = accounts.addAccount(kind: kind)
        select(account.id)
        return account
    }

    func update(_ account: Account) {
        guard let previous = accounts.account(with: account.id) else { return }
        accounts.update(account)
        web.refreshSessionIfNeeded(for: account)
        if previous.sessionID != account.sessionID {
            destroySessionIfUnused(previous.sessionID)
        }
    }

    func delete(_ account: Account) {
        accounts.remove(id: account.id)
        web.discardSession(for: account.id)
        if selectedAccountID == account.id {
            if let next = accounts.accounts.first {
                select(next.id)
            } else {
                selectedAccountID = nil
                defaults.removeObject(forKey: Self.selectedAccountKey)
            }
        }
        destroySessionIfUnused(account.sessionID)
        updateBadge()
    }

    /// Đăng xuất = xóa cookie của phiên. Mọi tài khoản dùng chung phiên cũng bị đăng xuất.
    func signOut(_ account: Account) async {
        await web.eraseData(forSessionID: account.sessionID)
        for other in accounts.accounts where other.sessionID == account.sessionID {
            web.session(for: other.id)?.loadStart()
        }
    }

    private func destroySessionIfUnused(_ sessionID: UUID) {
        guard !accounts.isSessionInUse(sessionID) else { return }
        let web = web
        Task { await web.destroyDataStore(sessionID) }
    }

    private func activate(_ accountID: UUID) {
        guard let account = accounts.account(with: accountID) else { return }
        web.ensureSession(for: account)
    }

    // MARK: - Cài đặt

    /// - Returns: `false` nếu thiết bị chưa đặt mật mã nên không thể bật khóa.
    func setLockEnabled(_ enabled: Bool) -> Bool {
        if enabled && !AppLock.isAvailable {
            return false
        }
        settings.lockEnabled = enabled
        if !enabled {
            lock.disable()
        }
        return true
    }

    /// - Returns: `false` nếu người dùng không cho phép thông báo.
    func setNotificationsEnabled(_ enabled: Bool) async -> Bool {
        guard enabled else {
            settings.notificationsEnabled = false
            notifier.setBadge(0)
            return true
        }
        let granted = await notifier.requestAuthorization()
        settings.notificationsEnabled = granted
        if granted {
            updateBadge()
        }
        return granted
    }

    // MARK: - Vòng đời

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            isSceneActive = true
            lock.sceneDidBecomeActive()
        case .background:
            isSceneActive = false
            if settings.lockEnabled {
                lock.lock()
            }
        default:
            break
        }
    }

    private func handleUnreadChange(accountID: UUID, from oldValue: Int, to newValue: Int, isInitialLoad: Bool) {
        updateBadge()
        guard settings.notificationsEnabled, newValue > oldValue, !isInitialLoad,
              let account = accounts.account(with: accountID)
        else { return }
        // Không báo cho tài khoản người dùng đang xem.
        if isSceneActive && selectedAccountID == accountID {
            return
        }
        notifier.notifyUnread(for: account, count: newValue)
    }

    private func updateBadge() {
        guard settings.notificationsEnabled else { return }
        notifier.setBadge(totalUnread)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
