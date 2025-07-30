The project LandMappin is an indoor/outdoor navigation solution that overlays custom architectural or landscape images on Google Maps with geo-referenced points. The project will have the follow features:

1. Image Upload
    - User uploads an architectural or landscape image (e.g. PNG, JPG).
    - Image could represent a floorplan, estate layout, park map, etc.

2. Coordinate Mapping Tool
    - Let users place points on the uploaded image (like markers).
    - Each point must be geo-referenced to a latitude/longitude coordinate (using a calibration tool or manual entry).

3. Overlay Image on Google Map
    - The uploaded image is overlaid on Google Maps and attached to appropriate coordinate point for accurante navigation.

4. Add Custom Markers on the Overlay
    - Show clickable markers at mapped locations with info or navigation help.
    - Allow mobile users to see where they are in relation to the overlay.

5. Visitor View
    - End-users navigate the Google Map, see the overlaid structure, and interact with the custom points.
    - User can type destination location and map will navigate user on realtime to the location.

Your task is to ensure that this project is beautifully designed, animated and sleek. It should be well structured for easy maintenance. Below is the consideration for the designs:

1. The base colours should be White and Black, well blended for lovely visual appealing.
2. Use Google Font "Noto Sans".
3. For DB to store mapping information, use Hive (so we can have multiple map project, with their associative mappings and cordinates e.g. Project ID, Image path, Map bounds (lat/lng), Points list with labels and coordinates, etc.). Uploaded image to be stored locally.
4. No authentication design need, just beautiful landing page with map projects and add new project icon, etc.
