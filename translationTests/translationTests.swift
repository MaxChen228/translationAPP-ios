//
//  translationTests.swift
//  translationTests
//
//  Created by 陳亮宇 on 2025/9/14.
//

import Testing
import Foundation
@testable import translation

struct translationTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func decodeDeckResponse() throws {
        let json = """
        {"name":"測試卡集","cards":[
           {"front":"寫感恩日記","frontNote":"","back":"{keep a gratitude diary / maintain a gratitude journal}","backNote":""},
           {"front":"更容易感到快樂","frontNote":null,"back":"{be more likely / have a higher tendency} to {be happy / feel joyful}","backNote":null},
           {"front":"經歷較少憂鬱症狀","back":"{experience fewer depressive symptoms / have fewer symptoms of depression}"},
           {"front":"辭去穩定工作","back":"{quit a stable job / give up a stable position}","backNote":"position 較正式"},
           {"front":"創業","back":"{start a business / start one's own business}"}
        ]}
        """.data(using: .utf8)!

        struct DeckCardDTO: Codable { let front: String; let frontNote: String?; let back: String; let backNote: String? }
        struct DeckMakeResponse: Codable { let name: String; let cards: [DeckCardDTO] }
        let dto = try JSONDecoder().decode(DeckMakeResponse.self, from: json)
        #expect(dto.cards.count == 5)
    }

    

}
