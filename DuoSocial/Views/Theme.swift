import SwiftUI

enum Theme {
    static let facebookBlue = Color(red: 24 / 255, green: 119 / 255, blue: 242 / 255)
    static let messengerPurple = Color(red: 160 / 255, green: 51 / 255, blue: 255 / 255)
    static let unreadRed = Color(red: 228 / 255, green: 30 / 255, blue: 63 / 255)

    static let messengerGradient = LinearGradient(
        colors: [
            Color(red: 0 / 255, green: 153 / 255, blue: 255 / 255),
            Color(red: 160 / 255, green: 51 / 255, blue: 255 / 255),
            Color(red: 255 / 255, green: 82 / 255, blue: 128 / 255),
        ],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )

    static let brandGradient = LinearGradient(
        colors: [facebookBlue, messengerPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension AccountKind {
    var tint: Color {
        switch self {
        case .facebook: Theme.facebookBlue
        case .messenger: Theme.messengerPurple
        }
    }
}

extension AccountColor {
    var color: Color {
        switch self {
        case .blue: Color(red: 24 / 255, green: 119 / 255, blue: 242 / 255)
        case .teal: Color(red: 13 / 255, green: 148 / 255, blue: 136 / 255)
        case .green: Color(red: 49 / 255, green: 162 / 255, blue: 76 / 255)
        case .orange: Color(red: 245 / 255, green: 124 / 255, blue: 0 / 255)
        case .red: Color(red: 228 / 255, green: 30 / 255, blue: 63 / 255)
        case .pink: Color(red: 225 / 255, green: 48 / 255, blue: 108 / 255)
        case .purple: Color(red: 138 / 255, green: 63 / 255, blue: 252 / 255)
        case .indigo: Color(red: 88 / 255, green: 86 / 255, blue: 214 / 255)
        }
    }

    var title: String {
        switch self {
        case .blue: "Xanh dương"
        case .teal: "Xanh ngọc"
        case .green: "Xanh lá"
        case .orange: "Cam"
        case .red: "Đỏ"
        case .pink: "Hồng"
        case .purple: "Tím"
        case .indigo: "Chàm"
        }
    }
}
