import Foundation

/// Shared data contract written by the Watch app and read by the Watch widget extension via App Group.
struct AppointmentSchedule: Codable, Equatable {
    static let widgetKind = "OnicotechNextAppointment"
    private static let defaults = UserDefaults(suiteName: "group.com.gsdev.Onicotech.watch")
    private static let key = "appointmentSchedule.v1"

    let starts: [Date]
    let expires: Date

    static func read() -> Self? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    static func replace(with schedule: Self?) {
        if let schedule, let data = try? JSONEncoder().encode(schedule) {
            defaults?.set(data, forKey: key)
        } else {
            defaults?.removeObject(forKey: key)
        }
    }
}
