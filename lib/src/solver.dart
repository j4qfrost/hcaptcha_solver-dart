import 'challenge.dart';
import 'utils.dart';

abstract class Solver {
  List<Task> solve(String category, String question, List<Task> tasks);
}

class GuessSolver implements Solver {
  @override
  List<Task> solve(String category, String question, List<Task> tasks) {
    final List<Task> answers = [];
    for (Task t in tasks) {
      if (Seed.chance(0.5)) {
        answers.add(t);
      }
    }
    return answers;
  }
}
