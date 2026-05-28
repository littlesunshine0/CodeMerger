import Foundation

// MARK: - Artifact Types

public enum ArtifactType: String, Sendable, Hashable, Codable, CaseIterable {
    case executable
    case framework
    case bundle
    case documentation
    case report
    case log
    case data
    case checkpoint
}

// MARK: - Artifact

public struct Artifact: Sendable, Hashable, Codable {
    public let id: String
    public let type: ArtifactType
    public let path: String
    public let hash: String
    public let size: Int64
    public let timestamp: Date
    public let metadata: [String: String]

    public init(
        id: String,
        type: ArtifactType,
        path: String,
        hash: String,
        size: Int64,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.path = path
        self.hash = hash
        self.size = size
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Resource Metrics

public struct ResourceMetrics: Sendable, Hashable, Codable {
    public let peakMemory: Int64
    public let cpuTime: TimeInterval
    public let filesModified: Int
    public let filesCreated: Int
    public let filesDeleted: Int
    public let diskSpaceUsed: Int64

    public init(
        peakMemory: Int64 = 0,
        cpuTime: TimeInterval = 0,
        filesModified: Int = 0,
        filesCreated: Int = 0,
        filesDeleted: Int = 0,
        diskSpaceUsed: Int64 = 0
    ) {
        self.peakMemory = peakMemory
        self.cpuTime = cpuTime
        self.filesModified = filesModified
        self.filesCreated = filesCreated
        self.filesDeleted = filesDeleted
        self.diskSpaceUsed = diskSpaceUsed
    }
}

// MARK: - Checkpoint

public struct Checkpoint: Sendable, Hashable, Codable {
    public let id: String
    public let phaseId: String
    public let timestamp: Date
    public let state: [String: String]
    public let artifacts: [Artifact]
    public let isRollbackPoint: Bool
    public let description: String

    public init(
        id: String,
        phaseId: String,
        timestamp: Date = Date(),
        state: [String: String] = [:],
        artifacts: [Artifact] = [],
        isRollbackPoint: Bool = true,
        description: String = ""
    ) {
        self.id = id
        self.phaseId = phaseId
        self.timestamp = timestamp
        self.state = state
        self.artifacts = artifacts
        self.isRollbackPoint = isRollbackPoint
        self.description = description
    }
}

// MARK: - Execution Metrics

public struct ExecutionMetrics: Sendable, Hashable, Codable {
    public let taskId: String
    public let startTime: Date
    public let endTime: Date?
    public let status: ExecutionStatus
    public let resourceUsage: ResourceMetrics
    public let checkpoints: [Checkpoint]
    public let attempts: Int
    public let lastError: String?

    public var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    public init(
        taskId: String,
        startTime: Date = Date(),
        endTime: Date? = nil,
        status: ExecutionStatus = .pending,
        resourceUsage: ResourceMetrics = ResourceMetrics(),
        checkpoints: [Checkpoint] = [],
        attempts: Int = 1,
        lastError: String? = nil
    ) {
        self.taskId = taskId
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.resourceUsage = resourceUsage
        self.checkpoints = checkpoints
        self.attempts = attempts
        self.lastError = lastError
    }
}

// MARK: - Task Result

public struct TaskResult: Sendable, Hashable, Codable {
    public let taskId: String
    public let output: String
    public let exitCode: Int
    public let artifacts: [Artifact]
    public let violations: [ValidationViolation]
    public let metrics: ExecutionMetrics
    public let timestamp: Date

    public init(
        taskId: String,
        output: String,
        exitCode: Int,
        artifacts: [Artifact] = [],
        violations: [ValidationViolation] = [],
        metrics: ExecutionMetrics = ExecutionMetrics(taskId: ""),
        timestamp: Date = Date()
    ) {
        self.taskId = taskId
        self.output = output
        self.exitCode = exitCode
        self.artifacts = artifacts
        self.violations = violations
        self.metrics = metrics
        self.timestamp = timestamp
    }
}

// MARK: - Step Result

public struct StepResult: Sendable, Hashable, Codable {
    public let stepId: String
    public let tasks: [String: TaskResult]
    public let status: ExecutionStatus
    public let metrics: ExecutionMetrics
    public let timestamp: Date

    public var allTasksSucceeded: Bool {
        tasks.values.allSatisfy { $0.exitCode == 0 }
    }

    public init(
        stepId: String,
        tasks: [String: TaskResult] = [:],
        status: ExecutionStatus = .pending,
        metrics: ExecutionMetrics = ExecutionMetrics(taskId: ""),
        timestamp: Date = Date()
    ) {
        self.stepId = stepId
        self.tasks = tasks
        self.status = status
        self.metrics = metrics
        self.timestamp = timestamp
    }
}

// MARK: - Phase Result

public struct PhaseResult: Sendable, Hashable, Codable {
    public let phaseId: String
    public let steps: [String: StepResult]
    public let status: ExecutionStatus
    public let metrics: ExecutionMetrics
    public let state: [String: String]
    public let timestamp: Date

    public var allStepsSucceeded: Bool {
        steps.values.allSatisfy { $0.allTasksSucceeded }
    }

    public init(
        phaseId: String,
        steps: [String: StepResult] = [:],
        status: ExecutionStatus = .pending,
        metrics: ExecutionMetrics = ExecutionMetrics(taskId: ""),
        state: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        self.phaseId = phaseId
        self.steps = steps
        self.status = status
        self.metrics = metrics
        self.state = state
        self.timestamp = timestamp
    }
}

// MARK: - Workflow Result

public struct WorkflowResult: Sendable, Hashable, Codable {
    public let workflowId: String
    public let phases: [String: PhaseResult]
    public let status: ExecutionStatus
    public let metrics: ExecutionMetrics
    public let timestamp: Date

    public var duration: TimeInterval {
        metrics.duration
    }

    public var allPhasesSucceeded: Bool {
        phases.values.allSatisfy { $0.allStepsSucceeded }
    }

    public var summary: String {
        let totalPhases = phases.count
        let successfulPhases = phases.values.filter { $0.status == .succeeded }.count
        let failedPhases = phases.values.filter { $0.status == .failed }.count
        
        return """
        Workflow \(workflowId): \(status.rawValue)
        Phases: \(successfulPhases)/\(totalPhases) succeeded, \(failedPhases) failed
        Duration: \(String(format: "%.2f", duration))s
        """
    }

    public init(
        workflowId: String,
        phases: [String: PhaseResult] = [:],
        status: ExecutionStatus = .pending,
        metrics: ExecutionMetrics = ExecutionMetrics(taskId: ""),
        timestamp: Date = Date()
    ) {
        self.workflowId = workflowId
        self.phases = phases
        self.status = status
        self.metrics = metrics
        self.timestamp = timestamp
    }
}
