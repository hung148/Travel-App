import 'package:flutter_test/flutter_test.dart';
import 'package:travel/service/ai/stop_name_matcher.dart';

void main() {
  const matcher = StopNameMatcher();

  test('matches an unaccented Vietnamese stop name exactly', () {
    final matches = matcher.rank('Pho Nuong', [
      'Phở Nướng',
      'Công viên biển Hà Khê',
    ]);

    expect(matches.first.name, 'Phở Nướng');
    expect(matches.first.score, 1);
  });

  test('ranks a close typo ahead of unrelated stops', () {
    final matches = matcher.rank('Imperal Cty', [
      'Dong Ba Market',
      'Imperial City',
      'Thien Mu Pagoda',
    ]);

    expect(matches.first.name, 'Imperial City');
    expect(matches.first.score, greaterThan(0.7));
  });

  test('partial Vietnamese category excludes unrelated similar names', () {
    final matches = matcher.rank('Cong Vien', [
      'Công viên 29/3',
      'Hoàng Vy Quán',
      'Công viên biển Hà Khê',
      'Công viên cầu vượt Ngã Ba Huế',
    ]);

    expect(
      matches.take(3).map((item) => item.name),
      everyElement(contains('viên')),
    );
    expect(matches.last.name, 'Hoàng Vy Quán');
  });
}
