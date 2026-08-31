import '../../models/travel_place.dart';

const mockTokyoPlaces = <TravelPlace>[
  TravelPlace(
    id: 'shibuya_sky',
    name: 'Shibuya Sky',
    category: 'attractions',
    tags: [
      'photography',
      'attractions',
      'city view',
    ],
    rating: 4.6,
    reviewCount: 18000,
    estimatedCost: 25,
    latitude: 35.6584,
    longitude: 139.7022,
    estimatedVisitMinutes: 90,
  ),

  TravelPlace(
    id: 'sensoji',
    name: 'Senso-ji',
    category: 'history',
    tags: [
      'history',
      'culture',
      'photography',
    ],
    rating: 4.5,
    reviewCount: 76000,
    estimatedCost: 0,
    latitude: 35.7148,
    longitude: 139.7967,
    estimatedVisitMinutes: 90,
  ),

  TravelPlace(
    id: 'meiji_shrine',
    name: 'Meiji Shrine',
    category: 'culture',
    tags: [
      'history',
      'culture',
      'nature',
    ],
    rating: 4.6,
    reviewCount: 39000,
    estimatedCost: 0,
    latitude: 35.6764,
    longitude: 139.6993,
    estimatedVisitMinutes: 90,
  ),

  TravelPlace(
    id: 'teamlab',
    name: 'teamLab Borderless',
    category: 'attractions',
    tags: [
      'photography',
      'culture',
      'attractions',
    ],
    rating: 4.6,
    reviewCount: 21000,
    estimatedCost: 35,
    latitude: 35.6605,
    longitude: 139.7292,
    estimatedVisitMinutes: 120,
  ),

  TravelPlace(
    id: 'tsukiji',
    name: 'Tsukiji Outer Market',
    category: 'food',
    tags: [
      'food',
      'local food',
      'culture',
    ],
    rating: 4.3,
    reviewCount: 57000,
    estimatedCost: 30,
    latitude: 35.6655,
    longitude: 139.7707,
    estimatedVisitMinutes: 120,
  ),

  TravelPlace(
    id: 'ueno_museum',
    name: 'Tokyo National Museum',
    category: 'museums',
    tags: [
      'museums',
      'history',
      'culture',
    ],
    rating: 4.5,
    reviewCount: 25000,
    estimatedCost: 8,
    latitude: 35.7188,
    longitude: 139.7765,
    estimatedVisitMinutes: 150,
  ),
];