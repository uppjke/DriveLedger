import Foundation
import UserNotifications

protocol MaintenanceUserNotificationCentering {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}

struct SystemMaintenanceUserNotificationCenter: MaintenanceUserNotificationCentering {
    private let center = UNUserNotificationCenter.current()

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

@MainActor
enum MaintenanceNotifications {
    private static let defaultTimeMinutes = 9 * 60

    static func requestAuthorizationIfNeeded() async -> Bool {
        await requestAuthorizationIfNeeded(notificationCenter: SystemMaintenanceUserNotificationCenter())
    }

    static func requestAuthorizationIfNeeded(
        notificationCenter: MaintenanceUserNotificationCentering
    ) async -> Bool {
        let status = await notificationCenter.authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    static func remove(intervalID: UUID) async {
        await remove(intervalID: intervalID, notificationCenter: SystemMaintenanceUserNotificationCenter())
    }

    static func remove(
        intervalID: UUID,
        notificationCenter: MaintenanceUserNotificationCentering
    ) async {
        let ids = identifiers(for: intervalID)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ids)
    }

    static func sync(
        intervalID: UUID,
        title: String,
        vehicleName: String?,
        dueDate: Date?,
        nextDueKm: Int?,
        currentKm: Int?,
        notificationsEnabled: Bool,
        notificationsByDateEnabled: Bool,
        notificationsByMileageEnabled: Bool,
        leadDays: Int,
        leadKm: Int?,
        timeMinutes: Int,
        repeatRule: MaintenanceNotificationRepeat,
        isEnabled: Bool,
        userDefaults: UserDefaults = .standard
    ) async {
        await sync(
            intervalID: intervalID,
            title: title,
            vehicleName: vehicleName,
            dueDate: dueDate,
            nextDueKm: nextDueKm,
            currentKm: currentKm,
            notificationsEnabled: notificationsEnabled,
            notificationsByDateEnabled: notificationsByDateEnabled,
            notificationsByMileageEnabled: notificationsByMileageEnabled,
            leadDays: leadDays,
            leadKm: leadKm,
            timeMinutes: timeMinutes,
            repeatRule: repeatRule,
            isEnabled: isEnabled,
            notificationCenter: SystemMaintenanceUserNotificationCenter(),
            userDefaults: userDefaults
        )
    }

    static func sync(
        intervalID: UUID,
        title: String,
        vehicleName: String?,
        dueDate: Date?,
        nextDueKm: Int?,
        currentKm: Int?,
        notificationsEnabled: Bool,
        notificationsByDateEnabled: Bool,
        notificationsByMileageEnabled: Bool,
        leadDays: Int,
        leadKm: Int?,
        timeMinutes: Int,
        repeatRule: MaintenanceNotificationRepeat,
        isEnabled: Bool,
        notificationCenter: MaintenanceUserNotificationCentering,
        userDefaults: UserDefaults = .standard
    ) async {
        await remove(intervalID: intervalID, notificationCenter: notificationCenter)

        guard notificationsEnabled, isEnabled else { return }

        guard await requestAuthorizationIfNeeded(notificationCenter: notificationCenter) else {
            return
        }

        let cal = Calendar.current
        let now = Date()

        let fireTimeMinutes = (0...(24 * 60 - 1)).contains(timeMinutes) ? timeMinutes : defaultTimeMinutes
        let fireHour = fireTimeMinutes / 60
        let fireMinute = fireTimeMinutes % 60

        func dateAtFireTime(_ date: Date) -> Date {
            cal.date(bySettingHour: fireHour, minute: fireMinute, second: 0, of: date) ?? date
        }

        func addCalendarRequest(id: String, title: String, subtitle: String?, body: String, fireDate: Date, repeats: Bool) async {
            guard fireDate > now || repeats else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                content.subtitle = subtitle
            }
            content.body = body
            content.sound = .default

            let comps: DateComponents
            if repeats {
                // Daily repeats at a time, regardless of date.
                comps = DateComponents(hour: fireHour, minute: fireMinute)
            } else {
                comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            }
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeats)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try? await notificationCenter.add(request)
        }

