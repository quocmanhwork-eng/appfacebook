import SwiftUI
import WebKit

/// Nhúng một `WKWebView` sẵn có (do `WebSession` giữ) vào SwiftUI mà không tạo lại nó.
struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground
        attach(to: container)
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        // Web view có thể được thay mới khi người dùng đổi giao diện/phiên của tài khoản.
        guard webView.superview !== container else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        attach(to: container)
    }

    private func attach(to container: UIView) {
        webView.frame = container.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(webView)
    }
}
