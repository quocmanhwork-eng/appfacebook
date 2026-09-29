import XCTest
@testable import DuoSocial

final class AccountStoreTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "DuoSocialTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    @MainActor
    func testSeedsTwoFacebookAndTwoMessengerAccounts() {
        let store = AccountStore(defaults: makeDefaults())

        XCTAssertEqual(store.accounts(of: .facebook).map(\.name), ["Facebook 1", "Facebook 2"])
        XCTAssertEqual(store.accounts(of: .messenger).map(\.name), ["Messenger 1", "Messenger 2"])
        XCTAssertEqual(Set(store.accounts.map(\.sessionID)).count, 4, "Mỗi tài khoản mặc định phải có phiên đăng nhập riêng")
    }

    @MainActor
    func testSessionIDsSurviveRelaunch() {
        let defaults = makeDefaults()
        let firstLaunch = AccountStore(defaults: defaults)
        let secondLaunch = AccountStore(defaults: defaults)

        XCTAssertEqual(secondLaunch.accounts, firstLaunch.accounts)
    }

    @MainActor
    func testAddUpdateRemovePersist() {
        let defaults = makeDefaults()
        let store = AccountStore(defaults: defaults)

        var added = store.addAccount(kind: .facebook)
        XCTAssertEqual(added.name, "Facebook 3")
        XCTAssertFalse(store.accounts.dropLast().contains { $0.color == added.color }, "Tài khoản mới nên có màu chưa dùng")

        added.name = "FB Shop"
        store.update(added)
        XCTAssertEqual(AccountStore(defaults: defaults).account(with: added.id)?.name, "FB Shop")

        store.remove(id: added.id)
        XCTAssertNil(AccountStore(defaults: defaults).account(with: added.id))
    }

    @MainActor
    func testDefaultNameFillsGaps() {
        let store = AccountStore(defaults: makeDefaults())
        let first = store.accounts(of: .facebook)[0]
        store.remove(id: first.id)

        XCTAssertEqual(store.nextDefaultName(for: .facebook), "Facebook 1")
        XCTAssertEqual(store.nextDefaultName(for: .messenger), "Messenger 3")
    }

    @MainActor
    func testSessionSharing() {
        let store = AccountStore(defaults: makeDefaults())
        let facebook = store.accounts(of: .facebook)[0]
        var messenger = store.accounts(of: .messenger)[0]
        let previousSession = messenger.sessionID

        messenger.sessionID = facebook.sessionID
        store.update(messenger)

        XCTAssertFalse(store.isSessionInUse(previousSession))
        XCTAssertEqual(store.accountsSharingSession(with: facebook).map(\.id), [messenger.id])
        XCTAssertEqual(store.accountsSharingSession(with: messenger).map(\.id), [facebook.id])
    }
}
