// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "FontShelf", platforms: [.macOS(.v13)], products: [.executable(name: "FontShelf", targets: ["FontShelf"])], targets: [.executableTarget(name: "FontShelf", path: "Sources")])
