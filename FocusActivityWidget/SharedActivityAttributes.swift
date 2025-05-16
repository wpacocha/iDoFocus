import ActivityKit

public struct FocusActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var timeRemaining: Int
        public var isBreak: Bool

        public init(timeRemaining: Int, isBreak: Bool) {
            self.timeRemaining = timeRemaining
            self.isBreak = isBreak
        }
    }

    public var taskName: String

    public init(taskName: String) {
        self.taskName = taskName
    }
}
