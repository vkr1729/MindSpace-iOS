import SwiftUI

public struct ConstellationNode: Identifiable, Sendable {
    public let id: String
    public let dayNumber: Int
    public let title: String
    public let isCompleted: Bool
    public let isActive: Bool
    public let isBridgeOfReflection: Bool // For Pregnancy gap waiver
    
    public init(
        id: String,
        dayNumber: Int,
        title: String,
        isCompleted: Bool,
        isActive: Bool,
        isBridgeOfReflection: Bool = false
    ) {
        self.id = id
        self.dayNumber = dayNumber
        self.title = title
        self.isCompleted = isCompleted
        self.isActive = isActive
        self.isBridgeOfReflection = isBridgeOfReflection
    }
}

/// Canvas-rendered cosmic star constellation path with Bezier curves and glowing nodes.
/// Reference: Mock Screen Codex.png (Screen 3: Managing Anxiety)
public struct ConstellationPathView: View {
    public let nodes: [ConstellationNode]
    public let onSelectNode: (ConstellationNode) -> Void
    
    public init(nodes: [ConstellationNode], onSelectNode: @escaping (ConstellationNode) -> Void) {
        self.nodes = nodes
        self.onSelectNode = onSelectNode
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let points = calculateNodeCoordinates(totalNodes: nodes.count, width: width)
            
            ZStack {
                // Background Constellation Curves (Splines)
                Canvas { context, _ in
                    guard points.count > 1 else { return }
                    
                    // 1. Draw solid completed paths with starlight gold gradient
                    var completedPath = Path()
                    var completedCount = 0
                    for (i, node) in nodes.enumerated() {
                        if node.isCompleted {
                            completedCount = i + 1
                        }
                    }
                    
                    if completedCount > 1 {
                        completedPath.move(to: points[0])
                        for i in 1..<completedCount {
                            let p0 = points[i - 1]
                            let p1 = points[i]
                            let midY = (p0.y + p1.y) / 2
                            completedPath.addCurve(to: p1, control1: CGPoint(x: p0.x, y: midY), control2: CGPoint(x: p1.x, y: midY))
                        }
                        context.stroke(
                            completedPath,
                            with: .color(CosmosTheme.starlightGold),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                        )
                    }
                    
                    // 2. Draw dashed upcoming paths
                    var upcomingPath = Path()
                    let startUpcoming = max(0, completedCount - 1)
                    if startUpcoming < points.count - 1 {
                        upcomingPath.move(to: points[startUpcoming])
                        for i in (startUpcoming + 1)..<points.count {
                            let p0 = points[i - 1]
                            let p1 = points[i]
                            let midY = (p0.y + p1.y) / 2
                            upcomingPath.addCurve(to: p1, control1: CGPoint(x: p0.x, y: midY), control2: CGPoint(x: p1.x, y: midY))
                        }
                        context.stroke(
                            upcomingPath,
                            with: .color(CosmosTheme.spaceCardBorder.opacity(0.85)),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 6])
                        )
                    }
                }
                
                // Interactive Star Nodes
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    if index < points.count {
                        let pt = points[index]
                        nodeView(for: node)
                            .position(pt)
                            .onTapGesture {
                                HapticService.shared.selection()
                                onSelectNode(node)
                            }
                    }
                }
            }
        }
        .frame(height: max(190, CGFloat((nodes.count + 2) / 3) * 68))
    }
    
    @ViewBuilder
    private func nodeView(for node: ConstellationNode) -> some View {
        ZStack {
            if node.isActive {
                ActiveNodeView(dayNumber: node.dayNumber)
            } else if node.isCompleted {
                // Completed Golden Node
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [CosmosTheme.starlightGold, Color(hex: "#EAB308")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 30)
                    .shadow(color: CosmosTheme.starlightGold.opacity(0.5), radius: 6, x: 0, y: 0)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(CosmosTheme.spaceBackground)
            } else if node.isBridgeOfReflection {
                // Gentle Bridge of Reflection for gap waiver
                RoundedRectangle(cornerRadius: 8)
                    .fill(CosmosTheme.moonLavender.opacity(0.7))
                    .frame(width: 34, height: 22)
                Text("~")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(CosmosTheme.textPrimary)
            } else {
                // Upcoming Dim Node
                Circle()
                    .fill(CosmosTheme.spaceCard)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Circle().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1.5)
                    )
                
                Text("\(node.dayNumber)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(CosmosTheme.textDisabled)
            }
        }
    }
    
    /// Generates a serpentine cosmic S-curve across columns
    private func calculateNodeCoordinates(totalNodes: Int, width: CGFloat) -> [CGPoint] {
        var result: [CGPoint] = []
        let paddingX: CGFloat = 45
        let usableWidth = max(100, width - (paddingX * 2))
        
        let cols = 3
        let rowHeight: CGFloat = 60
        
        for i in 0..<totalNodes {
            let row = i / cols
            let colInRow = i % cols
            let isEvenRow = (row % 2 == 0)
            let col = isEvenRow ? colInRow : (cols - 1 - colInRow)
            
            let x = paddingX + (usableWidth * CGFloat(col) / CGFloat(cols - 1))
            let y = 32 + (CGFloat(row) * rowHeight)
            result.append(CGPoint(x: x, y: y))
        }
        return result
    }
}

/// Isolated active node view containing its own pulsing animation,
/// preventing the parent ConstellationPathView from re-calculating Bezier splines and GeometryReader on every frame.
private struct ActiveNodeView: View {
    let dayNumber: Int
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Radiant Pulsing Halo
            Circle()
                .fill(CosmosTheme.cosmicPurple.opacity(0.25))
                .frame(width: 46, height: 46)
                .scaleEffect(pulseScale)
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: [CosmosTheme.cosmicPurple, Color(hex: "#6344E0")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 34, height: 34)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.85), lineWidth: 2)
                )
                .shadow(color: CosmosTheme.cosmicPurple.opacity(0.8), radius: 10, x: 0, y: 0)
            
            Text("\(dayNumber)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.3
            }
        }
    }
}
