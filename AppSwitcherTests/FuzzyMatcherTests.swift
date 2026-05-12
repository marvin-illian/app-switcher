import XCTest

final class FuzzyMatcherTests: XCTestCase {
    private let matcher = FuzzyMatcher()

    func testPrefixAbbreviationsRankFirst() {
        let matches = matcher.rankedMatches(
            query: "saf",
            candidates: ["Notes", "Safari", "System Settings"],
            name: { $0 }
        )

        XCTAssertEqual(matches.first?.item, "Safari")
    }

    func testWordPrefixMatchesMultiWordApps() {
        let matches = matcher.rankedMatches(
            query: "chr",
            candidates: ["Calendar", "Google Chrome", "Contacts"],
            name: { $0 }
        )

        XCTAssertEqual(matches.first?.item, "Google Chrome")
    }

    func testSubsequenceMatchesWordInitials() {
        let matches = matcher.rankedMatches(
            query: "vsc",
            candidates: ["Visual Studio Code", "Voice Memos", "Safari"],
            name: { $0 }
        )

        XCTAssertEqual(matches.first?.item, "Visual Studio Code")
    }

    func testContiguousMatchBeatsLooseSubsequence() {
        let matches = matcher.rankedMatches(
            query: "term",
            candidates: ["TextEdit Reminder", "Terminal"],
            name: { $0 }
        )

        XCTAssertEqual(matches.first?.item, "Terminal")
    }

    func testEmptyQueryReturnsNoMatches() {
        let matches = matcher.rankedMatches(
            query: "",
            candidates: ["Safari", "Terminal"],
            name: { $0 }
        )

        XCTAssertTrue(matches.isEmpty)
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertNotNil(matcher.score(query: "CODE", candidate: "Visual Studio Code"))
    }
}
