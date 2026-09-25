import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'modelos.dart';

/// Guarda la configuración cifrada con el Keystore de Android.
class Almacen {
  static const _storage = FlutterSecureStorage();
  static const _llave = 'config_app_v2';

  static Future<ConfigApp?> cargar() async {
    try {
      final json = await _storage.read(key: _llave);
      if (json == null) return null;
      final config =
          ConfigApp.fromJson(jsonDecode(json) as Map<String, dynamic>);
      config.validar();
      return config;
    } catch (_) {
      return null;
    }
  }

  static Future<void> guardar(ConfigApp config) =>
      _storage.write(key: _llave, value: jsonEncode(config.toJson()));

  static Future<void> borrar() => _storage.delete(key: _llave);

  /// Grupo o DVR que se estaba viendo, para volver a él al reiniciar la TV.
  static const _llaveSeleccion = 'seleccion_v1';

  static Future<Seleccion?> cargarSeleccion() async {
    try {
      return Seleccion.desdeClave(await _storage.read(key: _llaveSeleccion));
    } catch (_) {
      return null;
    }
  }

  static Future<void> guardarSeleccion(Seleccion? s) async {
    try {
      if (s == null) {
        await _storage.delete(key: _llaveSeleccion);
      } else {
        await _storage.write(key: _llaveSeleccion, value: s.clave);
      }
    } catch (_) {}
  }
}
