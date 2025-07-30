Due to the GroundOverlay implementation to overlay custom map/floorplan image on the Google Map, we need to implement a Custom Navigation Logic on Top of Your Overlay image for effective navigation path for user. Follow the below context to quide your implementation:

## Core Actions:
1. Define custom paths (nodes/edges) over the image.
2. Map those to GPS coordinates (lat/lng).
3. Use a pathfinding algorithm like A* (A-star).
4. Render the path as a polyline on top of Google Maps.

## Concept Architecture:
```pgsql
[Overlay Image]
    |
    └── Define Paths (as LatLng pairs, manually or by drawing)
           |
           └── Store in local DB (Hive/SQLite)
                  |
                  └── Use A* to calculate route between two points
                           |
                           └── Show result as a Polyline on Google Maps
```

# Step-by-Step Solution

## 1. Define Allowed Pathways (Manual or UI Drawing)
Create a UI tool to allow user to:
- Tap or draw lines on top of the image/overlay
- Each line becomes a path segment
- Convert to GPS using the image-to-coordinate calibration

Data Structure Example:
```json
{
  "nodes": [
    { "id": "A", "lat": 51.5071, "lng": -0.1277 },
    { "id": "B", "lat": 51.5072, "lng": -0.1278 }
  ],
  "edges": [
    { "from": "A", "to": "B", "distance": 5 }
  ]
}
```

## 2. Implement A* Pathfinding
Use a Dart A* library to feed the node graph and get a list of waypoints to draw.

## 3. Draw Path on Google Maps
Convert the result and implement to Polyline widget

Finally, once the implementation is completed and confirmed running fine, we do not need the Google Map navigator anymore.