//
//  CoordinateFormatting.swift
//  EcoJournal
//
//  One place to format coordinates for display.
//
//  Signed decimal degrees, deliberately: a field researcher needs to copy a
//  coordinate straight into a mapping or GIS tool, and those expect a signed
//  value. A hemisphere letter is not a substitute — "122.3321° W" has to be
//  mentally converted before it is usable, and it is easy to transcribe with
//  the wrong sign.
//

import Foundation
import CoreLocation

extension CLLocationCoordinate2D {
    /// Signed decimal degrees, e.g. `47.6062°, -122.3321°`.
    var formattedDecimalDegrees: String {
        String(format: "%.4f°, %.4f°", latitude, longitude)
    }
}

extension CLLocation {
    var formattedDecimalDegrees: String {
        coordinate.formattedDecimalDegrees
    }
}
