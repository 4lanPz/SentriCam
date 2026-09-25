import 'package:flutter/material.dart';

import 'almacen.dart';
import 'hikvision.dart';
import 'importar.dart';
import 'modelos.dart';

/// Lista los DVR guardados y permite eliminarlos, sin tocar credenciales.
/// Agregar o editar un DVR sigue haciéndose desde el servidor web (por ahora):
/// esta pantalla es el punto de extensión para reemplazar ese paso por un
/// formulario dentro de la app más adelante.
class PantallaAdministrarDvrs extends StatefulWidget {
  final ConfigApp config;
  final void Function(ConfigApp nuevaConfig) alCambiar;
  const PantallaAdministrarDvrs({
    super.key,
    required this.config,
    required this.alCambiar,
  });

  @override
  State<PantallaAdministrarDvrs> createState() =>
      _PantallaAdministrarDvrsState();
}

class _PantallaAdministrarDvrsState extends State<PantallaAdministrarDvrs> {
  late ConfigApp _config = widget.config;

  Future<void> _eliminar(Dvr dvr) async {
    if (_config.dvrs.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Debe quedar al menos un DVR.'),
      ));
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar DVR'),
        content: Text(
          '¿Eliminar "${dvr.nombre}" y sus ${dvr.camaras.length} cámaras de la lista?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final nueva = _config.sinDvr(dvr.nombre);
    await Almacen.guardar(nueva);
    if (!mounted) return;
    setState(() => _config = nueva);
    widget.alCambiar(nueva);
  }

  Future<void> _probar(Dvr dvr) async {
    final resultado = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Probando ${dvr.nombre}'),
        content: const SizedBox(
          height: 48,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
    final pasos = (await probarDvr(dvr)).pasos;
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    await resultado;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Prueba de ${dvr.nombre}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in pasos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        p.ok ? Icons.check_circle : Icons.error,
                        color: p.ok ? Colors.greenAccent : Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(p.texto)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _agregarOEditar() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PantallaImportar(actual: _config)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dvrs = _config.dvrs;
    return Scaffold(
      appBar: AppBar(title: const Text('Administrar DVRs')),
      body: ListView(
        children: [
          for (final dvr in dvrs)
            ListTile(
              title: Text(dvr.nombre),
              subtitle: Text(
                  '${dvr.host}:${dvr.puerto} · ${dvr.camaras.length} cámaras'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    autofocus: dvr == dvrs.first,
                    icon: const Icon(Icons.network_check),
                    tooltip: 'Probar conexión',
                    onPressed: () => _probar(dvr),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Eliminar DVR',
                    onPressed: () => _eliminar(dvr),
                  ),
                ],
              ),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Agregar o editar DVR'),
            subtitle: const Text('Se hace desde el navegador de otro equipo'),
            onTap: _agregarOEditar,
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'SentriCam · Desarrollada por 4lanpz',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }
}
