import Foundation
import XCTest

final class CommandLineTests: XCTestCase {
    func testHelpAndRejectedInputThroughTheRealExecutable() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        for (arguments, expectedStatus, text) in [(["--help"], Int32(0), "Usage: aws-auto-approve"),
                                                  ([], Int32(1), "Invalid arguments"),
                                                  (["https://evil.test/"], Int32(1), "Expected an HTTPS AWS SSO")] {
            let process = Process()
            process.executableURL = root.appendingPathComponent(".build/debug/aws-auto-approve")
            process.arguments = arguments
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            XCTAssertEqual(process.terminationStatus, expectedStatus)
            XCTAssertTrue(String(decoding: data, as: UTF8.self).contains(text))
        }
    }
}
