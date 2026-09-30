import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'modelos.dart';

/// Error de comunicación con un DVR, con un mensaje listo para mostrar.
/// Nunca incluye usuario, contraseña ni URLs con credenciales.
class ErrorDvr implements Exception {
  final String mensaje;
  final bool deAcceso;

  /// El DVR no ofrece esa consulta (404), típico de modelos antiguos.
  final bool noDisponible;
  const ErrorDvr(this.mensaje,
      {this.deAcceso = false, this.noDisponible = false});
  @override
  String toString() => mensaje;
}

class PasoPrueba {
  final bool ok;
  final String texto;
  const PasoPrueba(this.ok, this.texto);
}

const _maxRespuesta = 1024 * 1024;
const _espera = Duration(seconds: 8);

String _cnonceAleatorio() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
}

/// Arma la cabecera Authorization a partir de los desafíos WWW-Authenticate.
/// Es propia porque el cliente HTTP de Dart no autentica si el DVR envía más de
/// un desafío (Hikvision manda Digest y Basic juntos, o SHA-256 y MD5), y su
/// digest (nc de 9 dígitos, qop entre comillas) lo rechazan algunos firmwares.
String? cabeceraAutorizacion(
  List<String> desafios, {
  required String usuario,
  required String clave,
  required String metodo,
  required String uri,
  String? cnonce,
}) {
  Map<String, String>? digest;
  var basic = false;
  for (final d in desafios) {
    final t = d.trim();
    final i = t.indexOf(' ');
    final esquema = (i == -1 ? t : t.substring(0, i)).toLowerCase();
    if (esquema == 'basic') {
      basic = true;
      continue;
    }
    if (esquema != 'digest' || i == -1) continue;
    final p = <String, String>{
      for (final m in RegExp(r'(\w+)\s*=\s*(?:"([^"]*)"|([^\s,]+))')
          .allMatches(t.substring(i + 1)))
        m.group(1)!.toLowerCase(): m.group(2) ?? m.group(3)!,
    };
    final alg = (p['algorithm'] ?? 'MD5').toUpperCase();
    if (!const {'MD5', 'MD5-SESS', 'SHA-256', 'SHA-256-SESS'}.contains(alg))
      continue;
    // Con varios digest se prefiere MD5, el que soportan todos los firmwares.
    final actualEsMd5 =
        (digest?['algorithm'] ?? 'MD5').toUpperCase().startsWith('MD5');
    if (digest == null || (!actualEsMd5 && alg.startsWith('MD5'))) digest = p;
  }

  if (digest != null) {
    final algoritmo = digest['algorithm'];
    final alg = (algoritmo ?? 'MD5').toUpperCase();
    final Hash hash = alg.startsWith('SHA-256') ? sha256 : md5;
    String h(String v) => hash.convert(utf8.encode(v)).toString();
    final realm = digest['realm'] ?? '';
    final nonce = digest['nonce'] ?? '';
    final cn = cnonce ?? _cnonceAleatorio();
    final conQop = (digest['qop'] ?? '')
        .split(',')
        .map((q) => q.trim().toLowerCase())
        .contains('auth');
    const nc = '00000001';
    var ha1 = h('$usuario:$realm:$clave');
    if (alg.endsWith('-SESS')) ha1 = h('$ha1:$nonce:$cn');
    final ha2 = h('$metodo:$uri');
    final respuesta =
        conQop ? h('$ha1:$nonce:$nc:$cn:auth:$ha2') : h('$ha1:$nonce:$ha2');
    final b = StringBuffer('Digest username="$usuario", realm="$realm", '
        'nonce="$nonce", uri="$uri", response="$respuesta"');
    if (algoritmo != null) b.write(', algorithm=$algoritmo');
    final opaque = digest['opaque'];
    if (opaque != null) b.write(', opaque="$opaque"');
    if (conQop) b.write(', qop=auth, nc=$nc, cnonce="$cn"');
    return b.toString();
  }
  if (basic) return 'Basic ${base64.encode(utf8.encode('$usuario:$clave'))}';
  return null;
}

