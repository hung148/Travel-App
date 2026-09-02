class PlannerScoringWeights {
  final double rating;
  final double reviews;
  final double preference;
  final double budget;
  final double distance;

  const PlannerScoringWeights({
    required this.rating,
    required this.reviews,
    required this.preference,
    required this.budget,
    required this.distance,
  });

  double get total => rating + reviews + preference + budget + distance;
}

enum PlannerStyle { relaxed, balanced, explorer }

class PlannerProfile {
  final PlannerStyle style;
  final String label;
  final int maxPlacesPerDay;
  final int targetMinutesPerDay;
  final double distanceToleranceKm;
  final int maxDiningPlacesPerDay;
  final int minDiningPlacesPerDay;
  final int restMinutesPerDay;
  final PlannerScoringWeights scoringWeights;

  const PlannerProfile({
    required this.style,
    required this.label,
    required this.maxPlacesPerDay,
    required this.targetMinutesPerDay,
    required this.distanceToleranceKm,
    required this.maxDiningPlacesPerDay,
    required this.minDiningPlacesPerDay,
    required this.restMinutesPerDay,
    required this.scoringWeights,
  });

  static const relaxed = PlannerProfile(
    style: PlannerStyle.relaxed,
    label: 'Relaxed',
    maxPlacesPerDay: 3,
    targetMinutesPerDay: 300,
    distanceToleranceKm: 4,
    maxDiningPlacesPerDay: 3,
    minDiningPlacesPerDay: 3,
    restMinutesPerDay: 60,
    scoringWeights: PlannerScoringWeights(
      rating: 0.25,
      reviews: 0.10,
      preference: 0.25,
      budget: 0.15,
      distance: 0.25,
    ),
  );

  static const balanced = PlannerProfile(
    style: PlannerStyle.balanced,
    label: 'Balanced',
    maxPlacesPerDay: 4,
    targetMinutesPerDay: 420,
    distanceToleranceKm: 8,
    maxDiningPlacesPerDay: 3,
    minDiningPlacesPerDay: 3,
    restMinutesPerDay: 45,
    scoringWeights: PlannerScoringWeights(
      rating: 0.25,
      reviews: 0.15,
      preference: 0.30,
      budget: 0.15,
      distance: 0.15,
    ),
  );

  static const explorer = PlannerProfile(
    style: PlannerStyle.explorer,
    label: 'Explorer',
    maxPlacesPerDay: 6,
    targetMinutesPerDay: 570,
    distanceToleranceKm: 15,
    maxDiningPlacesPerDay: 3,
    minDiningPlacesPerDay: 3,
    restMinutesPerDay: 30,
    scoringWeights: PlannerScoringWeights(
      rating: 0.25,
      reviews: 0.15,
      preference: 0.35,
      budget: 0.15,
      distance: 0.10,
    ),
  );

  factory PlannerProfile.fromActivityLevel(String activityLevel) {
    switch (activityLevel.toLowerCase().trim()) {
      case 'relaxed':
        return relaxed;
      case 'very active':
      case 'explorer':
        return explorer;
      case 'moderate':
      case 'balanced':
      default:
        return balanced;
    }
  }
}
