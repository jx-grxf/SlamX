import SwiftUI

struct StatsView: View {
    @Bindable var monitor: SlapMonitor

    @State private var isShowingClearConfirmation = false

    private var stats: SlapStatsStore {
        monitor.stats
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.08),
                    Color(red: 0.11, green: 0.12, blue: 0.10),
                    Color(red: 0.07, green: 0.10, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    HStack(spacing: 14) {
                        MetricTile(title: "Total Slaps", value: "\(stats.totalSlaps)", symbol: "hand.raised.fill", tint: .mint)
                        MetricTile(title: "Max Hardness", value: gForce(stats.maxImpact), symbol: "flame.fill", tint: .orange)
                        MetricTile(title: "Average", value: gForce(stats.averageImpact), symbol: "chart.bar.fill", tint: .yellow)
                        MetricTile(title: "Today", value: "\(stats.slapsToday)", symbol: "sun.max.fill", tint: .cyan)
                    }

                    if stats.totalSlaps == 0 {
                        emptyState
                    } else {
                        hardestHitPanel
                        distributionPanel
                        recentSlapsPanel
                    }
                }
                .padding(28)
            }
        }
        .foregroundStyle(.white)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    isShowingClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .help("Clear slap history")
                .disabled(stats.totalSlaps == 0)
            }
        }
        .confirmationDialog(
            "Clear all recorded slaps?",
            isPresented: $isShowingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) {
                stats.clear()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your lifetime slap history. The live counter is not affected.")
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Slap Stats")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer()

            if stats.totalSlaps > 0 {
                HardnessBadge(hardness: stats.hardestHardness)
            }
        }
    }

    private var subtitle: String {
        guard let last = stats.lastEvent else {
            return "No slaps recorded yet"
        }

        return "Hardest hit \(gForce(stats.maxImpact)) · last slap \(last.date.formatted(.relative(presentation: .named)))"
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised.slash")
                .font(.system(size: 42))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(0.4))
            Text("No slaps logged yet")
                .font(.title3.weight(.semibold))
            Text("Start monitoring and land a slap to fill up your stats.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .panelStyle()
    }

    private var hardestHitPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            PanelHeader(title: "Hardest Hit", symbol: "trophy.fill")

            if let hardest = stats.hardestEvent {
                HStack(spacing: 18) {
                    Image(systemName: hardest.hardness.symbol)
                        .font(.system(size: 40))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(hardest.hardness.color)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(gForce(hardest.impact))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(hardest.hardness.label)
                            .font(.headline)
                            .foregroundStyle(hardest.hardness.color)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(hardest.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.callout.weight(.semibold))
                        Text(hardest.date.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
        }
        .panelStyle()
    }

    private var distributionPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            PanelHeader(title: "Hardness Distribution", symbol: "chart.bar.xaxis")

            let breakdown = stats.hardnessBreakdown
            let maxCount = max(breakdown.map(\.count).max() ?? 1, 1)

            VStack(spacing: 12) {
                ForEach(breakdown, id: \.hardness) { entry in
                    HardnessBar(
                        hardness: entry.hardness,
                        count: entry.count,
                        fraction: Double(entry.count) / Double(maxCount)
                    )
                }
            }
        }
        .panelStyle()
    }

    private var recentSlapsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeader(title: "Recent Slaps", symbol: "list.bullet.rectangle")

            VStack(spacing: 0) {
                ForEach(Array(stats.events.prefix(40))) { event in
                    SlapRow(event: event)

                    if event.id != stats.events.prefix(40).last?.id {
                        Divider().overlay(.white.opacity(0.08))
                    }
                }
            }
        }
        .panelStyle()
    }

    private func gForce(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(2)))) g"
    }
}

private struct SlapRow: View {
    let event: SlapRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.hardness.symbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(event.hardness.color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.hardness.label)
                    .font(.callout.weight(.semibold))
                Text(event.date.formatted(date: .abbreviated, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
            }

            Spacer()

            Text("\(event.impact.formatted(.number.precision(.fractionLength(2)))) g")
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
        }
        .padding(.vertical, 9)
    }
}

private struct HardnessBar: View {
    let hardness: SlapHardness
    let count: Int
    let fraction: Double

    var body: some View {
        HStack(spacing: 12) {
            Label(hardness.label, systemImage: hardness.symbol)
                .symbolRenderingMode(.hierarchical)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 132, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))

                    Capsule()
                        .fill(hardness.color.gradient)
                        .frame(width: count == 0 ? 0 : max(10, proxy.size.width * fraction))
                        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: fraction)
                }
            }
            .frame(height: 14)

            Text("\(count)")
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 44, alignment: .trailing)
        }
    }
}

private struct HardnessBadge: View {
    let hardness: SlapHardness

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: hardness.symbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(hardness.color)
            Text(hardness.label)
                .lineLimit(1)
        }
        .font(.callout.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .foregroundStyle(.primary)
        .help("Hardest tier reached")
    }
}

extension SlapHardness {
    var color: Color {
        switch self {
        case .soft:
            .mint
        case .solid:
            .green
        case .hard:
            .yellow
        case .brutal:
            .orange
        case .devastating:
            .red
        }
    }
}

private extension View {
    func panelStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
    }
}
