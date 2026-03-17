//
//  SunSortOrder:.swift
//  SunCapture
//
//  Created by Yanjun Sun on 2026/3/16.
//

import Foundation

/// 文件排序方式
public enum SunSortOrder: Sendable {
    case nameAscending
    case nameDescending
    case dateAscending
    case dateDescending
    case sizeAscending
    case sizeDescending
}

public extension SunSortOrder {

    /// 短标签，适合按钮/标题，如 "日期 最新"
    var shortLabel: String {
        switch self {
        case .nameAscending:  return "名称 A→Z"
        case .nameDescending: return "名称 Z→A"
        case .dateDescending: return "日期 最新"
        case .dateAscending:  return "日期 最旧"
        case .sizeDescending: return "大小 最大"
        case .sizeAscending:  return "大小 最小"
        }
    }

    /// 完整标签，适合菜单，如 "日期：最新优先"
    var label: String {
        switch self {
        case .nameAscending:  return "名称：A → Z"
        case .nameDescending: return "名称：Z → A"
        case .dateDescending: return "日期：最新优先"
        case .dateAscending:  return "日期：最旧优先"
        case .sizeDescending: return "大小：从大到小"
        case .sizeAscending:  return "大小：从小到大"
        }
    }

    /// 对应的 SF Symbol
    var systemImage: String {
        switch self {
        case .nameAscending, .nameDescending:
            return "textformat.abc"
        case .dateAscending, .dateDescending:
            return "calendar"
        case .sizeAscending, .sizeDescending:
            return "internaldrive"
        }
    }

    /// 是否是升序
    var isAscending: Bool {
        switch self {
        case .nameAscending, .dateAscending, .sizeAscending: return true
        default: return false
        }
    }
}

