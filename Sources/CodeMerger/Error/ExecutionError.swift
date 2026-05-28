import Foundation

// MARK: - Error Handling & Recovery Layer

public enum ExecutionError: Error, Sendable, Hashable, Codable {
    case taskFailed(
        id: String,
        reason: String,
        exitCode: Int?,
        recoveryStrategy: RecoveryStrategy
    )
    case validationFailed(
        id: String,
        violations: [ValidationViolation]
    )
    case dependencyMissing(
        required: String,
        available: [String]
    )
    case checkpointRestoreFailed(
        checkpointId: String,
        reason: String
    )
    case pluginExecutionFailed(
        pluginId: String,
        reason: String
    )
    case timeoutExceeded(
        taskId: String,
        timeoutSeconds: TimeInterval
    )
    case circularDependency(
        taskIds: [String]
    )

    public var localizedDescription: String {
        switch self {
        case .taskFailed(let id, let reason, let exitCode, _):
            let code = exitCode.map { " (exit code: \($0))" } ?? ""
            return "Task \(id) failed: \(reason)\(code)"
        case .validationFailed(let id, _):
            return "Validation failed for task \(id)"
        case .dependencyMissing(let required, _):
            return "Missing required dependency: \(required)"
        case .checkpointRestoreFailed(let id, let reason):
            return "Failed to restore checkpoint \(id): \(reason)"
        case .pluginExecutionFailed(let id, let reason):
            return "Plugin \(id) execution failed: \(reason)"
        case .timeoutExceeded(let id, let timeout):
            return "Task \(id) exceeded timeout of \(timeout)s"
        case .circularDependency(let ids):
            return "Circular dependency detected: \(ids.joined(separator: " -> "))"
        }
    }
}

// MARK: - Recovery Strategies

public enum RecoveryStrategy: Sendable, Hashable, Codable {
    case retry(maxAttempts: Int, backoffStrategy: BackoffStrategy)
    case rollback(toCheckpoint: String)
    case skip(withWarning: Bool)
    case fail(gracefully: Bool)
    case composite([RecoveryStrategy])

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .retry(let max, let backoff):
            try container.encode("retry", forKey: .type)
            try container.encode(max, forKey: .maxAttempts)
            try container.encode(backoff, forKey: .backoffStrategy)
        case .rollback(let checkpoint):
            try container.encode("rollback", forKey: .type)
            try container.encode(checkpoint, forKey: .checkpointId)
        case .skip(let warn):
            try container.encode("skip", forKey: .type)
            try container.encode(warn, forKey: .withWarning)
        case .fail(let graceful):
            try container.encode("fail", forKey: .type)
            try container.encode(graceful, forKey: .gracefully)
        case .composite(let strategies):
            try container.encode("composite", forKey: .type)
            try container.encode(strategies, forKey: .strategies)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "retry":
            let max = try container.decode(Int.self, forKey: .maxAttempts)
            let backoff = try container.decode(BackoffStrategy.self, forKey: .backoffStrategy)
            self = .retry(maxAttempts: max, backoffStrategy: backoff)
        case "rollback":
            let checkpoint = try container.decode(String.self, forKey: .checkpointId)
            self = .rollback(toCheckpoint: checkpoint)
        case "skip":
            let warn = try container.decode(Bool.self, forKey: .withWarning)
            self = .skip(withWarning: warn)
        case "fail":
            let graceful = try container.decode(Bool.self, forKey: .gracefully)
            self = .fail(gracefully: graceful)
        case "composite":
            let strategies = try container.decode([RecoveryStrategy].self, forKey: .strategies)
            self = .composite(strategies)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown recovery strategy type: \(type)"
            )
        }
    }

    enum CodingKeys: String, CodingKey {
        case type, maxAttempts, backoffStrategy, checkpointId, withWarning, gracefully, strategies
    }
}

// MARK: - Backoff Strategies

public enum BackoffStrategy: Sendable, Hashable, Codable {
    case linear(delaySeconds: Int)
    case exponential(baseSeconds: Int, maxSeconds: Int)
    case fibonacci
    case custom(sequence: [Int])

    public func delayForAttempt(_ attempt: Int) -> TimeInterval {
        switch self {
        case .linear(let delay):
            return TimeInterval(delay * attempt)
        case .exponential(let base, let max):
            let exponentialDelay = Int(pow(Double(base), Double(attempt)))
            return TimeInterval(min(exponentialDelay, max))
        case .fibonacci:
            let fib = fibonacci(attempt)
            return TimeInterval(fib)
        case .custom(let sequence):
            guard attempt - 1 < sequence.count else { return TimeInterval(sequence.last ?? 0) }
            return TimeInterval(sequence[attempt - 1])
        }
    }

    private func fibonacci(_ n: Int) -> Int {
        var a = 0, b = 1
        for _ in 0..<n {
            (a, b) = (b, a + b)
        }
        return a
    }
}

// MARK: - Validation Violations

public struct ValidationViolation: Sendable, Hashable, Codable {
    public let rule: String
    public let actual: String
    public let expected: String
    public let severity: Severity
    public let suggestions: [String]

    public init(
        rule: String,
        actual: String,
        expected: String,
        severity: Severity = .warning,
        suggestions: [String] = []
    ) {
        self.rule = rule
        self.actual = actual
        self.expected = expected
        self.severity = severity
        self.suggestions = suggestions
    }
}
