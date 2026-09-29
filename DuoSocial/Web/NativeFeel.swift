import ObjectiveC
import UIKit
import WebKit

/// Các chỉnh sửa phía app để web view bớt cảm giác "trang web trong Safari".
@MainActor
enum NativeFeel {
    /// Áp dụng cho mọi web view (tài khoản và cửa sổ bật lên).
    static func apply(to webView: WKWebView) {
        // Không nháy nền trắng khi đang tải ở chế độ tối.
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.underPageBackgroundColor = .systemBackground
        // Nhấn giữ link không hiện bản xem trước kiểu Safari.
        webView.allowsLinkPreview = false
        // Kéo nội dung xuống để ẩn bàn phím, như ô chat trong app.
        webView.scrollView.keyboardDismissMode = .interactive
        removeKeyboardAccessoryBar(from: webView)
    }

    /// Tên lớp con dùng để bỏ thanh "‹ › Xong" mà WebKit gắn phía trên bàn phím.
    static let accessoryFreeSuffix = "_DuoSocialNoAccessoryBar"

    /// Thay lớp của view nội dung WebKit bằng một lớp con trả về `inputAccessoryView = nil`
    /// (cách các app lai như Cordova vẫn dùng). Không làm gì nếu cấu trúc WebKit khác dự kiến.
    static func removeKeyboardAccessoryBar(from webView: WKWebView) {
        guard let contentView = webView.scrollView.subviews.first(where: {
            NSStringFromClass(type(of: $0)).hasPrefix("WKContent")
        }) else { return }

        let baseClass: AnyClass = type(of: contentView)
        let baseName = NSStringFromClass(baseClass)
        guard !baseName.hasSuffix(accessoryFreeSuffix) else { return }

        let subclassName = baseName + accessoryFreeSuffix
        var subclass: AnyClass? = NSClassFromString(subclassName)
        if subclass == nil, let newClass = objc_allocateClassPair(baseClass, subclassName, 0) {
            let selector = #selector(getter: UIResponder.inputAccessoryView)
            let noAccessory: @convention(block) (AnyObject) -> AnyObject? = { _ in nil }
            if let method = class_getInstanceMethod(UIResponder.self, selector) {
                _ = class_addMethod(newClass, selector, imp_implementationWithBlock(noAccessory), method_getTypeEncoding(method))
            }
            objc_registerClassPair(newClass)
            subclass = newClass
        }
        if let subclass {
            _ = object_setClass(contentView, subclass)
        }
    }
}
