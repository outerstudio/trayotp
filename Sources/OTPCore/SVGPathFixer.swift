import Foundation

/// Rewrites SVG path data into a form macOS's SVG renderer (CoreSVG) parses correctly.
///
/// Minified SVGs (e.g. Simple Icons) write arc flags without separators: `a1 1 0 00-7.88 3.7`
/// means flags `0`, `0` then x `-7.88`. CoreSVG misreads that and stops drawing the path, so
/// logos come out as fragments. Every number and flag is re-emitted with explicit spaces.
public enum SVGPathFixer {
    /// Normalizes every `d="..."` attribute in an SVG document.
    public static func normalize(svg: String) -> String {
        let pattern = #"(\sd\s*=\s*)(["'])(.*?)\2"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return svg }
        var result = svg
        let matches = regex.matches(in: svg, range: NSRange(svg.startIndex..., in: svg))
        for match in matches.reversed() {
            guard let whole = Range(match.range, in: svg),
                  let prefix = Range(match.range(at: 1), in: svg),
                  let quote = Range(match.range(at: 2), in: svg),
                  let data = Range(match.range(at: 3), in: svg)
            else { continue }
            let q = svg[quote]
            result.replaceSubrange(whole, with: "\(svg[prefix])\(q)\(normalize(path: String(svg[data])))\(q)")
        }
        return result
    }

    /// Normalizes one path's data. Returns the input unchanged if it can't be parsed.
    public static func normalize(path: String) -> String {
        let chars = Array(path.unicodeScalars)
        var i = 0
        var out: [String] = []
        var command: Character?
        var argIndex = 0

        func skipSeparators() {
            while i < chars.count, chars[i] == " " || chars[i] == "," || chars[i] == "\n" || chars[i] == "\t" || chars[i] == "\r" {
                i += 1
            }
        }

        func readNumber() -> String? {
            let start = i
            if i < chars.count, chars[i] == "+" || chars[i] == "-" { i += 1 }
            var digits = false, dot = false
            while i < chars.count {
                let c = chars[i]
                if c.properties.numericType != nil, ("0"..."9").contains(c) { digits = true; i += 1 }
                else if c == ".", !dot { dot = true; i += 1 }
                else { break }
            }
            guard digits else { i = start; return nil }
            if i < chars.count, chars[i] == "e" || chars[i] == "E" {
                let save = i
                i += 1
                if i < chars.count, chars[i] == "+" || chars[i] == "-" { i += 1 }
                let expStart = i
                while i < chars.count, ("0"..."9").contains(chars[i]) { i += 1 }
                if i == expStart { i = save }
            }
            return String(String.UnicodeScalarView(chars[start..<i]))
        }

        while true {
            skipSeparators()
            guard i < chars.count else { break }
            let c = chars[i]
            if c.properties.isAlphabetic, c != "e", c != "E" {
                command = Character(c)
                argIndex = 0
                out.append(String(c))
                i += 1
                continue
            }
            let isArc = command == "a" || command == "A"
            if isArc, argIndex % 7 == 3 || argIndex % 7 == 4 {
                // Flags are a single 0 or 1 and may touch the next number.
                guard c == "0" || c == "1" else { return path }
                out.append(String(c))
                i += 1
            } else {
                guard let number = readNumber() else { return path }
                out.append(number)
            }
            argIndex += 1
        }
        return out.joined(separator: " ")
    }
}