typedef _Respuesta = ({
  int estado,
  List<String> desafios,
  String? ubicacion,
  List<int> cuerpo,
});

Future<_Respuesta> _pedir(
    HttpClient cliente, Uri uri, String? autorizacion) async {
  final req = await cliente.getUrl(uri).timeout(_espera);
  req.followRedirects = false;
  if (autorizacion != null) {
    req.headers.set(HttpHeaders.authorizationHeader, autorizacion);
  }
  final res = await req.close().timeout(_espera);
  final cuerpo = <int>[];
  await for (final parte in res.timeout(_espera)) {
    cuerpo.addAll(parte);
    if (cuerpo.length > _maxRespuesta) {
      throw const ErrorDvr('El DVR envió una respuesta demasiado grande.');
    }
  }
  return (
    estado: res.statusCode,
    desafios:
        res.headers[HttpHeaders.wwwAuthenticateHeader] ?? const <String>[],
    ubicacion: res.headers.value(HttpHeaders.locationHeader),
    cuerpo: cuerpo,
  );
}

/// GET autenticado contra el servicio web del DVR (ISAPI o PSIA).
Future<String> _obtener(Dvr dvr, String ruta) async {
  final cliente = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6)
    // Algunos DVR nuevos redirigen la web a HTTPS con certificado propio.
    // Solo se acepta para la IP privada de este DVR.
    ..badCertificateCallback = (_, host, __) => host == dvr.host;
  try {
    var uri =
        Uri(scheme: 'http', host: dvr.host, port: dvr.puertoHttp, path: ruta);
    var r = await _pedir(cliente, uri, null);

    final destino = r.ubicacion == null ? null : Uri.tryParse(r.ubicacion!);
    if (r.estado >= 300 &&
        r.estado < 400 &&
        destino != null &&
        destino.scheme == 'https' &&
        (destino.host.isEmpty || destino.host == dvr.host)) {
      uri = uri.replace(
          scheme: 'https', port: destino.hasPort ? destino.port : 443);
      r = await _pedir(cliente, uri, null);
    }

    if (r.estado == 401) {
      final auth = cabeceraAutorizacion(r.desafios,
          usuario: dvr.usuario, clave: dvr.clave, metodo: 'GET', uri: ruta);
      if (auth != null) r = await _pedir(cliente, uri, auth);
    }

    switch (r.estado) {
      case 200:
        return utf8.decode(r.cuerpo, allowMalformed: true);
      case 401:
        throw const ErrorDvr(
            'Usuario o contraseña incorrectos, o este equipo quedó bloqueado por intentos '
            'fallidos (el DVR bloquea por IP unos 30 minutos aunque desde otro equipo sí entres).',
            deAcceso: true);
      case 403:
        throw const ErrorDvr(
            'El usuario no tiene permiso para consultar el DVR.');
      case 404:
        throw const ErrorDvr('El DVR no ofrece esta consulta.',
            noDisponible: true);
      default:
        throw ErrorDvr('El DVR respondió con el error ${r.estado}.');
    }
  } on ErrorDvr {
    rethrow;
  } on TimeoutException {
    throw ErrorDvr('${dvr.host}:${dvr.puertoHttp} no respondió a tiempo. '
        'Revisa la IP y que estén en la misma red.');
  } on SocketException {
    throw ErrorDvr('No se pudo conectar a ${dvr.host}:${dvr.puertoHttp}. '
        'Revisa la IP, la red y el puerto HTTP del DVR (normalmente 80).');
  } on IOException {
    throw ErrorDvr(
        '${dvr.host}:${dvr.puertoHttp} respondió de forma inesperada. '
        'Revisa que "puertoHttp" sea el puerto web del DVR.');
  } finally {
    cliente.close(force: true);
  }
}

String _desescapar(String t) => t
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

