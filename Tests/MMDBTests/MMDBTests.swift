import XCTest
import MMDB

class MMDBTests: XCTestCase {

    func testExample() throws {
        let db = try MMDB.open()
        XCTAssertEqual(try db.lookup(ip: "202.108.22.220")?.country()?.iso, "CN")
        XCTAssertEqual(try db.lookup(ip: "84.38.138.44")?.country()?.iso, "LV")

        XCTAssertNotNil(try db.lookup(ip: "1.1.1.1"))
        XCTAssertNotNil(try db.lookup(ip: "1.1.1.1"))

        XCTAssertEqual(try db.lookup(ip: "202.108.22.220")?.country()?.iso, "CN")
        XCTAssertEqual(try db.lookup(ip: "8.8.8.8")?.country()?.iso, "US")
        XCTAssertEqual(try db.lookup(ip: "8.8.4.4")?.country()?.iso, "US")

        XCTAssertNotNil(try db.lookup(ip: IPOfHost("youtube.com")!))
        XCTAssertNotNil(try db.lookup(ip: IPOfHost("facebook.com")!))
        XCTAssertNotNil(try db.lookup(ip: IPOfHost("twitter.com")!))
        XCTAssertNotNil(try db.lookup(ip: IPOfHost("instagram.com")!))
        XCTAssertNotNil(try db.lookup(ip: IPOfHost("google.com")!))

        XCTAssertEqual(try db.lookup(ip: "84.38.138.44")?.country()?.iso, "LV")
    }

    func testStates() throws {
        let db = try MMDB.open(kind: .city)
        XCTAssertEqual(try db.lookup(ip: "172.217.7.206")?.country()?.iso, "US")
        XCTAssertEqual(try db.lookup(ip: "72.229.28.185")?.country()?.iso, "US")
        XCTAssertEqual(try db.lookup(ip: "162.89.8.255")?.country()?.iso, "US")

        XCTAssertEqual(try? db.lookup(ip: "172.217.7.206")?.region()?.iso, nil)
        XCTAssertEqual(try db.lookup(ip: "72.229.28.185")?.region()?.iso, "NY")
        XCTAssertEqual(try db.lookup(ip: "162.89.8.255")?.region()?.iso, "TX")

        XCTAssertEqual(try db.lookup(ip: "15.207.13.28")?.region()?.iso, "MH")
        XCTAssertEqual(try db.lookup(ip: "84.38.138.44")?.region()?.iso, "RIX")
    }
}

private extension MMDB {
    enum Kind: String  {
        case city = "GeoLite2-City"
        case country = "GeoLite2-Country"
    }

    static func open(kind: Kind = .country) throws -> MMDB {
        let bundle = Bundle.module
        guard let fileURL = bundle.url(forResource: kind.rawValue, withExtension: "mmdb") else {
            fatalError("Missing file: \(kind.rawValue).mmdb")
        }

        return try MMDB(fileURL.path)
    }
}

//// See http://stackoverflow.com/questions/25890533/how-can-i-get-a-real-ip-address-from-dns-query-in-swift
func IPOfHost(_ host: String) -> String? {
    let host = CFHostCreateWithName(nil, host as CFString).takeRetainedValue()
    CFHostStartInfoResolution(host, .addresses, nil)
    var success = DarwinBoolean(false)
    guard let addressing = CFHostGetAddressing(host, &success) else {
        return nil
    }

    let addresses = addressing.takeUnretainedValue() as NSArray
    if addresses.count > 0 {
        let theAddress = addresses[0] as! Data
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let infoResult = getnameinfo(
            (theAddress as NSData).bytes.bindMemory(to: sockaddr.self, capacity: theAddress.count),
            socklen_t(theAddress.count),
            &hostname,
            socklen_t(hostname.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        if infoResult == 0 {
            if let numAddress = String(validatingUTF8: hostname) {
                return numAddress
            }
        }
    }

    return nil
}
