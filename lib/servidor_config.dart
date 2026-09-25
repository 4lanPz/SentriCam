import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'hikvision.dart';
import 'modelos.dart';
import 'pagina_web.dart';

/// Servidor HTTP temporal para configurar la app desde otro equipo de la red.
/// Solo corre mientras la pantalla de configuración está abierta.
class ServidorConfig {
  static const puerto = 8080;
  static const _maxBytes = 256 * 1024;
  static const _maxFallos = 5;

  final ConfigApp? actual;
  final Future<void> Function(ConfigApp nueva) alGuardar;
  void Function()? alCambiarCodigo;

  HttpServer? _server;
  String codigo = '';
  int _fallos = 0;
  final _rnd = Random.secure();

  ServidorConfig({required this.actual, required this.alGuardar});

  bool get activo => _server != null;

  void _nuevoCodigo() {
    codigo = List.generate(6, (_) => _rnd.nextInt(10)).join();
    _fallos = 0;
  }

  Future<void> iniciar() async {
    if (_server != null) return;
    _nuevoCodigo();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, puerto);
    _server!.listen(_atender, onError: (_) {});
  }

  Future<void> detener() async {
    final s = _server;
    _server = null;
    await s?.close(force: true);
  }

  static Future<String?> ipLocal() async {
    final interfaces =
        await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final i in interfaces) {
      for (final a in i.addresses) {
        if (esIpPrivada(a.address)) return a.address;
      }
    }
    return null;
  }

  /// Tras 5 intentos fallidos se genera un código nuevo.
  bool _codigoValido(dynamic recibido) {
    if (recibido is String && recibido == codigo) {
      _fallos = 0;
      return true;
    }
    _fallos++;
    if (_fallos >= _maxFallos) {
      _nuevoCodigo();
      alCambiarCodigo?.call();
    }
    return false;
  }

  Future<String> _leerCuerpo(HttpRequest req) async {
    final bytes = <int>[];
    await for (final parte in req) {
      bytes.addAll(parte);
      if (bytes.length > _maxBytes) {
        throw const FormatException('El archivo es demasiado grande');
      }
    }
    return utf8.decode(bytes);
  }

  Future<void> _json(HttpResponse res, int estado, Object cuerpo) async {
    try {
      res.statusCode = estado;
      res.headers.contentType = ContentType.json;
      res.headers.set('Cache-Control', 'no-store');
      res.write(jsonEncode(cuerpo));
      await res.close();
    } catch (_) {}
  }

  Future<void> _atender(HttpRequest req) async {
    final res = req.response;
    try {
      final remoto = req.connectionInfo?.remoteAddress.address ?? '';
      if (!esIpPrivada(remoto)) {
        res.statusCode = HttpStatus.forbidden;
        await res.close();
        return;
      }

      if (req.method == 'GET' && req.uri.path == '/') {
        res.headers.contentType = ContentType.html;
        res.headers.set('Cache-Control', 'no-store');
        res.headers.set(
            'Content-Security-Policy',
            "default-src 'none'; script-src 'unsafe-inline'; "
                "style-src 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'");
        res.write(paginaWeb);
        await res.close();
        return;
      }

      final ruta = req.uri.path;
      if (req.method == 'POST' &&
          (ruta == '/actual' || ruta == '/guardar' || ruta == '/probar')) {
        final datos =
            jsonDecode(await _leerCuerpo(req)) as Map<String, dynamic>;
        if (!_codigoValido(datos['codigo'])) {
          await _json(res, 401, {'error': 'Código incorrecto'});
          return;
        }

        if (ruta == '/actual') {
          // Nunca se devuelven las contraseñas de los DVR.
          await _json(res, 200, {
            'config': actual?.toJson(incluirClaves: false) ?? _porDefecto,
          });
          return;
        }

        if (ruta == '/probar') {
          final j = datos['dvr'];
          if (j is! Map<String, dynamic>) {
            throw const FormatException('Faltan los datos del DVR');
          }
          // Con la contraseña vacía se usa la guardada, solo si coinciden IP y usuario.
          final dvr = ConfigApp(dvrs: [Dvr.fromJson(j)]).conClavesDe(actual)
            ..validar(exigirCanales: false);
          final r = await probarDvr(dvr.dvrs.first);
          await _json(res, 200, {
            'pasos': [
              for (final p in r.pasos) {'ok': p.ok, 'texto': p.texto},
            ],
            'canales': [
              for (final c in r.canales) {'canal': c.canal, 'nombre': c.nombre},
            ],
          });
          return;
        }

        final recibida =
            ConfigApp.fromJson(datos['config'] as Map<String, dynamic>)
                .conClavesDe(actual);
        // Primero se valida lo básico (IPs privadas, claves...) y solo después
        // se consulta a los DVR por sus canales y nombres.
        recibida.validar(exigirCanales: false);
        final nueva = await completarCanales(recibida, anterior: actual);
        nueva
          ..validar()
          ..validarGrupos();
        await alGuardar(nueva);
        await _json(res, 200, {'ok': true});
        return;
      }

      res.statusCode = HttpStatus.notFound;
      await res.close();
    } on FormatException catch (e) {
      await _json(res, 400, {'error': e.message});
    } catch (_) {
      await _json(res, 400, {'error': 'Formato inválido, revisa el JSON'});
    }
  }

  /// Configuración inicial cuando la TV aún no tiene nada guardado: el
  /// formulario web empieza sin DVR y se agregan con "Añadir DVR".
  static const _porDefecto = {
    'camarasPorPagina': 9,
    'substream': true,
    'rotacionSegundos': 0,
    'pin': '',
    'dvrs': <Object>[],
    'grupos': <Object>[],
  };
}
