import 'package:vector_math/vector_math.dart';

import 'agents/agent.dart';

class Event {
  const Event(this.point, this.type, this.timestamp);

  final Vector2 point;
  final String type;
  final int timestamp;
}

class EventRecorder {
  EventRecorder(this.agent);

  bool recording = false;
  final Agent agent;
  final Map<String, dynamic> _manifest = {};

  final Map<String, EventContainer> timeBuffers = {};

  void record() {
    _manifest['st'] = agent.unix();
    recording = true;
  }

  Map<String, dynamic> data() {
    timeBuffers.forEach((key, value) {
      _manifest[key] = value.data;
      _manifest['$key-mp'] = value.meanPeriod;
    });
    return _manifest;
  }

  void setData(String key, dynamic value) {
    _manifest[key] = value;
  }

  void recordEvent(Event e) {
    if (!recording) {
      return;
    }

    if (!timeBuffers.containsKey(e.type)) {
      timeBuffers[e.type] = EventContainer(agent, 16, 15e3 as int);
    }
    timeBuffers[e.type]!.push(e);
  }
}

class EventContainer {
  EventContainer(this.agent, this.period, this.interval);

  List<List<int>> get data {
    _cleanStaleData();
    return _data;
  }

  final Agent agent;
  final int period, interval;
  final List<int> _date = [];
  final List<List<int>> _data = [];

  int _previousTimestamp = 0;
  late final int meanPeriod;
  int _meanCounter = 0;

  void push(Event event) {
    _cleanStaleData();

    bool notFirst = _date.isNotEmpty;
    int timestamp = 0;

    if (notFirst) {
      timestamp = _date.last;
    }

    if (event.timestamp - timestamp >= period) {
      _date.add(event.timestamp);
      _data.add([event.point.x as int, event.point.y as int, event.timestamp]);

      if (notFirst) {
        int delta = event.timestamp - _previousTimestamp;
        meanPeriod =
            ((meanPeriod * _meanCounter + delta) / (_meanCounter + 1)) as int;
        _meanCounter++;
      }
    }

    _previousTimestamp = event.timestamp;
  }

  void _cleanStaleData() {
    int date = agent.unix();

    for (int t = _date.length - 1; t >= 0; t--) {
      if (date - _date[t] >= interval) {
        _date.removeRange(0, t + 1);
        break;
      }
    }
  }
}
