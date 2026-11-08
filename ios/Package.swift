// swift-tools-version: 5.9
import PackageDescription

// A host-side test harness for the exact Foundation sources used by the iOS target.
let package = Package(
    name: "KavachContractTests",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "Kavach", path: "Kavach/Core", exclude: ["DesignSystem.swift"]),
        .testTarget(name: "KavachTests", dependencies: ["Kavach"], path: "KavachTests",
                    resources: [.process("Fixtures")])
    ]
)
