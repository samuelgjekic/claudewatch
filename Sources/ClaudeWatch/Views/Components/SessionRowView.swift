import SwiftUI

struct SessionRowView: View {
    let conversation: ConversationSummary

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.projectName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(conversation.messageCount) msgs")
                    Text("·")
                    Text(Formatting.duration(conversation.duration))
                    Text("·")
                    Text(conversation.lastTimestamp.formatted(.relative(presentation: .named)))
                }
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            SparklineView(
                data: conversation.sparklineData,
                color: .blue,
                width: 44,
                height: 14,
                filled: true
            )

            Text(String(format: "%.1f%%", conversation.percentOfTotal))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }
}
