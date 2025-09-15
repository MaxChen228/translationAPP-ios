import Foundation
import CoreText

enum FontLoader {
    // Registers any .ttf/.ttc found in the main bundle (e.g., Songti.ttf/ttc)
    static func registerBundledFonts() {
        let exts = ["ttf", "ttc", "otf"]
        for ext in exts {
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                for url in urls {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                }
            }
        }
    }
}

