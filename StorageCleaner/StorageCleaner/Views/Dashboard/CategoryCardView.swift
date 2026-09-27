import SwiftUI

public struct CategoryCardView: View {
    public let category: CleanCategory
    public let itemCount: Int
    public let sizeText: String
    public let action: () -> Void

    public init(
        category: CleanCategory,
        itemCount: Int,
        sizeText: String,
        action: @escaping () -> Void
    ) {
        self.category = category
        self.itemCount = itemCount
        self.sizeText = sizeText
        self.action = action
    }

    public var body: some View {
        Button(action: {
            HapticManager.impact(style: .light)
            action()
        }) {
            HStack(spacing: 14) {
                Image(systemName: category.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 32, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(category.subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if !sizeText.isEmpty && sizeText != "0 KB" {
                        Text(sizeText)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Text("\(itemCount) \(itemCount == 1 ? "item" : "items")")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(AppTheme.cardBackground)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
