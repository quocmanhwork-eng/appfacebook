import UIKit
import WebKit

/// Cửa sổ do trang mở bằng `window.open(...)` — vd. cửa sổ gọi video Messenger, trang chia sẻ.
@MainActor
final class PopupController: BrowserController {
    weak var viewController: UIViewController?

    init(configuration: WKWebViewConfiguration, customUserAgent: String?) {
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = customUserAgent
        super.init(webView: webView)
    }

    func close(completion: (() -> Void)? = nil) {
        guard let viewController, viewController.presentingViewController != nil else {
            completion?()
            return
        }
        viewController.dismiss(animated: true, completion: completion)
    }

    override func windowCloseRequested() {
        close()
    }

    override func openExternally(_ url: URL) {
        if webView.backForwardList.currentItem == nil {
            // Popup chỉ dùng để chuyển sang một link ngoài: đóng popup rồi mở trình duyệt.
            close { Presenter.openInAppBrowser(url) }
        } else {
            super.openExternally(url)
        }
    }
}

final class PopupViewController: UIViewController {
    let controller: PopupController
    private var titleObservation: NSKeyValueObservation?

    init(controller: PopupController) {
        self.controller = controller
        super.init(nibName: nil, bundle: nil)
        controller.viewController = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = controller.webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in
                self?.controller.close()
            }
        )
        titleObservation = controller.webView.observe(\.title, options: [.initial, .new]) { [weak self] webView, _ in
            MainActor.assumeIsolated {
                self?.title = webView.title
            }
        }
    }
}
