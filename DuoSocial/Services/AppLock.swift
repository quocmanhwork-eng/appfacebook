import LocalAuthentication
import Observation
import SwiftUI
import UIKit

/// Khóa ứng dụng bằng Face ID / Touch ID / mật mã.
///
/// Khi khóa, một cửa sổ riêng được đặt lên trên mọi thứ (kể cả popup, trình duyệt trong app)
/// để nội dung tin nhắn không lộ ra, kể cả trong màn hình đa nhiệm.
@Observable
@MainActor
final class AppLock {
    private(set) var isLocked = false
    private(set) var isAuthenticating = false
    private(set) var errorMessage: String?

    @ObservationIgnored private var coverWindow: UIWindow?

    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    static var biometryName: String {
        switch currentBiometryType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        default: "mật mã"
        }
    }

    static var biometrySymbol: String {
        switch currentBiometryType {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        default: "lock.open.fill"
        }
    }

    private static var currentBiometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    func lock() {
        isLocked = true
        errorMessage = nil
        showCoverWindow()
    }

    /// Tắt tính năng khóa: mở khóa ngay nếu đang khóa.
    func disable() {
        if isLocked {
            finishUnlock()
        }
    }

    func sceneDidBecomeActive() {
        guard isLocked else { return }
        showCoverWindow()
        Task { await unlock() }
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }

        let context = LAContext()
        context.localizedCancelTitle = "Hủy"
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            // Thiết bị chưa đặt mật mã thì không thể khóa — mở luôn để người dùng không bị kẹt.
            finishUnlock()
            return
        }

        isAuthenticating = true
        errorMessage = nil
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Mở khóa để xem các tài khoản Facebook và Messenger"
            )
            isAuthenticating = false
            if success {
                finishUnlock()
            }
        } catch {
            isAuthenticating = false
            switch (error as? LAError)?.code {
            case .userCancel, .appCancel, .systemCancel:
                errorMessage = nil
            default:
                errorMessage = error.localizedDescription
            }
        }
    }

    private func finishUnlock() {
        isLocked = false
        errorMessage = nil
        coverWindow?.isHidden = true
        coverWindow = nil
    }

    private func showCoverWindow() {
        guard coverWindow == nil, let scene = Presenter.activeWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.rootViewController = UIHostingController(rootView: LockView(lock: self))
        window.isHidden = false
        coverWindow = window
    }
}
