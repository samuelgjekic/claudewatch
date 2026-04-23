import SwiftUI

struct SparklineView: View {
    let data: [Double]
    var color: Color = .accentColor
    var width: CGFloat = 50
    var height: CGFloat = 16
    var filled: Bool = true

    var body: some View {
        Canvas { context, size in
            guard data.count >= 2 else { return }
            let maxVal = data.max() ?? 1
            guard maxVal > 0 else { return }
            let step = size.width / CGFloat(data.count - 1)

            var path = Path()
            for (i, value) in data.enumerated() {
                let x = CGFloat(i) * step
                let y = size.height - (size.height * CGFloat(value / maxVal))
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(path, with: .color(color), lineWidth: 1.5)

            if filled {
                var fill = path
                fill.addLine(to: CGPoint(x: size.width, y: size.height))
                fill.addLine(to: CGPoint(x: 0, y: size.height))
                fill.closeSubpath()
                context.fill(fill, with: .color(color.opacity(0.12)))
            }
        }
        .frame(width: width, height: height)
    }
}
