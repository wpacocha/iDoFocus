import ActivityKit
import WidgetKit
import SwiftUI

struct FocusActivityWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            VStack(spacing: 8) {
                Text(context.attributes.taskName)
                    .font(.headline)
                Text(context.state.isBreak ? "Break Time" : "Work Time")
                    .font(.title2)
                Text("⏳ \(formatTime(context.state.timeRemaining))")
                    .font(.system(.title3, design: .monospaced))
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.isBreak ? "Break" : "Work")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTime(context.state.timeRemaining))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.taskName)
                        .font(.footnote)
                }
            } compactLeading: {
                Text(context.state.isBreak ? "Break" : "Work")
            } compactTrailing: {
                Text(formatTimeShort(context.state.timeRemaining))
            } minimal: {
                Text("⏱")
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatTimeShort(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return "\(minutes)m"
    }
}
