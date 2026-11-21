import UIKit

public enum ExpressiveDetail: String, CaseIterable, Codable {
    case accents, full, minimal

    var title: String {
        switch self {
        case .accents: return "Акценты"
        case .full: return "Все клавиши"
        case .minimal: return "Минимум"
        }
    }
}

enum ExpressiveShape: Equatable {
    case tile, capsule, arch, leaf, clover, cookie

    init(key: KeySpec, detail: ExpressiveDetail) {
        if key.action == .space || key.action == .newline {
            self = .capsule
        } else if detail == .minimal {
            self = .tile
        } else {
            switch key.action {
            case .emoji: self = .cookie
            case .shift: self = .arch
            case .backspace: self = .leaf
            case .globe: self = .clover
            case .character(let text) where detail == .full:
                // Stable through Shift, Caps Lock and view reuse.
                switch (text.unicodeScalars.first?.value ?? 0) % 5 {
                case 0: self = .leaf
                case 1: self = .arch
                case 2: self = .clover
                default: self = .tile
                }
            default: self = .tile
            }
        }
    }

    func path(in rect: CGRect) -> CGPath {
        let side = min(rect.width, rect.height)
        switch self {
        case .capsule:
            return UIBezierPath(roundedRect: rect, cornerRadius: side / 2).cgPath
        case .tile:
            return UIBezierPath(roundedRect: rect, cornerRadius: side * 0.28).cgPath
        case .arch, .leaf:
            let corners: UIRectCorner = self == .arch ? [.topLeft, .topRight] : [.topLeft, .bottomRight]
            let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                                    cornerRadii: CGSize(width: side / 2, height: side / 2))
            return path.cgPath
        case .clover, .cookie:
            // Cubic interpolation of a periodic radius keeps the scallops smooth at any key size.
            let lobes = self == .clover ? 4 : 8
            let depth: CGFloat = self == .clover ? 0.085 : 0.05
            let step = CGFloat.pi / CGFloat(lobes)
            let path = UIBezierPath()
            func point(_ angle: CGFloat) -> CGPoint {
                let radius = 1 - depth + depth * cos(CGFloat(lobes) * angle)
                return CGPoint(x: rect.midX + rect.width / 2 * radius * cos(angle),
                               y: rect.midY + rect.height / 2 * radius * sin(angle))
            }
            path.move(to: point(0))
            for i in 0..<(lobes * 2) {
                let angle = CGFloat(i) * step
                let start = point(angle)
                let end = point(angle + step)
                let previous = point(angle - step)
                let next = point(angle + 2 * step)
                path.addCurve(to: end, controlPoint1: CGPoint(x: start.x + (end.x - previous.x) / 6,
                                                             y: start.y + (end.y - previous.y) / 6),
                              controlPoint2: CGPoint(x: end.x - (next.x - start.x) / 6,
                                                     y: end.y - (next.y - start.y) / 6))
            }
            path.close()
            return path.cgPath
        }
    }
}
