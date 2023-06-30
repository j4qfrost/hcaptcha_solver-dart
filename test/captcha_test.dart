import 'package:hcaptcha_solver/hcaptcha_solver.dart';
import 'package:logger/logger.dart';

// TestCaptcha
void main() async {
  ChallengeOptions opts =
      ChallengeOptions(Logger(), '', const Duration(seconds: 10));

  while (true) {
    try {
      final Challenge challenge = await Challenge.init(
        'https://accounts.hcaptcha.com/demo',
        'a5f74b19-9e45-40e0-b45d-47ff91b7a6c2',
        opts: opts,
      );
      await challenge.solve(GuessSolver());
      print(challenge.token);
      break;
    } catch (e) {
      print('Error from hCaptcha API: $e');
      rethrow;
      // continue;
    }
  }
}
