import 'dart:mirrors';

import 'package:hcaptcha_solver/src/constants.dart';
import 'package:http/http.dart' as http;

class AlgorithmLoader {
  static Map<String, Algorithm>? _algorithms;

  static Map<String, Algorithm> algorithms({bool reload = false}) {
    if (_algorithms == null || reload) {
      _algorithms = {};
      MirrorSystem current = currentMirrorSystem();
      ClassMirror algorithmMirror = reflectClass(Algorithm);
      for (LibraryMirror library in current.libraries.values) {
        for (DeclarationMirror declaration in library.declarations.values) {
          ClassMirror cm = declaration as ClassMirror;
          if (cm.isSubclassOf(algorithmMirror)) {
            Algorithm instance = cm.newInstance(Symbol.empty, []).reflectee;
            _algorithms![instance.name] = instance;
          }
        }
      }
    }
    return _algorithms!;
  }
}

class Proof {
  const Proof(this.algorithm, this.request, this.proof);

  final Algorithm algorithm;
  final String request;
  final String proof;
}

abstract class Algorithm {
  String get name;
  Future<String> prove(String request);
}

mixin Prover on Algorithm {
  Future<Proof> solve(String request) async {
    try {
      final proof = await prove(request);
      return Proof(this, request, proof);
    } catch (e) {
      return Proof(this, request, e.toString());
    }
  }

  Future<String> source() async {
    var url =
        Uri.parse('https://newassets.hcaptcha.com/c/$assetVersion/$name.js');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return response.body;
      } else {
        print('Request failed with status: ${response.statusCode}.');
        throw response.body;
      }
    } catch (e) {
      print('Request failed with error: $e.');
      rethrow;
    }
  }
}
