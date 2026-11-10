import AppKit
import ApprovalCore

let help = """
Usage: aws-auto-approve [--visible] [--timeout SECONDS] [--code ABCD-EFGH] URL
       aws-auto-approve --stdin [--visible] [--timeout SECONDS]

Uses macOS WebKit to approve a locally initiated AWS SSO request.
Login and MFA appear in a native window when required. Session cookies persist.
--stdin accepts authentication messages, one request per invocation. Do not pipe
'direnv export zsh' or credential output. Direct URL mode is suitable for Granted's
CustomSSOBrowserPath. Confirmation-code screens need --code or manual confirmation.
Exit codes: 0 approval page completed; 1 failure/timeout; 2 cancelled.
AWS credentials and final command success remain the initiating CLI's responsibility.
"""

do {
    let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
    if options.help {
        print(help)
    } else {
        let application = NSApplication.shared
        let delegate = ApprovalApplication(options: options)
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
} catch {
    FileHandle.standardError.write(Data(((error as? LocalizedError)?.errorDescription ?? "Invalid arguments.").utf8))
    FileHandle.standardError.write(Data("\n".utf8))
    exit(1)
}
