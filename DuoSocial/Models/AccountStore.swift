import Foundation
import Observation

/// Danh sách tài khoản, lưu trong UserDefaults.
@Observable
@MainActor
final class AccountStore {
    static let storageKey = "duosocial.accounts.v1"

    private(set) var accounts: [Account]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([Account].self, from: data) {
            accounts = decoded
        } else {
            accounts = Self.makeDefaultAccounts()
            // Lưu ngay để mã phiên của các tài khoản mặc định không đổi sau mỗi lần mở app.
            persist()
        }
    }

    /// 2 tài khoản Facebook + 2 tài khoản Messenger, mỗi tài khoản một phiên riêng.
    static func makeDefaultAccounts() -> [Account] {
        [
            Account(kind: .facebook, name: "Facebook 1", color: .blue),
            Account(kind: .facebook, name: "Facebook 2", color: .teal),
            Account(kind: .messenger, name: "Messenger 1", color: .purple),
            Account(kind: .messenger, name: "Messenger 2", color: .pink),
        ]
    }

    func account(with id: UUID) -> Account? {
        accounts.first { $0.id == id }
    }

    func accounts(of kind: AccountKind) -> [Account] {
        accounts.filter { $0.kind == kind }
    }

    /// Các tài khoản khác đang dùng chung phiên đăng nhập với `account`.
    func accountsSharingSession(with account: Account) -> [Account] {
        accounts.filter { $0.id != account.id && $0.sessionID == account.sessionID }
    }

    func isSessionInUse(_ sessionID: UUID) -> Bool {
        accounts.contains { $0.sessionID == sessionID }
    }

    @discardableResult
    func addAccount(kind: AccountKind) -> Account {
        let account = Account(kind: kind, name: nextDefaultName(for: kind), color: nextColor())
        accounts.append(account)
        persist()
        return account
    }

    func update(_ account: Account) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index] = account
        persist()
    }

    func remove(id: UUID) {
        accounts.removeAll { $0.id == id }
        persist()
    }

    /// Tên mặc định chưa bị dùng, vd. "Facebook 3".
    func nextDefaultName(for kind: AccountKind) -> String {
        let usedNames = Set(accounts.map(\.name))
        var number = 1
        while usedNames.contains("\(kind.displayName) \(number)") {
            number += 1
        }
        return "\(kind.displayName) \(number)"
    }

    private func nextColor() -> AccountColor {
        let used = Set(accounts.map(\.color))
        let palette = AccountColor.allCases
        return palette.first { !used.contains($0) } ?? palette[accounts.count % palette.count]
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
