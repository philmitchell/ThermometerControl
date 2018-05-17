//
//  Temperature.swift
//
// Copyright (c) 2018 Phil Mitchell

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

enum UnitSystem {
    case metric, imperial
}

protocol Measurement {

    var amount: Double { get }
    var measurementUnit: MeasurementUnit { get }
}

protocol MeasurementUnit {

    var abbreviation: String { get }

}

/// A concept is a range of values that has some identifiable meaning. EG., 90-100°F -> "sweltering".
protocol MeasurementConcept {

    func lowerBound(in unit: MeasurementUnit) -> Double

    func upperBound(in unit: MeasurementUnit) -> Double

    func average(in unit: MeasurementUnit) -> Measurement

    func includes(measurement: Measurement) -> Bool

}

enum TemperatureUnit: MeasurementUnit {
    case celsius, fahrenheit, kelvin

    var abbreviation: String {
        switch self {
        case .celsius:
            return "°C"
        case .kelvin:
            return "°K"
        case .fahrenheit:
            return "°F"
        }
    }
}

enum TemperatureWaypoint: String {
    case freezing="Water freezes", boiling="Water boils", bodyTemperature="Human body temperature"

    var temperature: Temperature {
        switch self {
        case .freezing:
            return Temperature(degrees: 0, unit: .celsius)
        case .boiling:
            return Temperature(degrees: 100, unit: .celsius)
        case .bodyTemperature:
            return Temperature(degrees: 37, unit: .celsius)
        }
    }
}

enum AmbientTemperatureConcept: MeasurementConcept {
    case frigid, cold, chilly, warm, hot, sweltering

    func lowerBound(in unit: MeasurementUnit) -> Double {
        guard let unit = unit as? TemperatureUnit else {
            return -Double.greatestFiniteMagnitude
        }
        let range = temperatureRange(in: unit)
        return range.min.degrees
    }

    func upperBound(in unit: MeasurementUnit) -> Double {
        guard let unit = unit as? TemperatureUnit else {
            return Double.greatestFiniteMagnitude
        }
        let range = temperatureRange(in: unit)
        return range.max.degrees
    }

    func average(in unit: MeasurementUnit) -> Measurement {
        guard let unit = unit as? TemperatureUnit else {
            return Temperature(degrees: Double.greatestFiniteMagnitude, unit: .celsius)
        }
        let (min, max) = temperatureRange(in: unit)
        let averageDegrees = (min.degrees + max.degrees) / 2.0
        return Temperature(degrees: averageDegrees, unit: unit)
    }

    func includes(measurement: Measurement) -> Bool {
        let lowerBound = self.lowerBound(in: measurement.measurementUnit)
        let upperBound = self.upperBound(in: measurement.measurementUnit)
        return lowerBound...upperBound ~= measurement.amount
    }

    func temperatureRange(in unit: TemperatureUnit) -> (min: Temperature, max: Temperature) {
        if unit == .kelvin {
            assert(false, "NOT HANDLED")
        }
        let min: Double
        let max: Double
        if unit == .celsius {
            switch self {
            case .frigid:
                min = -15
                max = 0
            case .cold:
                min = 0
                max = 10
            case .chilly:
                min = 10
                max = 20
            case .warm:
                min = 20
                max = 25
            case .hot:
                min = 25
                max = 35
            case .sweltering:
                min = 35
                max = 45
            }
        }
        else {
            switch self {
            case .frigid:
                min = 10
                max = 30
            case .cold:
                min = 30
                max = 50
            case .chilly:
                min = 50
                max = 68
            case .warm:
                min = 68
                max = 78
            case .hot:
                min = 78
                max = 95
            case .sweltering:
                min = 95
                max = 110
            }
        }
        let minTemperature = Temperature(degrees: min, unit: unit)
        let maxTemperature = Temperature(degrees: max, unit: unit)
        return (minTemperature, maxTemperature)
    }// temperatureRange(in:)

    static func allConcepts() -> [AmbientTemperatureConcept] {
        return [AmbientTemperatureConcept.frigid, .cold, .chilly, .warm, .hot, .sweltering]
    }

}// AmbientTemperatureConcept

extension AmbientTemperatureConcept: CustomStringConvertible {

    var description: String {
            switch self {
            case .frigid:
                return "frigid"
            case .cold:
                return "cold"
            case .chilly:
                return "chilly to mild"
            case .warm:
                return "mild to warm"
            case .hot:
                return "hot"
            case .sweltering:
                return "sweltering"
            }
    }
}

struct Temperature: Measurement {

    let degrees: Double
    let unit: TemperatureUnit

    var amount: Double {
        return degrees
    }

    var measurementUnit: MeasurementUnit {
        return unit
    }

    var waypoint: TemperatureWaypoint? {
        if self == TemperatureWaypoint.freezing.temperature {
            return .freezing
        }
        else if self == TemperatureWaypoint.boiling.temperature {
            return .boiling
        }
        else if self == TemperatureWaypoint.bodyTemperature.temperature {
            return .bodyTemperature
        }
        return nil
    }

    // Internally, all temperatures are represented in celsius
    private let _degreesCelsius: Double

    init(degrees: Double, unit: TemperatureUnit) {
        self.degrees = degrees
        self.unit = unit
        _degreesCelsius = Temperature._convertToCelsius(degrees: degrees, unit: unit)
    }

    /// Subtract two temperatures; resulting temperature is in units of
    /// lhs. Rhs does not have to be in same units.
    static func -(lhs: Temperature, rhs: Temperature) -> Temperature {
        let degreesCelsius = lhs._degreesCelsius - rhs._degreesCelsius
        return Temperature(degrees: degreesCelsius, unit: .celsius).inUnits(lhs.unit)
    }

    func inUnits(_ unit: TemperatureUnit) -> Temperature {
        return Temperature(degrees: self.inUnits(unit), unit: unit)
    }

    // https://www.nist.gov/pml/weights-and-measures/si-units-temperature
    func inUnits(_ unit: TemperatureUnit) -> Double {
        switch unit {
        case .celsius:
            return _degreesCelsius
        case .kelvin:
            return _degreesCelsius + 273.15
        case .fahrenheit:
            return (_degreesCelsius * 1.8) + 32
        }
    }// inUnits

    // https://www.nist.gov/pml/weights-and-measures/si-units-temperature
    private static func _convertToCelsius(degrees: Double, unit: TemperatureUnit) -> Double {
        switch unit {
        case .celsius:
            return degrees
        case .kelvin:
            return degrees - 273.15
        case .fahrenheit:
            return (degrees - 32) / 1.8
        }
    }// _convertToCelsius

}// Temperature

extension Temperature: Equatable {

    static func ==(lhs: Temperature, rhs: Temperature) -> Bool {

        return lhs._degreesCelsius == rhs._degreesCelsius
    }
}

extension Temperature: Comparable {

    static func <(lhs: Temperature, rhs: Temperature) -> Bool {

        return lhs._degreesCelsius < rhs._degreesCelsius
    }

    static func <=(lhs: Temperature, rhs: Temperature) -> Bool {

        return lhs._degreesCelsius <= rhs._degreesCelsius
    }

    static func >(lhs: Temperature, rhs: Temperature) -> Bool {

        return lhs._degreesCelsius > rhs._degreesCelsius
    }

    static func >=(lhs: Temperature, rhs: Temperature) -> Bool {

        return lhs._degreesCelsius >= rhs._degreesCelsius
    }
}

extension Temperature: CustomStringConvertible {
    
    var description: String {
        return String(format: "%.1f \(unit.abbreviation)", degrees)
    }
}
