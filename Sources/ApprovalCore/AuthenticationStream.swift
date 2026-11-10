import Foundation

/// Parses authentication messages only. Do not feed shell exports or credentials to this parser.
public struct AuthenticationStream: Sendable {
    private var pending = ""
    public private(set) var url: String?
    private var awaitingCode = false
    public private(set) var code: String?

    public init() {}

    public mutating func append(_ chunk: String) throws {
        pending += chunk
        guard pending.utf8.count <= 65_536 else { throw ApprovalError.inputTooLarge }
        while let newline = pending.firstIndex(of: "\n") {
            consume(String(pending[..<newline]))
            pending = String(pending[pending.index(after: newline)...])
        }
    }

    public mutating func finish() {
        consume(pending)
        pending = ""
    }

    public func request() throws -> ApprovalRequest? {
        guard let url else { return nil }
        return try ApprovalRequest(url: url, code: code)
    }

    private mutating func consume(_ line: String) {
        let clean = line.replacingOccurrences(of: "\u{001B}\\[[0-9;]*[A-Za-z]", with: "", options: .regularExpression)
        if let range = clean.range(of: "https://[^\\s<>\"']+", options: .regularExpression) {
            let candidate = String(clean[range]).trimmingCharacters(in: CharacterSet(charactersIn: "\\)"))
            if (try? ApprovalRequest(url: candidate)) != nil { url = candidate }
        }
        let trimmed = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        if awaitingCode, trimmed.range(of: "^[A-Z0-9]{4}-[A-Z0-9]{4}$", options: .regularExpression) != nil {
            code = trimmed
            awaitingCode = false
        }
        if trimmed.lowercased().contains("enter the code:") { awaitingCode = true }
        if let range = clean.range(of: "(?:Code:|code:)\\s*([A-Z0-9]{4}-[A-Z0-9]{4})", options: .regularExpression) {
            code = String(clean[range].suffix(9))
        }
    }
}
