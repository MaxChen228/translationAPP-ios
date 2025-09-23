import Foundation
import Testing
@testable import translation

@MainActor
@Suite("BankFoldersStore")
struct BankFoldersStoreTests {
    private let defaultsKey = "bank.folders"

    private func withIsolatedDefaults<T>(_ body: () throws -> T) rethrows -> T {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: defaultsKey)
        defaults.removeObject(forKey: defaultsKey)
        defer {
            if let data = previous as? Data {
                defaults.set(data, forKey: defaultsKey)
            } else if let previous {
                defaults.set(previous, forKey: defaultsKey)
            } else {
                defaults.removeObject(forKey: defaultsKey)
            }
        }
        return try body()
    }

    @Test("ensureCourseFolder 會重用同一資料夾並更新名稱")
    func ensureCourseFolderReuses() throws {
        try withIsolatedDefaults {
            let store = BankFoldersStore()
            let first = store.ensureCourseFolder(courseId: "course-1", title: "Course A")
            #expect(store.folders.count == 1)
            #expect(store.folders.first?.name == "Course A")

            let second = store.ensureCourseFolder(courseId: "course-1", title: "Course B")
            #expect(second.id == first.id)
            #expect(store.folders.count == 1)
            #expect(store.folders.first?.name == "Course B")
        }
    }

    @Test("recordCourseBook 會更新對應書名並清理舊記錄")
    func recordCourseBookTracksLatestName() throws {
        try withIsolatedDefaults {
            let store = BankFoldersStore()
            _ = store.ensureCourseFolder(courseId: "course-2", title: "Course")

            store.recordCourseBook(courseId: "course-2", courseBookId: "book-1", bookName: "Lesson 1")
            #expect(store.folders.first?.bookNames == ["Lesson 1"])
            #expect(store.existingCourseBookName(courseId: "course-2", courseBookId: "book-1") == "Lesson 1")

            store.recordCourseBook(courseId: "course-2", courseBookId: "book-1", bookName: "Lesson 1 (2)")
            #expect(store.folders.first?.bookNames == ["Lesson 1 (2)"])
            #expect(store.existingCourseBookName(courseId: "course-2", courseBookId: "book-1") == "Lesson 1 (2)")
        }
    }

    @Test("remove 會同時清除 course book mapping")
    func removeClearsCourseMapping() throws {
        try withIsolatedDefaults {
            let store = BankFoldersStore()
            _ = store.ensureCourseFolder(courseId: "course-3", title: "Course")
            store.recordCourseBook(courseId: "course-3", courseBookId: "book-2", bookName: "Lesson 2")

            store.remove(bookName: "Lesson 2")

            #expect(store.folders.first?.bookNames.isEmpty == true)
            #expect(store.existingCourseBookName(courseId: "course-3", courseBookId: "book-2") == nil)
        }
    }
}
