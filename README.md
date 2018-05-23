# MMDB-Swift

A tiny wrapper for [libmaxminddb](https://github.com/maxmind/libmaxminddb) which allows you to lookup Geo data by IP address.

This product uses [GeoLite2 data](http://dev.maxmind.com/geoip/geoip2/geolite2/) created by MaxMind, available from [http://www.maxmind.com](http://www.maxmind.com).

## Swift Package Manager

Package.swift

```swift
import PackageDescription

let package = Package(
    name: "YOUR_AWESOME_PROJECT",
    dependencies: [
        .package(url: "https://github.com/5t111111/MMDB-Swift.git", .branch("master"))
    ],
    ...
)
```

## Usage

```swift
import MMDB

guard let db = MMDB("/path/to/database/file") else {
    print("Failed to open DB.")
    return
}

if let country = db.lookup("8.8.4.4") {
    print(country)
} else {
    print("Not found")
}
```

This outputs:

```json
{
  "continent": {
    "code": "NA",
    "names": {
      "ja": "北アメリカ",
      "en": "North America",
      "ru": "Северная Америка",
      "es": "Norteamérica",
      "de": "Nordamerika",
      "zh-CN": "北美洲",
      "fr": "Amérique du Nord",
      "pt-BR": "América do Norte"
    }
  },
  "isoCode": "US",
  "names": {
    "ja": "アメリカ合衆国",
    "en": "United States",
    "ru": "США",
    "es": "Estados Unidos",
    "de": "USA",
    "zh-CN": "美国",
    "fr": "États-Unis",
    "pt-BR": "Estados Unidos"
  }
}
```

Notice that country is a struct defined as:

```swift
public struct MMDBContinent {
    var code: String?
    var names: [String: String]?
}

public struct MMDBCountry: CustomStringConvertible {
    var continent = MMDBContinent()
    var isoCode = ""
    var names = [String: String]()
  ...
}
```

## Original Author

[Lex Tang](https://github.com/lexrus) (Twitter: [@lexrus](https://twitter.com/lexrus))

## License

MMDB-Swift is available under the [Apache License Version 2.0](http://www.apache.org/licenses/LICENSE-2.0). See the [LICENSE](https://github.com/lexrus/MMDB-Swift/blob/master/LICENSE) file for more info.

The GeoLite2 databases are distributed under the [Creative Commons Attribution-ShareAlike 3.0 Unported License](http://creativecommons.org/licenses/by-sa/3.0/).
