import SwiftUI

/// Minimal SVG path (`d` attribute) parser → SwiftUI `Path`, scoped to the
/// commands soukmar's category icon set (`cat-icon.component.html`) actually
/// uses: M/m L/l H/h V/v C/c S/s A/a Z/z, including implicit command repeats
/// and multiple subpaths chained in a single `d` string. Mirrors Android's
/// `androidx.compose.ui.graphics.vector.PathParser`, which does the same job
/// for `CategoryIcons.kt` there. Coordinates stay in the SVG's 0–24 viewBox
/// space; callers scale the whole drawing to their target size.
enum SVGPath {
    private enum Token { case command(Character); case number(CGFloat) }

    private static func tokenize(_ d: String) -> [Token] {
        var tokens: [Token] = []
        let chars = Array(d)
        let commandLetters = Set("MmLlHhVvCcSsQqTtAaZz")
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if commandLetters.contains(c) {
                tokens.append(.command(c))
                i += 1
            } else if c == "-" || c == "+" || c == "." || c.isNumber {
                var j = i
                var s = ""
                if chars[j] == "+" || chars[j] == "-" { s.append(chars[j]); j += 1 }
                while j < chars.count, chars[j].isNumber { s.append(chars[j]); j += 1 }
                if j < chars.count, chars[j] == "." {
                    s.append("."); j += 1
                    while j < chars.count, chars[j].isNumber { s.append(chars[j]); j += 1 }
                }
                if let v = Double(s) { tokens.append(.number(CGFloat(v))) }
                i = j
            } else {
                i += 1
            }
        }
        return tokens
    }

    static func parse(_ d: String) -> Path {
        var path = Path()
        let tokens = tokenize(d)
        var idx = 0
        func num() -> CGFloat {
            guard idx < tokens.count, case let .number(n) = tokens[idx] else { return 0 }
            idx += 1
            return n
        }

        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastCubicControl: CGPoint?
        var activeCommand: Character = " "

        while idx < tokens.count {
            var cmd = activeCommand
            if case let .command(c) = tokens[idx] {
                cmd = c
                idx += 1
            }
            let isRelative = cmd.isLowercase
            let upper = Character(cmd.uppercased())

            switch upper {
            case "M":
                let x = num(), y = num()
                let p = isRelative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                path.move(to: p)
                current = p
                subpathStart = p
                activeCommand = isRelative ? "l" : "L"
                lastCubicControl = nil
            case "L":
                let x = num(), y = num()
                let p = isRelative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                path.addLine(to: p)
                current = p
                activeCommand = cmd
                lastCubicControl = nil
            case "H":
                let x = num()
                let p = CGPoint(x: isRelative ? current.x + x : x, y: current.y)
                path.addLine(to: p)
                current = p
                activeCommand = cmd
                lastCubicControl = nil
            case "V":
                let y = num()
                let p = CGPoint(x: current.x, y: isRelative ? current.y + y : y)
                path.addLine(to: p)
                current = p
                activeCommand = cmd
                lastCubicControl = nil
            case "C":
                let x1 = num(), y1 = num(), x2 = num(), y2 = num(), x = num(), y = num()
                let c1 = isRelative ? CGPoint(x: current.x + x1, y: current.y + y1) : CGPoint(x: x1, y: y1)
                let c2 = isRelative ? CGPoint(x: current.x + x2, y: current.y + y2) : CGPoint(x: x2, y: y2)
                let p = isRelative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                path.addCurve(to: p, control1: c1, control2: c2)
                lastCubicControl = c2
                current = p
                activeCommand = cmd
            case "S":
                let x2 = num(), y2 = num(), x = num(), y = num()
                let c2 = isRelative ? CGPoint(x: current.x + x2, y: current.y + y2) : CGPoint(x: x2, y: y2)
                let c1 = lastCubicControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let p = isRelative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                path.addCurve(to: p, control1: c1, control2: c2)
                lastCubicControl = c2
                current = p
                activeCommand = cmd
            case "A":
                let rx = num(), ry = num()
                _ = num() // x-axis-rotation — always 0 in this icon set, ignored
                let largeArc = num() != 0
                let sweep = num() != 0
                let x = num(), y = num()
                let end = isRelative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                appendArc(to: &path, from: current, rx: rx, ry: ry, largeArc: largeArc, sweep: sweep, end: end)
                current = end
                activeCommand = cmd
                lastCubicControl = nil
            case "Z":
                path.closeSubpath()
                current = subpathStart
                activeCommand = cmd
                lastCubicControl = nil
            default:
                idx += 1
            }
        }
        return path
    }

    /// Endpoint-to-center arc parameterization (W3C SVG spec, simplified for
    /// x-axis-rotation = 0 — the only case this icon set uses), converted to
    /// cubic Bézier segments since `Path` has no native SVG-arc verb.
    private static func appendArc(to path: inout Path, from start: CGPoint, rx rxIn: CGFloat, ry ryIn: CGFloat, largeArc: Bool, sweep: Bool, end: CGPoint) {
        var rx = abs(rxIn), ry = abs(ryIn)
        if rx == 0 || ry == 0 || start == end {
            path.addLine(to: end)
            return
        }
        let x1p = (start.x - end.x) / 2
        let y1p = (start.y - end.y) / 2
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            let s = sqrt(lambda)
            rx *= s; ry *= s
        }
        let sign: CGFloat = (largeArc != sweep) ? 1 : -1
        let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        let co = den == 0 ? 0 : sign * sqrt(max(0, num / den))
        let cxp = co * (rx * y1p / ry)
        let cyp = co * (-ry * x1p / rx)
        let cx = cxp + (start.x + end.x) / 2
        let cy = cyp + (start.y + end.y) / 2

        func angleBetween(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let len = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
            var a = acos(max(-1, min(1, len == 0 ? 1 : dot / len)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }

        let theta1 = angleBetween(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var dtheta = angleBetween((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep && dtheta > 0 { dtheta -= 2 * .pi }
        if sweep && dtheta < 0 { dtheta += 2 * .pi }

        let segments = max(1, Int(ceil(abs(dtheta) / (.pi / 2))))
        let delta = dtheta / CGFloat(segments)
        var a1 = theta1
        for _ in 0..<segments {
            let a2 = a1 + delta
            let t = tan((a2 - a1) / 4)
            let alpha = sin(a2 - a1) * (sqrt(4 + 3 * t * t) - 1) / 3
            let p1 = CGPoint(x: cos(a1), y: sin(a1))
            let p4 = CGPoint(x: cos(a2), y: sin(a2))
            let q1 = CGPoint(x: p1.x - alpha * sin(a1), y: p1.y + alpha * cos(a1))
            let q2 = CGPoint(x: p4.x + alpha * sin(a2), y: p4.y - alpha * cos(a2))
            let c1 = CGPoint(x: cx + q1.x * rx, y: cy + q1.y * ry)
            let c2 = CGPoint(x: cx + q2.x * rx, y: cy + q2.y * ry)
            let ep = CGPoint(x: cx + p4.x * rx, y: cy + p4.y * ry)
            path.addCurve(to: ep, control1: c1, control2: c2)
            a1 = a2
        }
    }
}

/// One drawable primitive of a category icon, mirroring the SVG elements
/// used in `cat-icon.component.html` (`<path>`, `<rect>`, `<circle>`,
/// `<line>`, `<polyline>`), plus a dashed variant for CARPOOLING's
/// `stroke-dasharray`.
private enum IconElement {
    case path(String)
    case dashedPath(String, dash: [CGFloat])
    case rect(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, rx: CGFloat)
    case circle(cx: CGFloat, cy: CGFloat, r: CGFloat)
    case line(CGFloat, CGFloat, CGFloat, CGFloat)
    case polyline([CGPoint])
}

/// All 18 category icons, transcribed 1:1 from
/// `soukmar/src/app/components/cat-icon/cat-icon.component.html`'s `d`/attribute
/// strings — mirrors Android's `CategoryIcons.kt`, which did the same
/// mechanical transcription via `PathParser`.
private func iconElements(for category: String) -> [IconElement] {
    switch category {
    case "VEHICLES":
        return [
            .path("M5 11l1.5-4.5A2 2 0 0 1 8.4 5h7.2a2 2 0 0 1 1.9 1.5L19 11"),
            .rect(x: 3, y: 11, w: 18, h: 6, rx: 2),
            .circle(cx: 7.5, cy: 17, r: 1.5),
            .circle(cx: 16.5, cy: 17, r: 1.5),
        ]
    case "REAL_ESTATE":
        return [
            .path("M3 10.5 12 3l9 7.5"),
            .path("M5 9.5V20a1 1 0 0 0 1 1h4v-6h4v6h4a1 1 0 0 0 1-1V9.5"),
        ]
    case "JOBS":
        return [
            .rect(x: 2, y: 7, w: 20, h: 13, rx: 2),
            .path("M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"),
            .path("M2 12h20"),
        ]
    case "ELECTRONICS":
        return [
            .rect(x: 6, y: 2, w: 12, h: 20, rx: 2),
            .line(11, 18, 13, 18),
        ]
    case "HOME_GARDEN":
        return [
            .path("M12 3c-2 2-2 5 0 7 2-2 2-5 0-7z"),
            .path("M12 10c-3-1-6 1-6 4h12c0-3-3-5-6-4z"),
            .line(12, 10, 12, 21),
            .path("M8 21h8"),
        ]
    case "FASHION":
        return [
            .path("M20.38 3.46 16 2a4 4 0 0 1-8 0L3.62 3.46a2 2 0 0 0-1.34 2.23l.58 3.47a1 1 0 0 0 .99.84H6v10a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V10h2.15a1 1 0 0 0 .99-.84l.58-3.47a2 2 0 0 0-1.34-2.23z"),
        ]
    case "SERVICES":
        return [
            .path("M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94z"),
        ]
    case "BABY_KIDS":
        return [
            .path("M10 2h4"),
            .path("M12 2v3"),
            .path("M9 8.5a3 3 0 0 1 6 0V19a2.5 2.5 0 0 1-2.5 2.5h-1A2.5 2.5 0 0 1 9 19z"),
            .line(9, 13, 15, 13),
        ]
    case "PETS":
        return [
            .circle(cx: 7, cy: 9, r: 2),
            .circle(cx: 12, cy: 6.5, r: 2),
            .circle(cx: 17, cy: 9, r: 2),
            .path("M12 12c-3.5 0-6.5 2.5-6.5 5.8 0 2 1.7 3.2 3.6 2.6.9-.3 1.9-.4 2.9-.4s2 .1 2.9.4c1.9.6 3.6-.6 3.6-2.6 0-3.3-3-5.8-6.5-5.8z"),
        ]
    case "SPORTS_LEISURE":
        return [
            .line(6, 12, 18, 12),
            .rect(x: 2, y: 9, w: 4, h: 6, rx: 1),
            .rect(x: 18, y: 9, w: 4, h: 6, rx: 1),
            .rect(x: 6, y: 10.5, w: 2, h: 3, rx: 0.5),
            .rect(x: 16, y: 10.5, w: 2, h: 3, rx: 0.5),
        ]
    case "LESSONS_COURSES":
        return [
            .path("M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"),
            .path("M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"),
        ]
    case "CARPOOLING":
        return [
            .circle(cx: 4, cy: 5, r: 1.5),
            .circle(cx: 20, cy: 5, r: 1.5),
            .dashedPath("M5.5 5h13", dash: [2.5, 2.5]),
            .path("M5 14l1.5-4.5A2 2 0 0 1 8.4 8h7.2a2 2 0 0 1 1.9 1.5L19 14"),
            .rect(x: 3, y: 14, w: 18, h: 6, rx: 2),
            .circle(cx: 7.5, cy: 20, r: 1.5),
            .circle(cx: 16.5, cy: 20, r: 1.5),
        ]
    case "TRANSPORT":
        return [
            .rect(x: 1, y: 7, w: 13, h: 9, rx: 1),
            .path("M14 10h4l4 3.5V16h-2"),
            .circle(cx: 5.5, cy: 18, r: 1.5),
            .circle(cx: 16.5, cy: 18, r: 1.5),
            .line(7, 18, 15, 18),
        ]
    case "RENTAL":
        return [
            .path("M3 12l1-3a1.5 1.5 0 0 1 1.4-1h5.2a1.5 1.5 0 0 1 1.4 1l1 3"),
            .rect(x: 2, y: 12, w: 12, h: 5, rx: 1.5),
            .circle(cx: 5.5, cy: 17, r: 1.3),
            .circle(cx: 10.5, cy: 17, r: 1.3),
            .circle(cx: 19, cy: 7, r: 2.2),
            .path("M19 4.3v-1M19 10.7v1M21.7 7h1M15.3 7h1M20.9 5.1l.7-.7M16.4 8.9l.7-.7M20.9 8.9l.7.7M16.4 5.1l.7.7"),
        ]
    case "TICKETS":
        return [
            .path("M2 9a3 3 0 0 1 0 6v2a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-2a3 3 0 0 1 0-6V7a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2Z"),
            .path("M13 5v2"),
            .path("M13 17v2"),
            .path("M13 11v2"),
        ]
    case "GIVEAWAY_SWAP":
        return [
            .rect(x: 3, y: 8, w: 18, h: 4, rx: 1),
            .path("M12 8v13"),
            .path("M19 12v7a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-7"),
            .path("M7.5 8a2.5 2.5 0 0 1 0-5C11 3 12 8 12 8s1-5 4.5-5a2.5 2.5 0 0 1 0 5"),
        ]
    case "MOVING":
        return [
            .rect(x: 3, y: 11, w: 8, h: 8, rx: 1),
            .rect(x: 13, y: 7, w: 8, h: 12, rx: 1),
            .line(7, 11, 7, 8),
            .line(5, 9.5, 9, 9.5),
        ]
    default: // "OTHER" and any unrecognized/future code fall back to the same box icon
        return [
            .path("M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"),
            .polyline([CGPoint(x: 3.29, y: 7), CGPoint(x: 12, y: 12), CGPoint(x: 20.71, y: 7)]),
            .line(12, 22, 12, 12),
        ]
    }
}

/// Draws a category's line-icon on a 24×24 SVG-equivalent canvas that scales
/// to whatever frame size the caller gives it, matching web's `app-cat-icon`
/// (`viewBox="0 0 24 24" stroke-width="2"`). Mirrors Android's
/// `CategoryIcon(category, tint, modifier)` Composable — used at exactly the
/// same 3 call sites the web redesign (`fe5ad55`) touched: home category
/// grid, listings filter chips, and the "add listing" category step. Every
/// other place (listing card badge, listing detail badge, my listings,
/// saved searches) deliberately keeps `CategoryConfig.emoji`, unchanged.
struct CategoryIcon: View {
    let category: String
    var tint: Color = .primary

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 24
            context.scaleBy(x: scale, y: scale)
            let style = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            for element in iconElements(for: category) {
                switch element {
                case .path(let d):
                    context.stroke(SVGPath.parse(d), with: .color(tint), style: style)
                case .dashedPath(let d, let dash):
                    context.stroke(SVGPath.parse(d), with: .color(tint), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: dash))
                case .rect(let x, let y, let w, let h, let rx):
                    let path = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: rx)
                    context.stroke(path, with: .color(tint), style: style)
                case .circle(let cx, let cy, let r):
                    let path = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
                    context.stroke(path, with: .color(tint), style: style)
                case .line(let x1, let y1, let x2, let y2):
                    var path = Path()
                    path.move(to: CGPoint(x: x1, y: y1))
                    path.addLine(to: CGPoint(x: x2, y: y2))
                    context.stroke(path, with: .color(tint), style: style)
                case .polyline(let points):
                    var path = Path()
                    if let first = points.first { path.move(to: first) }
                    for p in points.dropFirst() { path.addLine(to: p) }
                    context.stroke(path, with: .color(tint), style: style)
                }
            }
        }
    }
}
