import 'package:flutter/material.dart';

/// Pide el PIN. Tras 3 intentos fallidos bloquea 30 segundos.
class PantallaPin extends StatefulWidget {
  final String pinCorrecto;
  final void Function(BuildContext context) alAcertar;
  const PantallaPin(
      {super.key, required this.pinCorrecto, required this.alAcertar});

  @override
  State<PantallaPin> createState() => _PantallaPinState();
}

class _PantallaPinState extends State<PantallaPin> {
  final _ctrl = TextEditingController();
  int _fallos = 0;
  DateTime? _bloqueadoHasta;
  String? _mensaje;

  void _verificar() {
    final ahora = DateTime.now();
    if (_bloqueadoHasta != null && ahora.isBefore(_bloqueadoHasta!)) {
      final seg = _bloqueadoHasta!.difference(ahora).inSeconds + 1;
      setState(() => _mensaje = 'Espera $seg segundos');
      _ctrl.clear();
      return;
    }
    if (_ctrl.text == widget.pinCorrecto) {
      widget.alAcertar(context);
      return;
    }
    _fallos++;
    if (_fallos >= 3) {
      _fallos = 0;
      _bloqueadoHasta = ahora.add(const Duration(seconds: 30));
      setState(() => _mensaje = 'Demasiados intentos, espera 30 segundos');
    } else {
      setState(() => _mensaje = 'PIN incorrecto');
    }
    _ctrl.clear();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 48),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'PIN'),
                onSubmitted: (_) => _verificar(),
              ),
              if (_mensaje != null)
                Text(_mensaje!,
                    style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 12),
              ElevatedButton(
                  onPressed: _verificar, child: const Text('Entrar')),
            ],
          ),
        ),
      ),
    );
  }
}
