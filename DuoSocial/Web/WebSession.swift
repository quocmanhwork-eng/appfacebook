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
    let createdAt = Date()

    private weak var manager: WebSessionManager?
    private var observations: [NSKeyValueObservation] = []

    init(account: Account, dataStore: WKWebsiteDataStore, manager: WebSessionManager) {
        accountID = account.id
        kind = account.kind
        signature = account.sessionSignature
        startURL = account.startURL
        self.manager = manager
        super.init(webView: WebViewFactory.makeWebView(for: account, dataStore: dataStore))

        if account.kind == .facebook {
            installRefreshControl()
        }
        startObserving()
    }

    func loadStart() {
        webView.load(URLRequest(url: startURL))
    }

    func reloadPage() {
        if webView.url == nil {
            loadStart()
        } else {
            webView.reload()
        }
    }

    /// Chạm lại vào tài khoản đang mở: cuộn lên đầu, hoặc về trang chủ nếu đã ở đầu trang (như app Facebook).
    func handleReselect() {
        let scrollView = webView.scrollView
        let topOffset = -scrollView.adjustedContentInset.top
        if scrollView.contentOffset.y > topOffset + 1 {
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: topOffset), animated: true)
        } else if kind == .facebook {
            loadStart()
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
        report { $0.loadError = nil }
    }

    override func navigationFinished() {
        webView.scrollView.refreshControl?.endRefreshing()
        refreshLoginState()
    }

    override func navigationFailed(_ error: Error) {
        webView.scrollView.refreshControl?.endRefreshing()
        guard !Self.isIgnorable(error) else { return }
        report { $0.loadError = error.localizedDescription }
    }

    // MARK: - Private

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
        let unread = UnreadParser.unreadCount(fromTitle: title)
        report { state in
            state.title = title ?? ""
            if let unread {
                state.unreadCount = unread
            }
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
