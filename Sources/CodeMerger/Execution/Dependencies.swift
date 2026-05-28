import Foundation

// MARK: - Task Dependencies

public enum DependencyCondition: String, Sendable, Hashable, Codable, CaseIterable {
    case mustSucceed
    case canFail
    case optional
}

public struct TaskDependency: Sendable, Hashable, Codable {
    public let taskId: String
    public let condition: DependencyCondition
    public let timeout: TimeInterval

    public init(
        taskId: String,
        condition: DependencyCondition = .mustSucceed,
        timeout: TimeInterval = 300.0
    ) {
        self.taskId = taskId
        self.condition = condition
        self.timeout = timeout
    }
}

// MARK: - Task Conditions for Conditional Execution

public indirect enum TaskCondition: Sendable, Hashable, Codable {
    case always
    case onSuccess(previousTaskId: String)
    case onFailure(previousTaskId: String)
    case fileExists(path: String)
    case fileNotExists(path: String)
    case environmentVariable(key: String, equals: String?)
    case and([TaskCondition])
    case or([TaskCondition])
    case not(TaskCondition)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .always:
            try container.encode("always", forKey: .type)
        case .onSuccess(let taskId):
            try container.encode("onSuccess", forKey: .type)
            try container.encode(taskId, forKey: .taskId)
        case .onFailure(let taskId):
            try container.encode("onFailure", forKey: .type)
            try container.encode(taskId, forKey: .taskId)
        case .fileExists(let path):
            try container.encode("fileExists", forKey: .type)
            try container.encode(path, forKey: .path)
        case .fileNotExists(let path):
            try container.encode("fileNotExists", forKey: .type)
            try container.encode(path, forKey: .path)
        case .environmentVariable(let key, let value):
            try container.encode("environmentVariable", forKey: .type)
            try container.encode(key, forKey: .key)
            try container.encode(value, forKey: .value)
        case .and(let conditions):
            try container.encode("and", forKey: .type)
            try container.encode(conditions, forKey: .conditions)
        case .or(let conditions):
            try container.encode("or", forKey: .type)
            try container.encode(conditions, forKey: .conditions)
        case .not(let condition):
            try container.encode("not", forKey: .type)
            try container.encode(condition, forKey: .condition)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "always":
            self = .always
        case "onSuccess":
            let taskId = try container.decode(String.self, forKey: .taskId)
            self = .onSuccess(previousTaskId: taskId)
        case "onFailure":
            let taskId = try container.decode(String.self, forKey: .taskId)
            self = .onFailure(previousTaskId: taskId)
        case "fileExists":
            let path = try container.decode(String.self, forKey: .path)
            self = .fileExists(path: path)
        case "fileNotExists":
            let path = try container.decode(String.self, forKey: .path)
            self = .fileNotExists(path: path)
        case "environmentVariable":
            let key = try container.decode(String.self, forKey: .key)
            let value = try container.decode(String?.self, forKey: .value)
            self = .environmentVariable(key: key, equals: value)
        case "and":
            let conditions = try container.decode([TaskCondition].self, forKey: .conditions)
            self = .and(conditions)
        case "or":
            let conditions = try container.decode([TaskCondition].self, forKey: .conditions)
            self = .or(conditions)
        case "not":
            let condition = try container.decode(TaskCondition.self, forKey: .condition)
            self = .not(condition)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown condition type: \(type)"
            )
        }
    }

    enum CodingKeys: String, CodingKey {
        case type, taskId, path, key, value, conditions, condition
    }
}

// MARK: - Retry Policy

public struct RetryPolicy: Sendable, Hashable, Codable {
    public let maxAttempts: Int
    public let backoffStrategy: BackoffStrategy
    public let retryableExitCodes: [Int]
    public let retryableErrorPatterns: [String]

    public init(
        maxAttempts: Int = 3,
        backoffStrategy: BackoffStrategy = .linear(delaySeconds: 1),
        retryableExitCodes: [Int] = [],
        retryableErrorPatterns: [String] = []
    ) {
        self.maxAttempts = maxAttempts
        self.backoffStrategy = backoffStrategy
        self.retryableExitCodes = retryableExitCodes
        self.retryableErrorPatterns = retryableErrorPatterns
    }

    public func shouldRetry(exitCode: Int, errorOutput: String) -> Bool {
        if retryableExitCodes.contains(exitCode) {
            return true
        }
        
        for pattern in retryableErrorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(errorOutput.startIndex..<errorOutput.endIndex, in: errorOutput)
                if regex.firstMatch(in: errorOutput, range: range) != nil {
                    return true
                }
            }
        }
        
        return false
    }
}
