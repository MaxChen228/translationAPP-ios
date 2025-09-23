import Foundation

// Simulate AppConfig behavior
enum TestAppConfig {
    static var backendURL: URL? {
        // Prefer runtime environment
        if let s = ProcessInfo.processInfo.environment["BACKEND_URL"],
           let u = URL(string: s), !s.isEmpty { return u }
        
        // Hardcoded fallback
        return URL(string: "https://translation-l9qi.onrender.com")
    }
}

// Test
print("Backend URL: \(TestAppConfig.backendURL?.absoluteString ?? "nil")")
print("Is backend configured: \(TestAppConfig.backendURL != nil)")
