import Foundation

/// Shared Italian date formatting helpers.
enum DateFormatting {
    private static let italianMonths = [
        "", "Gennaio", "Febbraio", "Marzo", "Aprile", "Maggio", "Giugno",
        "Luglio", "Agosto", "Settembre", "Ottobre", "Novembre", "Dicembre"
    ]
    
    /// Formats "2026-02-20" → "20 Febbraio 2026"
    static func italianDate(from dateString: String) -> String {
        let components = dateString.split(separator: "-")
        guard components.count == 3,
              let day = Int(components[2]),
              let month = Int(components[1]),
              month >= 1, month <= 12 else { return dateString }
        return "\(day) \(italianMonths[month]) \(components[0])"
    }
}

/// Shared currency formatting helpers.
enum CurrencyFormatting {
    /// Formats cents to "€12.50"
    static func euros(fromCents cents: Int) -> String {
        let euros = Double(cents) / 100.0
        return String(format: "€%.2f", euros)
    }
}
