// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AWSAutoApprove",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "aws-auto-approve", targets: ["AWSAutoApprove"])],
    targets: [
        .target(name: "ApprovalCore", resources: [.process("Resources")]),
        .executableTarget(name: "AWSAutoApprove", dependencies: ["ApprovalCore"]),
        .testTarget(name: "ApprovalCoreTests", dependencies: ["ApprovalCore"])
    ]
)
