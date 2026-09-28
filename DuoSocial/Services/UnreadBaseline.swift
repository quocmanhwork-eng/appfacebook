import Foundation

/// Số chưa đọc đã biết của từng tài khoản, lưu qua các lần mở app, để chỉ báo khi số thực sự tăng.
///
/// Khi trang tải lại, tiêu đề thường tạm về "Facebook" (0) rồi mới hiện lại "(3) Facebook".
/// Những lần giảm trong lúc trang đang ổn định (`isSettling`) bị bỏ qua để không báo lại tin cũ.
struct UnreadBaseline: Equatable {
    private(set) var counts: [UUID: Int]

    init(counts: [UUID: Int] = [:]) {
        self.counts = counts
    }

    /// - Returns: `true` nếu nên gửi thông báo.
    mutating func observe(_ count: Int, for accountID: UUID, isSettling: Bool) -> Bool {
        guard let previous = counts[accountID] else {
            // Lần đầu thấy tài khoản này: chỉ ghi nhận, không báo tin cũ.
            counts[accountID] = count
            return false
        }
        if count < previous && isSettling {
            return false
        }
        counts[accountID] = count
        return count > previous
    }

    mutating func remove(_ accountID: UUID) {
        counts.removeValue(forKey: accountID)
    }
}

extension UnreadBaseline {
    private static let storageKey = "duosocial.unreadBaseline.v1"

    init(defaults: UserDefaults) {
        let stored = defaults.dictionary(forKey: Self.storageKey) as? [String: Int] ?? [:]
        var counts: [UUID: Int] = [:]
        for (key, value) in stored {
            if let id = UUID(uuidString: key) {
                counts[id] = value
            }
        }
        self.init(counts: counts)
    }

    func save(to defaults: UserDefaults) {
        let stored = Dictionary(uniqueKeysWithValues: counts.map { ($0.key.uuidString, $0.value) })
        defaults.set(stored, forKey: Self.storageKey)
    }
}
