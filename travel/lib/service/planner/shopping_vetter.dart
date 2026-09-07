/// A shopping candidate that has already passed the type and size rules.
///
/// Only the fields a judgement needs: what the place is called, what Google
/// thinks it is, and how busy it is.
class ShoppingCandidate {
  const ShoppingCandidate({
    required this.placeId,
    required this.name,
    required this.address,
    required this.primaryType,
    required this.types,
    required this.reviewCount,
  });

  final String placeId;
  final String name;
  final String address;
  final String primaryType;
  final List<String> types;
  final int reviewCount;

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'name': name,
      'address': address,
      'primaryType': primaryType,
      'types': types,
      'reviewCount': reviewCount,
    };
  }
}

/// The last word on whether a candidate is really a shopping destination.
///
/// The type and review rules in DestinationPlaceService cannot read a name,
/// and the name is what gives away a shophouse that registered itself as a
/// shopping mall. An implementation of this asks something that can read.
///
/// Contract: [approve] returns the ids to KEEP. An implementation that cannot
/// reach its judge, or gets no answer for a place, must return that place
/// anyway. Failing open is deliberate - a network blip must never empty a
/// traveler's shopping plan, which is a far worse outcome than one odd stop.
abstract class ShoppingVetter {
  Future<Set<String>> approve(List<ShoppingCandidate> candidates);
}
