import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var activeAlert: SettingsAlert?

    var body: some View {
        @Bindable var model = model
        @Bindable var settings = model.settings

        NavigationStack(path: $model.settingsPath) {
            Form {
                accountSection(kind: .facebook)
                accountSection(kind: .messenger)

                Section {
                    Button {
                        model.addAccount(kind: .facebook)
                    } label: {
                        Label("Thêm tài khoản Facebook", systemImage: "plus.circle.fill")
                    }
                    Button {
                        model.addAccount(kind: .messenger)
                    } label: {
                        Label("Thêm tài khoản Messenger", systemImage: "plus.circle.fill")
                    }
                }

                Section {
                    Toggle(isOn: lockBinding) {
                        Label("Khóa bằng \(AppLock.biometryName)", systemImage: "lock.fill")
                    }
                    Toggle(isOn: notificationsBinding) {
                        Label("Thông báo tin mới", systemImage: "bell.badge.fill")
                    }
                    Toggle(isOn: $settings.preloadAllAccounts) {
                        Label("Mở sẵn tất cả tài khoản", systemImage: "bolt.horizontal.fill")
                    }
                } header: {
                    Text("Bảo mật & thông báo")
                } footer: {
                    Text("Thông báo dựa trên số chưa đọc hiện trên tiêu đề trang và chỉ hoạt động khi app đang mở hoặc vừa chuyển xuống nền — iOS không cho trang web chạy nền lâu. \"Mở sẵn\" giúp cả 4 tài khoản cùng cập nhật số chưa đọc nhưng tốn thêm bộ nhớ.")
                }

                Section {
                    TipRow(symbol: "hand.tap", text: "Chạm lại tài khoản đang mở để cuộn lên đầu trang, chạm lần nữa để về trang chủ.")
                    TipRow(symbol: "hand.point.up.left", text: "Nhấn giữ biểu tượng tài khoản để tải lại, chỉnh sửa hoặc đăng xuất.")
                    TipRow(symbol: "arrow.left", text: "Vuốt từ mép trái màn hình để quay lại trang trước.")
                    TipRow(symbol: "link", text: "Muốn Messenger dùng luôn đăng nhập của Facebook? Mở tài khoản Messenger và chọn \"Dùng chung phiên\".")
                } header: {
                    Text("Mẹo")
                }

                Section {
                    LabeledContent("Phiên bản", value: Self.appVersion)
                    Text("Mỗi tài khoản dùng một kho dữ liệu web riêng (cookie, bộ nhớ đệm, localStorage), nên có thể đăng nhập nhiều tài khoản Facebook và Messenger cùng lúc mà không bị đăng xuất lẫn nhau.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("DuoSocial không phải ứng dụng chính thức của Meta. Ứng dụng hiển thị trực tiếp trang facebook.com / messenger.com; mật khẩu chỉ được nhập vào trang của Facebook và không được ứng dụng lưu lại.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Giới thiệu")
                }
            }
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { dismiss() }
                }
            }
            .navigationDestination(for: UUID.self) { accountID in
                AccountEditView(accountID: accountID)
            }
            .alert(
                activeAlert?.title ?? "",
                isPresented: Binding(get: { activeAlert != nil }, set: { if !$0 { activeAlert = nil } }),
                presenting: activeAlert
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { alert in
                Text(alert.message)
            }
        }
    }

    @ViewBuilder
    private func accountSection(kind: AccountKind) -> some View {
        let accounts = model.accounts.accounts(of: kind)
        Section {
            if accounts.isEmpty {
                Text("Chưa có tài khoản \(kind.displayName)")
                    .foregroundStyle(.secondary)
            }
            ForEach(accounts) { account in
                NavigationLink(value: account.id) {
                    AccountRow(
                        account: account,
                        state: model.web.state(for: account.id),
                        sharedWith: model.accounts.accountsSharingSession(with: account)
                    )
                }
            }
        } header: {
            Text("Tài khoản \(kind.displayName)")
        }
    }

    private var lockBinding: Binding<Bool> {
        Binding(
            get: { model.settings.lockEnabled },
            set: { newValue in
                if !model.setLockEnabled(newValue) {
                    activeAlert = SettingsAlert(
                        title: "Không thể bật khóa",
                        message: "Hãy đặt mật mã cho thiết bị trong Cài đặt > Face ID & Mật mã trước."
                    )
                }
            }
        )
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { model.settings.notificationsEnabled },
            set: { newValue in
                Task {
                    let succeeded = await model.setNotificationsEnabled(newValue)
                    if newValue && !succeeded {
                        activeAlert = SettingsAlert(
                            title: "Chưa được phép gửi thông báo",
                            message: "Hãy bật thông báo cho DuoSocial trong Cài đặt > Thông báo."
                        )
                    }
                }
            }
        )
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct SettingsAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct AccountRow: View {
    let account: Account
    let state: PageState
    let sharedWith: [Account]

    var body: some View {
        HStack(spacing: 12) {
            AccountAvatar(account: account, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.body.weight(.medium))
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(state.isLoggedIn == true ? Color.green : Color.secondary)
                if !sharedWith.isEmpty {
                    Text("Dùng chung phiên với \(sharedWith.map(\.name).joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if state.unreadCount > 0 {
                UnreadBadge(count: state.unreadCount)
            }
        }
        .padding(.vertical, 2)
    }

    private var statusText: String {
        switch state.isLoggedIn {
        case .some(true): "Đã đăng nhập"
        case .some(false): "Chưa đăng nhập"
        case .none: "Chưa mở"
        }
    }
}

private struct TipRow: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(.footnote)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(Theme.facebookBlue)
        }
    }
}
