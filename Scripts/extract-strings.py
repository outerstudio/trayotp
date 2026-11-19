#!/usr/bin/env python3
"""Lists the localizable strings in Sources/ as Localizable.strings keys, without Xcode's genstrings.

    Scripts/extract-strings.py           # prints the keys, one per line
    Scripts/extract-strings.py --check   # fails if a Localizable.strings misses keys, has extra ones, or
                                         # changes a key's format specifiers

Keys are what Foundation looks up: `\\(x)` becomes %@ for strings and %lld for integers, as in
String(localized:) and SwiftUI's LocalizedStringKey. Integer interpolations are listed in INTS below:
add new ones there, or the key comes out with %@ and the translation is never found.
"""
import glob, os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
# Interpolated expressions that are integers: Int is %lld, UInt64 %llu. Everything else is a string (%@).
INTS = {"count", "matched", "duplicates", "leftCount", "codeCount", "iconCount", "tokenCount", "number", "total",
        "status", "m / 60", "minutes", "days", "pack.icons.count", "pack.version"}
UINT64S = {"other"}
# App names, shown as they are in every language.
VERBATIM = {"2FAS", "Aegis", "Ente Auth", "Google Authenticator", "Bitwarden"}
LOCALIZATIONS = os.path.join(ROOT, "Support/Localizations")
# SwiftUI initializers and modifiers whose string literal argument is a LocalizedStringKey.
SWIFTUI = r"(?<![\w.])(?:Text|Button|Label|Toggle|Menu|TextField|SecureField|Picker|Section)\(|\.help\("


def literal_end(s, i):
    """Index just past the string literal starting at s[i] == '"', skipping interpolations."""
    i += 1
    while s[i] != '"':
        if s[i] == "\\" and s[i + 1] == "(":
            i = expr_end(s, i + 2) + 1
        elif s[i] == "\\":
            i += 2
        else:
            i += 1
    return i + 1


def expr_end(s, i):
    """Index of the ')' closing the parenthesis opened just before s[i]."""
    depth = 0
    while True:
        c = s[i]
        if c == '"':
            i = literal_end(s, i)
            continue
        if c == "(":
            depth += 1
        elif c == ")":
            if depth == 0:
                return i
            depth -= 1
        i += 1


def key(lit):
    """Swift literal source (with quotes) → lookup key."""
    body, out, i = lit[1:-1], "", 0
    while i < len(body):
        if body.startswith("\\(", i):
            end = expr_end(body, i + 2)
            expr = body[i + 2:end].strip()
            out += "%lld" if expr in INTS else "%llu" if expr in UINT64S else "%@"
            i = end + 1
        elif body[i] == "\\":
            out += {"n": "\n", '"': '"', "\\": "\\"}[body[i + 1]]
            i += 2
        elif body[i] == "%":
            out += "%%"  # a literal percent sign is escaped in format strings
            i += 1
        else:
            out += body[i]
            i += 1
    return out


def literals_in(s, start, end):
    i, found = start, []
    while i < end:
        if s[i] == '"':
            j = literal_end(s, i)
            found.append(s[i:j])
            i = j
        else:
            i += 1
    return found


def keys():
    seen = []
    for path in sorted(glob.glob(os.path.join(ROOT, "Sources/*/**/*.swift"), recursive=True)):
        if "OTPCoreTests" in path:
            continue
        s = open(path, encoding="utf-8").read()
        # Blank out comments (but not the // in "https://"), raw strings and multi-line strings.
        s = re.sub(r"(?<!:)//[^\n]*|#\"[^\n]*?\"#|\"\"\"[\s\S]*?\"\"\"", lambda m: " " * len(m.group()), s)
        for m in re.finditer(r"String\(localized:\s*", s):
            seen.append(key(s[m.end():literal_end(s, m.end())]))
        if "SwiftUI" in s:
            for m in re.finditer(SWIFTUI, s):
                # Only the first argument, and only when it is made of literals (`a ? "x" : "y"` counts).
                end = expr_end(s, m.end())
                depth, i = 0, m.end()
                while i < end:
                    if s[i] == '"':
                        i = literal_end(s, i)
                        continue
                    if s[i] in "([":
                        depth += 1
                    elif s[i] in ")]":
                        depth -= 1
                    elif s[i] == "," and depth == 0:
                        break
                    i += 1
                arg = s[m.end():i].strip()
                if arg.startswith('"') or re.match(r"^[\w.!]+ \? \"", arg):
                    seen.extend(key(l) for l in literals_in(s, m.end(), i))
    unique = []
    for k in seen:
        if k not in unique and k not in VERBATIM and re.search(r"[A-Za-z]", re.sub(r"%(lld|llu|@)", "", k)):
            unique.append(k)
    return unique


def unescape(text):
    return re.sub(r'\\(.)', lambda m: {"n": "\n"}.get(m.group(1), m.group(1)), text)


def strings_pairs(path):
    text = open(path, encoding="utf-8").read()
    return [(unescape(k), unescape(v))
            for k, v in re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";', text, re.M)]


def specifiers(text):
    """The format arguments in order of position: "%2$@ … %1$lld" → ["lld", "@"]."""
    found = re.findall(r"%(?:(\d+)\$)?(lld|llu|@)", text)
    if any(n for n, _ in found):
        return [t for _, t in sorted(found, key=lambda f: int(f[0] or 0))]
    return [t for _, t in found]


if __name__ == "__main__":
    ks = keys()
    if "--check" not in sys.argv:
        print("\n".join(k.replace("\n", "\\n") for k in ks))
        sys.exit()
    bad = False
    for path in sorted(glob.glob(os.path.join(LOCALIZATIONS, "*.lproj/Localizable.strings"))):
        pairs = strings_pairs(path)
        have = [k for k, _ in pairs]
        lang = os.path.basename(os.path.dirname(path))
        problems = [f"missing {k!r}" for k in ks if k not in have] + [f"unused {k!r}" for k in have if k not in ks]
        problems += [f"specifiers differ: {k!r} → {v!r}" for k, v in pairs if specifiers(k) != specifiers(v)]
        problems += [f"duplicate {k!r}" for i, k in enumerate(have) if k in have[:i]]
        for p in problems:
            print(f"{lang}: {p}")
        bad |= bool(problems)
    sys.exit(1 if bad else 0)
