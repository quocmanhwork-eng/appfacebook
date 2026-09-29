import SwiftUI

/// Thanh tab dưới cùng giống app Facebook trên iPhone:
/// Facebook: Trang chủ · Video · Bạn bè · Marketplace · Thông báo · [ảnh đại diện]
/// Messenger: Đoạn chat · [ảnh đại diện]
/// Tab ảnh đại diện mở danh sách tài khoản; nhấn giữ để chuyển nhanh.
struct PageTabBar: View {
    let account: Account
    let activeTab: PageTab?

    @Environment(AppModel.self) private var model
    @State private var tapCount = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PageTab.tabs(for: account.kind)) { tab in
                let isActive = tab == activeTab
                Button {
                    tapCount += 1
                    model.openTab(tab, in: account)
                } label: {
                    TabItemLabel(title: tab.title, isActive: isActive) {
                        Image(systemName: isActive ? tab.selectedSymbol : tab.symbol)
                            .font(.system(size: 21, weight: isActive ? .semibold : .regular))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
            AccountTabButton(account: account) {
                tapCount += 1
            }
        }
        .padding(.top, 6)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            Divider()
        }
        .sensoryFeedback(.selection, trigger: tapCount)
    }
}

private struct TabItemLabel<Icon: View>: View {
    let title: String
    let isActive: Bool
    let icon: Icon

    init(title: String, isActive: Bool, @ViewBuilder icon: () -> Icon) {
        self.title = title
        self.isActive = isActive
        self.icon = icon()
    }

    var body: some View {
        VStack(spacing: 3) {
            icon
                .frame(height: 26)
            Text(title)
                .font(.system(size: 10.5, weight: isActive ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(isActive ? Theme.facebookBlue : Color.secondary)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
        .contentShape(Rectangle())
    }
}

/// Tab cuối: ảnh đại diện + tên tài khoản đang mở, huy hiệu đỏ = số chưa đọc của các tài khoản khác.
private struct AccountTabButton: View {
    let account: Account
    let onTap: () -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        let others = model.accounts.accounts.filter { $0.id != account.id }
        let otherUnread = others.reduce(0) { $0 + model.web.state(for: $1.id).unreadCount }
        let spokenLabel: String = otherUnread > 0
            ? "Tài khoản \(account.name). Các tài khoản khác có \(otherUnread) chưa đọc"
            : "Tài khoản \(account.name)"

        Button {
            onTap()
            model.openAccountSwitcher()
        } label: {
            TabItemLabel(title: account.name, isActive: false) {
                AccountAvatar(account: account, size: 26)
                    .overlay(alignment: .topTrailing) {
                        if otherUnread > 0 {
                            UnreadBadge(count: otherUnread)
                                .offset(x: 10, y: -6)
                        }
                    }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            ForEach(model.accounts.accounts) { other in
                Button {
                    model.select(other.id)
                } label: {
                    Label(
                        quickSwitchTitle(for: other),
                        systemImage: other.id == account.id ? "checkmark.circle.fill" : "person.crop.circle"
                    )
                }
            }
            Divider()
            Button {
                model.openAccountSwitcher()
            } label: {
                Label("Quản lý tài khoản", systemImage: "person.2")
            }
            Button {
                model.openSettings()
            } label: {
                Label("Cài đặt", systemImage: "gearshape")
            }
        }
        .accessibilityLabel(spokenLabel)
        .accessibilityHint("Chạm để xem danh sách tài khoản, nhấn giữ để chuyển nhanh")
    }

    private func quickSwitchTitle(for other: Account) -> String {
        let unread = model.web.state(for: other.id).unreadCount
        return unread > 0 ? "\(other.name) (\(unread))" : other.name
    }
}
