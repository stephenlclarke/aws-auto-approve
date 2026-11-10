import Foundation

public struct Options: Sendable {
    public var request: ApprovalRequest?
    public var stdin = false
    public var visible = false
    public var help = false
    public var timeout: TimeInterval = 180

    public init(arguments: [String]) throws {
        var index = 0
        var url: String?
        var code: String?
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--help", "-h": help = true
            case "--stdin": stdin = true
            case "--visible": visible = true
            case "--code", "--timeout":
                index += 1
                guard index < arguments.count else { throw ApprovalError.invalidArguments }
                if argument == "--code" {
                    code = arguments[index]
                } else {
                    guard let seconds = Double(arguments[index]), seconds.isFinite,
                          seconds >= 1, seconds <= 900 else { throw ApprovalError.invalidArguments }
                    timeout = seconds
                }
            default:
                guard url == nil, !argument.hasPrefix("-") else { throw ApprovalError.invalidArguments }
                url = argument
            }
            index += 1
        }
        if help { return }
        guard stdin != (url != nil), !(stdin && code != nil) else { throw ApprovalError.invalidArguments }
        if let url { request = try ApprovalRequest(url: url, code: code) }
    }
}
