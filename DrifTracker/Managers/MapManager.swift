//
//  MapManager.swift
//  DrifTracker
//
//  Created by Erika Scaltrito and Sabrina Vinco on 26/11/24.
//

import CoreLocation
import MapKit

/// Represents a car as a map annotation
class Car : NSObject, MKAnnotation, Identifiable {
    
    var coordinate: CLLocationCoordinate2D
    
    /// Initializes a new `Car` instance with the specified coordinates (latitude and longitude)
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}
