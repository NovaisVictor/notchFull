import SwiftUI

struct ClockWidgetView: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 2) {
                Text(context.date, format: .dateTime.weekday(.wide))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
                    .textCase(.uppercase)
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(context.date, format: .dateTime.day().month(.wide))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
