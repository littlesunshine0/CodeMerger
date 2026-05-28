import Foundation

// MARK: - Core Ordering

public struct Sort: Sendable, Hashable, Codable, Comparable {
    public let value: Int

    public init(_ value: Int) {
        self.value = value
    }

    public static func < (lhs: Sort, rhs: Sort) -> Bool {
        lhs.value < rhs.value
    }
}

// MARK: - Semantic Versioning

public struct SemanticVersion: Sendable, Hashable, Codable, Comparable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: String?

    public init(_ major: Int, _ minor: Int, _ patch: Int, prerelease: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
    }

    public var versionString: String {
        let base = "\(major).\(minor).\(patch)"
        return prerelease.map { base + "-\($0)" } ?? base
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):
            return false
        case (nil, _):
            return false // release > prerelease
        case (_, nil):
            return true  // prerelease < release
        case (let lp?, let rp?):
            return lp < rp
        }
    }
}

// MARK: - Execution Status

public enum ExecutionStatus: String, Sendable, Hashable, Codable, CaseIterable {
    case pending
    case running
    case succeeded
    case failed
    case rolledBack
    case cancelled
    case skipped
}

// MARK: - Severity Levels

public enum Severity: String, Sendable, Hashable, Codable, CaseIterable {
    case critical
    case warning
    case info
    case debug
}

// MARK: - Log Level

public enum LogLevel: String, Sendable, Hashable, Codable, CaseIterable {
    case debug
    case info
    case warning
    case error
    case critical
}
