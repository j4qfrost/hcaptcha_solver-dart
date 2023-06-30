import 'dart:convert';

import 'algorithm.dart';

class HSL extends Algorithm with Prover {
  @override
  String get name => 'hsl';

  @override
  Future<String> prove(String request) async {
    Map<String, dynamic> claims;

    var parts = request.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid request format');
    }

    var decodedClaims = base64Url.decode(parts[1]);
    claims = json.decode(utf8.decode(decodedClaims));

    DateTime now = DateTime.now().toUtc();
    String formattedNow = now.toIso8601String();
    formattedNow = formattedNow.substring(0, formattedNow.length - 5);
    formattedNow = formattedNow.replaceAll('-', '');
    formattedNow = formattedNow.replaceAll(':', '');
    formattedNow = formattedNow.replaceAll('T', '');

    return [
      '1',
      claims['s'].toString(),
      formattedNow,
      claims['d'],
      '',
      '1',
    ].join(':');
  }
}
