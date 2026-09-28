import SwiftUI

/// Thanh trên cùng: tài khoản đang mở (chạm để xem tùy chọn / chuyển tài khoản) và ảnh đại diện
/// các tài khoản khác để chuyển nhanh — giống nút chuyển trang cá nhân của app Facebook.
struct AccountHeader: View {
    @Environment(AppModel.self) private var model

    /// Nhiều hơn số này thì hàng ảnh đại diện được cuộn ngang.
    private let maxInlineAvatars = 4

    var body: some View {
        let others = model.accounts.accounts.filter { $0.id != model.selectedAccountID }

        HStack(spacing: 8) {
            if let current = model.selectedAccount {
                CurrentAccountMenu(account: current)
                    .layoutPriority(1)
            }
            Spacer(minLength: 4)
            if others.count <= maxInlineAvatars {
                quickSwitchRow(others)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    quickSwitchRow(others)
                }
                .frame(maxWidth: 190)
            }
            Button {
                model.openSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color(.secondarySystemFill)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cài đặt và quản lý tài khoản")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func quickSwitchRow(_ accounts: [Account]) -> some View {
        HStack(spacing: 12) {
            ForEach(accounts) { account in
                QuickSwitchAvatar(account: account)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}

private struct CurrentAccountMenu: View {
    let account: Account

    @Environment(AppModel.self) private var model
    @State private var isConfirmingSignOut = false

    var body: some View {
        let unread = model.web.state(for: account.id).unreadCount

        Menu {
            Section(account.name) {
                AccountActionButtons(account: account, model: model) {
                    isConfirmingSignOut = true
                }
            }
            Section("Chuyển tài khoản") {
                ForEach(model.accounts.accounts) { other in
                    Button {
                        model.select(other.id)
                    } label: {
                        Label(
                            menuTitle(for: other),
                            systemImage: other.id == account.id ? "checkmark.circle.fill" : "person.crop.circle"
                        )
                    }
                }
            }
            Button {
                model.openSettings()
            } label: {
                Label("Quản lý tài khoản", systemImage: "gearshape")
            }
        } label: {
            HStack(spacing: 8) {
                AccountAvatar(account: account, size: 32)
                    .overlay(alignment: .topTrailing) {
                        if unread > 0 {
                            UnreadBadge(count: unread)
                                .offset(x: 9, y: -6)
                        }
                    }
                VStack(alignment: .leading, spacing: 0) {
                    Text(account.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text(account.kind.displayName)
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .signOutConfirmation(for: account, isPresented: $isConfirmingSignOut, model: model)
        .accessibilityLabel("Tài khoản đang mở: \(account.name). Chạm để chuyển tài khoản hoặc xem tùy chọn")
    }

    private func menuTitle(for other: Account) -> String {
        let unread = model.web.state(for: other.id).unreadCount
        return unread > 0 ? "\(other.name) (\(unread))" : other.name
    }
}

private struct QuickSwitchAvatar: View {
    let account: Account

    @Environment(AppModel.self) private var model
    @State private var isConfirmingSignOut = false

    var body: some View {
        let unread = model.web.state(for: account.id).unreadCount
        let spokenLabel: String = unread > 0
            ? "Chuyển sang \(account.name), \(unread) chưa đọc"
            : "Chuyển sang \(account.name)"

        Button {
            model.select(account.id)
        } label: {
            AccountAvatar(account: account, size: 30)
                .overlay(alignment: .topTrailing) {
                    if unread > 0 {
                        UnreadBadge(count: unread)
                            .offset(x: 9, y: -6)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            AccountActionButtons(account: account, model: model) {
                isConfirmingSignOut = true
            }
        }
        .signOutConfirmation(for: account, isPresented: $isConfirmingSignOut, model: model)
        .accessibilityLabel(spokenLabel)
    }
}

/// Các thao tác trên một tài khoản, dùng chung cho menu tài khoản đang mở và menu nhấn giữ.
private struct AccountActionButtons: View {
    let account: Account
    let model: AppModel
    let onSignOut: () -> Void

    var body: some View {
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
        Button(role: .destructive, action: onSignOut) {
            Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
        }
    }
}

private extension View {
    func signOutConfirmation(for account: Account, isPresented: Binding<Bool>, model: AppModel) -> some View {
        confirmationDialog("Đăng xuất \(account.name)?", isPresented: isPresented, titleVisibility: .visible) {
            Button("Đăng xuất", role: .destructive) {
                Task { await model.signOut(account) }
            }
        } message: {
            Text("Cookie và dữ liệu duyệt web của phiên này sẽ bị xóa khỏi thiết bị.")
        }
    }
}
