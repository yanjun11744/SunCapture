//
//  SunSortOrder:.swift
//  SunCapture
//
//  Created by Yanjun Sun on 2026/3/16.
//

import Foundation

/// 文件排序方式
public enum SunSortOrder: String, Sendable, CaseIterable {
    case nameAscending
    case nameDescending
    case dateAscending
    case dateDescending
    case sizeAscending
    case sizeDescending
}

public extension SunSortOrder {

    var fieldKey: LocalizedStringResource {
    switch self {
    case .nameAscending, .nameDescending:
        "sort.field.name"
    case .dateAscending, .dateDescending:
        "sort.field.date"
    case .sizeAscending, .sizeDescending:
        "sort.field.size"
    }
}

    var directionShortKey: LocalizedStringResource {
        switch self {
        case .nameAscending:  "sort.short.az"
        case .nameDescending: "sort.short.za"
        case .dateDescending: "sort.short.newest"
        case .dateAscending:  "sort.short.oldest"
        case .sizeDescending: "sort.short.largest"
        case .sizeAscending:  "sort.short.smallest"
        }
    }

    /// 完整标签，适合菜单，如 "日期：最新优先"
    var label: String {
        String(
            localized: "sort.label %@ %@",
            String(localized: fieldKey),
            String(localized: directionShortKey)
        )
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

