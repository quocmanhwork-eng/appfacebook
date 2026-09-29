import SafariServices
import UIKit

/// Hiển thị các màn hình UIKit (trình duyệt, popup, hộp thoại, chia sẻ) lên trên cùng của app.
@MainActor
enum Presenter {
    static var activeWindowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    /// View controller trên cùng của cửa sổ chính (bỏ qua cửa sổ màn hình khóa).
    static func topViewController() -> UIViewController? {
        guard let scene = activeWindowScene else { return nil }
        let appWindows = scene.windows.filter { $0.windowLevel == .normal && !$0.isHidden }
        let window = appWindows.first(where: \.isKeyWindow) ?? appWindows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    static func openInAppBrowser(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let top = topViewController()
        else {
            UIApplication.shared.open(url)
            return
        }
        let safari = SFSafariViewController(url: url)
        safari.dismissButtonStyle = .close
        safari.preferredControlTintColor = UIColor(red: 24 / 255, green: 119 / 255, blue: 242 / 255, alpha: 1)
        top.present(safari, animated: true)
    }

    @discardableResult
    static func presentPopup(_ controller: PopupController) -> Bool {
        guard let top = topViewController() else { return false }
        let navigation = UINavigationController(rootViewController: PopupViewController(controller: controller))
        navigation.modalPresentationStyle = .pageSheet
        top.present(navigation, animated: true)
        return true
    }

    static func share(fileURL: URL) {
        guard let top = topViewController() else { return }
        let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        top.present(activity, animated: true)
    }

    static func showAlert(title: String?, message: String, completion: (() -> Void)? = nil) {
        guard let top = topViewController() else {
            completion?()
            return
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completion?() })
        top.present(alert, animated: true)
    }

    static func showConfirm(title: String?, message: String, completion: @escaping (Bool) -> Void) {
        guard let top = topViewController() else {
            completion(false)
            return
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in completion(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completion(true) })
        top.present(alert, animated: true)
    }

    static func showPrompt(
        title: String?,
        message: String,
        defaultText: String?,
        completion: @escaping (String?) -> Void
    ) {
        guard let top = topViewController() else {
            completion(nil)
            return
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in completion(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in
            completion(alert?.textFields?.first?.text)
        })
        top.present(alert, animated: true)
    }
}
