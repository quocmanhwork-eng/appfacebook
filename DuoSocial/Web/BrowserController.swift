import UIKit
import WebKit

/// Xử lý chung cho mọi web view trong app: chính sách link, cửa sổ bật lên, hộp thoại JavaScript,
/// quyền camera/micro và tải tệp.
///
/// Lớp con tùy biến hành vi qua các "hook" (`navigationStarted()`, `makePopup(configuration:)`…)
/// thay vì tự cài phương thức delegate, vì phương thức delegate chỉ khai báo ở lớp con sẽ không được
/// Objective-C nhìn thấy.
@MainActor
class BrowserController: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    let webView: WKWebView
    private var downloadDestinations: [ObjectIdentifier: URL] = [:]

    init(webView: WKWebView) {
        self.webView = webView
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        NativeFeel.apply(to: webView)
        #if DEBUG
        webView.isInspectable = true
        #endif
    }

    // MARK: - Hooks cho lớp con

    func navigationStarted() {}
    func navigationFinished() {}
    func navigationFailed(_ error: Error) {}
    func windowCloseRequested() {}

    func openExternally(_ url: URL) {
        Presenter.openInAppBrowser(url)
    }

    /// Tạo web view cho `window.open(...)`. Bắt buộc dùng đúng `configuration` WebKit đưa vào.
    func makePopup(configuration: WKWebViewConfiguration) -> WKWebView? {
        let popup = PopupController(configuration: configuration, customUserAgent: webView.customUserAgent)
        return Presenter.presentPopup(popup) ? popup.webView : nil
    }

    // MARK: - WKNavigationDelegate

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let decision = LinkPolicy.decide(
            url: url,
            isMainFrame: navigationAction.targetFrame?.isMainFrame ?? true,
            isUserInitiated: navigationAction.navigationType == .linkActivated
        )
        switch decision {
        case .allow:
            decisionHandler(.allow)
        case .openInBrowser(let target):
            decisionHandler(.cancel)
            openExternally(target)
        case .openInSystem(let target):
            decisionHandler(.cancel)
            UIApplication.shared.open(target)
        case .block:
            decisionHandler(.cancel)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        let disposition = (navigationResponse.response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Disposition")?
            .lowercased() ?? ""
        let isAttachment = disposition.hasPrefix("attachment")
        if navigationResponse.isForMainFrame && (!navigationResponse.canShowMIMEType || isAttachment) {
            decisionHandler(.download)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        navigationStarted()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationFinished()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationFailed(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationFailed(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // iOS có thể dừng tiến trình web khi thiếu bộ nhớ — tải lại để tài khoản không bị trắng trang.
        webView.reload()
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    // MARK: - WKUIDelegate

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url, !LinkPolicy.isBlank(url) {
            let decision = LinkPolicy.decide(
                url: url,
                isMainFrame: true,
                isUserInitiated: navigationAction.navigationType == .linkActivated
            )
            switch decision {
            case .allow:
                // Link target="_blank" trong Facebook: mở ngay tại chỗ, vuốt để quay lại.
                if navigationAction.navigationType == .linkActivated {
                    webView.load(navigationAction.request)
                    return nil
                }
            case .openInBrowser(let target):
                openExternally(target)
                return nil
            case .openInSystem(let target):
                UIApplication.shared.open(target)
                return nil
            case .block:
                return nil
            }
        }
        // window.open() do trang gọi (vd. cửa sổ gọi video Messenger) cần một web view thật để giữ liên kết opener.
        return makePopup(configuration: configuration)
    }

    func webViewDidClose(_ webView: WKWebView) {
        windowCloseRequested()
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        Presenter.showAlert(title: frame.securityOrigin.host, message: message) {
            completionHandler()
        }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Presenter.showConfirm(title: frame.securityOrigin.host, message: message, completion: completionHandler)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        Presenter.showPrompt(
            title: frame.securityOrigin.host,
            message: prompt,
            defaultText: defaultText,
            completion: completionHandler
        )
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        // Cho phép gọi thoại/video trên Facebook/Messenger mà không hỏi lại mỗi lần (iOS vẫn hỏi quyền lần đầu).
        decisionHandler(LinkPolicy.isInternal(host: origin.host) ? .grant : .prompt)
    }

    // MARK: - WKDownloadDelegate

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Downloads", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let filename = suggestedFilename.isEmpty ? "tep-tai-ve" : suggestedFilename
            let destination = folder.appendingPathComponent(filename)
            downloadDestinations[ObjectIdentifier(download)] = destination
            completionHandler(destination)
        } catch {
            completionHandler(nil)
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let fileURL = downloadDestinations.removeValue(forKey: ObjectIdentifier(download)) else { return }
        Presenter.share(fileURL: fileURL)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloadDestinations.removeValue(forKey: ObjectIdentifier(download))
        Presenter.showAlert(title: "Tải xuống thất bại", message: error.localizedDescription)
    }
}
