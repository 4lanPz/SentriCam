// Envía config/config.local.json a la TV usando el servidor de configuración de la app.
// Uso: dart run tool/cargar_config.dart <IP_TV> <CODIGO> [ruta_config]
// Este archivo es solo para desarrollo; no forma parte del APK.
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Uso: dart run tool/cargar_config.dart <IP_TV> <CODIGO> [ruta_config]');
    exit(64);
  }
  final ip = args[0];
  final codigo = args[1];
  final ruta = args.length > 2 ? args[2] : 'config/config.local.json';

  final archivo = File(ruta);
  if (!archivo.existsSync()) {
    stderr.writeln('No existe $ruta. Copia config/config.ejemplo.json y llénalo.');
    exit(66);
  }

  final Object config;
  try {
    config = jsonDecode(await archivo.readAsString());
  } on FormatException catch (e) {
    stderr.writeln('El JSON tiene un error: ${e.message}');
    exit(65);
  }

  final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final req = await cliente.postUrl(Uri.parse('http://$ip:8080/guardar'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'codigo': codigo, 'config': config}));
    final res = await req.close();
    final cuerpo = await res.transform(utf8.decoder).join();
    if (res.statusCode == 200) {
      stdout.writeln('Configuración guardada en la TV.');
    } else {
      final error = (jsonDecode(cuerpo) as Map)['error'] ?? cuerpo;
      stderr.writeln('La TV rechazó la configuración: $error');
      exit(1);
    }
  } on SocketException catch (e) {
    stderr.writeln('No se pudo conectar con la TV ($ip:8080). ¿Está abierta la pantalla de configuración? ${e.message}');
    exit(1);
  } finally {
    cliente.close();
  }
}
