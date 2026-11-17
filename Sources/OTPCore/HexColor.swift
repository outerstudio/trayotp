import Foundation

/// An sRGB color typed or pasted by the user, e.g. for an icon background.
public struct HexColor: Equatable, Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Accepts "#1E90FF", "1e90ff", "#19F", "rgb(30, 144, 255)", "30,144,255" and "30 144 255".
    public init?(parsing input: String) {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.hasPrefix("rgb"), let open = text.firstIndex(of: "("), let close = text.lastIndex(of: ")"), open < close {
            text = String(text[text.index(after: open)..<close])
        }
        let numbers = text.split { $0 == "," || $0 == " " }.map(String.init)
        if numbers.count == 3 {
            let values = numbers.compactMap { UInt8($0) }
            guard values.count == 3 else { return nil }
            self.init(red: values[0], green: values[1], blue: values[2])
            return
        }
        if text.hasPrefix("#") { text.removeFirst() }
        if text.count == 3 { text = text.map { "\($0)\($0)" }.joined() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(red: UInt8(value >> 16 & 0xFF), green: UInt8(value >> 8 & 0xFF), blue: UInt8(value & 0xFF))
    }

    /// "#1E90FF".
    public var hex: String { String(format: "#%02X%02X%02X", red, green, blue) }
}
