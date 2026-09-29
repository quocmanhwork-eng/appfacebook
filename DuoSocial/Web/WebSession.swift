import UIKit
import WebKit

/// Web view "sống lâu" của một tài khoản. Giữ nguyên khi chuyển qua lại giữa các tài khoản
/// để không phải tải lại trang và vẫn nhận được số tin chưa đọc.
@MainActor
final class WebSession: BrowserController {
    let accountID: UUID
    let kind: AccountKind
    let signature: String
    let startURL: URL

    private weak var manager: WebSessionManager?
    private var observations: [NSKeyValueObservation] = []
    private var lastNavigationEvent = Date.distantPast

    /// Sau khi bắt đầu/kết thúc điều hướng, trang Facebook cần vài giây để cập nhật số chưa đọc trên tiêu đề.
    private static let settleInterval: TimeInterval = 6
    /// Màn hình chờ lần tải đầu không bao giờ che trang lâu hơn khoảng này (mạng chậm, trang tải dở).
    private static let splashTimeout: Duration = .seconds(15)

    init(account: Account, dataStore: WKWebsiteDataStore, signature: String, hideWebTabBar: Bool, manager: WebSessionManager) {
        accountID = account.id
        kind = account.kind
        self.signature = signature
        startURL = account.startURL
        self.manager = manager
        super.init(webView: WebViewFactory.makeWebView(for: account, dataStore: dataStore, hideWebTabBar: hideWebTabBar))

        if account.kind == .facebook {
            installRefreshControl()
        }
        startObserving()
        Task { [weak self] in
            try? await Task.sleep(for: Self.splashTimeout)
            self?.report { $0.hasLoadedOnce = true }
        }
    }

    /// Trang đang tải hoặc vừa tải xong: số chưa đọc trên tiêu đề có thể tạm thời sai (thường về 0).
    var isSettling: Bool {
        webView.isLoading || Date().timeIntervalSince(lastNavigationEvent) < Self.settleInterval
    }

    func loadStart() {
        load(startURL)
    }

    func reloadPage() {
        if webView.url == nil {
            loadStart()
        } else {
            lastNavigationEvent = Date()
            webView.reload()
        }
    }

    func open(_ tab: PageTab) {
        report { $0.activeTab = tab }
        load(tab.url(base: PageTab.baseURL(current: webView.url, start: startURL)))
    }

    /// Chạm lại tab/tài khoản đang mở: cuộn lên đầu, hoặc tải lại nếu đã ở đầu trang (như app Facebook).
    func handleReselect() {
        let scrollView = webView.scrollView
        let topOffset = -scrollView.adjustedContentInset.top
        if scrollView.contentOffset.y > topOffset + 1 {
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: topOffset), animated: true)
        } else {
            reloadPage()
        }
    }

    func tearDown() {
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.removeFromSuperview()
    }

    // MARK: - Hooks

    override func navigationStarted() {
        lastNavigationEvent = Date()
        report { $0.loadError = nil }
    }

    override func navigationFinished() {
        lastNavigationEvent = Date()
        report { $0.hasLoadedOnce = true }
        webView.scrollView.refreshControl?.endRefreshing()
        refreshLoginState()
        resyncUnreadAfterSettling()
    }

    override func navigationFailed(_ error: Error) {
        webView.scrollView.refreshControl?.endRefreshing()
        guard !Self.isIgnorable(error) else { return }
        report { $0.loadError = error.localizedDescription }
    }

    // MARK: - Private

    private func load(_ url: URL) {
        lastNavigationEvent = Date()
        webView.load(URLRequest(url: url))
    }

    private func installRefreshControl() {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = control
    }

    @objc private func handlePullToRefresh() {
        reloadPage()
    }

    private func startObserving() {
        observations = [
            webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
                MainActor.assumeIsolated {
                    self?.titleDidChange(webView.title)
                }
            },
            webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                MainActor.assumeIsolated {
                    self?.urlDidChange(webView.url)
                }
            },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                MainActor.assumeIsolated {
                    self?.report { $0.progress = webView.estimatedProgress }
                }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
                MainActor.assumeIsolated {
                    self?.report { $0.isLoading = webView.isLoading }
                }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
                MainActor.assumeIsolated {
                    self?.report { $0.canGoBack = webView.canGoBack }
                }
            },
        ]
    }

    private func titleDidChange(_ title: String?) {
        report { $0.title = title ?? "" }
        if let unread = UnreadParser.unreadCount(fromTitle: title) {
            manager?.unreadObserved(from: self, count: unread)
        }
    }

    private func urlDidChange(_ url: URL?) {
        let tab = PageTab.matching(url)
        report { state in
            state.url = url
            if let tab {
                state.activeTab = tab
            }
        }
    }

    /// Số chưa đọc giảm trong lúc trang đang tải bị bỏ qua; khi trang đã ổn định thì báo lại số hiện tại
    /// để số "đã biết" giảm theo (vd. người dùng vừa đọc tin).
    private func resyncUnreadAfterSettling() {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.settleInterval + 1))
            guard let self, !self.isSettling,
                  let unread = UnreadParser.unreadCount(fromTitle: self.webView.title)
            else { return }
            self.manager?.unreadObserved(from: self, count: unread)
        }
    }

    /// Facebook đặt cookie `c_user` (= ID người dùng) khi đã đăng nhập.
    private func refreshLoginState() {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        Task { [weak self] in
            let cookies = await cookieStore.allCookies()
            let userID = cookies.first { $0.name == "c_user" && !$0.value.isEmpty }?.value
            self?.report { state in
                state.isLoggedIn = userID != nil
                state.userID = userID
            }
        }
    }

    private func report(_ mutate: (inout PageState) -> Void) {
        manager?.update(from: self, mutate)
    }

    private static func isIgnorable(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return true
        }
        // 102 = "Frame load interrupted": xảy ra khi app tự hủy điều hướng (mở link ngoài, tải tệp…).
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 {
            return true
        }
        return false
    }
}
