import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum DeviceID {
    private static let udKey = "app.device.id"
    private static let kcService = "translation.app"
    private static let kcAccount = "device.id"

    static let current: String = {
        // 1) Keychain first (persisted across reinstalls)
        if let s = Keychain.getString(service: kcService, account: kcAccount), !s.isEmpty {
            return s
        }
        // 2) Migrate from UserDefaults if exists
        let ud = UserDefaults.standard
        if let s = ud.string(forKey: udKey), !s.isEmpty {
            _ = Keychain.setString(s, service: kcService, account: kcAccount)
            return s
        }
        // 3) Otherwise generate using identifierForVendor if available, else random UUID
        #if os(iOS)
        let seed = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        let seed = UUID().uuidString
        #endif
        _ = Keychain.setString(seed, service: kcService, account: kcAccount)
        ud.set(seed, forKey: udKey) // optional: for debugging/visibility
        return seed
    }()
}
