import SwiftUI

/// Trang web của một tài khoản kèm thanh tiến trình và thông báo lỗi.
struct AccountPage: View {
    let account: Account
    let session: WebSession
    let state: PageState

    var body: some View {
        WebViewContainer(webView: session.webView)
            .overlay(alignment: .top) {
                LoadingBar(progress: state.progress, isVisible: state.isLoading, tint: account.kind.tint)
            }
            .overlay(alignment: .bottom) {
                if let message = state.loadError {
                    LoadErrorBanner(message: message) {
                        session.reloadPage()
                    }
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: state.loadError)
    }
}

struct LoadingBar: View {
    let progress: Double
    let isVisible: Bool
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(tint)
                .frame(width: proxy.size.width * min(max(progress, 0.05), 1))
        }
        .frame(height: 2.5)
        .opacity(isVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: progress)
        .animation(.easeOut(duration: 0.3), value: isVisible)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct LoadErrorBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Không tải được trang")
                    .font(.subheadline.bold())
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Button("Thử lại", action: retry)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }
}
