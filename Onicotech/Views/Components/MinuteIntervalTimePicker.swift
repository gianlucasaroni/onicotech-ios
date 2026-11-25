import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Cross-platform time picker supporting configurable minute intervals (e.g. 5 minutes).
/// Uses native `UIDatePicker` (`minuteInterval`) on iOS and discrete hour/minute pickers on macOS.
struct MinuteIntervalTimePicker: View {
    let title: String
    @Binding var selection: Date
    var minuteInterval: Int = 5

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            #if os(iOS)
            UIKitMinuteIntervalTimePicker(
                selection: $selection,
                minuteInterval: minuteInterval
            )
            .fixedSize()
            #else
            macOSPicker
            #endif
        }
    }

    #if !os(iOS)
    private var minuteSteps: [Int] {
        let step = max(1, min(30, minuteInterval))
        return Array(stride(from: 0, to: 60, by: step))
    }

    private var hourBinding: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.hour, from: selection) },
            set: { newHour in
                var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: selection)
                comps.hour = newHour
                comps.second = 0
                if let updated = Calendar.current.date(from: comps) {
                    selection = updated
                }
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: {
                let raw = Calendar.current.component(.minute, from: selection)
                let step = max(1, min(30, minuteInterval))
                let snapped = (raw / step) * step
                return min(59, max(0, snapped))
            },
            set: { newMinute in
                var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: selection)
                comps.minute = newMinute
                comps.second = 0
                if let updated = Calendar.current.date(from: comps) {
                    selection = updated
                }
            }
        )
    }

    private var macOSPicker: some View {
        HStack(spacing: 4) {
            Picker("Ora", selection: hourBinding) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(String(format: "%02d", hour)).tag(hour)
                }
            }
            .labelsHidden()
            .frame(width: 64)

            Text(":")
                .fontWeight(.semibold)

            Picker("Minuti", selection: minuteBinding) {
                ForEach(minuteSteps, id: \.self) { minute in
                    Text(String(format: "%02d", minute)).tag(minute)
                }
            }
            .labelsHidden()
            .frame(width: 64)
        }
    }
    #endif

    /// Rounds a date up to the next multiple of `interval` minutes (e.g. 20:17 -> 20:20 for 5-min step).
    static func roundedUp(_ date: Date, minuteInterval interval: Int = 5) -> Date {
        let step = max(1, min(30, interval))
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = comps.minute ?? 0
        let remainder = minute % step
        let targetMinute = remainder == 0 ? minute : (minute + (step - remainder))

        var baseComps = comps
        baseComps.minute = 0
        baseComps.second = 0
        let base = cal.date(from: baseComps) ?? date
        return cal.date(byAdding: .minute, value: targetMinute, to: base) ?? date
    }
}

#if os(iOS)
private struct UIKitMinuteIntervalTimePicker: UIViewRepresentable {
    @Binding var selection: Date
    let minuteInterval: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .compact
        picker.minuteInterval = max(1, min(30, minuteInterval))
        picker.locale = Locale(identifier: "it_IT")
        picker.date = selection
        picker.setContentHuggingPriority(.required, for: .horizontal)
        picker.setContentCompressionResistancePriority(.required, for: .horizontal)
        picker.addTarget(
            context.coordinator,
            action: #selector(Coordinator.dateChanged(_:)),
            for: .valueChanged
        )
        return picker
    }

    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        context.coordinator.selection = $selection
        let clampedInterval = max(1, min(30, minuteInterval))
        if uiView.minuteInterval != clampedInterval {
            uiView.minuteInterval = clampedInterval
        }
        if abs(uiView.date.timeIntervalSince(selection)) >= 1 {
            uiView.date = selection
        }
    }

    final class Coordinator: NSObject {
        var selection: Binding<Date>

        init(selection: Binding<Date>) {
            self.selection = selection
        }

        @objc func dateChanged(_ sender: UIDatePicker) {
            selection.wrappedValue = sender.date
        }
    }
}
#endif