        func addImmediateRequest(id: String, title: String, subtitle: String?, body: String) async {
            let content = UNMutableNotificationContent()
            content.title = title
            if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                content.subtitle = subtitle
            }
            content.body = body
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try? await notificationCenter.add(request)
        }

        if notificationsByDateEnabled, let dueDate = dueDate {
            let dueFire = dateAtFireTime(dueDate)
            if dueFire > now {
                await addCalendarRequest(
                    id: identifiers(for: intervalID)[2],
                    title: title,
                    subtitle: vehicleName,
                    body: String(localized: "notification.maintenance.due.body"),
                    fireDate: dueFire,
                    repeats: false
                )
            }

            let resolvedLeadDays = max(0, leadDays)
            if resolvedLeadDays > 0, let warningDate = cal.date(byAdding: .day, value: -resolvedLeadDays, to: dueDate) {
                let warningFire = dateAtFireTime(warningDate)
                if warningFire > now {
                    let df = DateFormatter()
                    df.locale = Locale.autoupdatingCurrent
                    df.dateStyle = .medium
                    df.timeStyle = .none
                    let dueText = df.string(from: dueDate)

                    await addCalendarRequest(
                        id: identifiers(for: intervalID)[1],
                        title: title,
                        subtitle: vehicleName,
                        body: String(format: String(localized: "notification.maintenance.warning.body"), dueText),
                        fireDate: warningFire,
                        repeats: false
                    )
                }
            }

            // Overdue repeating reminder (date-based).
            if dueDate <= now, repeatRule != .none {
                let repeatsDaily = repeatRule == .daily
                if repeatsDaily {
                    await addCalendarRequest(
                        id: identifiers(for: intervalID)[3],
                        title: title,
                        subtitle: vehicleName,
                        body: String(localized: "notification.maintenance.overdue.body"),
                        fireDate: dateAtFireTime(now),
                        repeats: true
                    )
                } else {
                    // Weekly: schedule a non-repeating notification one week from now at the chosen time.
                    if let next = cal.date(byAdding: .day, value: 7, to: now) {
                        await addCalendarRequest(
                            id: identifiers(for: intervalID)[3],
                            title: title,
                            subtitle: vehicleName,
                            body: String(localized: "notification.maintenance.overdue.body"),
                            fireDate: dateAtFireTime(next),
                            repeats: false
                        )
                    }
                }
            }
        }

        // Mileage notifications are best-effort: they can only be evaluated when the app has a fresh odometer value.
        if notificationsByMileageEnabled, let nextDueKm, let currentKm {
            let kmLeft = nextDueKm - currentKm

            // Default lead distance when not configured.
            let effectiveLead = max(0, leadKm ?? 500)

            let inWarningZone = kmLeft <= effectiveLead
            if inWarningZone {
                let shouldFireNow: Bool = {
                    switch repeatRule {
                    case .none:
                        return !cooldownHit(intervalID: intervalID, rule: .weekly, userDefaults: userDefaults)
                    case .daily:
                        return !cooldownHit(intervalID: intervalID, rule: .daily, userDefaults: userDefaults)
                    case .weekly:
                        return !cooldownHit(intervalID: intervalID, rule: .weekly, userDefaults: userDefaults)
                    }
                }()

                if shouldFireNow {
                    let body: String
                    if kmLeft < 0 {
                        body = String(format: String(localized: "notification.maintenance.mileage.overdue.body"), abs(kmLeft))
                    } else {
                        body = String(format: String(localized: "notification.maintenance.mileage.warning.body"), kmLeft)
                    }
                    await addImmediateRequest(
                        id: identifiers(for: intervalID)[4],
                        title: title,
                        subtitle: vehicleName,
                        body: body
                    )
                    markCooldown(intervalID: intervalID, userDefaults: userDefaults)
                }

                if repeatRule == .daily {
                    await addCalendarRequest(
                        id: identifiers(for: intervalID)[5],
                        title: title,
                        subtitle: vehicleName,
                        body: String(localized: "notification.maintenance.mileage.repeat.body"),
                        fireDate: dateAtFireTime(now),
                        repeats: true
                    )
                } else if repeatRule == .weekly {
                    if let next = cal.date(byAdding: .day, value: 7, to: now) {
                        await addCalendarRequest(
                            id: identifiers(for: intervalID)[5],
                            title: title,
                            subtitle: vehicleName,
                            body: String(localized: "notification.maintenance.mileage.repeat.body"),
                            fireDate: dateAtFireTime(next),
                            repeats: false
                        )
                    }
                }
            }
        }
    }

    static func syncAll(for vehicle: Vehicle, currentKm: Int?) async {
        let resolvedCurrentKm: Int? = {
            if let currentKm { return currentKm }
            let fromEntries = vehicle.entries.compactMap { $0.odometerKm }.max()
            return fromEntries ?? vehicle.initialOdometerKm
        }()

        for interval in vehicle.maintenanceIntervals {
            await sync(
                intervalID: interval.id,
                title: interval.title,
                vehicleName: vehicle.name,
                dueDate: interval.nextDueDate(),
                nextDueKm: interval.nextDueKm(currentKm: resolvedCurrentKm),
                currentKm: resolvedCurrentKm,
                notificationsEnabled: interval.notificationsEnabled,
                notificationsByDateEnabled: interval.notificationsByDateEnabled,
                notificationsByMileageEnabled: interval.notificationsByMileageEnabled,
                leadDays: interval.notificationLeadDays,
                leadKm: interval.notificationLeadKm,
                timeMinutes: interval.notificationTimeMinutes,
                repeatRule: interval.notificationRepeat,
                isEnabled: interval.isEnabled
            )
        }
    }

    private static func identifiers(for intervalID: UUID) -> [String] {
        // [legacyWarning, warning, due, overdueRepeat, mileageNow, mileageRepeat]
        [
            "maintenance.\(intervalID.uuidString).warning",
            "maintenance.\(intervalID.uuidString).warning.v2",
            "maintenance.\(intervalID.uuidString).due",
            "maintenance.\(intervalID.uuidString).overdue",
            "maintenance.\(intervalID.uuidString).mileage.now",
            "maintenance.\(intervalID.uuidString).mileage.repeat"
        ]
    }

    private static func cooldownKey(for intervalID: UUID) -> String {
        "maintenance.notifications.cooldown.\(intervalID.uuidString)"
    }

    private static func cooldownHit(intervalID: UUID, rule: MaintenanceNotificationRepeat, userDefaults: UserDefaults) -> Bool {
        let defaults = userDefaults
        let key = cooldownKey(for: intervalID)
        guard let last = defaults.object(forKey: key) as? Date else { return false }
        let now = Date()

        switch rule {
        case .none:
            return false
        case .daily:
            return Calendar.current.isDate(last, inSameDayAs: now)
        case .weekly:
            return now.timeIntervalSince(last) < 7 * 24 * 60 * 60
        }
    }

    private static func markCooldown(intervalID: UUID, userDefaults: UserDefaults) {
        userDefaults.set(Date(), forKey: cooldownKey(for: intervalID))
    }
}
