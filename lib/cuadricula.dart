import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'administrar_dvrs.dart';
import 'almacen.dart';
import 'importar.dart';
import 'modelos.dart';
import 'pin.dart';
import 'vista_camara.dart';

/// Cuadrícula por páginas. Solo se reproducen las cámaras de la página visible.
/// Flechas izquierda/derecha en el borde, CH+/CH- o Página arriba/abajo cambian de página.
class PantallaCuadricula extends StatefulWidget {
  final ConfigApp config;
  const PantallaCuadricula({super.key, required this.config});

  @override
  State<PantallaCuadricula> createState() => _PantallaCuadriculaState();
}

class _PantallaCuadriculaState extends State<PantallaCuadricula> {
  late ConfigApp _config = widget.config;

  /// null = todas las cámaras.
  Seleccion? _seleccion;

  /// Hasta leer la selección guardada no se abre ningún video.
  bool _listo = false;
  int _pagina = 0;
  bool _pausada = false;
  bool _rotacionPausada = false;
  Timer? _rotacion;
  final _primerNodo = FocusNode();

  List<VistaRef> get _vistas => _config.vistasDe(_seleccion);

  int get _totalPaginas => max(1, (_vistas.length / _config.porPagina).ceil());

  @override
  void initState() {
    super.initState();
    _cargarSeleccion();
  }

  Future<void> _cargarSeleccion() async {
    final s = await Almacen.cargarSeleccion();
    if (!mounted) return;
    setState(() {
      _seleccion = s != null && _config.existe(s) ? s : null;
      _listo = true;
    });
    _iniciarRotacion();
  }

  void _iniciarRotacion() {
    _rotacion?.cancel();
    final s = _config.rotacionSegundos;
    if (s > 0 && _totalPaginas > 1) {
      _rotacion = Timer.periodic(Duration(seconds: s), (_) {
        if (!_pausada && !_rotacionPausada) _irA(_pagina + 1);
      });
    }
  }

  void _cambiarSeleccion(Seleccion? s) {
    setState(() {
      _seleccion = s;
      _pagina = 0;
    });
    Almacen.guardarSeleccion(s);
    _iniciarRotacion();
    _enfocarPrimera();
  }

  void _irA(int p) {
    final total = _totalPaginas;
    setState(() => _pagina = ((p % total) + total) % total);
    _enfocarPrimera();
  }

  void _cambioManual(int delta) {
    _irA(_pagina + delta);
    _iniciarRotacion(); // reinicia el conteo tras usar el control
  }

