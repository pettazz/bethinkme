import LocationRadiusPicker
import SwiftUI


struct LocationPickerView: UIViewControllerRepresentable {
    @Binding var radius: Double?
    @Binding var name: String?
    @Binding var address: String?
    @Binding var lat: Double?
    @Binding var lng: Double?

    func makeUIViewController(context: Context) -> UINavigationController {
        let configuration = LocationRadiusPickerConfigurationBuilder(
            initialRadius: radius ?? 100,
            minimumRadius: 50,
            maximumRadius: 5000)
             .title("Choose a Location")
            // .navigationBarSaveButtonTitle("Save")
            // .showNavigationBarSaveButton(true)
            // .cancelButtonTitle("Cancel")
            .initialLocation(LocationCoordinates(
                latitude: lat ?? 37.331711,
                longitude: lng ?? -122.030773))
            .radiusBorderColor(UIColor(Color.accentColor))
            .radiusBorderWidth(3)
            .radiusColor(UIColor(Color.accentColor).withAlphaComponent(0.3))
            .radiusLabelColor(.label)
            .grabberColor(UIColor(Color.accentColor))
            .grabberSize(20)
            .unitSystem(.system)
            .vibrateOnResize(true)
            .circlePadding(17)
            .overrideNavigationBarAppearance(false)
            // .mapPinImage(UIImage(resource: .mapPin))
            .calloutSelectButtonText("Select")
            .calloutSelectButtonTextColor(UIColor(Color.accentColor))
            .showSaveButton(true)
            .saveButtonTitle("Select location")
            .saveButtonBackgroundColor(UIColor(Color.accentColor))
            .saveButtonTextColor(.white)
            .saveButtonCornerStyle(.capsule)
            .searchFunctionality(true)
            .showSearchHistory(true)
            .historyHeaderText("Previously searched")
            .searchBarPlaceholder("Search or Enter Address")
            .build()

        let picker = LocationRadiusPickerController(configuration: configuration) { result in
            let titleCleaned = result.location.name.trimmingCharacters(in: .whitespaces)

            radius = result.radius
            name = titleCleaned.isEmpty ?
                    String(result.location.address.split(separator: ",", maxSplits: 1)[0]) :
                    titleCleaned
            address = result.location.address
            lat = result.location.coordinates.latitude
            lng = result.location.coordinates.longitude
        }
        picker.definesPresentationContext = true

        return UINavigationController(rootViewController: picker)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

struct LocationPicker: ModalSheet {
    @discardableResult
    init(radius: Binding<Double?>,
         name: Binding<String?>,
         address: Binding<String?>,
         lat: Binding<Double?>,
         lng: Binding<Double?>) {
        present(LocationPickerView(radius: radius,
                                   name: name,
                                   address: address,
                                   lat: lat,
                                   lng: lng))
    }
}
