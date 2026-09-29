import XCTest
@testable import DuoSocial

final class LinkPolicyTests: XCTestCase {
    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    func testInternalHosts() {
        XCTAssertTrue(LinkPolicy.isInternal(host: "facebook.com"))
        XCTAssertTrue(LinkPolicy.isInternal(host: "m.facebook.com"))
        XCTAssertTrue(LinkPolicy.isInternal(host: "WWW.FACEBOOK.COM"))
        XCTAssertTrue(LinkPolicy.isInternal(host: "www.messenger.com"))
        XCTAssertTrue(LinkPolicy.isInternal(host: "scontent.xx.fbcdn.net"))
        XCTAssertTrue(LinkPolicy.isInternal(host: "m.me"))

        XCTAssertFalse(LinkPolicy.isInternal(host: "notfacebook.com"))
        XCTAssertFalse(LinkPolicy.isInternal(host: "facebook.com.evil.example"))
        XCTAssertFalse(LinkPolicy.isInternal(host: "google.com"))
        XCTAssertFalse(LinkPolicy.isInternal(host: ""))
        XCTAssertFalse(LinkPolicy.isInternal(host: nil))
    }

    func testFacebookPagesLoadInPlace() {
        XCTAssertEqual(LinkPolicy.decide(url: url("https://m.facebook.com/home.php"), isMainFrame: true), .allow)
        XCTAssertEqual(LinkPolicy.decide(url: url("https://www.messenger.com/t/123"), isMainFrame: true), .allow)
    }

    func testExternalLinksOpenInBrowser() {
        let external = url("https://vnexpress.net/bai-viet")
        XCTAssertEqual(LinkPolicy.decide(url: external, isMainFrame: true), .openInBrowser(external))
    }

    func testIframesAreAlwaysAllowed() {
        XCTAssertEqual(LinkPolicy.decide(url: url("https://www.google.com/recaptcha/api2/anchor"), isMainFrame: false), .allow)
    }

    func testLinkShimIsUnwrapped() {
        let shim = url("https://l.facebook.com/l.php?u=https%3A%2F%2Fexample.com%2Fpath%3Fa%3D1&h=AT0abc")
        XCTAssertEqual(LinkPolicy.unwrapLinkShim(shim), url("https://example.com/path?a=1"))
        XCTAssertEqual(LinkPolicy.decide(url: shim, isMainFrame: true), .openInBrowser(url("https://example.com/path?a=1")))
    }

    func testLinkShimToFacebookStaysInApp() {
        let shim = url("https://lm.facebook.com/l.php?u=https%3A%2F%2Fwww.facebook.com%2Fgroups%2F1")
        XCTAssertEqual(LinkPolicy.decide(url: shim, isMainFrame: true), .allow)
    }

    func testLinkShimRejectsNonHTTPTargets() {
        let shim = url("https://l.facebook.com/l.php?u=javascript%3Aalert(1)")
        XCTAssertNil(LinkPolicy.unwrapLinkShim(shim))
    }

    func testSystemSchemesAreHandedToIOS() {
        let phone = url("tel:0901234567")
        XCTAssertEqual(LinkPolicy.decide(url: phone, isMainFrame: true), .openInSystem(phone))
        XCTAssertEqual(LinkPolicy.decide(url: phone, isMainFrame: false), .block)
        let mail = url("mailto:ban@example.com")
        XCTAssertEqual(LinkPolicy.decide(url: mail, isMainFrame: true), .openInSystem(mail))
    }

    func testOfficialAppSchemesAreBlocked() {
        XCTAssertEqual(LinkPolicy.decide(url: url("fb-messenger://threads"), isMainFrame: true, isUserInitiated: true), .block)
        XCTAssertEqual(LinkPolicy.decide(url: url("fb://profile/4"), isMainFrame: true, isUserInitiated: true), .block)
        XCTAssertEqual(LinkPolicy.decide(url: url("itms-apps://apps.apple.com/app/id454638411"), isMainFrame: true), .block)
    }

    func testAppStoreOnlyOpensWhenUserTaps() {
        let store = url("https://apps.apple.com/app/messenger/id454638411")
        XCTAssertEqual(LinkPolicy.decide(url: store, isMainFrame: true, isUserInitiated: false), .block)
        XCTAssertEqual(LinkPolicy.decide(url: store, isMainFrame: true, isUserInitiated: true), .openInBrowser(store))
    }

    func testUnknownSchemesRequireUserTap() {
        let zalo = url("zalo://chat")
        XCTAssertEqual(LinkPolicy.decide(url: zalo, isMainFrame: true, isUserInitiated: false), .block)
        XCTAssertEqual(LinkPolicy.decide(url: zalo, isMainFrame: true, isUserInitiated: true), .openInSystem(zalo))
    }

    func testPassthroughSchemes() {
        XCTAssertEqual(LinkPolicy.decide(url: url("about:blank"), isMainFrame: true), .allow)
        XCTAssertEqual(LinkPolicy.decide(url: url("blob:https://www.facebook.com/abc"), isMainFrame: true), .allow)
    }

    func testBlankURLs() {
        XCTAssertTrue(LinkPolicy.isBlank(nil))
        XCTAssertTrue(LinkPolicy.isBlank(url("about:blank")))
        XCTAssertFalse(LinkPolicy.isBlank(url("https://m.facebook.com")))
    }
}
