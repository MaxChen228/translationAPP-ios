import Foundation

// Test Bundle.main key reading
let keys = ["BACKEND_URL", "NSAppTransportSecurity", "UIApplicationSceneManifest"]
for key in keys {
    if let value = Bundle.main.object(forInfoDictionaryKey: key) {
        print("\(key): \(value)")
    } else {
        print("\(key): NOT FOUND")
    }
}

// Test environment variables
if let envBackend = ProcessInfo.processInfo.environment["BACKEND_URL"] {
    print("ENV BACKEND_URL: \(envBackend)")
} else {
    print("ENV BACKEND_URL: NOT FOUND")
}
