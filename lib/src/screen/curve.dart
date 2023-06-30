import 'package:hcaptcha_solver/src/screen/options.dart';
import 'package:vector_math/vector_math.dart';
import 'package:bezier/bezier.dart';
import 'dart:math';

import '../utils.dart';
import 'utils.dart';

class Curve {
  late final Vector2 fromPoint, toPoint;
  late final List<Vector2> points;

  Curve(this.fromPoint, this.toPoint, CurveOpts opts) {
    int offsetBoundaryX = opts.offsetBoundaryX;
    int offsetBoundaryY = opts.offsetBoundaryY;

    int leftBoundary =
        (opts.leftBoundary ?? min(fromPoint.x, toPoint.x).toInt()) -
            offsetBoundaryX;
    int rightBoundary =
        (opts.rightBoundary ?? max(fromPoint.x, toPoint.x).toInt()) +
            offsetBoundaryX;
    int downBoundary =
        (opts.downBoundary ?? min(fromPoint.y, toPoint.y).toInt()) -
            offsetBoundaryY;
    int upBoundary = (opts.upBoundary ?? max(fromPoint.y, toPoint.y).toInt()) +
        offsetBoundaryY;
    int count = opts.knotsCount;
    double distortionMean = opts.distortionMean;
    double distortionStdDev = opts.distortionStdDev;
    double distortionFrequency = opts.distortionFrequency;
    int targetPoints = opts.targetPoints;

    List<Vector2> internalKnots = _generateInternalKnots(
      leftBoundary,
      rightBoundary,
      downBoundary,
      upBoundary,
      count,
    );
    List<Vector2> points = _generatePoints(internalKnots);
    points = _distortPoints(
        points, distortionMean, distortionStdDev, distortionFrequency);
    this.points = _tweenPoints(points, opts.tween, targetPoints);
  }

  List<Vector2> _generateInternalKnots(
    int leftBoundary,
    int rightBoundary,
    int downBoundary,
    int upBoundary,
    int knotsCount,
  ) {
    if (knotsCount < 0) {
      throw Exception("knotsCount can't be negative");
    }
    if (leftBoundary > rightBoundary) {
      throw Exception(
          "leftBoundary must be less than or equal to rightBoundary");
    }
    if (downBoundary > upBoundary) {
      throw Exception("downBoundary must be less than or equal to upBoundary");
    }

    List<int> knotsX = Knot.knots(leftBoundary, rightBoundary, knotsCount);
    List<int> knotsY = Knot.knots(downBoundary, upBoundary, knotsCount);
    return Knot.merge(knotsX, knotsY);
  }

  List<Vector2> _generatePoints(List<Vector2> knots) {
    double midPointsCount = max(
      max(
        (fromPoint.x - toPoint.x).abs(),
        (fromPoint.y - toPoint.y).abs(),
      ),
      2,
    );

    knots = [fromPoint, ...knots, toPoint];
    final curve = Bezier.fromPoints(knots);
    List<Vector2> points = [];
    for (int t = 0; t <= midPointsCount; t++) {
      points.add(curve.pointAt(t / midPointsCount));
    }
    return points;
  }

  List<Vector2> _distortPoints(List<Vector2> points, double distortionMean,
      double distortionStdDev, double distortionFrequency) {
    if (distortionFrequency < 0 || distortionFrequency > 1) {
      throw Exception("distortionFrequency must be between 0 and 1");
    }

    List<Vector2> distortedPoints =
        List<Vector2>.filled(points.length, Vector2.zero());
    for (int i = 1; i < points.length - 1; i++) {
      Vector2 point = points[i];
      if (Seed.chance(distortionFrequency)) {
        double delta =
            Seed.generateNormalRandom() * distortionStdDev + distortionMean;
        distortedPoints[i] = Vector2(point.x, point.y + delta);
      } else {
        distortedPoints[i] = point;
      }
    }

    distortedPoints = [
      points[0],
      ...distortedPoints,
      points[points.length - 1]
    ];
    return distortedPoints;
  }

  List<Vector2> _tweenPoints(
      List<Vector2> points, double Function(double) tween, int targetPoints) {
    if (targetPoints < 2) {
      throw Exception('targetPoints must be at least 2');
    }

    List<Vector2> tweenedPoints = [];
    for (int i = 0; i < targetPoints; i++) {
      int index = (tween(i / (targetPoints - 1)) * (points.length - 1)).toInt();
      tweenedPoints.add(points[index]);
    }
    return tweenedPoints;
  }
}
