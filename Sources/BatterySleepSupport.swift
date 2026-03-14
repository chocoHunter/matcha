import Foundation

typealias BatterySleepSnapshot = (sleep: Int, disablesleep: Int)

enum BatterySleepSettingsParser {
    static func parse(from output: String) -> BatterySleepSnapshot? {
        let lines = output.components(separatedBy: .newlines)
        var isBatterySection = false
        var sleepValue: Int?
        var disablesleepValue = 0

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                continue
            }

            if line == "Battery Power:" {
                isBatterySection = true
                continue
            }

            if line.hasSuffix(":") {
                isBatterySection = false
                continue
            }

            guard isBatterySection else { continue }

            let components = line.split(whereSeparator: \.isWhitespace)
            guard components.count >= 2, let value = Int(components[1]) else { continue }

            let key = String(components[0]).lowercased()
            if key == "sleep" {
                sleepValue = value
            } else if key == "disablesleep" {
                disablesleepValue = value
            }
        }

        guard let sleepValue else { return nil }
        return (sleep: sleepValue, disablesleep: disablesleepValue)
    }
}

enum BatterySleepCommandBuilder {
    static func restoreCommand(snapshot: BatterySleepSnapshot?) -> String {
        guard let snapshot else {
            return "pmset -b disablesleep 0"
        }

        return "pmset -b sleep \(snapshot.sleep); pmset -b disablesleep \(snapshot.disablesleep)"
    }
}

enum BatterySleepRecoveryAction: Equatable {
    case none
    case clearStalePreference
    case restoreOverride
}

enum BatterySleepDisplayAction: Equatable {
    case none
    case sleepDisplay
}

enum BatterySleepOperationPlanner {
    static func shouldPreserveOverrideWhenStarting(
        mode: MatchaMode,
        batterySleepEnabled: Bool
    ) -> Bool {
        mode == .extreme && batterySleepEnabled
    }

    static func shouldRestoreOverrideOnStop(
        restoreRequested: Bool,
        overrideActive: Bool
    ) -> Bool {
        restoreRequested && overrideActive
    }

    static func recoveryAction(
        batterySleepEnabled: Bool,
        overrideActive: Bool
    ) -> BatterySleepRecoveryAction {
        if overrideActive {
            return .restoreOverride
        }

        if batterySleepEnabled {
            return .clearStalePreference
        }

        return .none
    }
}

enum BatterySleepDisplayPlanner {
    static func action(
        previousIsClosed: Bool?,
        currentIsClosed: Bool,
        batterySleepEnabled: Bool,
        mode: MatchaMode
    ) -> BatterySleepDisplayAction {
        guard batterySleepEnabled, mode == .extreme, let previousIsClosed else {
            return .none
        }

        return !previousIsClosed && currentIsClosed ? .sleepDisplay : .none
    }
}