String _limpiarNombre(String t) {
  final limpio = _desescapar(t).replaceAll(RegExp(r'[\x00-\x1F]'), '').trim();
  return limpio.length > 40 ? limpio.substring(0, 40) : limpio;
}

/// Extrae canal y nombre de la respuesta XML de Hikvision.
/// [etiqueta]: VideoInputChannel (entradas del equipo) o InputProxyChannel (cámaras IP).
List<Camara> parsearCanalesXml(String xml, String etiqueta) {
  final bloque =
      RegExp('<$etiqueta(?:\\s[^>]*)?>(.*?)</$etiqueta>', dotAll: true);
  final id = RegExp(r'<id>\s*(\d+)\s*</id>');
  final nombre = RegExp(r'<name>(.*?)</name>', dotAll: true);
  final vistos = <int>{};
  final resultado = <Camara>[];
  for (final m in bloque.allMatches(xml)) {
    final cuerpo = m.group(1) ?? '';
    final n = int.tryParse(id.firstMatch(cuerpo)?.group(1) ?? '');
    if (n == null || n < 1 || n > 64 || !vistos.add(n)) continue;
    resultado.add(
        Camara(n, _limpiarNombre(nombre.firstMatch(cuerpo)?.group(1) ?? '')));
  }
  resultado.sort((a, b) => a.canal.compareTo(b.canal));
  return resultado;
}

/// Consultas de canales, de la más nueva a la más antigua.
const _consultasCanales = [
  ('/ISAPI/System/Video/inputs/channels', 'VideoInputChannel'),
  ('/ISAPI/ContentMgmt/InputProxy/channels', 'InputProxyChannel'),
  // DVR antiguos, anteriores a ISAPI.
  ('/PSIA/System/Video/inputs/channels', 'VideoInputChannel'),
];

/// Pregunta al DVR qué canales tiene y cómo se llama cada uno.
Future<List<Camara>> descubrirCanales(Dvr dvr) async {
  var algunaRespondio = false;
  for (final (ruta, etiqueta) in _consultasCanales) {
    try {
      final lista = parsearCanalesXml(await _obtener(dvr, ruta), etiqueta);
      algunaRespondio = true;
      if (lista.isNotEmpty) return lista;
    } on ErrorDvr catch (e) {
      // Red caída o clave mala: probar otra ruta no ayuda.
      if (!e.noDisponible) rethrow;
    }
  }
  if (algunaRespondio) return const [];
  throw const ErrorDvr(
      'Este DVR (probablemente un modelo antiguo) no permite consultar su lista de canales. '
      'Escribe los números de canal a mano, por ejemplo "1, 2, 3".',
      noDisponible: true);
}

/// Consulta cada DVR al guardar: comprueba usuario/contraseña y completa lo que
/// falte con los nombres que ya tiene puestos el DVR:
/// - "canales" vacío: agrega todos los canales del DVR.
/// - canal sin nombre: usa el nombre del DVR (o "Cámara N" si no se pudo consultar).
/// Los nombres que escribiste a mano se respetan.
/// Una clave rechazada siempre impide guardar: si no, cada cuadro reintentaría
/// con la clave mala y el DVR bloquearía la cuenta.
/// Si un DVR no responde al guardar, se usan los nombres de [anterior].
Future<ConfigApp> completarCanales(ConfigApp config,
    {ConfigApp? anterior}) async {
  final previos = <String, String>{
    for (final d in anterior?.dvrs ?? const <Dvr>[])
      for (final c in d.camaras) '${d.host}#${c.canal}': c.nombre,
  };
  final dvrs = <Dvr>[];
  for (final d in config.dvrs) {
    List<Camara> delDvr = const [];
    try {
      delDvr = await descubrirCanales(d);
    } on ErrorDvr catch (e) {
      // Sin acceso web (p. ej. puerto 80 cerrado) se permite seguir si los
      // canales ya están escritos; con clave rechazada, nunca.
      if (e.deAcceso || d.camaras.isEmpty) {
        throw FormatException('${d.nombre}: ${e.mensaje}');
      }
    }

    final nombres = {for (final c in delDvr) c.canal: c.nombre};
    String nombreDe(int canal) {
      final delEquipo = nombres[canal] ?? '';
      if (delEquipo.isNotEmpty) return delEquipo;
      return previos['${d.host}#$canal'] ?? 'Cámara $canal';
    }

    if (d.camaras.isEmpty) {
      if (delDvr.isEmpty) {
        throw FormatException(
            '${d.nombre}: el DVR no devolvió canales. Escríbelos a mano, por ejemplo "1, 2, 3".');
      }
      dvrs.add(d.conCamaras([
        for (final c in delDvr) Camara(c.canal, nombreDe(c.canal)),
      ]));
    } else {
      dvrs.add(d.conCamaras([
        for (final c in d.camaras)
          if (c.nombre.isNotEmpty) c else Camara(c.canal, nombreDe(c.canal)),
      ]));
    }
  }
  return config.copiar(dvrs: dvrs);
}

