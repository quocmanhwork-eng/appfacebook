import XCTest
@testable import DuoSocial

final class PageTabTests: XCTestCase {
    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    func testTabsPerKind() {
        // Tab cuối (ảnh đại diện tài khoản) do thanh tab tự thêm, không nằm trong danh sách này.
        XCTAssertEqual(PageTab.tabs(for: .facebook), [.home, .video, .friends, .marketplace, .notifications])
        XCTAssertEqual(PageTab.tabs(for: .messenger), [.chats])
    }

    func testTabURLsKeepCurrentFacebookHost() {
        let mobileBase = PageTab.baseURL(current: url("https://m.facebook.com/profile.php?id=4"), start: url("https://m.facebook.com/"))
        XCTAssertEqual(PageTab.video.url(base: mobileBase), url("https://m.facebook.com/watch/"))
        XCTAssertEqual(PageTab.menu.url(base: mobileBase), url("https://m.facebook.com/bookmarks/"))

        let desktopBase = PageTab.baseURL(current: url("https://www.facebook.com/groups/1"), start: url("https://m.facebook.com/"))
        XCTAssertEqual(PageTab.marketplace.url(base: desktopBase), url("https://www.facebook.com/marketplace/"))
        XCTAssertEqual(PageTab.home.url(base: desktopBase), url("https://www.facebook.com/"))
    }

    func testBaseURLFallsBackToStartURL() {
        // Đang ở trang đăng nhập/chuyển hướng hoặc chưa tải gì: dùng tên miền của trang khởi động.
        let start = url("https://m.facebook.com/")
        XCTAssertEqual(PageTab.baseURL(current: nil, start: start), url("https://m.facebook.com"))
        XCTAssertEqual(PageTab.baseURL(current: url("https://l.facebook.com/l.php?u=x"), start: start), url("https://m.facebook.com"))
        XCTAssertEqual(PageTab.baseURL(current: url("https://www.messenger.com/"), start: url("https://www.messenger.com/")), url("https://m.facebook.com"))
    }

    func testMatchingCurrentPage() {
        XCTAssertEqual(PageTab.matching(url("https://m.facebook.com/")), .home)
        XCTAssertEqual(PageTab.matching(url("https://m.facebook.com")), .home)
        XCTAssertEqual(PageTab.matching(url("https://m.facebook.com/home.php?ref=bookmarks")), .home)
        XCTAssertEqual(PageTab.matching(url("https://m.facebook.com/watch/?v=123")), .video)
        XCTAssertEqual(PageTab.matching(url("https://www.facebook.com/reel/987")), .video)
        XCTAssertEqual(PageTab.matching(url("https://m.facebook.com/friends/requests/")), .friends)
        XCTAssertEqual(PageTab.matching(url("https://m.facebook.com/marketplace/item/1/")), .marketplace)
        XCTAssertEqual(PageTab.matching(url("https://m.facebook.com/notifications/")), .notifications)
        XCTAssertEqual(PageTab.matching(url("https://m.facebook.com/bookmarks/")), .menu)
    }

    func testPagesOutsideTabsDoNotMatch() {
        XCTAssertNil(PageTab.matching(url("https://m.facebook.com/profile.php?id=4")))
        XCTAssertNil(PageTab.matching(url("https://m.facebook.com/groups/123")))
        XCTAssertNil(PageTab.matching(url("https://www.messenger.com/")))
        XCTAssertNil(PageTab.matching(url("https://example.com/watch/")))
        XCTAssertNil(PageTab.matching(nil))
    }

    func testSelectedSymbols() {
        XCTAssertEqual(PageTab.home.selectedSymbol, "house.fill")
        XCTAssertEqual(PageTab.menu.selectedSymbol, "line.3.horizontal")
        XCTAssertEqual(PageTab.chats.selectedSymbol, "bubble.left.and.bubble.right.fill")
    }
}
