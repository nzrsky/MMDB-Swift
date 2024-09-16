//
//  Copyright(c) 2024, Alex Nazarov
//

import Foundation
import libmaxminddb

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public final class MMDB {

    public struct Country {
        public let iso: String
    }

    public struct Region {
        public let iso: String
    }

    public enum DataType: UInt32 {
        case extended = 0
        case pointer = 1
        case utf8String = 2
        case double = 3
        case bytes = 4
        case uint16 = 5
        case uint32 = 6
        case map = 7
        case int32 = 8
        case uint64 = 9
        case uint128 = 10
        case array = 11
        case container = 12
        case endMarker = 13
        case boolean = 14
        case float = 15
    }

    private var db = MMDB_s()

    public init(_ databasePath: String = Bundle.main.path(forResource: "GeoLite2-Country", ofType: "mmdb") ?? "") throws {
        let status = MMDB_open(databasePath, UInt32(MMDB_MODE_MMAP), &db)

        guard status == MMDB_SUCCESS else {
            printErrno(msg: "Failed to open database")
            throw MMDBError(rawValue: status) ?? .unknown
        }
    }

    deinit {
        MMDB_close(&db)
    }

    public func lookup(ip: String) throws -> LookupResult? {
        var gaiError: Int32 = 0
        var mmdbStatus: Int32 = 0

        let result = MMDB_lookup_string(&db, ip, &gaiError, &mmdbStatus)

        guard mmdbStatus == MMDB_SUCCESS else {
            guard gaiError == 0 else {
                printErr("error: getaddrinfo failed: \(String(validatingUTF8: gai_strerror(gaiError)) ?? "#\(gaiError)")")
                throw MMDB.GetAddrInfoError(int32: gaiError)
            }

            printErr("error: lookup failed: \(String(validatingUTF8: MMDB_strerror(mmdbStatus)) ?? "#\(mmdbStatus)")")
            throw MMDBError(rawValue: mmdbStatus) ?? .unknown
        }

        return result.found_entry ? try LookupResult(result) : nil
    }

    public class LookupResult {
        private var result: MMDB_lookup_result_s
        private var entryDataList: UnsafeMutablePointer<MMDB_entry_data_list_s>?

        init(_ result: MMDB_lookup_result_s) throws {
            self.result = result

            let status = MMDB_get_entry_data_list(&self.result.entry, &entryDataList)
            guard status == MMDB_SUCCESS else {
                printErr("error: lookup failed: \(String(validatingUTF8: MMDB_strerror(status)) ?? "#\(status)")")
                throw MMDB.MMDBError(rawValue: status) ?? .unknown
            }

            #if DEBUG
            try? dump()
            #endif
        }

        deinit {
            if entryDataList != nil {
                MMDB_free_entry_data_list(entryDataList)
            }
        }

        public struct Entry {
            private let entry: MMDB_entry_data_s

            init(value: MMDB_entry_data_s) {
                self.entry = value
            }

            func value<T: MMDBDataValue>() -> T? {
                entry.has_data ? T.value(from: entry) : nil
            }

            func value() -> Any? {
                DataType(rawValue: entry.type).flatMap {
                    switch $0 {
                    case .boolean:
                        value() as Bool?
                    case .int32:
                        value() as Int32?
                    case .uint32:
                        value() as UInt32?
                    case .uint16:
                        value() as UInt16?
                    case .uint64:
                        value() as UInt64?
                    case .float:
                        value() as Float?
                    case .double:
                        value() as Double?
                    case .pointer:
                        value() as UnsafePointer<Int32>?
                    case .utf8String:
                        value() as String?
                    case .extended:
                        { assertionFailure("unimplemented"); return nil }()
                    case .bytes:
                        { assertionFailure("unimplemented"); return nil }()
                    case .map:
                        { assertionFailure("unimplemented"); return nil }()
                    case .uint128:
                        { assertionFailure("unimplemented"); return nil }()
                    case .array:
                        { assertionFailure("unimplemented"); return nil }()
                    case .container:
                        { assertionFailure("unimplemented"); return nil }()
                    case .endMarker:
                        { assertionFailure("unimplemented"); return nil }()
                    }
                }
            }
        }
    }
}

extension MMDB.LookupResult: Sequence {
    public struct Iterator: IteratorProtocol {
        private var current: UnsafeMutablePointer<MMDB_entry_data_list_s>?

        init(start: UnsafeMutablePointer<MMDB_entry_data_list_s>?) {
            self.current = start
        }

        mutating public func next() -> Entry? {
            guard let currentEntry = current else { return nil }

            let entry = Entry(value: currentEntry.pointee.entry_data)
            current = currentEntry.pointee.next
            return entry
        }
    }

    public func makeIterator() -> Iterator {
        Iterator(start: entryDataList)
    }
}

extension MMDB.LookupResult {
    #if canImport(Darwin) || canImport(Glibc)
    public func dump() throws {
        let status = MMDB_dump_entry_data_list(stdout, entryDataList, 0)

        guard status == MMDB_SUCCESS else {
            printErrno(msg: "Failed to open database")
            throw MMDB.MMDBError(rawValue: status) ?? .unknown
        }
    }
    #endif

    public func country() throws -> MMDB.Country? {
        var entry = MMDB_entry_data_s()
        
        var pathKeys = allocPathKeys("country", "iso_code", nil)
        let status = MMDB_aget_value(&result.entry, &entry, &pathKeys)
        
        defer { deallocPathKeys(pathKeys) }

        guard status == MMDB_SUCCESS else {
            printErr("error: lookup failed: \(String(validatingUTF8: MMDB_strerror(status)) ?? "#\(status)")")
            throw MMDB.MMDBError(rawValue: status) ?? .unknown
        }

        guard let iso = Entry(value: entry).value() as? String else {
            return nil
        }

        return .init(iso: iso)
    }

    public func region() throws -> MMDB.Region? {
        var entry = MMDB_entry_data_s()
        
        var pathKeys = allocPathKeys("subdivisions", "0", "iso_code", nil)
        let status = MMDB_aget_value(&result.entry, &entry, &pathKeys)
        
        defer { deallocPathKeys(pathKeys) }

        guard status == MMDB_SUCCESS else {
            printErr("error: lookup failed: \(String(validatingUTF8: MMDB_strerror(status)) ?? "#\(status)")")
            throw MMDB.MMDBError(rawValue: status) ?? .unknown
        }

        guard let regionCode = Entry(value: entry).value() as? String else {
            return nil
        }

        return .init(iso: regionCode)
    }

    private func allocPathKeys(_ args: String?...) -> [UnsafePointer<CChar>?] {
        args.map { arg in arg.map { UnsafePointer<CChar>(strdup($0)) } }
    }

    private func deallocPathKeys(_ pathKeys: [UnsafePointer<CChar>?]) {
        pathKeys.forEach {
            if $0 != nil { free(UnsafeMutableRawPointer(mutating: $0)) }
        }
    }
}

private func printErr(_ string: String) {
    if let data = string.data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}

private func printErrno(msg: String) {
    printErr("error: \(msg) \(String(validatingUTF8: MMDB_strerror(errno)).map { "(\($0))" } ?? "")")
}

extension MMDB {
    public enum MMDBError: Int32, Error {
        case fileOpen = 1
        case corruptSearchTree = 2
        case invalidMetadata = 3
        case io = 4
        case outOfMemory = 5
        case unknownDatabaseFormat = 6
        case invalidData = 7
        case invalidLookupPath = 8
        case lookupPathDoesNotMatchData = 9
        case invalidNodeNumber = 10
        case ipv6LookupInIPv4Database = 11
        case unknown = -1
    }

    public enum GetAddrInfoError: Error {
        case again
        case badFlags
        case fail
        case family
        case memory
        case noname
        case service
        case sockType
        case system
        case overflow
        case nodata
        case addrFamily
        case badHints
        case `protocol`
        case inProgress
        case canceled
        case notCanceled
        case allDone
        case interrupted
        case idnEncode
        case unknown

        private static let mapping: [Int32: GetAddrInfoError] = {
            #if canImport(Darwin)
            [
                EAI_AGAIN : .again,
                EAI_BADFLAGS : .badFlags,
                EAI_FAIL : .fail,
                EAI_FAMILY : .family,
                EAI_MEMORY : .memory,
                EAI_NONAME : .noname,
                EAI_SERVICE : .service,
                EAI_SOCKTYPE : .sockType,
                EAI_SYSTEM : .system,
                EAI_OVERFLOW : .overflow
            ]
            #else
            [
                EAI_AGAIN : .again,
                EAI_BADFLAGS : .badFlags,
                EAI_FAIL : .fail,
                EAI_FAMILY : .family,
                EAI_MEMORY : .memory,
                EAI_NONAME : .noname,
                EAI_SERVICE : .service,
                EAI_SOCKTYPE : .sockType,
                EAI_SYSTEM : .system,
                EAI_OVERFLOW : .overflow
            ]
            #endif
        }()

        init(int32: Int32) {
            self = Self.mapping[int32] ?? .unknown
        }
    }
}

public protocol MMDBDataValue {
    static func value(from: MMDB_entry_data_s) -> Self
}

extension Float: MMDBDataValue {
    public static func value(from entry: MMDB_entry_data_s) -> Self {
        entry.float_value
    }
}

extension Double: MMDBDataValue {
    public static func value(from entry: MMDB_entry_data_s) -> Self {
        entry.double_value
    }
}

extension Bool: MMDBDataValue {
    public static func value(from entry: MMDB_entry_data_s) -> Self {
        entry.boolean
    }
}

extension String: MMDBDataValue {
    public static func value(from entry: MMDB_entry_data_s) -> Self {
        String(
            bytesNoCopy: UnsafeMutableRawPointer(mutating: entry.utf8_string),
            length: Int(entry.data_size),
            encoding: .utf8,
            freeWhenDone: false
        ) ?? ""
    }
}

extension Int32: MMDBDataValue {
    public static func value(from entry: MMDB_entry_data_s) -> Self {
        entry.int32
    }
}

extension UInt16: MMDBDataValue {
    public static func value(from entry: MMDB_entry_data_s) -> Self {
        entry.uint16
    }
}

extension UInt32: MMDBDataValue {
    public static func value(from entry: MMDB_entry_data_s) -> Self {
        entry.uint32
    }
}

extension UInt64: MMDBDataValue {
    public static func value(from entry: MMDB_entry_data_s) -> Self {
        entry.uint64
    }
}

extension Data: MMDBDataValue {
    public static func value(from entry: MMDB_entry_data_s) -> Self {
        .init(bytes: entry.bytes, count: Int(entry.data_size))
    }
}

extension UnsafePointer: MMDBDataValue {
    public static func value(from entry: MMDB_entry_data_s) -> Self {
        // .init(entry.pointer.assumingMemoryBound(to: Pointee.self))
        fatalError("unimplemented")
    }
}

//private func makePath(_ lookupKeys: [String]) -> UnsafePointer<UnsafePointer<CChar>?>? {
//    let stringArray: [UnsafePointer<CChar>?] = lookupKeys
//        .map({ str in
//            let cString = str.utf8CString
//            let cStringCopy = UnsafeMutableBufferPointer<CChar>
//                .allocate(capacity: cString.count)
//            _ = cStringCopy.initialize(from: cString)
//            return UnsafePointer(cStringCopy.baseAddress)
//        }) + [nil]
//
//    defer {
//        for string in stringArray {
//            string?.deallocate()
//        }
//    }
//
//    let stringMutableBufferPointer: UnsafeMutableBufferPointer<UnsafePointer<CChar>?> =
//        .allocate(capacity: stringArray.count)
//    _ = stringMutableBufferPointer.initialize(from: stringArray)
//
//    let address = UnsafePointer(stringMutableBufferPointer.baseAddress)
//    return address
//}
