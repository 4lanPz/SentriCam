import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Reproduce un flujo RTSP y se reconecta solo si se cae.
/// Si cambia [url] (otra página de la cuadrícula), reutiliza el mismo
/// reproductor en vez de crear uno nuevo: es más rápido y liviano.
/// Para no pedirle a la TV varios decodificadores de golpe (algunas se cuelgan
/// o se reinician), cada cuadro abre su video tras [retraso].
/// Importante: nunca imprimir la URL en logs, contiene la contraseña.
/// Los mensajes que se muestran en pantalla pasan por [_sanear] para quitar
/// la URL y la contraseña antes de mostrarse.
class VistaCamara extends StatefulWidget {
  final String url;
  final String nombre;

  /// Espera antes de abrir el video, contada después de detener el anterior.
  final Duration retraso;

  /// false = decodificación por software (ver `ConfigApp.hardware`).
  final bool hardware;

  /// Hilos del decodificador por software; null = los que decida mpv.
  final int? hilosSoftware;

  const VistaCamara({
    super.key,
    required this.url,
    required this.nombre,
    this.retraso = Duration.zero,
    this.hardware = true,
    this.hilosSoftware,
  });

  @override
  State<VistaCamara> createState() => _VistaCamaraState();
}

class _VistaCamaraState extends State<VistaCamara> {
  static const _limiteSinImagen = Duration(seconds: 20);

  /// Al crearse, el reproductor que se cerró antes (la cuadrícula o la
  /// pantalla completa) puede estar liberando todavía su decodificador.
  static const _esperaAlCrear = Duration(milliseconds: 600);

