import 'dart:collection';

export 'chrome.dart';

abstract class Agent {
  // UserAgent returns the user-agent string for the agent.
  String get agent;
  // ScreenProperties returns the screen properties of the agent.
  LinkedHashMap<String, dynamic> screenProperties();
  // NavigatorProperties returns the navigator properties of the agent.
  LinkedHashMap<String, dynamic> navigatorProperties();

  // Unix returns the current timestamp with any added offsets.
  int unix();
  // OffsetUnix offsets the Unix timestamp with the given offset.
  void offsetUnix(int offset);
  // ResetUnix resets the Unix timestamp with offsets to the current time.
  void resetUnix();
}
