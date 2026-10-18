// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "TiskzCore", platforms: [.iOS(.v17), .macOS(.v13)], products: [.library(name: "TiskzCore", targets: ["TiskzCore"])], targets: [.target(name: "TiskzCore"), .testTarget(name: "TiskzCoreTests", dependencies: ["TiskzCore"])])
