class CurveOpts {
  const CurveOpts({
    this.leftBoundary,
    this.rightBoundary,
    this.downBoundary,
    this.upBoundary,
    this.offsetBoundaryX = 100,
    this.offsetBoundaryY = 100,
    this.knotsCount = 2,
    this.distortionMean = 1.0,
    this.distortionStdDev = 0.6,
    this.distortionFrequency = 0.5,
    this.tween = _tween,
    this.targetPoints = 300,
  });
  final int offsetBoundaryX;
  final int offsetBoundaryY;

  final int? leftBoundary;
  final int? rightBoundary;
  final int? downBoundary;
  final int? upBoundary;

  final int knotsCount;

  final double distortionMean;
  final double distortionStdDev;
  final double distortionFrequency;

  final double Function(double) tween;

  final int targetPoints;
}

double _tween(double n) {
  if (n < 0 || n > 1) {
    throw RangeError.range(n, 0, 1);
  }
  return -n * (n - 2);
}
