import XCTest
@testable import DuoSocial

final class AccountTests: XCTestCase {
    func testDefaultsDependOnKind() {
        let facebook = Account(kind: .facebook, name: "Facebook 1", color: .blue)
        let messenger = Account(kind: .messenger, name: "Messenger 1", color: .purple)

        XCTAssertEqual(facebook.webMode, .mobile)
        XCTAssertEqual(messenger.webMode, .desktopFit)
        XCTAssertEqual(facebook.startURL.host, "m.facebook.com")
        XCTAssertEqual(messenger.startURL.host, "www.messenger.com")
    }

    func testCustomStartURL() {
        var account = Account(kind: .facebook, name: "FB", color: .blue)
        account.customStartURL = "facebook.com/messages"
        XCTAssertEqual(account.startURL, URL(string: "https://facebook.com/messages"))

        account.customStartURL = "not a url"
        XCTAssertEqual(account.startURL, AccountKind.facebook.defaultStartURL)

        account.customStartURL = "   "
        XCTAssertEqual(account.startURL, AccountKind.facebook.defaultStartURL)
    }

    func testNormalizedURL() {
        XCTAssertEqual(Account.normalizedURL(from: "https://www.messenger.com/t/1"), URL(string: "https://www.messenger.com/t/1"))
        XCTAssertEqual(Account.normalizedURL(from: " m.facebook.com/groups "), URL(string: "https://m.facebook.com/groups"))
        XCTAssertNil(Account.normalizedURL(from: "ftp://example.com"))
        XCTAssertNil(Account.normalizedURL(from: ""))
        XCTAssertNil(Account.normalizedURL(from: nil))
        XCTAssertNil(Account.normalizedURL(from: "hai tu"))
    }

    func testInitials() {
        XCTAssertEqual(Account.initials(for: "Facebook 1"), "F1")
        XCTAssertEqual(Account.initials(for: "nguyễn văn an"), "NA")
        XCTAssertEqual(Account.initials(for: "Tuấn"), "T")
        XCTAssertEqual(Account.initials(for: "   "), "?")
    }

    func testSessionSignatureChangesWithWebSettings() {
        var account = Account(kind: .messenger, name: "M", color: .purple)
        let original = account.sessionSignature

        account.name = "Đổi tên"
        account.color = .green
        XCTAssertEqual(account.sessionSignature, original, "Đổi tên/màu không được tạo lại web view")

        account.webMode = .mobile
        XCTAssertNotEqual(account.sessionSignature, original)
    }

    func testCodableRoundTrip() throws {
        let account = Account(
            kind: .messenger,
            name: "Messenger công việc",
            color: .orange,
            webMode: .desktop,
            customStartURL: "facebook.com/messages"
        )
        let data = try JSONEncoder().encode(account)
        XCTAssertEqual(try JSONDecoder().decode(Account.self, from: data), account)
    }

    func testDecodingToleratesMissingAndUnknownFields() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","kind":"messenger","name":"Cũ","color":"rainbow"}
        """
        let account = try JSONDecoder().decode(Account.self, from: Data(json.utf8))

        XCTAssertEqual(account.id, id)
        XCTAssertEqual(account.name, "Cũ")
        XCTAssertEqual(account.color, .blue)
        XCTAssertEqual(account.sessionID, id)
        XCTAssertEqual(account.webMode, .desktopFit)
        XCTAssertNil(account.customStartURL)
    }
}
