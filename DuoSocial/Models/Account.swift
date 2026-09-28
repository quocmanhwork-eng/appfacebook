import Foundation

/// Dịch vụ mà một tài khoản hiển thị.
enum AccountKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case facebook
    case messenger

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .facebook: "Facebook"
        case .messenger: "Messenger"
        }
    }

    /// Trang được mở khi tài khoản khởi động (nếu người dùng không đặt trang riêng).
    var defaultStartURL: URL {
        switch self {
        case .facebook: URL(string: "https://m.facebook.com/")!
        case .messenger: URL(string: "https://www.messenger.com/")!
        }
    }

    var defaultWebMode: WebMode {
        switch self {
        case .facebook: .mobile
        case .messenger: .desktopFit
        }
    }
}

/// Cách trang web được yêu cầu và hiển thị trong web view.
enum WebMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Giao diện web di động, giống Safari trên iPhone.
    case mobile
    /// Giao diện máy tính, thu nhỏ cho vừa màn hình.
    case desktop
    /// Giao diện máy tính nhưng ép khung nhìn theo chiều rộng điện thoại.
    case desktopFit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mobile: "Di động"
        case .desktop: "Máy tính"
        case .desktopFit: "Máy tính (vừa màn hình)"
        }
    }

    var detail: String {
        switch self {
        case .mobile:
            "Giao diện web di động giống Safari trên iPhone. Phù hợp nhất cho Facebook."
        case .desktop:
            "Giao diện máy tính đầy đủ, được thu nhỏ cho vừa màn hình. Dùng hai ngón tay để phóng to."
        case .desktopFit:
            "Giao diện máy tính co giãn theo chiều rộng điện thoại. Phù hợp cho Messenger vì bản web di động của Messenger thường bắt cài ứng dụng."
        }
    }

    var usesDesktopUserAgent: Bool { self != .mobile }
    var fitsViewportToScreen: Bool { self == .desktopFit }
}

/// Màu nhận diện của tài khoản trên thanh chuyển tài khoản.
enum AccountColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case blue, teal, green, orange, red, pink, purple, indigo

    var id: String { rawValue }
}

/// Một tài khoản Facebook hoặc Messenger được đăng nhập trong ứng dụng.
struct Account: Identifiable, Hashable, Sendable {
    var id: UUID
    var kind: AccountKind
    var name: String
    var color: AccountColor
    /// Mã kho dữ liệu web (cookie, localStorage, bộ nhớ đệm…).
    /// Mỗi mã là một phiên đăng nhập độc lập; hai tài khoản cùng mã sẽ dùng chung đăng nhập.
    var sessionID: UUID
    var webMode: WebMode
    /// Trang khởi động do người dùng tự đặt; `nil` nghĩa là dùng trang mặc định.
    var customStartURL: String?

    init(
        id: UUID = UUID(),
        kind: AccountKind,
        name: String,
        color: AccountColor,
        sessionID: UUID = UUID(),
        webMode: WebMode? = nil,
        customStartURL: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.color = color
        self.sessionID = sessionID
        self.webMode = webMode ?? kind.defaultWebMode
        self.customStartURL = customStartURL
    }

    var startURL: URL {
        Self.normalizedURL(from: customStartURL) ?? kind.defaultStartURL
    }

    /// Các giá trị mà khi thay đổi thì web view phải được tạo lại.
    var sessionSignature: String {
        [sessionID.uuidString, webMode.rawValue, startURL.absoluteString].joined(separator: "|")
    }

    var initials: String { Self.initials(for: name) }

    /// Chuyển chuỗi người dùng nhập (vd. "facebook.com/messages") thành URL http(s) hợp lệ.
    static func normalizedURL(from string: String?) -> URL? {
        guard let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              !trimmed.contains(where: \.isWhitespace)
        else { return nil }

        let candidate = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty
        else { return nil }
        return url
    }

    /// "Facebook 1" → "F1", "Nguyễn Văn An" → "NA", "Tuấn" → "T".
    static func initials(for name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
        guard let first = words.first?.first else { return "?" }
        if words.count > 1, let last = words.last?.first {
            return String(first).uppercased() + String(last).uppercased()
        }
        return String(first).uppercased()
    }
}

extension Account: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, kind, name, color, sessionID, webMode, customStartURL
    }

    // Giải mã "dễ tính" để dữ liệu cũ vẫn đọc được khi thêm trường mới.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let kind = try container.decode(AccountKind.self, forKey: .kind)
        self.id = id
        self.kind = kind
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? kind.displayName
        color = (try? container.decodeIfPresent(AccountColor.self, forKey: .color)) ?? .blue
        sessionID = try container.decodeIfPresent(UUID.self, forKey: .sessionID) ?? id
        webMode = (try? container.decodeIfPresent(WebMode.self, forKey: .webMode)) ?? kind.defaultWebMode
        customStartURL = try container.decodeIfPresent(String.self, forKey: .customStartURL)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(name, forKey: .name)
        try container.encode(color, forKey: .color)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(webMode, forKey: .webMode)
        try container.encodeIfPresent(customStartURL, forKey: .customStartURL)
    }
}
