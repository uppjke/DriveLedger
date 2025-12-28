import XCTest
import UserNotifications
@testable import DriveLedger

final class MaintenanceNotificationsTests: XCTestCase {

    private final class FakeCenter: MaintenanceUserNotificationCentering {
        var status: UNAuthorizationStatus = .authorized
        var addedRequests: [UNNotificationRequest] = []
        var removedPending: [[String]] = []
        var removedDelivered: [[String]] = []

        func authorizationStatus() async -> UNAuthorizationStatus { status }

        func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
            status = .authorized
            return true
        }

        func add(_ request: UNNotificationRequest) async throws {
            addedRequests.append(request)
        }

        func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
            removedPending.append(identifiers)
        }

        func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
            removedDelivered.append(identifiers)
        }
    }

    private var fakeCenter: FakeCenter!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        fakeCenter = FakeCenter()
        defaults = UserDefaults(suiteName: "MaintenanceNotificationsTests")!
        defaults.removePersistentDomain(forName: "MaintenanceNotificationsTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "MaintenanceNotificationsTests")
        defaults = nil
        fakeCenter = nil
        super.tearDown()
    }

    func testDateNotifications_schedulesWarningAndDue() async {
        let intervalID = UUID()
        let due = Date().addingTimeInterval(60 * 60 * 24 * 40) // +40d

        await MaintenanceNotifications.sync(
            intervalID: intervalID,
            title: "Engine oil",
            vehicleName: "Car",
            dueDate: due,
            nextDueKm: nil,
            currentKm: nil,
            notificationsEnabled: true,
            notificationsByDateEnabled: true,
            notificationsByMileageEnabled: false,
            leadDays: 30,
            leadKm: nil,
            timeMinutes: 9 * 60,
            repeatRule: .none,
            isEnabled: true,
            notificationCenter: fakeCenter,
            userDefaults: defaults
        )

        let ids = Set(fakeCenter.addedRequests.map { $0.identifier })
        XCTAssertTrue(ids.contains("maintenance.\(intervalID.uuidString).warning.v2"))
        XCTAssertTrue(ids.contains("maintenance.\(intervalID.uuidString).due"))
    }

    func testOverdueDateNotifications_schedulesRepeatDaily() async {
        let intervalID = UUID()
        let due = Date().addingTimeInterval(-60 * 60 * 24) // yesterday

        await MaintenanceNotifications.sync(
            intervalID: intervalID,
            title: "Inspection",
            vehicleName: nil,
            dueDate: due,
            nextDueKm: nil,
            currentKm: nil,
            notificationsEnabled: true,
            notificationsByDateEnabled: true,
            notificationsByMileageEnabled: false,
            leadDays: 7,
            leadKm: nil,
            timeMinutes: 9 * 60,
            repeatRule: .daily,
            isEnabled: true,
            notificationCenter: fakeCenter,
            userDefaults: defaults
        )

        let overdue = fakeCenter.addedRequests.first { $0.identifier == "maintenance.\(intervalID.uuidString).overdue" }
        XCTAssertNotNil(overdue)
        XCTAssertTrue(overdue?.trigger is UNCalendarNotificationTrigger)
        XCTAssertEqual((overdue?.trigger as? UNCalendarNotificationTrigger)?.repeats, true)
    }

    func testMileageNotifications_fireOnceWithCooldown() async {
        let intervalID = UUID()

        await MaintenanceNotifications.sync(
            intervalID: intervalID,
            title: "Brake pads",
            vehicleName: "Car",
            dueDate: nil,
            nextDueKm: 10_000,
            currentKm: 9_800,
            notificationsEnabled: true,
            notificationsByDateEnabled: false,
            notificationsByMileageEnabled: true,
            leadDays: 0,
            leadKm: 500,
            timeMinutes: 9 * 60,
            repeatRule: .weekly,
            isEnabled: true,
            notificationCenter: fakeCenter,
            userDefaults: defaults
        )

        await MaintenanceNotifications.sync(
            intervalID: intervalID,
            title: "Brake pads",
            vehicleName: "Car",
            dueDate: nil,
            nextDueKm: 10_000,
            currentKm: 9_800,
            notificationsEnabled: true,
            notificationsByDateEnabled: false,
            notificationsByMileageEnabled: true,
            leadDays: 0,
            leadKm: 500,
            timeMinutes: 9 * 60,
            repeatRule: .weekly,
            isEnabled: true,
            notificationCenter: fakeCenter,
            userDefaults: defaults
        )

        let immediateCount = fakeCenter.addedRequests.filter { $0.identifier == "maintenance.\(intervalID.uuidString).mileage.now" }.count
        XCTAssertEqual(immediateCount, 1)
    }
}
