import SwiftUI

/// Danh sách tài khoản (mở từ tab ảnh đại diện), giống màn hình chuyển trang cá nhân của app Facebook.
struct AccountSwitcherView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.accounts.accounts) { account in
                        AccountSwitcherRow(account: account, isCurrent: account.id == model.selectedAccountID)
                    }
                } footer: {
                    Text("Nhấn giữ một tài khoản để tải lại, chỉnh sửa hoặc đăng xuất.")
                }

                Section {
                    Button {
                        model.addAccount(kind: .facebook)
                        dismiss()
                    } label: {
                        Label("Thêm tài khoản Facebook", systemImage: "plus.circle.fill")
                    }
                    Button {
                        model.addAccount(kind: .messenger)
                        dismiss()
                    } label: {
                        Label("Thêm tài khoản Messenger", systemImage: "plus.circle.fill")
                    }
                }

                Section {
                    Button {
                        model.openSettings()
                    } label: {
                        Label("Cài đặt", systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle("Tài khoản")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct AccountSwitcherRow: View {
    let account: Account
    let isCurrent: Bool

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingSignOut = false

    var body: some View {
        let state = model.web.state(for: account.id)

        Button {
            model.select(account.id)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                AccountAvatar(account: account, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.body.weight(isCurrent ? .semibold : .regular))
                        .foregroundStyle(Color.primary)
                    Text(subtitle(for: state))
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                Spacer(minLength: 0)
                if state.unreadCount > 0 {
                    UnreadBadge(count: state.unreadCount)
                }
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.facebookBlue)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            AccountActionButtons(account: account, model: model, onNavigate: { dismiss() }) {
                isConfirmingSignOut = true
            }
        }
        .signOutConfirmation(for: account, isPresented: $isConfirmingSignOut, model: model)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func subtitle(for state: PageState) -> String {
        let status: String
        switch state.isLoggedIn {
        case .some(true): status = "Đã đăng nhập"
        case .some(false): status = "Chưa đăng nhập"
        case .none: status = "Chưa mở"
        }
        return "\(account.kind.displayName) · \(status)"
    }
}

/// Các thao tác trên một tài khoản (menu nhấn giữ).
struct AccountActionButtons: View {
    let account: Account
    let model: AppModel
    var onNavigate: () -> Void = {}
    let onSignOut: () -> Void

    var body: some View {
        Button {
            model.goHome(account)
            onNavigate()
        } label: {
            Label("Về trang chủ", systemImage: "house")
        }
        Button {
            model.reload(account)
            onNavigate()
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

extension View {
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
