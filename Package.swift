// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YokoWhisper",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "YokoWhisper", targets: ["YokoWhisper"])],
    dependencies: [.package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.1.0")],
    targets: [
        .executableTarget(name: "YokoWhisper", dependencies: [.product(name: "WhisperKit", package: "argmax-oss-swift")], path: "YokoWhisper", exclude: ["YokoWhisper.entitlements"], resources: [.process("PrivacyInfo.xcprivacy")]),
        .testTarget(name: "YokoWhisperTests", dependencies: ["YokoWhisper"], path: "YokoWhisperTests")
    ]
)
