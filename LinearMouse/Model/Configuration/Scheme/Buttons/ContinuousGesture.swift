// MIT License
// Copyright (c) 2021-2026 LinearMouse

import Foundation

extension Scheme.Buttons {
    struct ContinuousGesture: Equatable, ImplicitInitable {
        var enabled: Bool?
        var trigger: Scheme.Trigger?

        init() {}
    }
}

extension Scheme.Buttons.ContinuousGesture: Codable {
    private enum CodingKeys: String, CodingKey {
        case enabled
        case trigger
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
        trigger = try container.decodeIfPresent(Scheme.Trigger.self, forKey: .trigger)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(enabled, forKey: .enabled)
        try container.encodeIfPresent(trigger, forKey: .trigger)
    }
}

extension Scheme.Buttons.ContinuousGesture {
    func merge(into continuousGesture: inout Self) {
        if let enabled {
            continuousGesture.enabled = enabled
        }

        if let trigger {
            continuousGesture.trigger = trigger
        }
    }

    func merge(into continuousGesture: inout Self?) {
        if continuousGesture == nil {
            continuousGesture = Self()
        }

        merge(into: &continuousGesture!)
    }
}
