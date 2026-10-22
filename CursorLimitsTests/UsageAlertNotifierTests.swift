import XCTest
@testable import CursorLimits

final class UsageAlertNotifierTests: XCTestCase {
    func testCrossesMultipleThresholdsOnNewCycle() {
        let result = UsageAlertNotifier.crossings(
            fraction: 0.95,
            providerID: .cursor,
            providerName: "Cursor",
            lastNotifiedThreshold: 0.9,
            cycleKey: "cycle-b",
            previousCycleKey: "cycle-a"
        )
        XCTAssertEqual(result.crossings.map(\.threshold), [0.70, 0.90])
        XCTAssertEqual(result.newLast, 0.90)
    }

    func testDoesNotRepeatSameThreshold() {
        let result = UsageAlertNotifier.crossings(
            fraction: 0.92,
            providerID: .cursor,
            providerName: "Cursor",
            lastNotifiedThreshold: 0.90,
            cycleKey: "cycle-a",
            previousCycleKey: "cycle-a"
        )
        XCTAssertTrue(result.crossings.isEmpty)
        XCTAssertEqual(result.newLast, 0.90)
    }

    func testNotifiesNextThresholdOnly() {
        let result = UsageAlertNotifier.crossings(
            fraction: 0.91,
            providerID: .claude,
            providerName: "Claude",
            lastNotifiedThreshold: 0.70,
            cycleKey: "c",
            previousCycleKey: "c"
        )
        XCTAssertEqual(result.crossings.map(\.threshold), [0.90])
        XCTAssertEqual(result.newLast, 0.90)
    }

    func testHundredPercent() {
        let result = UsageAlertNotifier.crossings(
            fraction: 1.0,
            providerID: .cursor,
            providerName: "Cursor",
            lastNotifiedThreshold: 0.90,
            cycleKey: "c",
            previousCycleKey: "c"
        )
        XCTAssertEqual(result.crossings.map(\.threshold), [1.0])
    }

    func testQuietHoursWrapsMidnight() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let evening = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 23))!
        let morning = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 7))!
        let midday = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
        XCTAssertTrue(UsageAlertNotifier.isInQuietHours(now: evening, calendar: cal, startHour: 22, endHour: 8))
        XCTAssertTrue(UsageAlertNotifier.isInQuietHours(now: morning, calendar: cal, startHour: 22, endHour: 8))
        XCTAssertFalse(UsageAlertNotifier.isInQuietHours(now: midday, calendar: cal, startHour: 22, endHour: 8))
    }

    func testQuietHoursSameStartEndIsOff() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let noon = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
        XCTAssertFalse(UsageAlertNotifier.isInQuietHours(now: noon, calendar: cal, startHour: 10, endHour: 10))
    }
}
