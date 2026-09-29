import XCTest
@testable import DuoSocial

final class UnreadParserTests: XCTestCase {
    func testReadsCountFromTitle() {
        XCTAssertEqual(UnreadParser.unreadCount(fromTitle: "(3) Facebook"), 3)
        XCTAssertEqual(UnreadParser.unreadCount(fromTitle: "(12) Messenger"), 12)
        XCTAssertEqual(UnreadParser.unreadCount(fromTitle: "Messenger (5)"), 5)
        XCTAssertEqual(UnreadParser.unreadCount(fromTitle: "(1) Nguyễn Văn An | Facebook"), 1)
    }

    func testReadsCappedCount() {
        XCTAssertEqual(UnreadParser.unreadCount(fromTitle: "(99+) Facebook"), 99)
    }

    func testPlainTitleMeansZero() {
        XCTAssertEqual(UnreadParser.unreadCount(fromTitle: "Facebook"), 0)
        XCTAssertEqual(UnreadParser.unreadCount(fromTitle: "Messenger"), 0)
        XCTAssertEqual(UnreadParser.unreadCount(fromTitle: "Nhóm Du lịch | Facebook"), 0)
    }

    func testUnknownTitleKeepsPreviousValue() {
        // Tiêu đề nhấp nháy khi có tin nhắn mới — không được đặt lại về 0.
        XCTAssertNil(UnreadParser.unreadCount(fromTitle: "Lan đã gửi tin nhắn cho bạn"))
        XCTAssertNil(UnreadParser.unreadCount(fromTitle: ""))
        XCTAssertNil(UnreadParser.unreadCount(fromTitle: "   "))
        XCTAssertNil(UnreadParser.unreadCount(fromTitle: nil))
    }
}
