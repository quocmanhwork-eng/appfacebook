import Foundation

/// Quyết định một điều hướng được mở trong web view, trong trình duyệt, bằng ứng dụng hệ thống hay bị chặn.
enum LinkPolicy {
    enum Decision: Equatable {
        /// Cho phép tải trong web view hiện tại.
        case allow
        /// Mở trong trình duyệt trong app (Safari View Controller).
        case openInBrowser(URL)
        /// Giao cho iOS xử lý (gọi điện, email, bản đồ…).
        case openInSystem(URL)
        /// Chặn lại.
        case block
    }

    /// Các tên miền thuộc Facebook/Messenger — được phép tải ngay trong web view.
    static let internalDomains = [
        "facebook.com", "facebook.net", "fb.com", "fb.me", "fb.gg", "fb.watch",
        "fbcdn.net", "fbsbx.com", "messenger.com", "m.me", "meta.com",
    ]

    /// Trang chuyển hướng liên kết ngoài của Facebook (l.php?u=…).
    static let linkShimHosts: Set<String> = ["l.facebook.com", "lm.facebook.com", "l.messenger.com"]

    /// Scheme luôn tải trong web view.
    static let passthroughSchemes: Set<String> = ["about", "blob", "data", "javascript"]

    /// Scheme được giao cho iOS xử lý.
    static let systemSchemes: Set<String> = ["tel", "telprompt", "mailto", "sms", "facetime", "facetime-audio", "maps"]

    /// Scheme của ứng dụng Facebook/Messenger chính thức và App Store.
    /// Chặn để trang web không đẩy người dùng sang app chính thức (làm hỏng việc dùng nhiều tài khoản).
    static let blockedSchemes: Set<String> = [
        "fb", "fbapi", "fbauth", "fbauth2", "fb-messenger", "fb-messenger-api", "fb-messenger-share-api",
        "fbshareextension", "fb-work", "itms", "itms-apps", "itms-appss",
    ]

    /// Trang App Store — chỉ mở khi người dùng tự bấm, không cho trang web tự chuyển hướng.
    static let appStoreHosts: Set<String> = ["apps.apple.com", "itunes.apple.com"]

    static func isInternal(host: String?) -> Bool {
        guard let host = host?.lowercased(), !host.isEmpty else { return false }
        return internalDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    static func isInternal(_ url: URL) -> Bool {
        isInternal(host: url.host)
    }

    static func isBlank(_ url: URL?) -> Bool {
        guard let url else { return true }
        return url.absoluteString.isEmpty || url.absoluteString == "about:blank"
    }

    /// Lấy địa chỉ đích từ link chuyển hướng của Facebook, vd.
    /// `https://l.facebook.com/l.php?u=https%3A%2F%2Fexample.com` → `https://example.com`.
    static func unwrapLinkShim(_ url: URL) -> URL? {
        guard let host = url.host?.lowercased(), linkShimHosts.contains(host),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let target = components.queryItems?.first(where: { $0.name == "u" })?.value,
              let targetURL = URL(string: target),
              let scheme = targetURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        return targetURL
    }

    static func decide(url: URL, isMainFrame: Bool, isUserInitiated: Bool = false) -> Decision {
        let scheme = url.scheme?.lowercased() ?? ""

        if passthroughSchemes.contains(scheme) {
            return .allow
        }
        if systemSchemes.contains(scheme) {
            return isMainFrame ? .openInSystem(url) : .block
        }
        if blockedSchemes.contains(scheme) {
            return .block
        }
        guard scheme == "http" || scheme == "https" else {
            // Scheme lạ (whatsapp://, zalo://…): chỉ mở khi người dùng tự bấm.
            return isMainFrame && isUserInitiated ? .openInSystem(url) : .block
        }

        // iframe (captcha, video nhúng, quảng cáo…) luôn được tải bình thường.
        guard isMainFrame else { return .allow }

        if let target = unwrapLinkShim(url) {
            return isInternal(target) ? .allow : .openInBrowser(target)
        }
        if isInternal(url) {
            return .allow
        }
        if let host = url.host?.lowercased(), appStoreHosts.contains(host), !isUserInitiated {
            return .block
        }
        return .openInBrowser(url)
    }
}
