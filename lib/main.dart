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

/// Con el control remoto hay que ver de lejos qué está seleccionado: lo que
/// tiene el foco se pinta en ámbar (botones con fondo ámbar e ícono negro).
ThemeData _tema() {
  final base = ThemeData.dark(useMaterial3: true);
  const acento = Colors.amber;
  bool enfocado(Set<WidgetState> s) => s.contains(WidgetState.focused);
  // null = el color normal del botón.
  final resaltar = ButtonStyle(
    backgroundColor:
        WidgetStateProperty.resolveWith((s) => enfocado(s) ? acento : null),
    foregroundColor: WidgetStateProperty.resolveWith(
        (s) => enfocado(s) ? Colors.black : null),
    iconColor: WidgetStateProperty.resolveWith(
        (s) => enfocado(s) ? Colors.black : null),
  );
  return base.copyWith(
    // Listas (p. ej. "¿Qué cámaras ver?" y "Administrar DVRs").
    focusColor: acento.withValues(alpha: 0.4),
    iconButtonTheme: IconButtonThemeData(style: resaltar),
    textButtonTheme: TextButtonThemeData(style: resaltar),
    elevatedButtonTheme: ElevatedButtonThemeData(style: resaltar),
    filledButtonTheme: FilledButtonThemeData(style: resaltar),
    outlinedButtonTheme: OutlinedButtonThemeData(style: resaltar),
  );
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
      theme: _tema(),
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
