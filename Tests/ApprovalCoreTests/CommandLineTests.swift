import Foundation
import XCTest

final class CommandLineTests: XCTestCase {
    func testHelpAndRejectedInputThroughTheRealExecutable() throws {
        let products = Bundle(for: Self.self).bundleURL.deletingLastPathComponent()
        for (arguments, expectedStatus, text) in [(["--help"], Int32(0), "Usage: aws-auto-approve"),
                                                  ([], Int32(1), "Invalid arguments"),
                                                  (["https://evil.test/"], Int32(1), "Expected an HTTPS AWS SSO")] {
            let process = Process()
            process.executableURL = products.appendingPathComponent("aws-auto-approve")
            process.arguments = arguments
            var environment = ProcessInfo.processInfo.environment
            if environment["LLVM_PROFILE_FILE"] == nil {
                let coverage = products.appendingPathComponent("codecov", isDirectory: true)
                try FileManager.default.createDirectory(at: coverage, withIntermediateDirectories: true)
                environment["LLVM_PROFILE_FILE"] = coverage.appendingPathComponent("commandline-%p.profraw").path
            }
            process.environment = environment
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
