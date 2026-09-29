import WebKit
import XCTest
@testable import DuoSocial

final class NativeFeelTests: XCTestCase {
    func testNativeFeelScriptIsBundled() {
        // Nếu native-feel.js không được đóng gói vào app, trang sẽ không được chỉnh cho giống app.
        XCTAssertTrue(UserScripts.nativeFeel.contains("__duoSocialNativeFeel"))
    }

    func testConfigScript() {
        XCTAssertEqual(UserScripts.nativeFeelConfig(hideWebTabBar: true), "window.__duoSocialConfig = { hideWebTabBar: true };")
        XCTAssertEqual(UserScripts.nativeFeelConfig(hideWebTabBar: false), "window.__duoSocialConfig = { hideWebTabBar: false };")
    }

    @MainActor
    func testFacebookWebViewGetsScriptsAndOnlyFacebookHidesWebTabBar() {
        let store = WKWebsiteDataStore.nonPersistent()
        let facebook = WebViewFactory.makeWebView(
            for: Account(kind: .facebook, name: "FB", color: .blue), dataStore: store, hideWebTabBar: true
        )
        let facebookScripts = facebook.configuration.userContentController.userScripts.map(\.source)
        XCTAssertTrue(facebookScripts.contains("window.__duoSocialConfig = { hideWebTabBar: true };"))
        XCTAssertTrue(facebookScripts.contains(UserScripts.nativeFeel))

        let messenger = WebViewFactory.makeWebView(
            for: Account(kind: .messenger, name: "M", color: .purple), dataStore: store, hideWebTabBar: true
        )
        let messengerScripts = messenger.configuration.userContentController.userScripts.map(\.source)
        XCTAssertTrue(messengerScripts.contains("window.__duoSocialConfig = { hideWebTabBar: false };"))
    }

    @MainActor
    func testWebViewTweaks() {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        NativeFeel.apply(to: webView)

        XCTAssertFalse(webView.allowsLinkPreview)
        XCTAssertFalse(webView.isOpaque)
        XCTAssertEqual(webView.scrollView.keyboardDismissMode, .interactive)
    }

    @MainActor
    func testKeyboardAccessoryBarIsRemoved() throws {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        guard let contentView = webView.scrollView.subviews.first(where: {
            NSStringFromClass(type(of: $0)).hasPrefix("WKContent")
        }) else {
            throw XCTSkip("Phiên bản WebKit này không có WKContentView như dự kiến.")
        }

        NativeFeel.removeKeyboardAccessoryBar(from: webView)
        NativeFeel.removeKeyboardAccessoryBar(from: webView) // gọi lần hai không được tạo lớp lồng nhau

        let className = NSStringFromClass(type(of: contentView))
        XCTAssertTrue(className.hasSuffix(NativeFeel.accessoryFreeSuffix))
        XCTAssertFalse(className.hasSuffix(NativeFeel.accessoryFreeSuffix + NativeFeel.accessoryFreeSuffix))
        XCTAssertNil(contentView.inputAccessoryView)
    }

    @MainActor
    func testChangingWebTabBarOptionChangesSignature() {
        let manager = WebSessionManager()
        let account = Account(kind: .facebook, name: "FB", color: .blue)

        manager.hideWebTabBar = true
        let hidden = manager.signature(for: account)
        manager.hideWebTabBar = false
        let shown = manager.signature(for: account)

        XCTAssertNotEqual(hidden, shown, "Đổi tùy chọn phải tạo lại web view để script mới có hiệu lực")
        XCTAssertTrue(hidden.hasPrefix(account.sessionSignature))
    }
}
