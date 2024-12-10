// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FirebaseResultsController",
    platforms: [
        .macOS(.v14),
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "FirebaseResultsController",
            targets: ["FirebaseResultsController"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/cgossain/Debounce.git", from: "1.5.1"),
        .package(url: "https://github.com/jflinter/Dwifft.git", branch: "master"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.1.0")
    ],
    targets: [
        .target(
            name: "FirebaseResultsController",
            dependencies: [
                .product(name: "Debounce", package: "Debounce"),
                .product(name: "Dwifft", package: "Dwifft"),
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk")
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
