//
//  APIDate.swift
//  DancePractice
//

import Foundation

/// Dates on the wire are ISO-8601 UTC strings, like Java's `Instant`.
///
/// Sent dates are rounded to the millisecond. Postgres keeps microseconds, but comparing a local
/// Double against what came back from the server only stays exact if both sides agree on a
/// precision, so the app rounds and compares in whole milliseconds (`millis`).
enum APIDate {
    private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let withoutFraction = ISO8601DateFormatter()

    static func string(from date: Date) -> String {
        withFraction.string(from: date.roundedToMilliseconds)
    }

    /// Java prints 0, 3, 6 or 9 fraction digits; the formatter only reads 3, so the fraction is parsed by hand.
    static func date(from string: String) -> Date? {
        guard string.hasSuffix("Z") else { return nil }
        var base = string.dropLast()
        var fraction = 0.0
        if let dot = base.firstIndex(of: ".") {
            fraction = Double("0" + base[dot...]) ?? 0
            base = base[..<dot]
        }
        return withoutFraction.date(from: base + "Z")?.addingTimeInterval(fraction).roundedToMilliseconds
    }

    static func millis(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    static let encodingStrategy = JSONEncoder.DateEncodingStrategy.custom { date, encoder in
        var container = encoder.singleValueContainer()
        try container.encode(string(from: date))
    }

    static let decodingStrategy = JSONDecoder.DateDecodingStrategy.custom { decoder in
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let date = date(from: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an ISO-8601 date: \(text)")
        }
        return date
    }
}

extension Date {
    var roundedToMilliseconds: Date {
        Date(timeIntervalSince1970: (timeIntervalSince1970 * 1000).rounded() / 1000)
    }
}
