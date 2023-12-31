import 'package:vector_math/vector_math.dart';

import '../utils.dart';

class Knot {
  static List<Vector2> merge(List<int> a, List<int> b) {
    if (a.length != b.length) {
      throw Exception("Arguments must be of the same length");
    }

    List<Vector2> r = List<Vector2>.filled(a.length, Vector2.zero());
    for (int i = 0; i < a.length; i++) {
      r[i] = Vector2(a[i].toDouble(), b[i].toDouble());
    }
    return r;
  }

  static List<int> knots(int firstBoundary, int secondBoundary, int size) {
    List<int> result = [];
    for (int i = 0; i < size; i++) {
      result.add(Seed.between(firstBoundary, secondBoundary));
    }
    return result;
  }
}
