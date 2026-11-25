import Foundation
import OTPCore

// Minimal test runner: XCTest is not available with Command Line Tools only.
// Run with: swift run OTPCoreTests

var failures = 0
var passes = 0

func check(_ condition: @autoclosure () throws -> Bool, _ message: String, line: Int = #line) {
    do {
        if try condition() { passes += 1; return }
        print("✗ line \(line): \(message)")
    } catch {
        print("✗ line \(line): \(message) — threw \(error)")
    }
    failures += 1
}

func equal<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: T, _ message: String, line: Int = #line) {
    do {
        let v = try a()
        if v == b { passes += 1; return }
        print("✗ line \(line): \(message) — got \(v), expected \(b)")
    } catch {
        print("✗ line \(line): \(message) — threw \(error)")
    }
    failures += 1
}

/// Real exports from other apps, used to check compatibility. They come from GPL-licensed projects,
/// so they are not part of this repo: `Scripts/fetch-test-fixtures.sh` downloads them into
/// ThirdPartyFixtures/ (git-ignored). Tests that need them are skipped when they're missing.
var skippedSuites: [String] = []

func fixture(_ name: String) -> Data? {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return try? Data(contentsOf: root.appendingPathComponent("ThirdPartyFixtures/\(name)"))
}

// MARK: Base32

equal(Base32.decode("MZXW6YTBOI"), Data("foobar".utf8), "decode foobar")
equal(Base32.decode("mzxw 6ytb-oi======"), Data("foobar".utf8), "lenient decode")
equal(Base32.encode(Data("foobar".utf8)), "MZXW6YTBOI", "encode foobar")
check(Base32.decode("not base32!") == nil, "invalid chars rejected")

// MARK: RFC 6238 test vectors (Appendix B)

let seeds: [OTPAlgorithm: String] = [
    .sha1: "12345678901234567890",
    .sha256: "12345678901234567890123456789012",
    .sha512: "1234567890123456789012345678901234567890123456789012345678901234",
]
let vectors: [(Double, OTPAlgorithm, String)] = [
    (59, .sha1, "94287082"), (59, .sha256, "46119246"), (59, .sha512, "90693936"),
    (1111111109, .sha1, "07081804"), (1111111109, .sha256, "68084774"), (1111111109, .sha512, "25091201"),
    (1234567890, .sha1, "89005924"), (1234567890, .sha256, "91819424"), (1234567890, .sha512, "93441116"),
    (20000000000, .sha1, "65353130"), (20000000000, .sha256, "77737706"), (20000000000, .sha512, "47863826"),
]
for (time, alg, expected) in vectors {
    let token = Token(name: "t", secret: Base32.encode(Data(seeds[alg]!.utf8)), algorithm: alg, digits: 8)
    equal(token.code(at: Date(timeIntervalSince1970: time)), expected, "TOTP \(alg) @\(Int(time))")
}

// MARK: RFC 4226 HOTP vectors

let hotpExpected = ["755224", "287082", "359152", "969429", "338314"]
for (counter, expected) in hotpExpected.enumerated() {
    let token = Token(name: "h", secret: Base32.encode(Data("12345678901234567890".utf8)), kind: .hotp, counter: UInt64(counter))
    equal(token.code(), expected, "HOTP counter \(counter)")
}

// MARK: Helpers

equal("123456".otpGrouped, "123 456", "group 6")
equal("12345678".otpGrouped, "1234 5678", "group 8")
let t30 = Token(name: "x", secret: "JBSWY3DPEHPK3PXP")
equal(t30.secondsRemaining(at: Date(timeIntervalSince1970: 61)), 29, "seconds remaining")

// MARK: otpauth://

do {
    let t = try OTPAuthURI.parse("otpauth://totp/ACME%20Co:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME%20Co&algorithm=SHA256&digits=8&period=60")
    equal(t.name, "ACME Co", "uri name")
    equal(t.account, "john@example.com", "uri account")
    equal(t.algorithm, .sha256, "uri algorithm")
    equal(t.digits, 8, "uri digits")
    equal(t.period, 60, "uri period")

    let h = try OTPAuthURI.parse("otpauth://hotp/Foo?secret=JBSWY3DPEHPK3PXP&counter=7")
    equal(h.kind, .hotp, "hotp kind")
    equal(h.counter, 7, "hotp counter")

    let back = try OTPAuthURI.parse(OTPAuthURI.make(t))
    equal(back.secret, t.secret, "uri round trip secret")
    equal(back.account, t.account, "uri round trip account")
} catch {
    check(false, "otpauth parsing threw \(error)")
}
equal(Result { try OTPAuthURI.parse("otpauth://totp/x?issuer=y") }.inputError, .missingSecret, "missing secret")
equal(Result { try TokenInput.parse("jbsw y3dp ehpk 3pxp", fallbackName: "Raw") }.value?.secret, "JBSWY3DPEHPK3PXP", "raw secret")

// MARK: 2FAS

if let sampleEncrypted = fixture("encrypted_test.2fas") {
    // A real export from the 2FAS Android app (password "example.com").
    check(TwoFAS.isEncrypted(sampleEncrypted), "fixture is encrypted")
    equal(Result { try TwoFAS.decode(sampleEncrypted) }.twoFASError, .passwordRequired, "password required")
    equal(Result { try TwoFAS.decode(sampleEncrypted, password: "wrong") }.twoFASError, .wrongPassword, "wrong password")
    equal(try TwoFAS.decryptReference(sampleEncrypted, password: "example.com"), TwoFAS.referencePlaintext,
          "reference constant matches a real 2FAS export")

    do {
        let backup = try TwoFAS.decode(sampleEncrypted, password: "example.com")
        check(!backup.tokens.isEmpty, "decrypted tokens")
        check(backup.tokens.allSatisfy(\.isValid), "all tokens valid")
        print("  fixture tokens: \(backup.tokens.map(\.name).joined(separator: ", "))")

        // Plain round trip keeps every field.
        let plain = try TwoFAS.encode(backup)
        let again = try TwoFAS.decode(plain)
        equal(again.tokens.map(\.secret), backup.tokens.map(\.secret), "plain round trip secrets")
        equal(again.tokens.map(\.name), backup.tokens.map(\.name), "plain round trip names")
        equal(again.tokens.map { $0.extra?["icon"] }, backup.tokens.map { $0.extra?["icon"] }, "icons preserved")
        equal(again.groups, backup.groups, "groups preserved")

        // Encrypted round trip.
        let enc = try TwoFAS.encode(backup, password: "hunter2")
        check(TwoFAS.isEncrypted(enc), "export is encrypted")
        equal(try TwoFAS.decryptReference(enc, password: "hunter2"), TwoFAS.referencePlaintext, "export reference")
        equal(try TwoFAS.decode(enc, password: "hunter2").tokens.map(\.secret), backup.tokens.map(\.secret), "encrypted round trip")
        equal(Result { try TwoFAS.decode(enc, password: "nope") }.twoFASError, .wrongPassword, "export wrong password")

        // Integers stay integers in exported JSON.
        let json = String(decoding: plain, as: UTF8.self)
        check(json.contains("\"schemaVersion\":4"), "schemaVersion is an integer")
    } catch {
        check(false, "2FAS fixture threw \(error)")
    }
} else {
    skippedSuites.append("2FAS real export")
}

