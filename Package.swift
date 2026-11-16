// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "TrayOTP",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic: OTP math, Base32, otpauth:// parsing, 2FAS import/export.
        .target(name: "OTPCore"),

        // The menu bar app (SwiftUI MenuBarExtra).
        .executableTarget(
            name: "TrayOTP",
            dependencies: ["OTPCore"]
        ),

        // Test runner as a plain executable, because XCTest only ships with full Xcode.
        // Run with: make test
        .executableTarget(
            name: "OTPCoreTests",
            dependencies: ["OTPCore"]
        ),
    ]
)
