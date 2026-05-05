// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "EnglishPaperReader",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "EnglishPaperReader",
            targets: ["EnglishPaperReader"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "EnglishPaperReader",
            dependencies: []
        ),
        .testTarget(
            name: "EnglishPaperReaderTests",
            dependencies: ["EnglishPaperReader"]
        )
    ]
)
