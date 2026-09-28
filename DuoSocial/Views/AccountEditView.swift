import SwiftUI

struct AccountEditView: View {
    let accountID: UUID
    @Environment(AppModel.self) private var model

    var body: some View {
        if let account = model.accounts.account(with: accountID) {
            AccountEditForm(original: account)
        } else {
            ContentUnavailableView("Không tìm thấy tài khoản", systemImage: "person.crop.circle.badge.questionmark")
        }
    }
}

private struct AccountEditForm: View {
    let original: Account

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Account
    @State private var isConfirmingDelete = false
    @State private var isConfirmingSignOut = false

    init(original: Account) {
        self.original = original
        _draft = State(initialValue: original)
    }

    var body: some View {
        let state = model.web.state(for: original.id)
        let sharedWith = model.accounts.accountsSharingSession(with: original)

        Form {
            Section("Tên hiển thị") {
                HStack(spacing: 12) {
                    AccountAvatar(account: draft, size: 44)
                    TextField("Tên tài khoản", text: $draft.name)
                        .textInputAutocapitalization(.words)
                }
                .padding(.vertical, 4)
            }

            Section("Màu") {
                AccountColorPicker(selection: $draft.color)
            }

            Section {
                Picker("Giao diện", selection: $draft.webMode) {
                    ForEach(WebMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            } header: {
                Text("Giao diện web")
            } footer: {
                Text(draft.webMode.detail)
            }

            Section {
                TextField(draft.kind.defaultStartURL.absoluteString, text: startURLBinding)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Trang khởi động")
            } footer: {
                if isStartURLValid {
                    Text("Để trống để dùng trang mặc định. Ví dụ: facebook.com/messages hoặc m.facebook.com/groups")
                } else {
                    Text("Địa chỉ không hợp lệ.")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Picker("Phiên đăng nhập", selection: sharingBinding) {
                    Text("Riêng biệt").tag(UUID?.none)
                    ForEach(sharingCandidates) { other in
                        Text("Dùng chung với \(other.name)").tag(UUID?.some(other.id))
                    }
                }
            } header: {
                Text("Phiên đăng nhập")
            } footer: {
                Text("\"Riêng biệt\" để đăng nhập một tài khoản khác. \"Dùng chung\" để tài khoản này dùng luôn đăng nhập của tài khoản kia (vd. Messenger 1 dùng chung với Facebook 1). Phiên cũ không còn ai dùng sẽ bị xóa khi lưu.")
            }

            Section {
                LabeledContent("Trạng thái", value: statusText(state))
                if let userID = state.userID {
                    LabeledContent("ID người dùng", value: userID)
                        .textSelection(.enabled)
                }
                Button(role: .destructive) {
                    isConfirmingSignOut = true
                } label: {
                    Label("Đăng xuất & xóa dữ liệu phiên", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } header: {
                Text("Đăng nhập")
            } footer: {
                if !sharedWith.isEmpty {
                    Text("Phiên này đang dùng chung với \(sharedWith.map(\.name).joined(separator: ", ")). Đăng xuất sẽ đăng xuất tất cả.")
                }
            }

            Section {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("Xóa tài khoản khỏi ứng dụng", systemImage: "trash")
                }
            }
        }
        .navigationTitle(original.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Lưu") { save() }
                    .disabled(!hasChanges || !isValid)
            }
        }
        .confirmationDialog("Đăng xuất \(original.name)?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button("Đăng xuất", role: .destructive) {
                Task { await model.signOut(original) }
            }
        } message: {
            Text("Cookie và dữ liệu duyệt web của phiên này sẽ bị xóa khỏi thiết bị.")
        }
        .confirmationDialog("Xóa \(original.name)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Xóa tài khoản", role: .destructive) {
                model.delete(original)
                dismiss()
            }
        } message: {
            if sharedWith.isEmpty {
                Text("Tài khoản và toàn bộ dữ liệu đăng nhập của nó sẽ bị xóa khỏi thiết bị.")
            } else {
                Text("Tài khoản sẽ bị gỡ khỏi ứng dụng. Phiên đăng nhập vẫn được giữ cho các tài khoản dùng chung.")
            }
        }
    }

    // MARK: - Helpers

    private var hasChanges: Bool { draft != original }

    private var isStartURLValid: Bool {
        guard let custom = draft.customStartURL, !custom.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
        return Account.normalizedURL(from: custom) != nil
    }

    private var isValid: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isStartURLValid
    }

    private var sharingCandidates: [Account] {
        model.accounts.accounts.filter { $0.id != original.id }
    }

    private var startURLBinding: Binding<String> {
        Binding(
            get: { draft.customStartURL ?? "" },
            set: { draft.customStartURL = $0.isEmpty ? nil : $0 }
        )
    }

    /// `nil` = phiên riêng; ngược lại là ID tài khoản mà bản nháp đang dùng chung phiên.
    private var sharingBinding: Binding<UUID?> {
        Binding(
            get: {
                model.accounts.accounts.first { $0.id != draft.id && $0.sessionID == draft.sessionID }?.id
            },
            set: { newValue in
                if let otherID = newValue, let other = model.accounts.account(with: otherID) {
                    draft.sessionID = other.sessionID
                } else {
                    // Quay về phiên riêng: giữ phiên gốc nếu nó vốn là riêng, nếu không thì tạo phiên mới.
                    let originalWasShared = model.accounts.accounts.contains {
                        $0.id != original.id && $0.sessionID == original.sessionID
                    }
                    draft.sessionID = originalWasShared ? UUID() : original.sessionID
                }
            }
        )
    }

    private func statusText(_ state: PageState) -> String {
        switch state.isLoggedIn {
        case .some(true): "Đã đăng nhập"
        case .some(false): "Chưa đăng nhập"
        case .none: "Chưa mở"
        }
    }

    private func save() {
        var account = draft
        account.name = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let custom = account.customStartURL?.trimmingCharacters(in: .whitespacesAndNewlines) {
            account.customStartURL = custom.isEmpty ? nil : custom
        }
        model.update(account)
        dismiss()
    }
}

private struct AccountColorPicker: View {
    @Binding var selection: AccountColor

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AccountColor.allCases) { option in
                Button {
                    selection = option
                } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 28, height: 28)
                        .overlay {
                            if option == selection {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(option == selection ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