// New token without 2FAS metadata exports required fields.
do {
    let fresh = try TwoFAS.encode(.init(tokens: [Token(name: "GitHub", account: "me", secret: "JBSWY3DPEHPK3PXP")]))
    let root = try JSONDecoder().decode(JSONValue.self, from: fresh)
    let s = root["services"]?.array?.first
    check(s?["updatedAt"]?.int != nil, "fresh: updatedAt")
    equal(s?["order"]?["position"]?.int, 0, "fresh: order")
    equal(s?["otp"]?["tokenType"]?.string, "TOTP", "fresh: tokenType")
}

// MARK: Icons

do {
    // Vaults saved before icons existed still decode.
    let old = try JSONEncoder().encode(Token(name: "Old", secret: "JBSWY3DPEHPK3PXP"))
    var dict = try JSONSerialization.jsonObject(with: old) as! [String: Any]
    dict.removeValue(forKey: "icon")
    let decoded = try JSONDecoder().decode(Token.self, from: JSONSerialization.data(withJSONObject: dict))
    check(decoded.icon == nil, "token without icon field decodes")

    // Custom icons are not written into 2FAS backups.
    let png = Data(repeating: 0xAB, count: 64)
    let withIcon = Token(name: "Iconic", secret: "JBSWY3DPEHPK3PXP", icon: png)
    let exported = try TwoFAS.encode(.init(tokens: [withIcon]))
    check(!String(decoding: exported, as: UTF8.self).contains(png.base64EncodedString()), "icon data not exported to 2FAS")
    equal(try JSONDecoder().decode(Token.self, from: JSONEncoder().encode(withIcon)).icon, png, "icon persists in vault encoding")
}

// MARK: Aegis icon pack

do {
    let manifest = """
    {"uuid":"u","name":"Test Pack","version":3,"icons":[
      {"name":"Google","filename":"icons/Google.svg","category":null,"issuer":["Google"]},
      {"name":"Google Cloud","filename":"icons/GoogleCloud.svg","issuer":["Google Cloud"]},
      {"name":"GitHub","filename":"icons/GitHub.svg","category":"Dev","issuer":["GitHub","github.com"]},
      {"filename":"icons/EA.svg","issuer":["EA"]},
      {"name":"Mail","filename":"icons/Mail.svg","issuer":["Mail"]},
      {"name":"NoIssuer","filename":"icons/x.svg"}
    ]}
    """
    let pack = try IconPack.decode(Data(manifest.utf8))
    equal(pack.icons.count, 6, "pack decodes (null category, missing issuer)")
    equal(pack.bestMatch(name: "github", issuer: nil)?.name, "GitHub", "exact match, case-insensitive")
    equal(pack.bestMatch(name: "Work", issuer: "GitHub.com")?.name, "GitHub", "issuer domain match")
    equal(pack.bestMatch(name: "Google Workspace", issuer: nil)?.name, "Google", "partial match")
    equal(pack.bestMatch(name: "Google Cloud Console", issuer: nil)?.name, "Google Cloud", "longest partial wins")
    check(pack.bestMatch(name: "Seattle", issuer: nil) == nil, "short keys (EA) don't partial-match")
    equal(pack.bestMatch(name: "EA", issuer: nil)?.filename, "icons/EA.svg", "short keys still match exactly")
    equal(pack.search("goo").map(\.displayName), ["Google", "Google Cloud"], "search by prefix")
    equal(pack.search("").count, 6, "empty search lists all")
    equal(pack.bestMatch(name: "accounts.google.com", issuer: nil)?.name, "Google", "match a later word")
    check(pack.bestMatch(name: "Gmail", issuer: nil) == nil, "no match inside a word (Gmail ≠ Mail)")
}

// MARK: Simple Icons

