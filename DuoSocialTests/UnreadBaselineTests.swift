import XCTest
@testable import DuoSocial

final class UnreadBaselineTests: XCTestCase {
    private let account = UUID()

    func testFirstObservationOnlyRecords() {
        var baseline = UnreadBaseline()
        XCTAssertFalse(baseline.observe(5, for: account, isSettling: false), "Không báo tin cũ khi mới mở app lần đầu")
        XCTAssertEqual(baseline.counts[account], 5)
    }

    func testIncreaseAlertsOnce() {
        var baseline = UnreadBaseline(counts: [account: 2])
        XCTAssertTrue(baseline.observe(3, for: account, isSettling: false))
        XCTAssertFalse(baseline.observe(3, for: account, isSettling: false))
    }

    func testReloadDoesNotRepeatOldAlert() {
        // Tải lại trang: "(3) Facebook" → "Facebook" → "(3) Facebook".
        var baseline = UnreadBaseline(counts: [account: 3])
        XCTAssertFalse(baseline.observe(0, for: account, isSettling: true))
        XCTAssertEqual(baseline.counts[account], 3)
        XCTAssertFalse(baseline.observe(3, for: account, isSettling: true))
    }

    func testIncreaseWhileSettlingStillAlerts() {
        // Chạy nền: trang vừa tải lại và có tin mới.
        var baseline = UnreadBaseline(counts: [account: 1])
        XCTAssertTrue(baseline.observe(2, for: account, isSettling: true))
    }

    func testReadingLowersBaselineSoNextMessageAlerts() {
        var baseline = UnreadBaseline(counts: [account: 3])
        XCTAssertFalse(baseline.observe(0, for: account, isSettling: false))
        XCTAssertEqual(baseline.counts[account], 0)
        XCTAssertTrue(baseline.observe(1, for: account, isSettling: false))
    }

    func testAccountsAreIndependent() {
        let other = UUID()
        var baseline = UnreadBaseline(counts: [account: 4, other: 0])
        XCTAssertTrue(baseline.observe(1, for: other, isSettling: false))
        XCTAssertEqual(baseline.counts[account], 4)
        baseline.remove(account)
        XCTAssertNil(baseline.counts[account])
    }

    func testPersistence() {
        let suiteName = "DuoSocialTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }

        var baseline = UnreadBaseline(defaults: defaults)
        XCTAssertTrue(baseline.counts.isEmpty)
        _ = baseline.observe(7, for: account, isSettling: false)
        baseline.save(to: defaults)

        XCTAssertEqual(UnreadBaseline(defaults: defaults).counts, [account: 7])
    }
}
