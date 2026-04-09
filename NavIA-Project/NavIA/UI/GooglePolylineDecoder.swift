//
//  GooglePolylineDecoder.swift
//  NavIA
//

import CoreLocation

enum GooglePolylineDecoder {
    static func decode(_ encodedPath: String) -> [CLLocationCoordinate2D] {
        guard !encodedPath.isEmpty else {
            return []
        }

        let scalars = Array(encodedPath.unicodeScalars)
        var coordinates: [CLLocationCoordinate2D] = []
        var index = 0
        var latitude = 0
        var longitude = 0

        while index < scalars.count {
            guard let latitudeDelta = decodeValue(from: scalars, index: &index),
                  let longitudeDelta = decodeValue(from: scalars, index: &index)
            else {
                break
            }

            latitude += latitudeDelta
            longitude += longitudeDelta

            coordinates.append(
                CLLocationCoordinate2D(
                    latitude: Double(latitude) / 1e5,
                    longitude: Double(longitude) / 1e5
                )
            )
        }

        return coordinates
    }

    private static func decodeValue(from scalars: [UnicodeScalar], index: inout Int) -> Int? {
        var result = 0
        var shift = 0

        while index < scalars.count {
            let value = Int(scalars[index].value) - 63
            index += 1

            result |= (value & 0x1F) << shift
            shift += 5

            if value < 0x20 {
                let isNegative = (result & 1) == 1
                let delta = result >> 1
                return isNegative ? ~delta : delta
            }
        }

        return nil
    }
}