do {
    let metadata = """
    [
      {"title":"GitHub","slug":"github","source":"https://github.com/logos"},
      {"title":"Google","slug":"google","source":"https://about.google/"},
      {"title":"Discord","slug":"discord","source":"https://discord.com/"},
      {"title":"Cloudflare","slug":"cloudflare","source":"https://cloudflare.com/"},
      {"title":"Codeberg","slug":"codeberg","source":"https://codeberg.org/"},
      {"title":"SourceHut","slug":"sourcehut","source":"https://sourcehut.org/"},
      {"title":"Bluesky","slug":"bluesky","aliases":{"aka":["bsky"]}},
      {"title":"X","slug":"x","aliases":{"aka":["Twitter"]}},
      {"title":"Graphite","slug":"graphite"},
      {"title":"Graphite Editor","slug":"graphite_editor","aliases":{"aka":["Graphite"]}}
    ]
    """
    let catalog = try SimpleIconsCatalog(data: Data(metadata.utf8))
    let github = catalog.search("Git Hub", limit: 1).first
    equal(github?.slug, "github", "catalog search ranks exact normalized matches first")
    equal(github?.downloadURL.lastPathComponent, "github.svg", "catalog produces a single SVG URL")
    equal(SimpleIconsCatalog.catalogURL.deletingLastPathComponent().deletingLastPathComponent(),
          github?.downloadURL.deletingLastPathComponent().deletingLastPathComponent(),
          "metadata and SVGs use the same pinned package")
    equal(catalog.search("bsky", limit: 1).first?.slug, "bluesky", "catalog search includes upstream aliases")
    equal(catalog.search("", limit: 10).count, 0, "empty query shows no results")
    let invalid = Data(#"[{"title":"Invalid","slug":"../icon"}]"#.utf8)
    check((try? SimpleIconsCatalog(data: invalid)) == nil, "catalog rejects slugs outside the icon namespace")
    equal(catalog.suggestedIcon(name: "Work", issuer: " Codeberg.org ")?.slug, "codeberg",
          "automatic match accepts an exact issuer domain")
    equal(catalog.suggestedIcon(name: "SourceHut", issuer: nil)?.slug, "sourcehut",
          "automatic match uses the name if there is no issuer")
    equal(catalog.suggestedIcon(name: "Codeberg", issuer: "Example Unknown Service")?.slug, "codeberg",
          "automatic match falls back to the display name when the issuer is unknown")
    equal(catalog.suggestedIcon(name: "GitHub", issuer: "Discord")?.slug, "discord",
          "an identified issuer takes precedence over the display name")
    check(catalog.suggestedIcon(name: "Codeberg clone", issuer: nil) == nil,
          "automatic match rejects partial names")
    check(catalog.suggestedIcon(name: "Graphite", issuer: nil) == nil,
          "automatic match rejects a name shared by two logos")
    equal(catalog.suggestedIcon(name: "GitHub", issuer: nil)?.slug, "github",
          "ordinary brand names can appear as suggestions")
    equal(catalog.suggestedIcon(name: "Work", issuer: "https://accounts.google.com")?.slug, "google",
          "an issuer subdomain matches a known service domain")
    equal(catalog.suggestedIcon(name: "Twitter", issuer: nil)?.slug, "x",
          "an unambiguous upstream alias matches")

    let codeberg = Token(name: "Codeberg", secret: "JBSWY3DPEHPK3PXP")
    let codebergWork = Token(name: "Work", issuer: "codeberg.org", secret: "JBSWY3DPEHPK3PXP")
    let sourcehut = Token(name: "SourceHut", secret: "JBSWY3DPEHPK3PXP")
    let custom = Token(name: "Codeberg", secret: "JBSWY3DPEHPK3PXP", icon: Data([1]))
    let suggestions = catalog.suggestions(for: [sourcehut, codeberg, codebergWork, custom])
    equal(suggestions.map(\.id), ["codeberg", "sourcehut"], "batch suggestions contain one row per distinct logo")
    equal(suggestions.first?.tokenIDs, [codeberg.id, codebergWork.id], "batch suggestions preserve matched IDs and skip custom artwork")

    let services = [
        Token(name: "Work account", issuer: "github.com", secret: "JBSWY3DPEHPK3PXP"),
        Token(name: "Discord", secret: "JBSWY3DPEHPK3PXP"),
        Token(name: "Cloudflare", issuer: "Uncatalogued SSO", secret: "JBSWY3DPEHPK3PXP"),
    ]
    let twoFAS = try TwoFAS.encode(.init(tokens: services))
    let imported = try Importer.decode(twoFAS).1.tokens
    equal(catalog.suggestions(for: imported).map(\.id), ["cloudflare", "discord", "github"],
          "common 2FAS services appear in the batch icon review")
}

// MARK: SVG path normalization

equal(SVGPathFixer.normalize(path: "M1 2a10 10 0 00-7.88 3.7"), "M 1 2 a 10 10 0 0 0 -7.88 3.7", "compact arc flags split")
equal(SVGPathFixer.normalize(path: "a.2612.2612 0 11.316.416"), "a .2612 .2612 0 1 1 .316 .416", "flags touching a decimal")
equal(SVGPathFixer.normalize(path: "M0,0L1e-3-2.5z"), "M 0 0 L 1e-3 -2.5 z", "exponents and signs")
equal(SVGPathFixer.normalize(path: "a1 1 0 0 1 2 2 1 1 0 102 2"), "a 1 1 0 0 1 2 2 1 1 0 1 0 2 2", "repeated arc arguments")
equal(SVGPathFixer.normalize(path: "M1 2 Q #"), "M1 2 Q #", "unparseable input unchanged")
check(SVGPathFixer.normalize(svg: #"<svg><path d="M0 0a1 1 0 011 1" fill="white"/></svg>"#)
        == #"<svg><path d="M 0 0 a 1 1 0 0 1 1 1" fill="white"/></svg>"#, "normalizes d attributes in a document")

// MARK: Favicon

equal(Favicon.guessDomain(name: "Plurk", issuer: "Plurk"), "plurk.com", "guess from name")
equal(Favicon.guessDomain(name: "Work", issuer: "GitHub.com"), "github.com", "issuer that is a domain")
equal(Favicon.guessDomain(name: "Air Canada", issuer: nil), "aircanada.com", "multi-word guess")
equal(Favicon.normalizeDomain("https://www.plurk.com/login?x=1"), "www.plurk.com", "strip scheme and path")
equal(Favicon.normalizeDomain("  GitHub.com/ "), "github.com", "trim and lowercase")
check(Favicon.normalizeDomain("not a domain") == nil, "spaces rejected")
check(Favicon.normalizeDomain("localhost") == nil, "needs a dot")
check(Favicon.normalizeDomain("evil.com/../x?y") == "evil.com", "only the host is used")
check(Favicon.normalizeDomain("a..com") == nil, "empty label rejected")
equal(Favicon.urls(for: "plurk.com").map(\.absoluteString),
      ["https://icons.duckduckgo.com/ip3/plurk.com.ico", "https://icons.duckduckgo.com/ip3/www.plurk.com.ico"], "www fallback")
equal(Favicon.urls(for: "www.google.com").last?.absoluteString, "https://icons.duckduckgo.com/ip3/google.com.ico", "www removed")

// MARK: Groups

do {
    let work = TokenGroup(id: "g-work", name: "Work", isExpanded: false)
    let a = Token(name: "GitHub", secret: "JBSWY3DPEHPK3PXP", groupId: work.id)
    let b = Token(name: "Plurk", secret: "JBSWY3DPEHPK3PXQ")
    let data = try TwoFAS.encode(.init(tokens: [a, b], groups: [work]))
    let root = try JSONDecoder().decode(JSONValue.self, from: data)
    let g = root["groups"]?.array?.first
    equal(g?["name"]?.string, "Work", "group exported")
    equal(g?["isExpanded"]?.bool, false, "group expanded state exported")
    check(g?["updatedAt"]?.int != nil, "group updatedAt exported")
    let services = root["services"]?.array ?? []
    equal(services.first?["groupId"]?.string, "g-work", "token groupId exported")
    check(services.last?["groupId"] == .null, "ungrouped token exports null groupId")
    check(services.allSatisfy { s in ["badge", "icon", "serviceTypeID"].allSatisfy { s[$0] != nil } },
          "required nullable 2FAS keys always present")

    let back = try TwoFAS.decode(data)
    equal(back.groups, [work], "groups round trip")
    equal(back.tokens.map(\.groupId), ["g-work", nil], "token groups round trip")

    // A token pointing at an undefined group becomes ungrouped.
    var orphan = try JSONDecoder().decode(JSONValue.self, from: data)
    orphan["groups"] = .array([])
    let fixed = try TwoFAS.decode(JSONEncoder().encode(orphan))
    check(fixed.tokens.allSatisfy { $0.groupId == nil }, "orphan groupId dropped")
}

// MARK: scrypt (RFC 7914 test vectors)

equal(CryptoUtil_scryptHex("", "", 16, 1, 1),
      "77d6576238657b203b19ca42c18a0497f16b4844e3074ae8dfdffa3fede21442fcd0069ded0948f8326a753a0fc81f17e8d3e0fb2e0d3628cf35e20c38d18906", "scrypt vector 1")
equal(CryptoUtil_scryptHex("password", "NaCl", 1024, 8, 16),
      "fdbabe1c9d3472007856e7190d01e9fe7c6ad7cbc8237830e77376634b3731622eaf30d92e22a3886ff109279d9830dac727afb94a83ee6d8360cbdfa2cc0640", "scrypt vector 2")

// MARK: Aegis / Ente imports (fixtures from Aegis's own importer tests)

if let plain = fixture("aegis_plain.json"), let encrypted = fixture("aegis_encrypted.json"),
   let ente = fixture("ente_auth.txt") {
  do {
    equal(Importer.detect(plain), .aegis, "detect Aegis plain")
    equal(Importer.detect(encrypted), .aegis, "detect Aegis encrypted")
    equal(Importer.detect(ente), .ente, "detect Ente")
    check(Importer.needsPassword(encrypted) && !Importer.needsPassword(plain), "Aegis needsPassword")

    let (_, a) = try Importer.decode(plain)
    print("  Aegis plain: \(a.tokens.count) tokens, skipped \(a.skipped)")
    check(!a.tokens.isEmpty && a.tokens.allSatisfy(\.isValid), "Aegis plain tokens valid")
    equal(Result { try Importer.decode(encrypted) }.twoFASError, .passwordRequired, "Aegis needs password")
    equal(Result { try Importer.decode(encrypted, password: "wrong") }.twoFASError, .wrongPassword, "Aegis wrong password")
    let (_, ae) = try Importer.decode(encrypted, password: "test")
    equal(ae.tokens.map(\.secret), a.tokens.map(\.secret), "Aegis encrypted == plain")

    let (_, e) = try Importer.decode(ente)
    print("  Ente: \(e.tokens.count) tokens, skipped \(e.skipped)")
    let key = { (t: Token) in "\(t.issuer ?? "")|\(t.account ?? "")|\(t.secret)|\(t.kind)|\(t.algorithm)|\(t.digits)|\(t.period)|\(t.counter)" }
    equal(Set(e.tokens.map(key)), Set(a.tokens.map(key)), "Ente and Aegis fixtures import the same tokens")
    check(e.tokens.contains { $0.issuer == "Air Canada" }, "'+' decoded as space")
    check(e.tokens.contains { $0.kind == .steam && $0.digits == 5 }, "Steam via otpauth://steam")
  } catch {
    check(false, "Aegis/Ente fixtures threw \(error)")
  }
} else {
    skippedSuites.append("Aegis/Ente real exports")
}

do {
    // Aegis v3 groups and Ente tags become groups; trashed Ente codes are skipped.
    let v3 = """
    {"version":1,"header":{"slots":null,"params":null},"db":{"version":3,
     "entries":[{"type":"totp","uuid":"e1","name":"me","issuer":"GitHub","info":{"secret":"JBSWY3DPEHPK3PXP","algo":"SHA1","digits":6,"period":30},"groups":["g1"]},
                {"type":"yandex","uuid":"e2","name":"me","issuer":"Yandex","info":{"secret":"JBSWY3DPEHPK3PXP","algo":"SHA256","digits":8,"period":30,"pin":"1234"}}],
     "groups":[{"uuid":"g1","name":"Work"}]}}
    """
    let (_, b) = try Importer.decode(Data(v3.utf8))
    equal(b.groups.map(\.name), ["Work"], "Aegis v3 groups")
    equal(b.tokens.first?.groupId, "g1", "Aegis entry group")
    equal(b.skipped.count, 1, "Yandex skipped")

    let tags = #"otpauth://totp/X:a?secret=JBSWY3DPEHPK3PXP&issuer=X&codeDisplay=%7B%22trashed%22%3Afalse%2C%22tags%22%3A%5B%22Work%22%5D%7D"#
        + "\n" + #"otpauth://totp/Y:b?secret=JBSWY3DPEHPK3PXP&issuer=Y&codeDisplay=%7B%22trashed%22%3Atrue%7D"#
    let (_, t) = try Importer.decode(Data(tags.utf8))
    equal(t.tokens.map(\.name), ["X"], "trashed Ente code skipped")
    equal(t.groups.map(\.name), ["Work"], "Ente tag becomes group")
    equal(t.tokens.first?.groupId, t.groups.first?.id, "Ente token in tag group")

    let enc = #"{"version":1,"kdfParams":{"memLimit":1,"opsLimit":1,"salt":"x"},"encryptedData":"x","encryptionNonce":"x"}"#
    check({ if case .unsupported = Result(catching: { try Importer.decode(Data(enc.utf8)) }).twoFASError { return true }; return false }(),
          "encrypted Ente explains it is unsupported")
    equal(try OTPAuthURI.parse("otpauth://totp/A?secret=JBSWY3DPEHPK3PXP&issuer=C%2B%2B+Club").issuer, "C++ Club", "%2B stays a plus")
} catch {
    check(false, "group/tag imports threw \(error)")
}

// MARK: Export to Aegis / Ente (round trip through our importers)

do {
    let work = TokenGroup(id: "2fas-group-1", name: "Work & Play")   // not a UUID, like 2FAS ids
    let tokens = [
        Token(name: "GitHub", issuer: "GitHub", account: "me@x.com", secret: "JBSWY3DPEHPK3PXP", groupId: work.id),
        Token(name: "C++ Club", issuer: "C++ Club", account: "a b", secret: "JBSWY3DPEHPK3PXQ", algorithm: .sha256, digits: 8, period: 60),
        Token(name: "Bank", issuer: "Bank", account: "x", secret: "JBSWY3DPEHPK3PXR", kind: .hotp, counter: 42),
        Token(name: "Steam", issuer: "Steam", account: "gamer", secret: "JBSWY3DPEHPK3PXS", kind: .steam, icon: Data([1, 2, 3])),
    ]
    let backup = TwoFAS.Backup(tokens: tokens, groups: [work])
    let key = { (t: Token) in "\(t.issuer ?? "")|\(t.account ?? "")|\(t.secret)|\(t.kind)|\(t.algorithm)|\(t.digits)|\(t.period)|\(t.counter)" }
    let groupName = { (b: TwoFAS.Backup, t: Token) in b.groups.first { $0.id == t.groupId }?.name }

    for format in [BackupFormat.twoFAS, .aegis, .ente] {
        let (detected, back) = try Importer.decode(Exporter.encode(backup, as: format))
        equal(detected, format, "\(format.rawValue) export detected")
        equal(back.tokens.map(key), tokens.map(key), "\(format.rawValue) export round trip")
        equal(back.tokens.map { groupName(back, $0) }, ["Work & Play", nil, nil, nil], "\(format.rawValue) groups round trip")
    }

    let twoFASEnc = try Exporter.encode(backup, as: .twoFAS, password: "hunter2")
    equal(Importer.detect(twoFASEnc), .twoFAS, "detect 2FAS")
    equal(try TwoFAS.decryptReference(twoFASEnc, password: "hunter2"), TwoFAS.referencePlaintext, "2FAS export reference")
    equal(try Importer.decode(twoFASEnc, password: "hunter2").1.tokens.map(key), tokens.map(key), "2FAS encrypted round trip")
    equal(Result { try Importer.decode(twoFASEnc, password: "nope") }.twoFASError, .wrongPassword, "2FAS export wrong password")

    let aegisPlain = try Exporter.encode(backup, as: .aegis)
    let aegisRoot = try JSONDecoder().decode(JSONValue.self, from: aegisPlain)
    let groupUUID = aegisRoot["db"]?["groups"]?.array?.first?["uuid"]?.string ?? ""
    check(UUID(uuidString: groupUUID) != nil, "Aegis group ids are UUIDs")
    equal(try Importer.decode(aegisPlain).1.tokens.last?.icon, Data([1, 2, 3]), "Aegis export keeps icons")

    let aegisEnc = try Exporter.encode(backup, as: .aegis, password: "hunter2")
    check(Importer.needsPassword(aegisEnc), "Aegis encrypted export needs a password")
    equal(try Importer.decode(aegisEnc, password: "hunter2").1.tokens.map(key), tokens.map(key), "Aegis encrypted round trip")
    equal(Result { try Importer.decode(aegisEnc, password: "nope") }.twoFASError, .wrongPassword, "Aegis export wrong password")

    let (linkFormat, links) = try Importer.decode(Exporter.encode(backup, as: .linkList))
    equal(linkFormat, .linkList, "otpauth link export detected")
    equal(links.tokens.map(key), tokens.map(key), "otpauth link export round trip")

    // Google: QR code links, read back by our importer. Steam and 60 s tokens can't go.
    let google = GoogleAuthenticator.encode(backup)
    equal(google.count, 1, "Google export: one QR code for a few tokens")
    let googleBack = try Importer.decode(Data(google.joined(separator: "\n").utf8)).1
    let googleKey = { (t: Token) in "\(t.issuer ?? "")|\(t.account ?? "")|\(t.secret)|\(t.kind)|\(t.algorithm)|\(t.digits)|\(t.counter)" }
    equal(googleBack.tokens.map(googleKey), tokens.filter(GoogleAuthenticator.canExport).map(googleKey), "Google export round trip")
    equal(Exporter.unsupported(tokens, in: .googleAuthenticator).map(\.name), ["C++ Club", "Steam"], "Google leaves out 60 s and Steam")
    let many = TwoFAS.Backup(tokens: (0..<23).map { Token(name: "S\($0)", secret: "JBSWY3DPEHPK3PXP") })
    let batches = GoogleAuthenticator.encode(many)
    equal(batches.count, 3, "Google export in batches of 10")
    equal(try batches.map { try Importer.decode(Data($0.utf8)).1.tokens.count }, [10, 10, 3], "each batch imports on its own")

    let (bwFormat, bw) = try Importer.decode(Exporter.encode(backup, as: .bitwarden))
    equal(bwFormat, .bitwarden, "Bitwarden export detected")
    equal(bw.tokens.map(key), tokens.filter { $0.kind != .hotp }.map(key), "Bitwarden export round trip (no HOTP)")
    equal(bw.tokens.map { groupName(bw, $0) }, ["Work & Play", nil, nil], "Bitwarden folders round trip")
    equal(Exporter.unsupported(tokens, in: .bitwarden).map(\.name), ["Bank"], "Bitwarden leaves out HOTP")

    let ente = String(decoding: try Exporter.encode(backup, as: .ente), as: UTF8.self)
    check(ente.contains("otpauth://steam/"), "Ente writes Steam as otpauth://steam")
    check(ente.contains("C%2B%2B"), "plus signs are percent-encoded")
} catch {
    check(false, "export round trips threw \(error)")
}

// MARK: BLAKE2b / Argon2id (RFC 7693, RFC 9106 test vectors)

equal(Blake2b_hex("abc"), "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923", "BLAKE2b-512 abc")
equal(Blake2b_hex(""), "786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce", "BLAKE2b-512 empty")
equal(Argon2_idHex(password: [UInt8](repeating: 1, count: 32), salt: [UInt8](repeating: 2, count: 16),
                   secret: [UInt8](repeating: 3, count: 8), ad: [UInt8](repeating: 4, count: 12), t: 3, m: 32, p: 4, length: 32),
      "0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659", "Argon2id RFC 9106 vector")

// MARK: Other apps (fixtures from Aegis's importer tests; all hold the same test accounts)

let tokenKey = { (t: Token) in "\(t.secret)|\(t.kind)|\(t.algorithm)|\(t.digits)|\(t.period)|\(t.counter)" }
if let reference = fixture("plain.txt").flatMap({ try? Importer.decode($0).1 }) {
    let expected = Set(reference.tokens.map(tokenKey))
    let cases: [(file: String, format: BackupFormat, password: String?)] = [
        ("andotp_plain.json", .andOTP, nil), ("andotp_encrypted.bin", .andOTP, "test"),
        ("bitwarden.json", .bitwarden, nil), ("bitwarden.csv", .passwordCSV, nil),
        ("freeotp_plus.json", .freeOTPPlus, nil),
        ("proton_authenticator.json", .proton, nil), ("proton_authenticator_encrypted.json", .proton, "test"),
        ("stratum_plain.json", .stratum, nil), ("stratum_encrypted.bin", .stratum, "test"),
        ("stratum_encrypted_legacy.bin", .stratum, "test"),
    ]
    for c in cases {
        guard let data = fixture(c.file) else { skippedSuites.append(c.file); continue }
        equal(Importer.detect(data), c.format, "\(c.file) detected")
        equal(Importer.needsPassword(data), c.password != nil, "\(c.file) needsPassword")
        do {
            if c.password != nil {
                equal(Result { try Importer.decode(data) }.twoFASError, .passwordRequired, "\(c.file) asks for a password")
                equal(Result { try Importer.decode(data, password: "wrong") }.twoFASError, .wrongPassword, "\(c.file) wrong password")
            }
            let started = Date()
            let (_, b) = try Importer.decode(data, password: c.password)
            let got = Set(b.tokens.map(tokenKey))
            // FreeOTP+ stores HOTP counters one lower than the others; compare those without the counter.
            let strip = { (s: String) in String(s[..<s.lastIndex(of: "|")!]) }
            if c.format == .freeOTPPlus {
                equal(Set(got.map(strip)), Set(expected.filter { !$0.contains("steam") }.map(strip)), "\(c.file) tokens")
            } else {
                check(!got.isEmpty && got.isSubset(of: expected), "\(c.file) tokens match the reference: \(got.subtracting(expected))")
            }
            check(b.tokens.allSatisfy(\.isValid), "\(c.file) tokens valid")
            if c.password != nil, c.format != .andOTP {
                print(String(format: "  %@: %d tokens, %.2fs", c.file, b.tokens.count, Date().timeIntervalSince(started)))
            }
        } catch {
            check(false, "\(c.file) threw \(error)")
        }
    }
    if let legacy = fixture("andotp_encrypted_old.bin") {
        equal(Result { try Importer.decode(legacy, password: "test") }.twoFASError, .wrongPassword,
              "legacy andOTP backup is rejected even with the correct password")
    } else {
        skippedSuites.append("andotp_encrypted_old.bin")
    }
    if let bw = fixture("bitwarden.json"), let b = try? Importer.decode(bw).1 {
        check(b.tokens.contains { $0.kind == .steam }, "Bitwarden steam:// imported")
        equal(b.tokens.first?.name, "Test 1", "Bitwarden item name is the token name")
    }
} else {
    skippedSuites.append("other apps' real exports")
}

do {
    // Google Authenticator migration payload, built by hand:
    // otp 1: secret "Hello!\xDE\xAD\xBE\xEF", name "Google:me@x.com", TOTP SHA1 6 digits;
    // otp 2: issuer "Bank", name "acct", HOTP SHA256 8 digits counter 5.
    func pb(_ n: Int, _ bytes: [UInt8]) -> [UInt8] { [UInt8(n << 3 | 2), UInt8(bytes.count)] + bytes }
    func pv(_ n: Int, _ v: UInt8) -> [UInt8] { [UInt8(n << 3), v] }
    let secret: [UInt8] = Array("Hello!".utf8) + [0xDE, 0xAD, 0xBE, 0xEF]
    let otp1 = pb(1, secret) + pb(2, Array("Google:me@x.com".utf8)) + pv(4, 1) + pv(5, 1) + pv(6, 2)
    let otp2 = pb(1, secret) + pb(2, Array("acct".utf8)) + pb(3, Array("Bank".utf8)) + pv(4, 2) + pv(5, 2) + pv(6, 1) + pv(7, 5)
    let payload = Data(pb(1, otp1) + pb(1, otp2) + pv(2, 1) + pv(3, 1))
    let encoded = payload.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    let link = "otpauth-migration://offline?data=\(encoded)"
    check(GoogleAuthenticator.isMigrationLink(link), "migration link recognized")
    let (format, g) = try Importer.decode(Data(link.utf8))
    equal(format, .googleAuthenticator, "Google detected")
    equal(g.tokens.map(\.name), ["Google", "Bank"], "Google names")
    equal(g.tokens.first?.account, "me@x.com", "issuer split from name")
    equal(g.tokens.first?.secret, Base32.encode(Data(secret)), "Google secret")
    equal(g.tokens.last?.kind, .hotp, "Google HOTP")
    equal(g.tokens.last?.algorithm, .sha256, "Google algorithm")
    equal(g.tokens.last?.digits, 8, "Google digits")
    equal(g.tokens.last?.counter, 5, "Google counter")
    equal(Result { try Importer.decode(Data("otpauth-migration://offline?data=%%%".utf8)) }.value?.1.tokens.count, nil, "bad migration data rejected")
} catch {
    check(false, "Google import threw \(error)")
}

do {
    // Apple Passwords / 1Password / KeePassXC style CSV, with quoting and rows without 2FA.
    let csv = "\u{FEFF}Title,URL,Username,Password,Notes,OTPAuth\r\n"
        + "GitHub,https://github.com,me,pw,,otpauth://totp/GitHub:me?secret=JBSWY3DPEHPK3PXP&issuer=GitHub\r\n"
        + "\"Bank, Inc.\",https://bank.com,\"a \"\"b\"\"\",pw,\"multi\nline\",JBSWY3DPEHPK3PXQ\r\n"
        + "NoTwoFA,https://x.com,me,pw,,\r\n"
    let (format, c) = try Importer.decode(Data(csv.utf8))
    equal(format, .passwordCSV, "CSV detected")
    equal(c.tokens.map(\.name), ["GitHub", "Bank, Inc."], "CSV names, rows without OTP ignored")
    equal(c.tokens.last?.account, "a \"b\"", "CSV quoted account")
    equal(c.tokens.last?.secret, "JBSWY3DPEHPK3PXQ", "CSV bare secret")

    let kp = "\"Group\",\"Title\",\"Username\",\"Password\",\"URL\",\"Notes\",\"TOTP\"\n\"Root/Work\",\"Mail\",\"me\",\"\",\"\",\"\",\"otpauth://totp/Mail:me?secret=JBSWY3DPEHPK3PXP\"\n"
    let k = try Importer.decode(Data(kp.utf8)).1
    equal(k.groups.map(\.name), ["Work"], "KeePassXC group path")

    let raivo = #"[{"issuer":"Raivo","account":"me","secret":"JBSWY3DPEHPK3PXP","algorithm":"SHA256","digits":"8","kind":"TOTP","timer":"60","counter":"0","pinned":"false","iconType":"","iconValue":""}]"#
    let (rf, r) = try Importer.decode(Data(raivo.utf8))
    equal(rf, .raivo, "Raivo JSON detected")
    equal(r.tokens.first.map(tokenKey), "JBSWY3DPEHPK3PXP|totp|sha256|8|60|0", "Raivo string fields")

    let stratumGroups = #"{"Authenticators":[{"Type":2,"Issuer":"A","Username":"u","Secret":"JBSWY3DPEHPK3PXP","Algorithm":0,"Digits":6,"Period":30,"Counter":0,"Ranking":1},{"Type":3,"Issuer":"M","Username":null,"Secret":"abc","Algorithm":0,"Digits":6,"Period":10,"Counter":0,"Ranking":0}],"Categories":[{"Id":"c1","Name":"Work","Ranking":0}],"AuthenticatorCategories":[{"CategoryId":"c1","AuthenticatorSecret":"JBSWY3DPEHPK3PXP","Ranking":0}],"CustomIcons":[]}"#
    let s = try Importer.decode(Data(stratumGroups.utf8)).1
    equal(s.groups.map(\.name), ["Work"], "Stratum categories")
    equal(s.tokens.first?.groupId, "c1", "Stratum token in category")
    equal(s.skipped.count, 1, "Stratum mOTP skipped")

    let enc = #"{"encrypted":true,"passwordProtected":true,"salt":"x","kdfType":0,"data":"x"}"#
    check({ if case .unsupported = Result(catching: { try Importer.decode(Data(enc.utf8)) }).twoFASError { return true }; return false }(),
          "encrypted Bitwarden explains it is unsupported")
} catch {
    check(false, "CSV/Raivo/Stratum imports threw \(error)")
}

// Raivo's real exports are AES-encrypted ZIPs; build one with 7-Zip when it's installed.
if let sevenZip = ["/opt/homebrew/bin/7z", "/usr/local/bin/7z", "/opt/homebrew/bin/7zz"].first(where: FileManager.default.isExecutableFile) {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("trayotp-raivo-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let json = "[" + (0..<40).map { #"{"issuer":"Site \#($0)","account":"me","secret":"JBSWY3DPEHPK3PXP","algorithm":"SHA1","digits":"6","kind":"TOTP","timer":"30","counter":"0"}"# }.joined(separator: ",") + "]"
    try? Data(json.utf8).write(to: dir.appendingPathComponent("raivo-otp-export.json"))
    for (level, label) in [("-mx0", "stored"), ("-mx9", "deflated")] {
        let zip = dir.appendingPathComponent("\(label).zip")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: sevenZip)
        p.arguments = ["a", "-tzip", "-mem=AES256", "-phunter2", level, zip.path, dir.appendingPathComponent("raivo-otp-export.json").path]
        p.standardOutput = FileHandle.nullDevice
        try? p.run(); p.waitUntilExit()
        guard let data = try? Data(contentsOf: zip) else { check(false, "7z \(label)"); continue }
        equal(Importer.detect(data), .raivo, "Raivo ZIP (\(label)) detected")
        check(Importer.needsPassword(data), "Raivo ZIP (\(label)) needs password")
        equal(Result { try Importer.decode(data, password: "nope") }.twoFASError, .wrongPassword, "Raivo ZIP (\(label)) wrong password")
        equal(Result { try Importer.decode(data, password: "hunter2") }.value?.1.tokens.count, 40, "Raivo ZIP (\(label)) tokens")
    }
} else {
    skippedSuites.append("Raivo ZIP (needs 7z)")
}

// Photos of QR codes must not be mistaken for andOTP's header-less encrypted backups.
for (name, header) in [("PNG", [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] as [UInt8]),
                       ("JPEG", [0xFF, 0xD8, 0xFF, 0xE0]),
                       ("HEIC", [0x00, 0x00, 0x00, 0x18] + Array("ftypheic".utf8))] {
    let file = Data(header + [UInt8](repeating: 0xC3, count: 64))
    check(Importer.detect(file) == nil, "\(name) image is not detected as a backup")
}
check(Importer.detect(Data([UInt8](repeating: 0xC3, count: 64))) == .andOTP, "other binary data may be andOTP")

// MARK: Colors typed or pasted for icon backgrounds

equal(HexColor(parsing: "#1E90FF")?.hex, "#1E90FF", "hex color")
equal(HexColor(parsing: " 1e90ff ")?.hex, "#1E90FF", "hex without #")
equal(HexColor(parsing: "#19F")?.hex, "#1199FF", "short hex")
equal(HexColor(parsing: "rgb(30, 144, 255)")?.hex, "#1E90FF", "rgb()")
equal(HexColor(parsing: "30,144,255")?.hex, "#1E90FF", "comma list")
equal(HexColor(parsing: "30 144 255")?.hex, "#1E90FF", "space list")
check(HexColor(parsing: "300, 0, 0") == nil && HexColor(parsing: "#12345") == nil && HexColor(parsing: "blue") == nil,
      "bad colors rejected")

// MARK: Master password

do {
    let key = Data((0..<32).map { UInt8($0) })
    let blob = try MasterPassword.wrap(key, password: "correct horse", n: 1 << 10)
    check(MasterPassword.isWrapped(blob), "wrapped blob recognized")
    check(!MasterPassword.isWrapped(key), "raw 32-byte key is not wrapped")
    equal(try MasterPassword.unwrap(blob, password: "correct horse"), key, "unwrap with right password")
    equal(Result { try MasterPassword.unwrap(blob, password: "wrong") }.masterError, .wrongPassword, "wrong master password")
    check(try MasterPassword.wrap(key, password: "x", n: 1 << 10) != MasterPassword.wrap(key, password: "x", n: 1 << 10), "fresh salt each time")
    check(!String(decoding: blob, as: UTF8.self).contains(key.base64EncodedString()), "key not stored in the clear")

    let started = Date()
    let strong = try MasterPassword.wrap(key, password: "p")
    _ = try MasterPassword.unwrap(strong, password: "p")
    print(String(format: "  default master-password scrypt: %.2fs per wrap+unwrap", Date().timeIntervalSince(started)))
}

extension Result where Failure == Error {
    var masterError: MasterPassword.Error? { if case .failure(let e) = self { return e as? MasterPassword.Error }; return nil }
}

// MARK: Export password

do {
    let verifier = try ExportPassword.makeVerifier(password: "correct horse", n: 1 << 10)
    check(ExportPassword.verify(verifier, password: "correct horse"), "export password accepted")
    check(!ExportPassword.verify(verifier, password: "wrong"), "wrong export password rejected")
    check(!ExportPassword.verify(Data("junk".utf8), password: "correct horse"), "damaged verifier rejected")
    check(try ExportPassword.makeVerifier(password: "x", n: 1 << 10) != ExportPassword.makeVerifier(password: "x", n: 1 << 10),
          "fresh salt each time")
}

// MARK: Done

extension Result where Failure == Error {
    var value: Success? { try? get() }
    var twoFASError: TwoFAS.Error? { if case .failure(let e) = self { return e as? TwoFAS.Error }; return nil }
}
extension Result where Failure == Error {
    var inputError: TokenInputError? { if case .failure(let e) = self { return e as? TokenInputError }; return nil }
}

// MARK: Updates

check(AppVersion("v0.10.0")! > AppVersion("0.9.3")!, "versions compare numerically, not as text")
check(AppVersion("1.0")! == AppVersion("v1.0.0")!, "missing components count as zero")
check(AppVersion("0.2.0-beta.1")! < AppVersion("0.2.0")!, "a pre-release is older than its release")
check(AppVersion("0.2.0-beta.1")! > AppVersion("0.1.9")!, "a pre-release is newer than the previous release")
check(AppVersion("1.0.0-beta.2")! < AppVersion("1.0.0-beta.10")!, "numeric pre-release parts compare as numbers")
check(AppVersion("1.0.0-alpha")! < AppVersion("1.0.0-beta")! && AppVersion("1.0.0-beta")! < AppVersion("1.0.0-beta.1")!,
      "pre-release parts compare as text, and more parts is newer")
check(AppVersion("v1.0.0-beta.1")!.description == "1.0.0-beta.1", "description keeps the pre-release")
check(AppVersion("1.0.0-") == nil && AppVersion("1.0.0-beta..1") == nil, "empty pre-release parts are rejected")
check(AppVersion("0.1.0")! < AppVersion("0.1.1")!, "patch bump is newer")
check(AppVersion("") == nil && AppVersion("latest") == nil && AppVersion("1..2") == nil, "junk is rejected")

let releaseJSON = Data("""
{"tag_name":"v0.2.0","html_url":"https://github.com/outerstudio/trayotp/releases/tag/v0.2.0","body":"Notes",
 "assets":[{"name":"TrayOTP-v0.2.0.zip.sha256","browser_download_url":"https://example.com/a.sha256"},
           {"name":"TrayOTP-v0.2.0.zip","browser_download_url":"https://example.com/a.zip"}]}
""".utf8)
let release = try? JSONDecoder().decode(Release.self, from: releaseJSON)
equal(release?.version?.description, "0.2.0", "release version")
equal(release?.zip?.name, "TrayOTP-v0.2.0.zip", "zip asset")
equal(release?.checksum?.name, "TrayOTP-v0.2.0.zip.sha256", "checksum asset")
let digest = String(repeating: "ab", count: 32)
equal(Release.parseChecksum("\(digest.uppercased())  TrayOTP-v0.2.0.zip\n"), digest, "checksum line parsed")
check(Release.parseChecksum("not a hash") == nil, "bad checksum rejected")

equal(UpdateChannel(AppVersion("1.1.3")!), .stable, "a release is stable")
equal(UpdateChannel(AppVersion("1.1.2-beta")!), .beta, "beta suffix")
equal(UpdateChannel(AppVersion("1.1.2-RC.1")!), .beta, "a release candidate is beta")
equal(UpdateChannel(AppVersion("1.1.1-alpha.2")!), .alpha, "alpha suffix")
equal(UpdateChannel(AppVersion("1.1.1-nightly")!), .alpha, "an unknown suffix is alpha")

func releases(_ tags: [String]) -> [Release] {
    tags.compactMap { tag in
        try? JSONDecoder().decode(Release.self, from: Data("""
        {"tag_name":"\(tag)","html_url":"https://github.com/outerstudio/trayotp/releases/tag/\(tag)","assets":[]}
        """.utf8))
    }
}
func newest(_ channel: UpdateChannel, from current: String, _ tags: [String]) -> String? {
    channel.newest(of: releases(tags), after: AppVersion(current)!)?.tag
}
// Alpha on 1.1.1-alpha takes a newer beta or release.
equal(newest(.alpha, from: "v1.1.1-alpha", ["v1.1.2-beta"]), "v1.1.2-beta", "alpha takes a newer beta")
equal(newest(.alpha, from: "v1.1.1-alpha", ["v1.1.3"]), "v1.1.3", "alpha takes a newer release")
equal(newest(.alpha, from: "v1.1.1-alpha", ["v1.1.2-beta", "v1.1.3", "v1.1.0"]), "v1.1.3", "alpha takes the newest of all")
// Beta on 1.1.2-beta skips alphas, old or new, and takes newer releases and betas.
equal(newest(.beta, from: "v1.1.2-beta", ["v1.1.1-alpha"]), nil, "beta skips an older alpha")
equal(newest(.beta, from: "v1.1.2-beta", ["v1.1.3-alpha"]), nil, "beta skips a newer alpha")
equal(newest(.beta, from: "v1.1.2-beta", ["v1.1.3"]), "v1.1.3", "beta takes a newer release")
equal(newest(.beta, from: "v1.1.2-beta", ["v1.1.4-beta"]), "v1.1.4-beta", "beta takes a newer beta")
equal(newest(.beta, from: "v1.1.2-beta", ["v1.1.3", "v1.1.4-beta", "v1.1.5-alpha"]), "v1.1.4-beta",
      "beta takes the newest beta or release, not the newer alpha")
// Stable takes releases only, and never goes back.
equal(newest(.stable, from: "v1.1.2-beta", ["v1.1.1", "v1.1.3-beta"]), nil, "stable skips pre-releases and older releases")
equal(newest(.stable, from: "v1.1.2-beta", ["v1.1.2", "v1.1.3-beta"]), "v1.1.2", "stable takes the release of a beta")
equal(newest(.stable, from: "v1.1.3", ["v1.1.3", "not-a-version"]), nil, "the same version and junk tags are skipped")

if !skippedSuites.isEmpty {
    print("  skipped (run Scripts/fetch-test-fixtures.sh): \(skippedSuites.joined(separator: ", "))")
}
print(failures == 0 ? "✓ \(passes) checks passed" : "\(failures) failed, \(passes) passed")
exit(failures == 0 ? 0 : 1)
