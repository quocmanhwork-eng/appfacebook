import UIKit
import WebKit

enum UserAgent {
    /// Gắn vào cuối User-Agent mặc định của WKWebView để Facebook coi app như Safari trên iPhone
    /// (thay vì một trình duyệt nhúng bị giới hạn tính năng).
    @MainActor
    static var mobileSafariSuffix: String {
        let major = UIDevice.current.systemVersion.split(separator: ".").first.map(String.init) ?? "17"
        return "Version/\(major).0 Mobile/15E148 Safari/604.1"
    }

    static let desktopSafari =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
}

enum UserScripts {
    /// Script làm trang giống app hơn (DuoSocial/Web/Scripts/native-feel.js, được đóng gói vào app).
    static let nativeFeel: String = {
        guard let url = Bundle.main.url(forResource: "native-feel", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return source
    }()

    /// Cấu hình cho native-feel.js, phải chạy trước nó.
    static func nativeFeelConfig(hideWebTabBar: Bool) -> String {
        "window.__duoSocialConfig = { hideWebTabBar: \(hideWebTabBar ? "true" : "false") };"
    }

    /// Ép trang giao diện máy tính co giãn theo chiều rộng màn hình điện thoại.
    static let fitViewport = """
    (function () {
      var meta = document.querySelector('meta[name="viewport"]');
      if (!meta) {
        meta = document.createElement('meta');
        meta.name = 'viewport';
        (document.head || document.documentElement).appendChild(meta);
      }
      meta.setAttribute('content', 'width=device-width, initial-scale=1');
    })();
    """
}

@MainActor
enum WebViewFactory {
    /// Tạo web view cho một tài khoản. `dataStore` quyết định tài khoản dùng phiên đăng nhập nào.
    /// `hideWebTabBar`: ẩn thanh tab của chính trang Facebook vì app đã có thanh tab riêng.
    static func makeWebView(for account: Account, dataStore: WKWebsiteDataStore, hideWebTabBar: Bool) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.applicationNameForUserAgent = UserAgent.mobileSafariSuffix
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        if !account.webMode.usesDesktopUserAgent {
            // Trên iPad WebKit mặc định dùng giao diện máy tính; ép về di động khi người dùng chọn.
            configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        }
        if !UserScripts.nativeFeel.isEmpty {
            let config = UserScripts.nativeFeelConfig(hideWebTabBar: hideWebTabBar && account.kind == .facebook)
            configuration.userContentController.addUserScript(
                WKUserScript(source: config, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            )
            configuration.userContentController.addUserScript(
                WKUserScript(source: UserScripts.nativeFeel, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            )
        }
        if account.webMode.fitsViewportToScreen {
            configuration.userContentController.addUserScript(
                WKUserScript(source: UserScripts.fitViewport, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            )
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = account.webMode.usesDesktopUserAgent ? UserAgent.desktopSafari : nil
        return webView
    }
}
