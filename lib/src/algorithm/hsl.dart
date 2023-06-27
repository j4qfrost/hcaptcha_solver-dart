import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'algorithm.dart';

class HSL extends Algorithm with Prover {
  @override
  String get name => 'hsl';

  @override
  Future<String> prove(String request) async {
    final jwt = JWT.decode(request);

    final claims = jwt.payload;

    String now = DateTime.now().toUtc().toIso8601String();
    now = now.substring(0, now.length - 5);
    now = now.replaceAll('-', '');
    now = now.replaceAll(':', '');
    now = now.replaceAll('T', '');

    return [
      '1',
      claims['s'].toInt().toString(),
      now,
      claims['d'].toString(),
      '',
      '1'
    ].join(':');
  }
}
