import SwiftUI
import WidgetKit

private struct Entry: TimelineEntry {
    let date: Date
    let next: Date?
    let hasSchedule: Bool
}

private struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        let now = Date()
        return Entry(date: now, next: now.addingTimeInterval(1800), hasSchedule: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entries(at: Date())[0])
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // The host requests a reload on every schedule or authentication change.
        completion(Timeline(entries: entries(at: Date()), policy: .never))
    }

    private func entries(at now: Date) -> [Entry] {
        guard let schedule = AppointmentSchedule.read(), schedule.expires > now else {
            return [Entry(date: now, next: nil, hasSchedule: false)]
        }
        let starts = schedule.starts.filter { $0 > now }.sorted()
        var entries = [Entry(date: now, next: starts.first, hasSchedule: true)]
        for (index, start) in starts.enumerated() where start < schedule.expires {
            entries.append(Entry(date: start, next: starts.dropFirst(index + 1).first, hasSchedule: true))
        }
        entries.append(Entry(date: schedule.expires, next: nil, hasSchedule: false))
        return entries
    }
}

@main
struct NextAppointmentWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppointmentSchedule.widgetKind, provider: ScheduleProvider()) { entry in
            VStack(alignment: .leading) {
                if let next = entry.next {
                    Label { Text(next, style: .time) } icon: { Image(systemName: "calendar") }
                    Text(timerInterval: entry.date...next, countsDown: true)
                        .font(.headline.monospacedDigit())
                        .accessibilityLabel("Tempo al prossimo appuntamento")
                } else {
                    Label("Agenda", systemImage: "calendar")
                    Text(entry.hasSchedule ? "Nessun altro appuntamento" : "Apri Onicotech")
                        .font(.caption)
                }
            }
            .privacySensitive()
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Prossimo appuntamento")
        .description("Orario e conto alla rovescia del prossimo appuntamento di oggi.")
        .supportedFamilies([.accessoryRectangular])
    }
}
