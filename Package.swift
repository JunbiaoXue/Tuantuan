// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "Tuantuan", platforms: [.macOS(.v14)], products: [.executable(name: "Tuantuan", targets: ["Tuantuan"])], targets: [.executableTarget(name: "Tuantuan", path: "Sources"), .testTarget(name: "TuantuanTests", dependencies: ["Tuantuan"], path: "tests")])
