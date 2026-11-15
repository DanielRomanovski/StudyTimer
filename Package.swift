// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StudyTimer",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "StudyTimer", targets: ["StudyTimer"])],
    targets: [.executableTarget(name: "StudyTimer")]
)