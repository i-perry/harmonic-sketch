// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "HarmonicSketch", platforms: [.macOS(.v13)], products: [.executable(name: "HarmonicSketch", targets: ["HarmonicSketch"])], targets: [.executableTarget(name: "HarmonicSketch"), .testTarget(name: "HarmonicSketchTests", dependencies: ["HarmonicSketch"])], swiftLanguageModes: [.v5])
