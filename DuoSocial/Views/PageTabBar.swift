import SwiftUI

/// Thanh tab dưới cùng của tài khoản Facebook: Trang chủ · Video · Bạn bè · Marketplace · Thông báo · Menu.
struct PageTabBar: View {
    let account: Account
    let activeTab: PageTab?

    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PageTab.tabs(for: account.kind)) { tab in
                let isActive = tab == activeTab
                Button {
                    model.openTab(tab, in: account)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: isActive ? tab.selectedSymbol : tab.symbol)
                            .font(.system(size: 20, weight: isActive ? .semibold : .regular))
                            .frame(height: 24)
                        Text(tab.title)
                            .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(isActive ? Theme.facebookBlue : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 7)
                    .padding(.bottom, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) {
                    // Vạch xanh phía trên tab đang mở, giống app Facebook.
                    Capsule()
                        .fill(isActive ? Theme.facebookBlue : Color.clear)
                        .frame(width: 36, height: 3)
                }
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
