import Foundation

struct FuzzyMatch<Candidate> {
    let item: Candidate
    let score: Int
}

struct FuzzyMatcher {
    func rankedMatches<Candidate>(
        query: String,
        candidates: [Candidate],
        name: (Candidate) -> String
    ) -> [FuzzyMatch<Candidate>] {
        candidates.compactMap { candidate in
            score(query: query, candidate: name(candidate)).map {
                FuzzyMatch(item: candidate, score: $0)
            }
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return name(lhs.item).localizedStandardCompare(name(rhs.item)) == .orderedAscending
        }
    }

    func score(query rawQuery: String, candidate rawCandidate: String) -> Int? {
        let query = normalize(rawQuery)
        let candidate = normalize(rawCandidate)

        guard !query.isEmpty, !candidate.isEmpty else {
            return nil
        }

        if let range = candidate.range(of: query) {
            let start = candidate.distance(from: candidate.startIndex, to: range.lowerBound)
            var score = 10_000 + (query.count * 80) - (start * 40)

            if start == 0 {
                score += 3_000
            } else if isWordBoundary(in: candidate, at: range.lowerBound) {
                score += 1_500
            }

            if query.count == candidate.count {
                score += 4_000
            }

            return score
        }

        guard let positions = subsequencePositions(query: query, candidate: candidate) else {
            return nil
        }

        let first = positions[0]
        let last = positions[positions.count - 1]
        let span = last - first + 1
        let gaps = span - query.count
        var score = 5_000 + (query.count * 70) - (first * 35) - (gaps * 60)

        if first == 0 {
            score += 1_000
        }

        var adjacentPairs = 0
        var boundaryHits = 0
        let chars = Array(candidate)
        for (offset, position) in positions.enumerated() {
            if offset > 0, position == positions[offset - 1] + 1 {
                adjacentPairs += 1
            }
            if position == 0 || isBoundary(chars: chars, position: position) {
                boundaryHits += 1
            }
        }

        score += adjacentPairs * 250
        score += boundaryHits * 180

        return score
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private func subsequencePositions(query: String, candidate: String) -> [Int]? {
        let queryCharacters = Array(query)
        let candidateCharacters = Array(candidate)
        var positions: [Int] = []
        var searchStart = 0

        for queryCharacter in queryCharacters {
            var foundPosition: Int?

            for index in searchStart..<candidateCharacters.count where candidateCharacters[index] == queryCharacter {
                foundPosition = index
                break
            }

            guard let foundPosition else {
                return nil
            }

            positions.append(foundPosition)
            searchStart = foundPosition + 1
        }

        return positions
    }

    private func isWordBoundary(in value: String, at index: String.Index) -> Bool {
        guard index != value.startIndex else {
            return true
        }

        let previous = value[value.index(before: index)]
        let current = value[index]
        return isBoundary(previous: previous, current: current)
    }

    private func isBoundary(chars: [Character], position: Int) -> Bool {
        guard position > 0, position < chars.count else {
            return position == 0
        }

        return isBoundary(previous: chars[position - 1], current: chars[position])
    }

    private func isBoundary(previous: Character, current: Character) -> Bool {
        if previous == " " || previous == "-" || previous == "_" || previous == "." {
            return true
        }

        if previous.isLowercase && current.isUppercase {
            return true
        }

        return false
    }
}