/// Revisa que el servicio de video (RTSP) del DVR responda. No envía credenciales.
Future<PasoPrueba> _probarRtsp(Dvr dvr) async {
  Socket? socket;
  try {
    socket = await Socket.connect(dvr.host, dvr.puerto,
        timeout: const Duration(seconds: 5));
    socket.write(
        'OPTIONS rtsp://${dvr.host}:${dvr.puerto}/ RTSP/1.0\r\nCSeq: 1\r\n\r\n');
    final primera = await socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first
        .timeout(const Duration(seconds: 5));
    if (primera.startsWith('RTSP/')) {
      return PasoPrueba(true, 'Puerto RTSP ${dvr.puerto}: responde.');
    }
    return PasoPrueba(false,
        'El puerto ${dvr.puerto} no es de video RTSP. Revisa el puerto.');
  } on TimeoutException {
    return PasoPrueba(false,
        'El puerto ${dvr.puerto} conecta pero no contesta. Revisa el puerto RTSP.');
  } on SocketException {
    return PasoPrueba(false,
        'Sin conexión con ${dvr.host}:${dvr.puerto}. Revisa la IP y el puerto RTSP.');
  } catch (_) {
    return PasoPrueba(
        false, 'El puerto ${dvr.puerto} no respondió como se esperaba.');
  } finally {
    socket?.destroy();
  }
}

/// Pide DESCRIBE por RTSP (autenticándose si el DVR lo exige) y devuelve el
/// código de respuesta, o null si no se pudo completar.
Future<int?> _codigoDescribe(Dvr dvr, String ruta) async {
  Socket? s;
  try {
    s = await Socket.connect(dvr.host, dvr.puerto,
        timeout: const Duration(seconds: 5));
    final socket = s;
    final it =
        StreamIterator(socket.cast<List<int>>().transform(latin1.decoder));
    final uri = 'rtsp://${dvr.host}:${dvr.puerto}$ruta';
    var buf = '';

    Future<void> leerMas() async {
      if (!await it.moveNext().timeout(const Duration(seconds: 5))) {
        throw const SocketException('conexión cerrada');
      }
      buf += it.current;
    }

    Future<(int, List<String>)> pedir(int cseq, String? auth) async {
      socket.write(
          'DESCRIBE $uri RTSP/1.0\r\nCSeq: $cseq\r\nAccept: application/sdp\r\n'
          '${auth == null ? '' : 'Authorization: $auth\r\n'}\r\n');
      while (!buf.contains('\r\n\r\n')) {
        await leerMas();
      }
      final fin = buf.indexOf('\r\n\r\n');
      final lineas = buf.substring(0, fin).split('\r\n');
      buf = buf.substring(fin + 4);
      var largo = 0;
      final desafios = <String>[];
      for (final l in lineas.skip(1)) {
        final i = l.indexOf(':');
        if (i == -1) continue;
        final nombre = l.substring(0, i).trim().toLowerCase();
        final valor = l.substring(i + 1).trim();
        if (nombre == 'content-length') largo = int.tryParse(valor) ?? 0;
        if (nombre == 'www-authenticate') desafios.add(valor);
      }
      while (buf.length < largo) {
        await leerMas();
      }
      buf = buf.substring(largo);
      final partes = lineas.first.split(' ');
      return (partes.length > 1 ? int.tryParse(partes[1]) ?? 0 : 0, desafios);
    }

    var (codigo, desafios) = await pedir(1, null);
    if (codigo == 401) {
      final auth = cabeceraAutorizacion(desafios,
          usuario: dvr.usuario, clave: dvr.clave, metodo: 'DESCRIBE', uri: uri);
      if (auth != null) (codigo, _) = await pedir(2, auth);
    }
    return codigo;
  } catch (_) {
    return null;
  } finally {
    s?.destroy();
  }
}

