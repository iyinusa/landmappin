
# LandMappin

LandMappin is a sleek indoor/outdoor navigation solution for overlaying custom architectural or landscape images on Google Maps, with geo-referenced points and real-time navigation. Built with Flutter, it is designed for beautiful, animated, and maintainable user experiences.

## Features

- **Image Upload:** Upload floorplans, estate layouts, or park maps (PNG/JPG).
- **Coordinate Mapping Tool:** Place and geo-reference points on images using calibration or manual entry.
- **Custom Overlay:** Overlay images on Google Maps, accurately attached to coordinates.
- **Custom Markers:** Clickable markers at mapped locations with info and navigation help.
- **Visitor View:** End-users can navigate, interact with overlays, and get real-time directions.
- **Multiple Map Projects:** Store multiple projects and their mappings using Hive DB.
- **Beautiful UI:** Modern, animated, and visually appealing design using Noto Sans font and a black/white color scheme.

## Architecture

```
[Overlay Image]
    |
    └── Define Paths (LatLng pairs)
           |
           └── Store in Hive DB
                  |
                  └── A* Pathfinding for navigation
                           |
                           └── Render Polyline on Google Maps
```

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- Android Studio or Xcode (for mobile development)

### Installation
1. Clone the repository:
   ```sh
   git clone https://github.com/yourusername/landmappin.git
   cd landmappin
   ```
2. Install dependencies:
   ```sh
   flutter pub get
   ```
3. Run the app:
   ```sh
   flutter run
   ```

### Assets & Fonts
- All images and fonts are located in the `assets/` directory.
- Uses Google Font **Noto Sans** for a modern look.

## Usage

1. Launch the app and add a new map project.
2. Upload your custom image (floorplan, estate, etc.).
3. Place points and calibrate them to GPS coordinates.
4. Overlay the image on Google Maps and interact with custom markers.
5. Use the navigation tool to find paths between points.

## Technologies Used

- **Flutter** (UI framework)
- **Hive** (local DB)
- **Google Maps Flutter** (map integration)
- **Noto Sans** (font)
- **Image Picker, File Picker, Path Provider, Geolocator, Shimmer, Share Plus, HTTP** (various features)

## Folder Structure

```
lib/
  main.dart
  db/
  models/
  services/
  views/
  widgets/
assets/
  images/
  demo/
  fonts/
android/
ios/
web/
test/
```

## Contributing

Contributions are welcome! Please open issues or submit pull requests for improvements, bug fixes, or new features.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
