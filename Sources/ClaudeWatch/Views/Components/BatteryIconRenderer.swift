import AppKit

enum BatteryIconRenderer {

    static func makeMenuBarImage(mode: String, sessionPercent: Int, weeklyPercent: Int, sonnetPercent: Int) -> NSImage {
        switch mode {
        case "Both":
            return makeBothImage(sessionPercent: sessionPercent, weeklyPercent: weeklyPercent)
        case "Weekly":
            return makeLabeledImage(percent: weeklyPercent)
        case "Sonnet":
            return makeLabeledImage(percent: sonnetPercent)
        default:
            return makeLabeledImage(percent: sessionPercent)
        }
    }

    private static func makeLabeledImage(percent: Int) -> NSImage {
        let batteryW: CGFloat = 22
        let batteryH: CGFloat = 10
        let nubW: CGFloat = 2
        let textW: CGFloat = 30
        let totalW = batteryW + nubW + 3 + textW
        let totalH: CGFloat = 16

        let image = NSImage(size: NSSize(width: totalW, height: totalH), flipped: true) { _ in
            let yOffset = (totalH - batteryH) / 2
            drawBattery(
                at: NSPoint(x: 0, y: yOffset),
                size: NSSize(width: batteryW, height: batteryH),
                fillPercent: CGFloat(percent) / 100.0
            )
            drawText("\(percent)%", at: NSPoint(x: batteryW + nubW + 3, y: 1), width: textW, height: totalH)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func makeBothImage(sessionPercent: Int, weeklyPercent: Int) -> NSImage {
        let batteryW: CGFloat = 20
        let batteryH: CGFloat = 10
        let nubW: CGFloat = 2
        let textW: CGFloat = 28
        let blockW = batteryW + nubW + 2 + textW
        let gap: CGFloat = 6
        let totalW = blockW * 2 + gap
        let totalH: CGFloat = 16

        let image = NSImage(size: NSSize(width: totalW, height: totalH), flipped: true) { _ in
            let yOffset = (totalH - batteryH) / 2

            drawBattery(
                at: NSPoint(x: 0, y: yOffset),
                size: NSSize(width: batteryW, height: batteryH),
                fillPercent: CGFloat(sessionPercent) / 100.0
            )
            drawText("\(sessionPercent)%", at: NSPoint(x: batteryW + nubW + 2, y: 1), width: textW, height: totalH)

            let x2 = blockW + gap
            drawBattery(
                at: NSPoint(x: x2, y: yOffset),
                size: NSSize(width: batteryW, height: batteryH),
                fillPercent: CGFloat(weeklyPercent) / 100.0
            )
            drawText("\(weeklyPercent)%", at: NSPoint(x: x2 + batteryW + nubW + 2, y: 1), width: textW, height: totalH)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawBattery(at origin: NSPoint, size: NSSize, fillPercent: CGFloat) {
        let x = origin.x
        let y = origin.y
        let w = size.width
        let h = size.height
        let radius: CGFloat = 2.5
        let inset: CGFloat = 1.5
        let nubW: CGFloat = 2
        let nubH: CGFloat = 5

        let bodyRect = NSRect(x: x, y: y, width: w, height: h)
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: radius, yRadius: radius)
        NSColor.white.withAlphaComponent(0.6).setStroke()
        bodyPath.lineWidth = 1.0
        bodyPath.stroke()

        let nubX = x + w
        let nubY = y + (h - nubH) / 2
        let nubRect = NSRect(x: nubX, y: nubY, width: nubW, height: nubH)
        let nubPath = NSBezierPath(roundedRect: nubRect, xRadius: 1, yRadius: 1)
        NSColor.white.withAlphaComponent(0.5).setFill()
        nubPath.fill()

        let fillW = max(0, (w - inset * 2) * min(fillPercent, 1.0))
        if fillW > 0 {
            let fillRect = NSRect(x: x + inset, y: y + inset, width: fillW, height: h - inset * 2)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 1.5, yRadius: 1.5)

            let fillColor: NSColor
            if fillPercent > 0.9 {
                fillColor = .systemRed
            } else if fillPercent > 0.7 {
                fillColor = .systemOrange
            } else if fillPercent > 0.4 {
                fillColor = .systemBlue
            } else {
                fillColor = .systemGreen
            }
            fillColor.setFill()
            fillPath.fill()
        }
    }

    private static func drawText(_ text: String, at point: NSPoint, width: CGFloat, height: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.9)
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let strSize = str.size()
        let drawY = point.y + (height - strSize.height) / 2
        str.draw(at: NSPoint(x: point.x, y: drawY))
    }
}
