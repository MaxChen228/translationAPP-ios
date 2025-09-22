import SwiftUI

enum BankItemDifficulty {
    static func romanNumeral(for value: Int) -> String {
        switch value {
        case 1: return "Ⅰ"
        case 2: return "Ⅱ"
        case 3: return "Ⅲ"
        case 4: return "Ⅳ"
        case 5: return "Ⅴ"
        default: return "Ⅰ"
        }
    }

    static func tint(for value: Int) -> Color {
        switch value {
        case 1: return DS.Palette.success
        case 2: return DS.Brand.scheme.cornhusk
        case 3: return DS.Brand.scheme.peachQuartz
        case 4: return DS.Palette.warning
        case 5: return DS.Palette.danger
        default: return DS.Palette.neutral
        }
    }
}