  void _enfocarPrimera() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _primerNodo.context != null) _primerNodo.requestFocus();
    });
  }

  /// Abre otra pantalla y apaga los videos de la cuadrícula mientras tanto.
  Future<void> _abrir(Widget pantalla) async {
    setState(() => _pausada = true);
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => pantalla));
    if (!mounted) return;
    setState(() => _pausada = false);
    _enfocarPrimera();
  }

  void _abrirConfig() {
    final config = _config;
    _abrir(config.pin != null
        ? PantallaPin(
            pinCorrecto: config.pin!,
            alAcertar: (ctx) => Navigator.of(ctx).pushReplacement(
              MaterialPageRoute(
                  builder: (_) => PantallaImportar(actual: config)),
            ),
          )
        : PantallaImportar(actual: config));
  }

  /// Recibe la config actualizada tras eliminar/agregar un DVR en
  /// "Administrar DVRs", sin reiniciar la app.
  void _alCambiarConfig(ConfigApp nueva) {
    if (!mounted) return;
    final s = _seleccion;
    setState(() {
      _config = nueva;
      _pagina = 0;
    });
    if (s != null && !nueva.existe(s)) {
      _cambiarSeleccion(null);
    } else {
      _iniciarRotacion();
    }
  }

  void _abrirAdministrar() {
    final destino =
        PantallaAdministrarDvrs(config: _config, alCambiar: _alCambiarConfig);
    final pin = _config.pin;
    _abrir(pin != null
        ? PantallaPin(
            pinCorrecto: pin,
            alAcertar: (ctx) => Navigator.of(ctx).pushReplacement(
              MaterialPageRoute(builder: (_) => destino),
            ),
          )
        : destino);
  }

  /// Diálogo para elegir todas las cámaras, un grupo o un DVR; no pausa la cuadrícula.
  Future<void> _elegirVista() async {
    final config = _config;
    Widget titulo(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
          child: Text(t,
              style: const TextStyle(color: Colors.amber, fontSize: 13)),
        );
    Widget opcion(BuildContext ctx, Seleccion? s, String texto, int cantidad) =>
        ListTile(
          autofocus: s == _seleccion,
          selected: s == _seleccion,
          title: Text('$texto ($cantidad)'),
          onTap: () => Navigator.pop(ctx, (s,)),
        );

    // Se envuelve en un record para distinguir "Todas" (null) de cerrar sin elegir.
    final elegido = await showDialog<(Seleccion?,)>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('¿Qué cámaras ver?'),
        children: [
          opcion(ctx, null, 'Todas las cámaras', config.vistas.length),
          if (config.grupos.isNotEmpty) titulo('Grupos'),
          for (final g in config.grupos)
            opcion(ctx, Seleccion.grupo(g.nombre), g.nombre,
                config.vistasDe(Seleccion.grupo(g.nombre)).length),
          titulo('DVRs'),
          for (final d in config.dvrs)
            opcion(ctx, Seleccion.dvr(d.nombre), d.nombre, d.camaras.length),
        ],
      ),
    );
    if (elegido == null || !mounted) return;
    _cambiarSeleccion(elegido.$1);
  }

  KeyEventResult _teclas(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent)
      return KeyEventResult.ignored;
    final k = e.logicalKey;

    if (k == LogicalKeyboardKey.channelUp || k == LogicalKeyboardKey.pageDown) {
      _cambioManual(1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.channelDown || k == LogicalKeyboardKey.pageUp) {
      _cambioManual(-1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.contextMenu) {
      _abrirConfig();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Solo con el foco en una cámara: izquierda/derecha en el borde cambian de página.
  /// En la barra de arriba las flechas se mueven entre botones con normalidad.
  KeyEventResult _teclasCuadricula(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent)
      return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.arrowLeft) {
      final derecha = k == LogicalKeyboardKey.arrowRight;
      final foco = FocusManager.instance.primaryFocus;
      final seMovio = foco?.focusInDirection(
              derecha ? TraversalDirection.right : TraversalDirection.left) ??
          false;
      // Si ya no hay celda hacia ese lado, cambia de página.
      if (!seMovio && _totalPaginas > 1) _cambioManual(derecha ? 1 : -1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _rotacion?.cancel();
    _primerNodo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final porPagina = config.porPagina;
    final cols = porPagina <= 1
        ? 1
        : porPagina <= 4
            ? 2
            : porPagina <= 9
                ? 3
                : 4;
    final filas = (porPagina / cols).ceil();
    final totalPaginas = _totalPaginas;
    // Si el total de páginas bajó (p. ej. al filtrar o eliminar un DVR), no
    // se muestra una página fuera de rango mientras _pagina no se reinicia.
    final paginaSegura = _pagina >= totalPaginas ? 0 : _pagina;
    final pagina =
        _vistas.skip(paginaSegura * porPagina).take(porPagina).toList();
    const espacio = 2.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _teclas,
          child: Column(
            children: [
              SizedBox(
                height: 40,
                child: Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.chevron_left, color: Colors.white70),
                      tooltip: 'Página anterior',
                      onPressed:
                          totalPaginas > 1 ? () => _cambioManual(-1) : null,
                    ),
                    Text(
                      'Página ${paginaSegura + 1} de $totalPaginas',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right,
                          color: Colors.white70),
                      tooltip: 'Página siguiente',
                      onPressed:
                          totalPaginas > 1 ? () => _cambioManual(1) : null,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        _seleccion?.nombre ?? 'Todas las cámaras',
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Colors.amber, fontSize: 13),
                      ),
                    ),
                    const Spacer(),
                    if (config.rotacionSegundos > 0 && totalPaginas > 1)
                      IconButton(
                        icon: Icon(
                            _rotacionPausada ? Icons.play_arrow : Icons.pause,
                            color: Colors.white70,
                            size: 20),
                        tooltip: _rotacionPausada
                            ? 'Reanudar cambio automático de página'
                            : 'Pausar cambio automático de página',
                        onPressed: () => setState(
                            () => _rotacionPausada = !_rotacionPausada),
                      ),
                    IconButton(
                      icon: const Icon(Icons.grid_view,
                          color: Colors.white70, size: 20),
                      tooltip: 'Elegir grupo o DVR',
                      onPressed: _elegirVista,
                    ),
                    IconButton(
                      icon: const Icon(Icons.dns,
                          color: Colors.white70, size: 20),
                      tooltip: 'Administrar DVRs',
                      onPressed: _abrirAdministrar,
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings,
                          color: Colors.white70, size: 20),
                      tooltip: 'Configuración',
                      onPressed: _abrirConfig,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _pausada || !_listo
                    ? const SizedBox.expand()
                    : pagina.isEmpty
                        ? const Center(
                            child: Text('No hay cámaras en esta vista',
                                style: TextStyle(color: Colors.white54)),
                          )
                        : Focus(
                            canRequestFocus: false,
                            skipTraversal: true,
                            onKeyEvent: _teclasCuadricula,
                            // Deslizar a los lados cambia de página en pantallas táctiles.
                            child: GestureDetector(
                              onHorizontalDragEnd: (d) {
                                final v = d.primaryVelocity ?? 0;
                                if (v.abs() > 300 && totalPaginas > 1)
                                  _cambioManual(v < 0 ? 1 : -1);
                              },
                              child: LayoutBuilder(builder: (context, c) {
                                final anchoCelda =
                                    (c.maxWidth - espacio * (cols - 1)) / cols;
                                final altoCelda =
                                    (c.maxHeight - espacio * (filas - 1)) /
                                        filas;
                                return GridView.builder(
                                  // Sin esto, GridView suma el alto de las barras del sistema
                                  // como relleno y las filas de abajo quedan cortadas.
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    childAspectRatio: anchoCelda / altoCelda,
                                    mainAxisSpacing: espacio,
                                    crossAxisSpacing: espacio,
                                  ),
                                  itemCount: pagina.length,
                                  itemBuilder: (context, i) {
                                    final v = pagina[i];
                                    return _Celda(
                                      focusNode: i == 0 ? _primerNodo : null,
                                      autofocus: i == 0,
                                      onTap: () =>
                                          _abrir(PantallaCompleta(vista: v)),
                                      child: VistaCamara(
                                        // Clave por posición: al cambiar de página cada
                                        // cuadro reutiliza su reproductor.
                                        key: ValueKey('celda$i'),
                                        url: v.dvr.urlRtsp(v.camara.canal,
                                            substream: config.substream),
                                        nombre: v.camara.nombre,
                                      ),
                                    );
                                  },
                                );
                              }),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Celda navegable con el control remoto: marco amarillo al tener el foco.
class _Celda extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool autofocus;
  final FocusNode? focusNode;
  const _Celda({
    required this.child,
    required this.onTap,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<_Celda> createState() => _CeldaState();
}

class _CeldaState extends State<_Celda> {
  bool _foco = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onTap: widget.onTap,
      focusColor: Colors.transparent,
      onFocusChange: (f) => setState(() => _foco = f),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: _foco ? Colors.amber : Colors.transparent,
            width: 3,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Una sola cámara en calidad principal. El botón Atrás regresa a la cuadrícula.
class PantallaCompleta extends StatelessWidget {
  final VistaRef vista;
  const PantallaCompleta({super.key, required this.vista});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: VistaCamara(
        key: ValueKey('completa-${vista.id}'),
        url: vista.dvr.urlRtsp(vista.camara.canal, substream: false),
        nombre: '${vista.camara.nombre} · ${vista.dvr.nombre}',
      ),
    );
  }
}
