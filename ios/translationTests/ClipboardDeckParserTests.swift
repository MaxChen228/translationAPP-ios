import XCTest
@testable import translation

final class ClipboardDeckParserTests: XCTestCase {
    private var parser: ClipboardDeckParser!

    override func setUp() {
        super.setUp()
        parser = ClipboardDeckParser()
    }

    func testValidateSuccess() throws {
        let clipboard = """
        ### Translation.DeepResearch v1
        {\n  \"deck_name\": \"Food Safety\",\n  \"generated_at\": \"2024-07-10T12:34:56Z\",\n  \"cards\": [\n    {\n      \"front\": \"edible oil\",\n      \"back\": \"可食用的油\"\n    }\n  ]\n}
        """

        switch parser.validate(clipboard) {
        case .success(let deck):
            XCTAssertEqual(deck.name, "Food Safety")
            XCTAssertEqual(deck.cards.count, 1)
            XCTAssertEqual(deck.cards.first?.front, "edible oil")
        default:
            XCTFail("Expected success state")
        }
    }

    func testValidateNotMatchedWhenMissingHeader() {
        let clipboard = "{\"deck_name\":\"Test\",\"cards\":[]}"
        XCTAssertEqual(parser.validate(clipboard), .notMatched)
    }

    func testValidateFailureWhenJSONBroken() {
        let clipboard = """
        ### Translation.DeepResearch v1
        { invalid json }
        """

        switch parser.validate(clipboard) {
        case .failure(let message):
            XCTAssertFalse(message.isEmpty)
        default:
            XCTFail("Expected failure state")
        }
    }

    func testValidateSuccessWithCodeFence() {
        let clipboard = """
        ```json
        ### Translation.DeepResearch v1
        {\n  \"deck_name\": \"Chemistry\",\n  \"cards\": [\n    {\n      \"front\": \"catalyst\",\n      \"back\": \"降低反應活化能的物質\"\n    }\n  ]\n}
        ```
        """

        if case .success(let deck) = parser.validate(clipboard) {
            XCTAssertEqual(deck.cards.count, 1)
            XCTAssertEqual(deck.name, "Chemistry")
        } else {
            XCTFail("Expected success state for fenced clipboard")
        }
    }
}
