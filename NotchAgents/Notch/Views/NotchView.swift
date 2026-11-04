import SwiftUI

struct NotchView: View {
    let model: NotchViewModel

    private var topRadius: CGFloat { model.isOpen ? 14 : 6 }
    private var bottomRadius: CGFloat { model.isOpen ? 28 : 10 }

    var body: some View {
        // The shape is widened by the ears so the body under the menu bar matches the physical notch.
        let size = model.currentSize

        NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
            .fill(.black)
            .frame(width: size.width + topRadius * 2, height: size.height)
            .overlay {
                if model.isOpen {
                    openContent
                        .padding(.horizontal, topRadius + 20)
                        .padding(.top, model.closedSize.height)
                        .padding(.bottom, 16)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.38, dampingFraction: 0.8), value: model.isOpen)
    }

    private var openContent: some View {
        Text("NotchAgents")
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