  late final Player _player;
  late final VideoController _controller;
  final _subs = <StreamSubscription>[];
  Timer? _reintento;
  Timer? _limite;
  Timer? _gracia;
  bool _cargando = true;
  bool _conError = false;
  bool _sinReintento = false;
  bool _preparado = false;
  int _apertura = 0;
  String? _errorMpv;
  final _registros = <String>[];

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn),
    );
    _controller = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: widget.hardware,
      ),
    );
    _iniciar();
  }

  Future<void> _iniciar() async {
    final nativo = _player.platform;
    if (nativo is NativePlayer) {
      final opciones = {
        // TCP evita imagen gris o cortada; sin caché para menor retraso.
        'rtsp-transport': 'tcp',
        'cache': 'no',
        'network-timeout': '10',
        // Sin audio: no se decodifica lo que nunca se escucha.
        'aid': 'no',
        // Arranque rápido: analiza el flujo 0,5 s en vez de ~5 s antes de mostrar
        // imagen (mismos valores base que el perfil low-latency de mpv).
        'demuxer-lavf-analyzeduration': '0.5',
        'demuxer-lavf-o': 'fflags=+nobuffer',
        'video-latency-hacks': 'yes',
        // Tope de memoria por cámara (por defecto mpv permite ~150 MB).
        'demuxer-max-bytes': '2MiB',
        'demuxer-max-back-bytes': '0',
        // Por software, varias cámaras con todos los hilos cada una saturan la CPU.
        if (!widget.hardware && widget.hilosSoftware != null)
          'vd-lavc-threads': '${widget.hilosSoftware}',
      };
      for (final o in opciones.entries) {
        await nativo.setProperty(o.key, o.value);
      }
    }

    // media_kit también emite "error" por fallas menores del decodificador
    // (típicas en los primeros cuadros de un RTSP). Con imagen se ignoran;
    // sin imagen se espera un poco antes de darlo por fallido.
    _subs.add(_player.stream.error.listen((e) {
      _errorMpv = e;
      if (!_cargando) return;
      if (_errorDeAcceso) {
        _programarReintento();
      } else {
        _gracia ??= Timer(const Duration(seconds: 4), () {
          _gracia = null;
          if (mounted && _cargando) _programarReintento();
        });
      }
    }));
    _subs.add(_player.stream.log.listen((l) {
      if (l.level == 'error' || l.level == 'fatal' || l.level == 'warn') {
        _registros.add(l.text);
        if (_registros.length > 8) _registros.removeAt(0);
      }
    }));
    _subs.add(_player.stream.completed.listen((fin) {
      if (fin) _programarReintento();
    }));
    _subs.add(_player.stream.width.listen((_) => _revisarImagen()));
    _subs.add(_player.stream.buffering.listen((_) => _revisarImagen()));
    // El ancho solo avisa si cambia; al pasar a otra cámara de igual resolución
    // la señal de imagen nueva es que la posición avanza desde cero.
    _subs.add(_player.stream.position.listen((p) {
      if (p > Duration.zero) _revisarImagen(avanzo: true);
    }));

    _preparado = true;
    _abrir(espera: _esperaAlCrear);
  }

  @override
  void didUpdateWidget(VistaCamara anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.url != widget.url) {
      _reintento?.cancel();
      _sinReintento = false;
      if (_preparado) _abrir();
    }
  }

  /// Solo cuenta mientras se espera la primera imagen de la apertura actual;
  /// así un evento tardío de un flujo caído no cancela la reconexión.
  void _revisarImagen({bool avanzo = false}) {
    final w = _player.state.width ?? 0;
    if ((w > 0 || avanzo) && mounted && _cargando) {
      _limite?.cancel();
      _gracia?.cancel();
      _gracia = null;
      _reintento?.cancel();
      setState(() {
        _cargando = false;
        _conError = false;
        _errorMpv = null;
        _registros.clear();
      });
    }
  }

  Future<void> _abrir({Duration espera = Duration.zero}) async {
    if (!mounted) return;
    final apertura = ++_apertura;
    _gracia?.cancel();
    _gracia = null;
    _reintento?.cancel();
    _limite?.cancel();
    _errorMpv = null;
    _registros.clear();
    setState(() {
      _cargando = true;
      _conError = false;
    });
    // stop() deja la posición en cero: así se detecta la imagen de la cámara
    // nueva. También libera el decodificador antes de pedir el siguiente.
    await _player.stop();
    // Si mientras tanto se pidió otra cámara, esa apertura manda.
    if (!mounted || apertura != _apertura) return;
    final total = espera + widget.retraso;
    if (total > Duration.zero) {
      await Future<void>.delayed(total);
      if (!mounted || apertura != _apertura) return;
    }
    _limite = Timer(_limiteSinImagen, () {
      if (mounted && _cargando) _programarReintento();
    });
    await _player.open(Media(widget.url));
  }

  bool get _errorDeAcceso {
    final t = _textoTecnico().toLowerCase();
    return t.contains('401') ||
        t.contains('unauthorized') ||
        t.contains('authorization failed');
  }

  String _textoTecnico() =>
      [..._registros, if (_errorMpv != null) _errorMpv!].join(' ');

  void _programarReintento() {
    if (!mounted || _sinReintento || (_reintento?.isActive ?? false)) return;
    // Con usuario o contraseña mal no se reintenta: el DVR bloquea la cuenta
    // tras varios intentos fallidos.
    if (_errorDeAcceso) {
      _limite?.cancel();
      setState(() {
        _conError = true;
        _sinReintento = true;
      });
      return;
    }
    setState(() => _conError = true);
    _reintento = Timer(const Duration(seconds: 5), _abrir);
  }

  /// Quita del texto la URL, el usuario y la contraseña.
  String _sanear(String texto) {
    var t = texto.replaceAll(widget.url, '[URL]');
    final info = Uri.tryParse(widget.url)?.userInfo ?? '';
    final secretos = <String>{};
    for (final parte in info.split(':')) {
      if (parte.isEmpty) continue;
      secretos.add(parte);
      secretos.add(Uri.decodeComponent(parte));
    }
    if (info.isNotEmpty) secretos.add(info);
    for (final s in secretos) {
      t = t.replaceAll(s, '***');
    }
    t = t.replaceAll(RegExp(r'rtsp://\S+', caseSensitive: false), 'rtsp://…');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length > 140 ? '${t.substring(0, 140)}…' : t;
  }

  /// Traduce el error técnico a algo que se pueda actuar.
  String _explicar() {
    final t = _textoTecnico().toLowerCase();
    if (_errorDeAcceso) {
      return 'Usuario o contraseña rechazados (o este equipo quedó bloqueado ~30 min por intentos fallidos)';
    }
    if (t.contains('403') || t.contains('forbidden')) {
      return 'El usuario no tiene permiso para ver este canal';
    }
    if (t.contains('404') || t.contains('not found')) {
      return 'Ese canal no existe en el DVR';
    }
    if (t.contains('refused')) {
      return 'Conexión rechazada: revisa la IP y el puerto RTSP';
    }
    if (t.contains('unreachable') || t.contains('no route')) {
      return 'No hay ruta al DVR: revisa la red y la IP';
    }
    if (t.contains('timed out') || t.contains('timeout')) {
      return 'El DVR no responde (tiempo agotado)';
    }
    if (t.contains('codec') || t.contains('decoder')) {
      return 'No se pudo decodificar el video de esta cámara';
    }
    if (t.contains('recognize') || t.contains('invalid data')) {
      // Mensaje genérico de mpv para cualquier fallo al abrir el video.
      return 'No se pudo abrir el video (clave, puerto RTSP o canal incorrectos)';
    }
    return 'No se pudo abrir la cámara';
  }

  @override
  void dispose() {
    _reintento?.cancel();
    _limite?.cancel();
    _gracia?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Widget _mensaje() {
    final crudo = _registros.isNotEmpty ? _registros.last : _errorMpv;
    final titulo = _explicar();
    final detalle = crudo == null ? null : _sanear(crudo);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 32),
            const SizedBox(height: 4),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            if (detalle != null)
              Text(
                detalle,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            Text(
              _sinReintento
                  ? 'No se reintenta solo, para no bloquear la cuenta del DVR'
                  : 'Reintentando…',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        Video(
          controller: _controller,
          controls: NoVideoControls,
          fill: Colors.black,
          // Estira la imagen al cuadro completo aunque la cámara sea 4:3 o 16:9.
          fit: BoxFit.fill,
        ),
        // Fondo negro opaco: al reutilizar el reproductor no debe verse la
        // última imagen de la cámara anterior bajo el nombre de la nueva.
        if (_conError)
          ColoredBox(color: Colors.black, child: _mensaje())
        else if (_cargando)
          // Sin animación: 9 o 16 ruedas girando cuestan en una TV antigua.
          const ColoredBox(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam, color: Colors.white24, size: 28),
                  SizedBox(height: 4),
                  Text('Conectando…',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
          ),
        Positioned(
          left: 8,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: Colors.black54,
            child: Text(
              widget.nombre,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
