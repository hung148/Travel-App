class StopNameMatch {
  const StopNameMatch(this.name, this.score);

  final String name;
  final double score;
}

class StopNameMatcher {
  const StopNameMatcher();

  List<StopNameMatch> rank(String query, Iterable<String> names) {
    final matches =
        names
            .toSet()
            .map((name) => StopNameMatch(name, similarity(query, name)))
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
    return matches;
  }

  double similarity(String left, String right) {
    final a = normalize(left);
    final b = normalize(right);
    if (a == b) return 1;
    if (a.contains(b) || b.contains(a)) {
      return 0.9 *
          (a.length < b.length ? a.length / b.length : b.length / a.length);
    }
    final aTokens = a.split(' ').where((value) => value.isNotEmpty).toSet();
    final bTokens = b.split(' ').where((value) => value.isNotEmpty).toSet();
    final sharedTokens = aTokens.intersection(bTokens).length;
    final tokenScore = aTokens.isEmpty ? 0.0 : sharedTokens / aTokens.length;
    final distance = _levenshtein(a, b);
    final longest = a.length > b.length ? a.length : b.length;
    final editScore = longest == 0 ? 1.0 : 1 - distance / longest;
    if (editScore >= 0.7) return editScore;
    if (tokenScore == 0 && aTokens.length > 1) return editScore * 0.45;
    return (editScore * 0.45 + tokenScore * 0.55).clamp(0.0, 1.0);
  }

  String normalize(String value) {
    var normalized = value.toLowerCase();
    const groups = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };
    for (final entry in groups.entries) {
      for (final character in entry.value.split('')) {
        normalized = normalized.replaceAll(character, entry.key);
      }
    }
    return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  int _levenshtein(String left, String right) {
    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 1; i <= left.length; i++) {
      final current = <int>[i];
      for (var j = 1; j <= right.length; j++) {
        final cost = left[i - 1] == right[j - 1] ? 0 : 1;
        current.add(
          [
            current[j - 1] + 1,
            previous[j] + 1,
            previous[j - 1] + cost,
          ].reduce((a, b) => a < b ? a : b),
        );
      }
      previous = current;
    }
    return previous.last;
  }
}
