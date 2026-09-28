import Combine
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var isKeyboardVisible = false

    var body: some View {
        @Bindable var model = model

        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if model.accounts.accounts.isEmpty {
                EmptyAccountsView()
            } else {
                // Mọi web view đã mở đều được giữ trong cây giao diện (chỉ ẩn đi) để chuyển tài khoản tức thì
                // và các tài khoản không xem vẫn cập nhật số tin chưa đọc.
                ForEach(model.accounts.accounts) { account in
                    if let session = model.web.session(for: account.id) {
                        let isSelected = account.id == model.selectedAccountID
                        AccountPage(account: account, session: session, state: model.web.state(for: account.id))
                            .opacity(isSelected ? 1 : 0)
                            .allowsHitTesting(isSelected)
                            .accessibilityHidden(!isSelected)
                            .zIndex(isSelected ? 1 : 0)
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !model.accounts.accounts.isEmpty {
                AccountHeader()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Như app Facebook: ẩn thanh tab khi đang gõ để nhường chỗ cho bàn phím.
            if let account = model.selectedAccount, !PageTab.tabs(for: account.kind).isEmpty, !isKeyboardVisible {
                PageTabBar(account: account, activeTab: model.web.state(for: account.id).activeTab)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .sheet(isPresented: $model.isShowingSettings) {
            SettingsView()
        }
        .overlay {
            if model.lock.isLocked {
                LockView(lock: model.lock)
            }
        }
        .task {
            model.bootstrap()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            model.scenePhaseChanged(phase)
        }
    }
}

struct EmptyAccountsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label("Chưa có tài khoản nào", systemImage: "person.2.slash")
        } description: {
            Text("Thêm tài khoản Facebook hoặc Messenger để bắt đầu. Mỗi tài khoản được lưu đăng nhập riêng biệt.")
        } actions: {
            Button("Thêm Facebook") {
                model.addAccount(kind: .facebook)
            }
            .buttonStyle(.borderedProminent)

            Button("Thêm Messenger") {
                model.addAccount(kind: .messenger)
            }
            .buttonStyle(.bordered)

            Button("Cài đặt") {
                model.openSettings()
            }
        }
    }
}
