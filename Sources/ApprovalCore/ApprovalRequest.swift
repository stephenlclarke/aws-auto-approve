import Foundation

public enum ApprovalError: Error, LocalizedError {
    case invalidURL, invalidCode, invalidArguments, inputTooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "Expected an HTTPS AWS SSO authorisation URL."
        case .invalidCode: "Expected a confirmation code in the form ABCD-EFGH."
        case .invalidArguments: "Invalid arguments. Run aws-auto-approve --help."
        case .inputTooLarge: "Authentication input exceeded the supported line length."
        }
    }
}

public struct ApprovalRequest: Equatable, Sendable {
    public let url: URL
    public let code: String?

    public init(url text: String, code: String? = nil) throws {
        guard let parts = URLComponents(string: text), parts.scheme == "https",
              parts.user == nil, parts.password == nil, parts.port == nil,
              let host = parts.host, Self.isApprovalHost(host),
              Self.isApprovalPath(parts.path), let url = parts.url else {
            throw ApprovalError.invalidURL
        }
        if let code, code.range(of: "^[A-Z0-9]{4}-[A-Z0-9]{4}$", options: .regularExpression) == nil {
            throw ApprovalError.invalidCode
        }
        self.url = url
        self.code = code
    }

    public static func isApprovalHost(_ host: String) -> Bool {
        host.range(of: "^[a-z]{2}(?:-[a-z]+)+-[0-9]+\\.signin\\.aws$", options: .regularExpression) != nil
            || host.range(of: "^device\\.sso\\.[a-z]{2}(?:-[a-z]+)+-[0-9]+\\.amazonaws\\.com$", options: .regularExpression) != nil
    }

    private static func isApprovalPath(_ path: String) -> Bool {
        ["/platform/authorize", "/", "/authorize"].contains(path)
    }

    public func script() throws -> String {
        let settings: [String: Any] = ["expectedCode": code ?? "", "host": url.host ?? ""]
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.sortedKeys])
        let json = String(decoding: data, as: UTF8.self)
        return "(function(settings) {\n" + Self.automationSource + "\n})(" + json + ")"
    }

    public static var automationSource: String {
        // The resource is part of the signed/built product, never remote page content.
        let packaged = Bundle.main.resourceURL.flatMap { Bundle(url: $0.appendingPathComponent("AWSAutoApprove_ApprovalCore.bundle")) }
        guard let url = (packaged ?? Bundle.module).url(forResource: "approval", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            preconditionFailure("Missing bundled approval script")
        }
        return source
    }
}
