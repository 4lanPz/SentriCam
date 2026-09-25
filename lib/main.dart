import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'almacen.dart';
import 'cuadricula.dart';
import 'importar.dart';
import 'modelos.dart';
import 'pin.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  WakelockPlus.enable(); // evita que la TV active el protector de pantalla
  // En tablets y celulares oculta las barras del sistema; en la TV no hay.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final config = await Almacen.cargar();
  runApp(AppCamaras(config: config));
}

class AppCamaras extends StatelessWidget {
  final ConfigApp? config;
  const AppCamaras({super.key, this.config});

  @override
  Widget build(BuildContext context) {
    final c = config;
    final Widget inicio;
    if (c == null) {
      inicio = const PantallaImportar();
    } else if (c.pin != null) {
      inicio = PantallaPin(
        pinCorrecto: c.pin!,
        alAcertar: (ctx) => Navigator.of(ctx).pushReplacement(
          MaterialPageRoute(builder: (_) => PantallaCuadricula(config: c)),
        ),
      );
    } else {
      inicio = PantallaCuadricula(config: c);
    }

    return MaterialApp(
      title: 'SentriCam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      // El botón central del control remoto funciona como "aceptar".
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.select):
            const ActivateIntent(),
      },
      home: inicio,
    );
  }
}
