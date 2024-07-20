#if !os(WASI)
import Foundation

public extension WebSocket {
    enum Utils {
        static let customDateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Foundation.Calendar(identifier: .iso8601)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "h:mm MM/dd/yy"
            return formatter
        }()
        
        static let iso8601DateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Foundation.Calendar(identifier: .iso8601)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            return formatter
        }()

        static let iso8601DateOnlyFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Foundation.Calendar(identifier: .iso8601)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }()

        static let iso8601DateMillisecondsFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Foundation.Calendar(identifier: .iso8601)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            return formatter
        }()

        public static var jsonEncoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            encoder.dateEncodingStrategy = .iso8601
            return encoder
        }()

        public static var jsonDecoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.nonConformingFloatDecodingStrategy = .convertFromString(
                positiveInfinity: "Infinity",
                negativeInfinity: "-Infinity",
                nan: "NaN"
            )
            decoder.dateDecodingStrategy = .custom({ decoder in
                let container = try decoder.singleValueContainer()
                let value = try container.decode(String.self)
                if let date = Self.iso8601DateFormatter.date(from: value) {
                    return date
                }
                if let date = Self.iso8601DateMillisecondsFormatter.date(from: value) {
                    return date
                }
                if let date = Self.iso8601DateOnlyFormatter.date(from: value) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(value)")
            })
            return decoder
        }()
    }
}
#endif
