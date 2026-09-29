import Foundation

/// Các tab dưới cùng của một tài khoản, giống thanh tab của app Facebook/Messenger.
/// Tab cuối của thanh luôn là ảnh đại diện tài khoản (chuyển tài khoản), không nằm trong enum này.
enum PageTab: String, CaseIterable, Identifiable, Sendable {
    case home
    case video
    case friends
    case marketplace
    case notifications
    /// Menu của trang Facebook (không có trên thanh — trang đã có nút ≡ riêng; chỉ dùng để nhận ra trang).
    case menu
    /// Danh sách đoạn chat của Messenger (trang khởi động của tài khoản Messenger).
    case chats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Trang chủ"
        case .video: "Video"
        case .friends: "Bạn bè"
        case .marketplace: "Marketplace"
        case .notifications: "Thông báo"
        case .menu: "Menu"
        case .chats: "Đoạn chat"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .video: "play.tv"
        case .friends: "person.2"
        case .marketplace: "storefront"
        case .notifications: "bell"
        case .menu: "line.3.horizontal"
        case .chats: "bubble.left.and.bubble.right"
        }
    }

    var selectedSymbol: String {
        switch self {
        case .menu: "line.3.horizontal"
        default: symbol + ".fill"
        }
    }

    var path: String {
        switch self {
        case .home: "/"
        case .video: "/watch/"
        case .friends: "/friends/"
        case .marketplace: "/marketplace/"
        case .notifications: "/notifications/"
        case .menu: "/bookmarks/"
        case .chats: "/"
        }
    }

    static func tabs(for kind: AccountKind) -> [PageTab] {
        switch kind {
        case .facebook: [.home, .video, .friends, .marketplace, .notifications]
        case .messenger: [.chats]
        }
    }

    /// Tên miền hiển thị giao diện chính của Facebook (không gồm l.facebook.com, business.facebook.com…).
    static let appHosts: Set<String> = [
        "facebook.com", "www.facebook.com", "m.facebook.com", "web.facebook.com", "touch.facebook.com",
    ]

    static func isAppHost(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return appHosts.contains(host)
    }

    /// Gốc để ghép đường dẫn tab: giữ tên miền đang dùng (m. hay www.) để không bị chuyển giao diện.
    static func baseURL(current: URL?, start: URL) -> URL {
        for candidate in [current, start] {
            if let candidate, isAppHost(candidate), let scheme = candidate.scheme, let host = candidate.host,
               let base = URL(string: "\(scheme)://\(host)") {
                return base
            }
        }
        return URL(string: "https://m.facebook.com")!
    }

    func url(base: URL) -> URL {
        URL(string: path, relativeTo: base)?.absoluteURL ?? base
    }

    /// Tab tương ứng với trang đang mở, hoặc `nil` nếu trang không thuộc tab nào (vd. trang cá nhân).
    static func matching(_ url: URL?) -> PageTab? {
        guard let url, isAppHost(url) else { return nil }
        let path = url.path.lowercased()
        if path.isEmpty || path == "/" || path == "/home.php" {
            return .home
        }
        let prefixes: [(String, PageTab)] = [
            ("/watch", .video), ("/reel", .video), ("/video", .video),
            ("/friends", .friends),
            ("/marketplace", .marketplace),
            ("/notifications", .notifications),
            ("/bookmarks", .menu), ("/menu", .menu),
        ]
        return prefixes.first { path.hasPrefix($0.0) }?.1
    }
}
