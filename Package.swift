// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MasterDock",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "MasterDock",
            targets: ["MasterDockApp"]
        ),
        .library(
            name: "MasterDockCore",
            targets: ["MasterDockCore"]
        ),
        .library(
            name: "MasterDockUI",
            targets: ["MasterDockUI"]
        ),
        .library(
            name: "MasterDockServices",
            targets: ["MasterDockServices"]
        ),
        .library(
            name: "MasterDockAI",
            targets: ["MasterDockAI"]
        )
    ],
    dependencies: [],
    targets: [
        // C bridge target for low-level MultitouchSupport.framework
        .target(
            name: "MasterDockMultitouchC",
            path: "Sources/MasterDockMultitouchC",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ]
        ),
        // Core framework: Multitouch Manager, Gesture State Machine, Glass Windowing, Permissions
        .target(
            name: "MasterDockCore",
            dependencies: ["MasterDockMultitouchC"],
            path: "Sources/MasterDockCore"
        ),
        // System Services: Clipboard, Media, Calendar, Wallpapers, App/Folder Launchers, Widgets, Storage
        .target(
            name: "MasterDockServices",
            dependencies: ["MasterDockCore"],
            path: "Sources/MasterDockServices"
        ),
        // AI & Audio: Streaming LLMs, Voice Recording Pipeline, Waveforms, Prompt Actions
        .target(
            name: "MasterDockAI",
            dependencies: ["MasterDockCore"],
            path: "Sources/MasterDockAI"
        ),
        // UI Design System: Liquid Glass, Waveforms, Cards, Buttons, and Section Views
        .target(
            name: "MasterDockUI",
            dependencies: ["MasterDockCore", "MasterDockServices", "MasterDockAI"],
            path: "Sources/MasterDockUI"
        ),
        // Main Application executable & ViewModel
        .executableTarget(
            name: "MasterDockApp",
            dependencies: [
                "MasterDockCore",
                "MasterDockUI",
                "MasterDockServices",
                "MasterDockAI"
            ],
            path: "Sources/MasterDockApp"
        ),
        // Unit & Integration Test Suite
        .executableTarget(
            name: "MasterDockTests",
            dependencies: [
                "MasterDockCore",
                "MasterDockUI",
                "MasterDockServices",
                "MasterDockAI",
                "MasterDockApp"
            ],
            path: "Tests/MasterDockTests"
        )
    ]
)
