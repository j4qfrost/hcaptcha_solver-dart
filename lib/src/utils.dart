import 'dart:math';

const frameSize = (400, 600);
// TileImageSize is the size of the tile image.
const tileImageSize = (123, 123);
// TileImageStartPosition is the start position of the tile image.
const tileImageStartPosition = (11, 130);
// TileImagePadding is the padding between the tile images.
const tileImagePadding = (5, 6);
// VerifyButtonPosition is the position of the verify button.
const verifyButtonPosition = (314, 559);

// TilesPerPage is the number of tiles per page.
const tilesPerPage = 9;
// TilesPerRow is the number of tiles per row.
const tilesPerRow = 3;

// Version is the latest supported version.
const version = 'c572e75';
// AssetVersion is the latest supported version of the assets.
const assetVersion = '45108af';

class Seed {
  static Random _rand = Random(DateTime.now().millisecondsSinceEpoch);

  static void setSeed(int seed) {
    _rand = Random(seed);
  }

  static int between(int from, int to) {
    return _rand.nextInt(to - from) + from;
  }

  static bool chance(double c) {
    return _rand.nextDouble() < c;
  }

  static double generateNormalRandom() {
    double u1 = 1.0 - _rand.nextDouble(); // Uniform random value between (0, 1]
    double u2 = 1.0 - _rand.nextDouble(); // Uniform random value between (0, 1]

    double z = sqrt(-2.0 * log(u1)) *
        cos(2.0 * pi * u2); // Transform to standard normal distribution
    return z;
  }
}