Future<PasoPrueba> _probarVideo(Dvr dvr, int canal) async {
  final codigo =
      await _codigoDescribe(dvr, '/Streaming/Channels/${canal * 100 + 2}');
  switch (codigo) {
    case 200:
      return PasoPrueba(true, 'Video del canal $canal: correcto.');
    case 401:
      return const PasoPrueba(
          false,
          'Video: usuario o contraseña rechazados (o la TV quedó bloqueada '
          '~30 min por intentos fallidos).');
    case 404:
      final antigua =
          await _codigoDescribe(dvr, '/h264/ch$canal/sub/av_stream');
      if (antigua == 200) {
        return const PasoPrueba(false,
            'El DVR usa la dirección de video antigua (/h264/...), aún no soportada.');
      }
      return PasoPrueba(false, 'El canal $canal no existe en el DVR.');
    case null:
      return const PasoPrueba(
          false, 'No se pudo completar la prueba de video.');
    default:
      return PasoPrueba(false, 'Video: el DVR respondió con el error $codigo.');
  }
}

class ResultadoPrueba {
  final List<PasoPrueba> pasos;

  /// Canales que informó el DVR (vacío si no se pudieron consultar).
  final List<Camara> canales;
  const ResultadoPrueba(this.pasos, this.canales);
}

/// Prueba completa de un DVR para diagnosticar por qué no se ve una cámara.
Future<ResultadoPrueba> probarDvr(Dvr dvr) async {
  final rtsp = await _probarRtsp(dvr);
  final pasos = <PasoPrueba>[rtsp];
  var canales = const <Camara>[];
  var claveRechazada = false;
  try {
    canales = await descubrirCanales(dvr);
    if (canales.isEmpty) {
      pasos.add(const PasoPrueba(true, 'Usuario y contraseña correctos.'));
    } else {
      pasos.add(PasoPrueba(
          true, 'Usuario y contraseña correctos (${canales.length} canales).'));
      final existentes = canales.map((c) => c.canal).toSet();
      final ausentes = dvr.camaras
          .map((c) => c.canal)
          .toSet()
          .difference(existentes)
          .toList()
        ..sort();
      if (ausentes.isNotEmpty) {
        pasos.add(PasoPrueba(false,
            'Canales que no existen en el DVR: ${ausentes.join(', ')}.'));
      }
    }
  } on ErrorDvr catch (e) {
    claveRechazada = e.deAcceso;
    pasos.add(PasoPrueba(
        false,
        e.noDisponible
            ? 'No se pudo leer la lista de canales (modelo antiguo); el video no se afecta.'
            : 'Web del DVR: ${e.mensaje}'));
  }
  if (claveRechazada) {
    // Otro intento fallido acerca el bloqueo de la cuenta en el DVR.
    pasos.add(const PasoPrueba(
        false, 'Video sin probar, para no bloquear la cuenta del DVR.'));
  } else if (rtsp.ok) {
    final canal = dvr.camaras.isNotEmpty
        ? dvr.camaras.first.canal
        : canales.isNotEmpty
            ? canales.first.canal
            : 1;
    pasos.add(await _probarVideo(dvr, canal));
  }
  return ResultadoPrueba(pasos, canales);
}
