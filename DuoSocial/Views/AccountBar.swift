import SwiftUI

/// Thanh dưới cùng kiểu Facebook để chuyển nhanh giữa các tài khoản.
struct AccountBar: View {
    @Environment(AppModel.self) private var model

    /// Từ 5 tài khoản trở xuống thì chia đều chiều rộng; nhiều hơn thì cho cuộn ngang.
    private let maxEvenlySpacedTabs = 5

    var body: some View {
        let accounts = model.accounts.accounts

        HStack(spacing: 0) {
            if accounts.count <= maxEvenlySpacedTabs {
                ForEach(accounts) { account in
                    AccountTabButton(account: account)
                        .frame(maxWidth: .infinity)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(accounts) { account in
                            AccountTabButton(account: account)
                                .frame(width: 72)
                        }
                    }
                }
            }
            MenuTabButton()
                .frame(width: 60)
        }
        .padding(.top, 7)
        .padding(.bottom, 3)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

struct AccountTabButton: View {
    let account: Account

    @Environment(AppModel.self) private var model
    @State private var isConfirmingSignOut = false

    var body: some View {
        let isSelected = model.selectedAccountID == account.id
        let state = model.web.state(for: account.id)

        Button {
            model.tapAccount(account.id)
        } label: {
            VStack(spacing: 3) {
                AccountAvatar(account: account, size: 32)
                    .opacity(isSelected ? 1 : 0.75)
                    .overlay(alignment: .topTrailing) {
                        if state.unreadCount > 0 {
                            UnreadBadge(count: state.unreadCount)
                                .offset(x: 10, y: -6)
                        }
                    }
                Text(account.name)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? account.color.color : .secondary)
            }
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            // Vạch màu phía trên tab đang chọn, giống thanh điều hướng của Facebook.
            Capsule()
                .fill(isSelected ? account.color.color : .clear)
                .frame(width: 28, height: 3)
                .offset(y: -7)
        }
        .contextMenu {
            Button {
                model.goHome(account)
            } label: {
                Label("Về trang chủ", systemImage: "house")
            }
            Button {
                model.reload(account)
            } label: {
                Label("Tải lại", systemImage: "arrow.clockwise")
            }
            Button {
                model.openSettings(editing: account.id)
            } label: {
                Label("Chỉnh sửa tài khoản", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                isConfirmingSignOut = true
            } label: {
                Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
        .confirmationDialog("Đăng xuất \(account.name)?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button("Đăng xuất", role: .destructive) {
                Task { await model.signOut(account) }
            }
        } message: {
            Text("Cookie và dữ liệu duyệt web của phiên này sẽ bị xóa khỏi thiết bị.")
        }
        .accessibilityLabel(spokenLabel(unread: state.unreadCount))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func spokenLabel(unread: Int) -> String {
        let base = "\(account.name), \(account.kind.displayName)"
        return unread > 0 ? "\(base), \(unread) chưa đọc" : base
    }
}

struct MenuTabButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.openSettings()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 32, height: 32)
                Text("Menu")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cài đặt và quản lý tài khoản")
    }
}
