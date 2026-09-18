import SwiftUI
import MapKit
import CoreLocation

private let MOROCCO_CENTER = CLLocationCoordinate2D(latitude: 31.7917, longitude: -7.0926)
private let MOROCCO_SPAN = MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)

/// Mirrors web's `app-listings-map` (Leaflet + free OpenStreetMap tiles) —
/// iOS gets the same "no paid API key" property for free via MapKit, which
/// needs no key or SDK setup at all. Pins come straight from `ListingDto`'s
/// `lat`/`lng` (backend-geocoded from the city name, city-centroid
/// precision, see `soukmar-backend/src/lib/geocode.ts`) — no client-side
/// geocoding needed. Tapping a pin pushes the listing id the same way
/// `ListingCardView` does, via the `String.self` destination registered at
/// `HomeView`'s stack root.
struct ListingsMapView: View {
    let listings: [ListingDto]

    @State private var region = MKCoordinateRegion(center: MOROCCO_CENTER, span: MOROCCO_SPAN)

    private var pins: [ListingPin] {
        listings.compactMap { listing in
            guard let lat = listing.lat, let lng = listing.lng else { return nil }
            return ListingPin(id: listing.id, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: pins) { pin in
            MapAnnotation(coordinate: pin.coordinate) {
                NavigationLink(value: pin.id) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.soukmarPrimary)
                        .background(Circle().fill(.white).padding(3))
                }
            }
        }
        .onAppear { fitToPins() }
        .onChange(of: listings) { _ in fitToPins() }
    }

    private func fitToPins() {
        guard !pins.isEmpty else {
            region = MKCoordinateRegion(center: MOROCCO_CENTER, span: MOROCCO_SPAN)
            return
        }
        let lats = pins.map(\.coordinate.latitude)
        let lngs = pins.map(\.coordinate.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLng = lngs.min()!, maxLng = lngs.max()!
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.15, (maxLat - minLat) * 1.4),
                longitudeDelta: max(0.15, (maxLng - minLng) * 1.4)
            )
        )
    }
}

private struct ListingPin: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
}
