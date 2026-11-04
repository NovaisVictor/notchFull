import Observation
import CoreGraphics

@MainActor
@Observable
final class NotchViewModel {
    static let openSize = CGSize(width: 640, height: 200)

    let closedSize: CGSize
    private(set) var isOpen = false

    init(closedSize: CGSize) {
        self.closedSize = closedSize
    }

    var currentSize: CGSize {
        isOpen ? Self.openSize : closedSize
    }

    func open() {
        isOpen = true
    }

    func close() {
        isOpen = false
    }
}
