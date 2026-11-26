import Foundation
import Observation

/// Runs `body` now and again every time an `@Observable` property it read changes.
///
/// Lets AppKit-side managers react to stores without SwiftUI. Stops once `owner` is gone.
@MainActor
func observeContinuously<Owner: AnyObject>(_ owner: Owner, _ body: @escaping @MainActor (Owner) -> Void) {
    withObservationTracking {
        body(owner)
    } onChange: { [weak owner] in
        Task { @MainActor in
            guard let owner else { return }
            observeContinuously(owner, body)
        }
    }
}
