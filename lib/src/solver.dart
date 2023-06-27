import 'dart:math';

import 'challenge.dart';

abstract class Solver {
  List<Task> solve(String category, String question, List<Task> tasks);
}

class GuessSolver implements Solver {
  static final _rand = Random(DateTime.now().millisecondsSinceEpoch);

  @override
  List<Task> solve(String category, String question, List<Task> tasks) {
    final List<Task> answers = [];
    for (Task t in tasks) {
      if (_rand.nextDouble() < 0.5) {
        answers.add(t);
      }
    }
    return answers;
  }
}
