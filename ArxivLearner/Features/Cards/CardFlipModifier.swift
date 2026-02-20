import SwiftUI

// MARK: - CardFlipModifier

/// A custom AnimatableModifier that performs a 3D card flip around the Y axis.
struct CardFlipModifier: AnimatableModifier {
    var rotation: Double

    var animatableData: Double {
        get { rotation }
        set { rotation = newValue }
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .opacity(rotation > 90 && rotation < 270 ? 0 : 1)
    }
}

// MARK: - View Extension

extension View {
    /// Applies a 3D card flip animation. When `isFlipped` is true the view rotates 180 degrees
    /// around the Y axis; otherwise it sits at 0 degrees.
    func cardFlip(isFlipped: Bool) -> some View {
        modifier(CardFlipModifier(rotation: isFlipped ? 180 : 0))
    }
}
