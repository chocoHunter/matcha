import XCTest
@testable import Matcha

final class BatterySleepSupportTests: XCTestCase {
    func testParsesBatteryPowerValuesFromPmsetCustomOutput() {
        let output = """
        Battery Power:
         sleep                12
         disablesleep         1
        AC Power:
         sleep                30
         disablesleep         0
        """

        let settings = BatterySleepSettingsParser.parse(from: output)

        XCTAssertEqual(settings?.sleep, 12)
        XCTAssertEqual(settings?.disablesleep, 1)
    }

    func testReturnsNilWhenBatterySectionIsMissingRequiredValues() {
        let output = """
        Battery Power:
         disablesleep         1
        AC Power:
         sleep                30
        """

        XCTAssertNil(BatterySleepSettingsParser.parse(from: output))
    }

    func testDefaultsMissingDisablesleepToZero() {
        let output = """
        Battery Power:
         Sleep On Power Button 1
         sleep                1
         displaysleep         2
        AC Power:
         sleep                1
        """

        let settings = BatterySleepSettingsParser.parse(from: output)

        XCTAssertEqual(settings?.sleep, 1)
        XCTAssertEqual(settings?.disablesleep, 0)
    }

    func testBuildsRestoreCommandFromSnapshot() {
        let command = BatterySleepCommandBuilder.restoreCommand(
            snapshot: (sleep: 15, disablesleep: 1)
        )

        XCTAssertEqual(command, "pmset -b sleep 15; pmset -b disablesleep 1")
    }

    func testBuildsFallbackRestoreCommandWithoutSnapshot() {
        let command = BatterySleepCommandBuilder.restoreCommand(snapshot: nil)

        XCTAssertEqual(command, "pmset -b disablesleep 0")
    }

    func testPreservesBatteryOverrideOnlyForExtremeModeWithBatteryModeEnabled() {
        XCTAssertTrue(
            BatterySleepOperationPlanner.shouldPreserveOverrideWhenStarting(
                mode: .extreme,
                batterySleepEnabled: true
            )
        )

        XCTAssertFalse(
            BatterySleepOperationPlanner.shouldPreserveOverrideWhenStarting(
                mode: .extreme,
                batterySleepEnabled: false
            )
        )

        XCTAssertFalse(
            BatterySleepOperationPlanner.shouldPreserveOverrideWhenStarting(
                mode: .awake,
                batterySleepEnabled: true
            )
        )
    }

    func testRequiresRestoreOnlyWhenRequestedAndOverrideIsActive() {
        XCTAssertTrue(
            BatterySleepOperationPlanner.shouldRestoreOverrideOnStop(
                restoreRequested: true,
                overrideActive: true
            )
        )

        XCTAssertFalse(
            BatterySleepOperationPlanner.shouldRestoreOverrideOnStop(
                restoreRequested: false,
                overrideActive: true
            )
        )

        XCTAssertFalse(
            BatterySleepOperationPlanner.shouldRestoreOverrideOnStop(
                restoreRequested: true,
                overrideActive: false
            )
        )
    }

    func testRecoveryActionRestoresWhenOverrideIsActive() {
        let action = BatterySleepOperationPlanner.recoveryAction(
            batterySleepEnabled: true,
            overrideActive: true
        )

        XCTAssertEqual(action, .restoreOverride)
    }

    func testRecoveryActionClearsStaleFlagWhenOnlyPreferenceRemains() {
        let action = BatterySleepOperationPlanner.recoveryAction(
            batterySleepEnabled: true,
            overrideActive: false
        )

        XCTAssertEqual(action, .clearStalePreference)
    }

    func testRecoveryActionDoesNothingWhenBatteryModeIsAlreadyClean() {
        let action = BatterySleepOperationPlanner.recoveryAction(
            batterySleepEnabled: false,
            overrideActive: false
        )

        XCTAssertEqual(action, .none)
    }

    func testSleepsDisplayWhenBatteryModeClosesLidWhileExtremeModeIsRunning() {
        let action = BatterySleepDisplayPlanner.action(
            previousIsClosed: false,
            currentIsClosed: true,
            batterySleepEnabled: true,
            mode: .extreme
        )

        XCTAssertEqual(action, .sleepDisplay)
    }

    func testDoesNotSleepDisplayOnInitialObservation() {
        let action = BatterySleepDisplayPlanner.action(
            previousIsClosed: nil,
            currentIsClosed: true,
            batterySleepEnabled: true,
            mode: .extreme
        )

        XCTAssertEqual(action, .none)
    }

    func testDoesNotSleepDisplayWhenOpeningLid() {
        let action = BatterySleepDisplayPlanner.action(
            previousIsClosed: true,
            currentIsClosed: false,
            batterySleepEnabled: true,
            mode: .extreme
        )

        XCTAssertEqual(action, .none)
    }

    func testDoesNotSleepDisplayOutsideBatteryExtremeMode() {
        XCTAssertEqual(
            BatterySleepDisplayPlanner.action(
                previousIsClosed: false,
                currentIsClosed: true,
                batterySleepEnabled: false,
                mode: .extreme
            ),
            .none
        )

        XCTAssertEqual(
            BatterySleepDisplayPlanner.action(
                previousIsClosed: false,
                currentIsClosed: true,
                batterySleepEnabled: true,
                mode: .awake
            ),
            .none
        )
    }
}
