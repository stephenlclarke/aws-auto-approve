import Foundation

func execute(_ arguments: [String]) throws -> Data {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = ["--toolchain", "XcodeDefault"] + arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw CocoaError(.executableRuntimeMismatch) }
    return data
}
let root = FileManager.default.currentDirectoryPath
let debug = URL(fileURLWithPath: root + "/.build/debug").resolvingSymlinksInPath()
let entries = FileManager.default.enumerator(at: debug, includingPropertiesForKeys: [.isRegularFileKey])!
let binaries = entries.compactMap { $0 as? URL }.filter {
    $0.path.contains(".xctest/Contents/MacOS/") && !$0.path.contains(".dSYM")
        && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
}
guard let testBinary = binaries.first else { fatalError("Missing XCTest executable") }
let raw = try execute(["llvm-cov", "export", testBinary.path,
                       "-object=" + debug.appendingPathComponent("aws-auto-approve").path,
                       "-instr-profile=" + debug.appendingPathComponent("codecov/default.profdata").path])
let report = try JSONSerialization.jsonObject(with: raw) as! [String: Any]
let records = report["data"] as! [[String: Any]]
var xml = "<coverage version=\"1\">\n"
var covered = 0
var total = 0
for record in records {
    for file in record["files"] as! [[String: Any]] {
        let path = file["filename"] as! String
        guard path.hasPrefix(root + "/Sources/"), path.hasSuffix(".swift") else { continue }
        var lines: [Int: Bool] = [:]
        let segments = file["segments"] as! [[Any]]
        for (index, segment) in segments.enumerated() {
            guard segment[3] as! Bool else { continue }
            let start = segment[0] as! Int
            let next = index + 1 < segments.count ? segments[index + 1][0] as! Int : start
            let end = max(start, next - 1)
            for line in start...end { lines[line] = (lines[line] ?? false) || (segment[2] as! Int > 0) }
        }
        let escaped = path.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
        xml += "<file path=\"\(escaped)\">\n"
        for line in lines.keys.sorted() {
            let hit = lines[line]!
            xml += "<lineToCover lineNumber=\"\(line)\" covered=\"\(hit)\"/>\n"
            total += 1
            if hit { covered += 1 }
        }
        xml += "</file>\n"
    }
}
xml += "</coverage>\n"
guard total > 0 else { fatalError("Empty coverage report") }
try xml.write(toFile: "coverage.xml", atomically: true, encoding: .utf8)
print("Swift source coverage: \(covered)/\(total) executable lines (\(covered * 100 / total)%).")
