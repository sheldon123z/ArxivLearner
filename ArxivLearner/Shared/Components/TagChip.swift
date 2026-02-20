import SwiftUI

struct TagChip: View {
    let text: String
    var color: Color = AppTheme.primary

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: AppTheme.spacing) {
        TagChip(text: "cs.AI")
        TagChip(text: "cs.LG", color: AppTheme.secondary)
        TagChip(text: "cs.CV", color: AppTheme.accent)
        TagChip(text: "cs.CL", color: Color(hex: "FDCB6E"))
    }
    .padding()
}
