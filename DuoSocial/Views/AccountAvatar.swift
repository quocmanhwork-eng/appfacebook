import SwiftUI

/// Ảnh đại diện dạng chữ cái đầu + huy hiệu nhỏ cho biết đây là Facebook hay Messenger.
struct AccountAvatar: View {
    let account: Account
    var size: CGFloat = 32

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [account.color.color.opacity(0.8), account.color.color],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Text(account.initials)
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(size * 0.1)
            }
            .overlay(alignment: .bottomTrailing) {
                KindBadge(kind: account.kind, size: size * 0.46)
                    .offset(x: size * 0.1, y: size * 0.08)
            }
            .accessibilityHidden(true)
    }
}

struct KindBadge: View {
    let kind: AccountKind
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemBackground))
            Circle()
                .fill(kind == .messenger ? AnyShapeStyle(Theme.messengerGradient) : AnyShapeStyle(Theme.facebookBlue))
                .padding(size * 0.1)
            if kind == .facebook {
                Text("f")
                    .font(.system(size: size * 0.62, weight: .heavy, design: .rounded))
                    .offset(y: size * 0.04)
            } else {
                Image(systemName: "bolt.fill")
                    .font(.system(size: size * 0.4, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .frame(width: size, height: size)
    }
}

struct UnreadBadge: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 10, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .frame(minWidth: 17, minHeight: 17)
            .background(Capsule().fill(Theme.unreadRed))
            .overlay(Capsule().stroke(Color(.systemBackground), lineWidth: 1.5))
    }
}
