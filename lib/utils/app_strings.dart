/// Application strings for localization
class AppStrings {
  // General
  static const String appName = 'World Fog';
  static const String appDescription = 'World Fog - Exploration Map';
  static const String version = '1.0.0';
  static const String loading = 'Loading...';
  static const String tryAgain = 'Try Again';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String close = 'Close';
  static const String clear = 'Clear';
  static const String edit = 'Edit';
  static const String start = 'Start';
  static const String stop = 'Stop';
  static const String pause = 'Pause';
  static const String resume = 'Resume';
  static const String play = 'Play';
  static const String add = 'Add';

  // App initialization
  static const String startingApp = 'Starting World Fog...';
  static const String appStartFailed = 'Application could not be started: ';
  static const String locationPermissionRequired = 'Location Permission Required';
  static const String locationPermissionMessage = 'World Fog needs location permission to show your position on the map and save explored areas.';
  static const String later = 'Later';
  static const String grantPermission = 'Grant Permission';

  // Location
  static const String gettingLocation = 'Getting location...';
  static const String locationServiceUnavailable = 'Location service not available';
  static const String locationDisabled = 'Location disabled. Tap to enable.';
  static const String enableLocation = 'Enable Location';
  static const String motionDetected = 'Motion Detected';
  static const String routePausedWalking = 'Route is paused but you started walking. Do you want to continue?';
  static const String continueLabel = 'Continue';

  // Routes
  static const String activeRoute = 'Active Route';
  static const String routeHistory = 'Route History';
  static const String noSavedRoutes = 'No saved routes yet';
  static const String startTrackingToSave = 'Start tracking on the map to save your routes';
  static const String routeName = 'Route Name';
  static const String editRouteName = 'Edit Route Name';
  static const String deleteRoute = 'Delete Route';
  static const String confirmDeleteRoute = 'Are you sure you want to delete the';
  static const String routeSavedAs = 'Route saved as:';
  static const String routeTrackingStarted = 'Route tracking started';
  static const String totalRoutes = 'Total Routes';
  static const String totalDistance = 'Total Distance';
  static const String totalTime = 'Total Time';
  static const String breakLabel = 'Break:';
  static const String averageSpeed = 'Avg Speed';

  // Weather
  static const String weather = 'Weather';
  static const String sunny = 'Sunny';
  static const String cloudy = 'Cloudy';
  static const String rainy = 'Rainy';
  static const String snowy = 'Snowy';
  static const String windy = 'Windy';
  static const String foggy = 'Foggy';
  static const String temperature = 'Temperature';

  // Waypoints
  static const String addWaypoint = 'Add Waypoint';
  static const String addWaypointTitle = 'Add Waypoint';
  static const String waypointType = 'Waypoint Type';
  static const String scenery = 'Scenery';
  static const String fountain = 'Fountain';
  static const String junction = 'Junction';
  static const String waterfall = 'Waterfall';
  static const String other = 'Other';
  static const String waypointDescription = 'Description';

  // Map
  static const String mapView = 'Map View';
  static const String normalMap = 'Normal';
  static const String satelliteMap = 'Satellite';
  static const String terrainMap = 'Terrain';
  static const String hybridMap = 'Hybrid';

  // Elevation
  static const String ascent = 'Ascent';
  static const String descent = 'Descent';

  // Settings
  static const String settings = 'Settings';
  static const String explorationSettings = 'Exploration Settings';
  static const String explorationRadius = 'Exploration Radius';
  static const String meters = 'meters';
  static const String explorationRadiusDescription = 'This setting determines the minimum distance required for a point to be considered explored. A larger radius allows you to explore wider areas.';
  static const String exploredAreasVisibility = 'Visibility of Explored Areas';
  static const String exploredAreasVisibilityDescription = 'This setting determines how visible the explored areas are on the map. Lower values make the map appear clearer.';
  static const String mapSettings = 'Map Settings';
  static const String clearExploredAreas = 'Clear Explored Areas';
  static const String confirmClearExploredAreas = 'Are you sure you want to delete all explored areas? This action cannot be undone.';
  static const String deleteAllExploredAreas = 'Deletes all explored areas from the map';
  static const String exploredAreasCleared = 'Explored areas cleared';
  static const String appInfo = 'Application Information';
  static const String appNameLabel = 'Application Name';
  static const String versionLabel = 'Version';
  static const String descriptionLabel = 'Description';
  static const String appFullDescription = 'Visualize the places you visit on the map by exploring them';
  static const String explorationFrequencyColorMap = 'Exploration Frequency Color Map';
  static const String firstTime = 'First time';
  static const String twoToThreeTimes = '2-3 times';
  static const String fourToFiveTimes = '4-5 times';
  static const String sixToSevenTimes = '6-7 times';
  static const String eightToNineTimes = '8-9 times';
  static const String tenPlusTimes = '10+ times';
  static const String colorMapDescription = 'Explored areas are colored from blue (few) to red (many) according to frequency.';

  // Route controls
  static const String startTracking = 'Start';
  static const String progress = 'Progress:';

  // Elevation
  static const String elevation = 'Elevation:';

  // Tooltips
  static const String followMyLocation = 'Follow My Location';
  static const String pastRoutes = 'Past Routes';
  static const String goToMyLocation = 'Go to My Location';
  static const String profileAndRouteHistory = 'Profile and Route History';
  static const String profile = 'Profile';

  // Map View
  static const String mapViewTitle = 'Map View';

  // Rating
  static const String rateRoute = 'Rate Route';

  // Route Stats Card
  static const String distance = 'Distance';
  static const String duration = 'Duration';
  static const String breakTime = 'Break Time';
  static const String paused = 'Paused';
  static const String km = 'km';
  static const String kmPerHour = 'km/h';
  static const String metersUnit = 'm';
  static const String hourUnit = 'h';
  static const String minuteUnit = 'm';
  static const String secondUnit = 's';

  // Route Save Bottom Sheet
  static const String saveRoute = 'Save Route';
  static const String routeDetails = 'Route Details';
  static const String points = 'Points';
  static const String waypointsLabel = 'Waypoints';
  static const String enterRouteNameHint = 'Enter a name for your route';
  static const String rating = 'Rating';
  static const String deleteRouteTurkish = 'Delete Route';
  static const String confirmDeleteRouteMessage = 'Are you sure you want to delete this route? This action cannot be undone.';
  static const String deleteTurkish = 'Delete';
  static const String untitled = 'Untitled';

  // Route Name Dialog
  static const String yourLocation = 'Your Location';
  static const String startPoint = 'Start';
  static const String deleteRouteTooltip = 'Delete Route';
  static const String descriptionOptional = 'Description (Optional)';
  static const String addNoteHint = 'Add a note about this place...';
  static const String avgSpeed = 'Avg Speed';
  static const String pointCount = 'Point Count';
  static const String routeTracking = 'Route Tracking';
  static const String routeTrackingDescription = 'Route tracking is in progress';
  static const String routeRecording = 'Recording Route';
  static const String routeActive = 'Route active';
  static const String locationWarnings = 'Location Warnings';
  static const String locationWarningsDescription = 'Warning notification shown when location service is disabled';
  static const String locationServiceDisabled = 'Location Service Disabled';
  static const String routeStoppedTapToEnable = 'Route tracking stopped! Tap to enable location.';
  static const String signOut = 'Sign Out';
  static const String signedOut = 'Signed out';

  // Duration format
  static const String hoursShort = 'h';
  static const String minutesShort = 'm';
}
