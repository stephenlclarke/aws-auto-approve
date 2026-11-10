import XCTest
@testable import ApprovalCore

final class ApprovalCoreTests: XCTestCase {
    let address = "https://eu-west-1.signin.aws/platform/authorize?request_uri=example&identitystore_id=d-example"

    func testCurrentAndLegacyURLs() throws {
        XCTAssertEqual(try ApprovalRequest(url: address).url.host, "eu-west-1.signin.aws")
        XCTAssertNoThrow(try ApprovalRequest(url: "https://device.sso.eu-west-1.amazonaws.com/"))
        XCTAssertNoThrow(try ApprovalRequest(url: "https://us-gov-west-1.signin.aws/platform/authorize"))
    }

    func testRejectsUntrustedURLs() {
        for url in ["http://eu-west-1.signin.aws/platform/authorize", "https://eu-west-1.signin.aws.evil.test/",
                    "https://evil.test/", "https://user@eu-west-1.signin.aws/", "https://eu-west-1.signin.aws:443/",
                    "file:///tmp/request", "https://eu-west-1.signin.aws/settings"] {
            XCTAssertThrowsError(try ApprovalRequest(url: url), url)
        }
    }

    func testIdentityStoreRedirectIsBoundToTheRequest() throws {
        let request = try ApprovalRequest(url: address)
        XCTAssertTrue(request.allowsAutomation(at: request.url))
        XCTAssertFalse(request.allowsAutomation(at: nil))
        let bound = try ApprovalRequest(url: "https://eu-west-1.signin.aws/platform/authorize?identitystore_id=d-0123456789")
        XCTAssertTrue(bound.allowsAutomation(at: URL(string: "https://eu-west-1.signin.aws/platform/d-0123456789/login")))
        for destination in ["https://eu-west-1.signin.aws/platform/d-9876543210/login",
                            "http://eu-west-1.signin.aws/platform/d-0123456789/login",
                            "https://evil.test/platform/d-0123456789/login"] {
            XCTAssertFalse(bound.allowsAutomation(at: URL(string: destination)))
        }
        let invalidID = try ApprovalRequest(url: "https://eu-west-1.signin.aws/platform/authorize?identitystore_id=../evil")
        XCTAssertEqual(invalidID.approvalPaths.count, 1)
    }

    func testCodesArePassedAsData() throws {
        let request = try ApprovalRequest(url: address, code: "ABCD-1234")
        let settings = try XCTUnwrap(request.scriptArguments["settings"] as? [String: Any])
        XCTAssertEqual(settings["expectedCode"] as? String, "ABCD-1234")
        XCTAssertEqual(settings["host"] as? String, request.url.host)
        XCTAssertEqual(settings["paths"] as? [String], request.approvalPaths)
        for code in ["bad", "abcd-1234", "ABCD-1234';alert(1)", "ABCD-12345"] {
            XCTAssertThrowsError(try ApprovalRequest(url: address, code: code))
        }
    }

    func testStreamAcrossChunksWithANSICodeAndEOF() throws {
        var parser = AuthenticationStream()
        try parser.append("[i] open https://eu-west-1.signin.")
        XCTAssertNil(try parser.request())
        try parser.append("aws/platform/authorize?request_uri=example\n")
        try parser.append("\u{1b}[32m[i] Code: ABCD-1234\u{1b}[0m")
        parser.finish()
        XCTAssertEqual(try parser.request()?.code, "ABCD-1234")
        XCTAssertEqual(try parser.request()?.url.host, "eu-west-1.signin.aws")
    }

    func testAWSCLIStandaloneCodeIsBoundToItsPrompt() throws {
        var parser = AuthenticationStream()
        try parser.append("ABCD-9999\nThen enter the code:\n\n    WXYZ-1234\n")
        parser.finish()
        XCTAssertEqual(parser.code, "WXYZ-1234")
    }

    func testStreamIgnoresOtherLinksAndCapsInput() throws {
        var parser = AuthenticationStream()
        try parser.append("https://evil.test/\nordinary output\n")
        XCTAssertNil(try parser.request())
        XCTAssertThrowsError(try parser.append(String(repeating: "x", count: 65_537)))
    }

    func testOptions() throws {
        XCTAssertTrue(try Options(arguments: ["--help"]).help)
        XCTAssertTrue(try Options(arguments: ["--stdin"]).stdin)
        let options = try Options(arguments: ["--visible", "--timeout", "30", "--code", "ABCD-1234", address])
        XCTAssertTrue(options.visible)
        XCTAssertEqual(options.timeout, 30)
        XCTAssertEqual(options.request?.code, "ABCD-1234")
        for args in [[], ["--stdin", address], ["--stdin", "--code", "ABCD-1234"],
                     ["--timeout"], ["--timeout", "nan", address], ["--timeout", "0", address],
                     ["--timeout", "901", address], ["--other"], [address, address]] {
            XCTAssertThrowsError(try Options(arguments: args), "\(args)")
        }
    }

    func testErrorsHaveDescriptions() {
        for error in [ApprovalError.invalidURL, .invalidCode, .invalidArguments, .inputTooLarge] {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
}
