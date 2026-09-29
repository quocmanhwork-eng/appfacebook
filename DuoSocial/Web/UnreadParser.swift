import Foundation

/// Đọc số thông báo/tin nhắn chưa đọc từ tiêu đề trang, vd. "(3) Facebook" → 3.
enum UnreadParser {
    private static let countPattern = try! NSRegularExpression(pattern: #"\((\d{1,4})\+?\)"#)

    /// - Returns: số chưa đọc; `0` nếu tiêu đề là trang bình thường không có số;
    ///   `nil` nếu không xác định được (tiêu đề rỗng hoặc đang nhấp nháy "X đã nhắn tin cho bạn").
    static func unreadCount(fromTitle title: String?) -> Int? {
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return nil
        }

        let range = NSRange(title.startIndex..., in: title)
        if let match = countPattern.firstMatch(in: title, range: range),
           let numberRange = Range(match.range(at: 1), in: title),
           let value = Int(title[numberRange]) {
            return value
        }

        let lowercased = title.lowercased()
        if lowercased.contains("facebook") || lowercased.contains("messenger") {
            return 0
        }
        return nil
    }
}
