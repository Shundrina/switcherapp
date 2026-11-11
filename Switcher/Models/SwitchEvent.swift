import Foundation
import SwiftData

@Model
final class SwitchEvent {
    var timestamp: Date = Date.now
    var isOn: Bool = false
    var item: SwitchItem?

    init(timestamp: Date = .now, isOn: Bool) {
        self.timestamp = timestamp
        self.isOn = isOn
    }
}
