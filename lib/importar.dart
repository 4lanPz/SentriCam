import 'dart:async';

import 'package:flutter/material.dart';

import 'almacen.dart';
import 'cuadricula.dart';
import 'modelos.dart';
import 'servidor_config.dart';

/// Muestra la dirección y el código para configurar desde otro equipo.
class PantallaImportar extends StatefulWidget {
  final ConfigApp? actual;
  const PantallaImportar({super.key, this.actual});

  @override
  State<PantallaImportar> createState() => _PantallaImportarState();
}

class _PantallaImportarState extends State<PantallaImportar> {
  late final ServidorConfig _srv;
  String? _url;
  String? _error;
  bool _activo = false;
  Timer? _limite;

  @override
  void initState() {
    super.initState();
    _srv = ServidorConfig(actual: widget.actual, alGuardar: _guardado)
      ..alCambiarCodigo = () {
        if (mounted) setState(() {});
      };
    _arrancar();
  }

  Future<void> _arrancar() async {
    try {
      await _srv.iniciar();
      final ip = await ServidorConfig.ipLocal();
      _limite?.cancel();
      _limite = Timer(const Duration(minutes: 10), () async {
        await _srv.detener();
        if (mounted) setState(() => _activo = false);
      });
      if (!mounted) return;
      setState(() {
        _activo = true;
        _error = null;
        _url = ip == null ? null : 'http://$ip:${ServidorConfig.puerto}';
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo iniciar el acceso: $e');
    }
  }

  Future<void> _guardado(ConfigApp nueva) async {
    await Almacen.guardar(nueva);
    // Pequeña espera para que la respuesta llegue al navegador antes de cerrar.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => PantallaCuadricula(config: nueva)),
        (_) => false,
      );
    });
  }

  @override
  void dispose() {
    _limite?.cancel();
    _srv.detener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contenido = <Widget>[];
    if (_error != null) {
      contenido
          .add(Text(_error!, style: const TextStyle(color: Colors.redAccent)));
    } else if (!_activo) {
      contenido.addAll([
        const Text('El acceso para configurar se cerró por seguridad.'),
        const SizedBox(height: 16),
        ElevatedButton(
          autofocus: true,
          onPressed: _arrancar,
          child: const Text('Volver a activar'),
        ),
      ]);
    } else {
      contenido.addAll([
        const Text(
          'Desde una computadora o celular conectado a la misma red, abre:',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          _url ?? 'No se encontró la IP de la TV',
          style: const TextStyle(fontSize: 32, color: Colors.amber),
        ),
        const SizedBox(height: 24),
        const Text('Código:'),
        Text(
          _srv.codigo,
          style: const TextStyle(fontSize: 48, letterSpacing: 8),
        ),
        const SizedBox(height: 24),
        const Text(
          'Este acceso se cierra solo en 10 minutos o al salir de esta pantalla.',
          style: TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar cámaras'),
        automaticallyImplyLeading: widget.actual != null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(mainAxisSize: MainAxisSize.min, children: contenido),
        ),
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'SentriCam · Desarrollada por 4lanpz',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38),
        ),
      ),
    );
  }
}
