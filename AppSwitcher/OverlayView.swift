import AppKit
import SwiftUI

struct OverlayMatch: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let score: Int?
    let isHighlighted: Bool
    let icon: NSImage?

    static func == (lhs: OverlayMatch, rhs: OverlayMatch) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.subtitle == rhs.subtitle
            && lhs.score == rhs.score
            && lhs.isHighlighted == rhs.isHighlighted
    }
}

enum OverlayLayout {
    static let width: CGFloat = 440
    static let cornerRadius: CGFloat = 18
    static let baseHeight: CGFloat = 102
    static let rowSpacing: CGFloat = 4
    static let textRowHeight: CGFloat = 28
    static let iconRowHeight: CGFloat = 34

    static func height(rowCount: Int, showsIcons: Bool) -> CGFloat {
        baseHeight + listHeight(rowCount: rowCount, showsIcons: showsIcons)
    }

    static func listHeight(rowCount: Int, showsIcons: Bool) -> CGFloat {
        let visibleRows = max(rowCount, 1)
        let rowHeight = showsIcons ? iconRowHeight : textRowHeight
        return CGFloat(visibleRows) * rowHeight + CGFloat(max(visibleRows - 1, 0)) * rowSpacing
    }
}

final class OverlayViewModel: ObservableObject {
    @Published var title = "Apps"
    @Published var query = ""
    @Published var matches: [OverlayMatch] = []
    @Published var usesNativeGlassEffect = false
    @Published var showsIcons = false
    @Published var windowHeight = OverlayLayout.height(rowCount: 5, showsIcons: false)
}

struct OverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(viewModel.query.isEmpty ? " " : viewModel.query)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(viewModel.matches) { match in
                    OverlayMatchRow(match: match, showsIcon: viewModel.showsIcons)
                }
            }
            .frame(
                height: OverlayLayout.listHeight(
                    rowCount: viewModel.matches.count,
                    showsIcons: viewModel.showsIcons
                ),
                alignment: .top
            )
        }
        .padding(18)
        .frame(width: OverlayLayout.width, height: viewModel.windowHeight, alignment: .topLeading)
        .background {
            if !viewModel.usesNativeGlassEffect {
                RoundedRectangle(cornerRadius: OverlayLayout.cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: OverlayLayout.cornerRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
        }
    }
}

private struct OverlayMatchRow: View {
    let match: OverlayMatch
    let showsIcon: Bool

    var body: some View {
        HStack(spacing: 10) {
            if showsIcon {
                if let icon = match.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                } else {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: 22, height: 22)
                }
            }

            Text(match.name)
                .font(.system(size: 15, weight: match.isHighlighted ? .semibold : .regular))
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(match.subtitle)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: showsIcon ? OverlayLayout.iconRowHeight : OverlayLayout.textRowHeight)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(match.isHighlighted ? Color.accentColor.opacity(0.18) : Color.clear)
        }
    }
}
