import SwiftUI

struct OverlayMatch: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let score: Int?
    let isHighlighted: Bool
}

final class OverlayViewModel: ObservableObject {
    @Published var title = "Apps"
    @Published var query = ""
    @Published var matches: [OverlayMatch] = []
    @Published var usesNativeGlassEffect = false
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
                    OverlayMatchRow(match: match)
                }
            }
            .frame(height: 154, alignment: .top)
        }
        .padding(18)
        .frame(width: 440, height: 258, alignment: .topLeading)
        .background {
            if !viewModel.usesNativeGlassEffect {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
        }
    }
}

private struct OverlayMatchRow: View {
    let match: OverlayMatch

    var body: some View {
        HStack(spacing: 10) {
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
        .frame(height: 28)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(match.isHighlighted ? Color.accentColor.opacity(0.18) : Color.clear)
        }
    }
}
