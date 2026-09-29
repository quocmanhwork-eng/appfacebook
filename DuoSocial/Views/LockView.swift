import SwiftUI

struct LockView: View {
    let lock: AppLock

    var body: some View {
        ZStack {
            Theme.brandGradient
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 52, weight: .semibold))
                Text("DuoSocial đang khóa")
                    .font(.title2.bold())
                Text("Xác thực để xem các tài khoản Facebook và Messenger của bạn.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .opacity(0.9)

                if let message = lock.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .opacity(0.85)
                }

                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label("Mở khóa bằng \(AppLock.biometryName)", systemImage: AppLock.biometrySymbol)
                        .font(.headline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(Theme.facebookBlue)
                .disabled(lock.isAuthenticating)
                .padding(.top, 8)
            }
            .foregroundStyle(.white)
            .padding(32)
        }
    }
}
