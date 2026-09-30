class Camara {
  final int canal;
  final String nombre;
  const Camara(this.canal, this.nombre);
}

class Dvr {
  final String nombre;
  final String host;
  final int puerto;
  final int puertoHttp;
  final String usuario;
  final String clave;
  final List<Camara> camaras;

  const Dvr({
    required this.nombre,
    required this.host,
    required this.puerto,
    this.puertoHttp = 80,
    required this.usuario,
    required this.clave,
    required this.camaras,
  });

  /// Formato Hikvision: canal * 100 + 1 (principal) o + 2 (substream).
  String urlRtsp(int canal, {required bool substream}) {
    final u = Uri.encodeComponent(usuario);
    final c = Uri.encodeComponent(clave);
    final flujo = canal * 100 + (substream ? 2 : 1);
    return 'rtsp://$u:$c@$host:$puerto/Streaming/Channels/$flujo';
  }

  String get canalesTexto =>
      camaras.map((c) => '${c.canal}:${c.nombre}').join(', ');

  Dvr conClave(String nuevaClave) => Dvr(
        nombre: nombre,
        host: host,
        puerto: puerto,
        puertoHttp: puertoHttp,
        usuario: usuario,
        clave: nuevaClave,
        camaras: camaras,
      );

  Dvr conCamaras(List<Camara> nuevas) => Dvr(
        nombre: nombre,
        host: host,
        puerto: puerto,
        puertoHttp: puertoHttp,
        usuario: usuario,
        clave: clave,
        camaras: nuevas,
      );

  Map<String, dynamic> toJson({bool incluirClave = true}) => {
        'nombre': nombre,
        'host': host,
        'puerto': puerto,
        'puertoHttp': puertoHttp,
        'usuario': usuario,
        'clave': incluirClave ? clave : '',
        'canales': canalesTexto,
      };

  factory Dvr.fromJson(Map<String, dynamic> j) {
    final nombre = (j['nombre'] as String?)?.trim() ?? '';
    try {
      return Dvr(
        nombre: nombre,
        host: (j['host'] as String?)?.trim() ?? '',
        puerto: (j['puerto'] as num?)?.toInt() ?? 554,
        puertoHttp: (j['puertoHttp'] as num?)?.toInt() ?? 80,
        usuario: (j['usuario'] as String?)?.trim() ?? '',
        clave: (j['clave'] as String?) ?? '',
        camaras: parsearCamaras((j['canales'] as String?) ?? ''),
      );
    } on FormatException catch (e) {
      throw FormatException('$nombre: ${e.message}');
    }
  }
}

/// Una cámara concreta de un DVR concreto, tal como se muestra en pantalla.
class VistaRef {
  final Dvr dvr;
  final Camara camara;
  const VistaRef(this.dvr, this.camara);
  String get id => '${dvr.nombre}#${camara.canal}';
}

/// Cámara dentro de un grupo: DVR (por nombre) y canal.
class CamaraRef {
  final String dvr;
  final int canal;
  const CamaraRef(this.dvr, this.canal);

  Map<String, dynamic> toJson() => {'dvr': dvr, 'canal': canal};

  factory CamaraRef.fromJson(Map<String, dynamic> j) => CamaraRef(
        (j['dvr'] as String?)?.trim() ?? '',
        (j['canal'] as num?)?.toInt() ?? 0,
      );
}

/// Cámaras de uno o varios DVR que se ven juntas, por ejemplo las de una planta.
class Grupo {
  final String nombre;
  final List<CamaraRef> camaras;
  const Grupo(this.nombre, this.camaras);

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'camaras': camaras.map((c) => c.toJson()).toList(),
      };

  factory Grupo.fromJson(Map<String, dynamic> j) => Grupo(
        (j['nombre'] as String?)?.trim() ?? '',
        ((j['camaras'] as List?) ?? const [])
            .map((e) => CamaraRef.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Lo que muestra la cuadrícula cuando no son todas las cámaras: un grupo o un DVR.
class Seleccion {
  final bool esGrupo;
  final String nombre;
  const Seleccion.grupo(this.nombre) : esGrupo = true;
  const Seleccion.dvr(this.nombre) : esGrupo = false;

  /// Texto para guardarla y recordarla al reiniciar la TV.
  String get clave => '${esGrupo ? 'g' : 'd'}:$nombre';

  static Seleccion? desdeClave(String? t) {
    if (t == null || t.length < 3 || t[1] != ':') return null;
    final nombre = t.substring(2);
    return switch (t[0]) {
      'g' => Seleccion.grupo(nombre),
      'd' => Seleccion.dvr(nombre),
      _ => null,
    };
  }

  @override
  bool operator ==(Object o) =>
      o is Seleccion && o.esGrupo == esGrupo && o.nombre == nombre;

  @override
  int get hashCode => Object.hash(esGrupo, nombre);
}

class ConfigApp {
  final List<Dvr> dvrs;
  final List<Grupo> grupos;
  final int porPagina;
  final bool substream;

  /// Pantalla completa en calidad principal; en falso usa el substream
  /// (para TV que se traban al ampliar una cámara).
  final bool completaAlta;

  /// Decodificar el video con el chip de la TV (MediaCodec). En falso se
  /// decodifica por software: más carga de CPU, pero evita fallas del
  /// decodificador de algunas TV.
  final bool hardware;
  final int rotacionSegundos;
  final String? pin;

  const ConfigApp({
    required this.dvrs,
    this.grupos = const [],
    this.porPagina = 9,
    this.substream = true,
    this.completaAlta = true,
    this.hardware = true,
    this.rotacionSegundos = 0,
    this.pin,
  });

  ConfigApp copiar({List<Dvr>? dvrs, List<Grupo>? grupos}) => ConfigApp(
        dvrs: dvrs ?? this.dvrs,
        grupos: grupos ?? this.grupos,
        porPagina: porPagina,
        substream: substream,
        completaAlta: completaAlta,
        hardware: hardware,
        rotacionSegundos: rotacionSegundos,
        pin: pin,
      );

  /// Todas las cámaras en el orden del archivo: DVR por DVR, canal por canal.
  List<VistaRef> get vistas => [
        for (final d in dvrs)
          for (final c in d.camaras) VistaRef(d, c),
      ];

  /// Cámaras de un grupo o un DVR (null = todas). Las referencias de un grupo
  /// que ya no existan se omiten.
  List<VistaRef> vistasDe(Seleccion? s) {
    if (s == null) return vistas;
    if (!s.esGrupo)
      return vistas.where((v) => v.dvr.nombre == s.nombre).toList();
    final grupo = grupos.where((g) => g.nombre == s.nombre).firstOrNull;
    if (grupo == null) return const [];
    return [
      for (final r in grupo.camaras)
        for (final d in dvrs.where((d) => d.nombre == r.dvr))
          for (final c in d.camaras.where((c) => c.canal == r.canal))
            VistaRef(d, c),
    ];
  }

  bool existe(Seleccion s) => s.esGrupo
      ? grupos.any((g) => g.nombre == s.nombre)
      : dvrs.any((d) => d.nombre == s.nombre);

  Map<String, dynamic> toJson({bool incluirClaves = true}) => {
        'camarasPorPagina': porPagina,
        'substream': substream,
        'pantallaCompletaAlta': completaAlta,
        'decodificacionHardware': hardware,
        'rotacionSegundos': rotacionSegundos,
        'pin': pin ?? '',
        'dvrs': dvrs.map((d) => d.toJson(incluirClave: incluirClaves)).toList(),
        'grupos': grupos.map((g) => g.toJson()).toList(),
      };

  factory ConfigApp.fromJson(Map<String, dynamic> j) {
    final pinTxt = (j['pin'] as String?)?.trim() ?? '';
    return ConfigApp(
      dvrs: ((j['dvrs'] as List?) ?? const [])
          .map((e) => Dvr.fromJson(e as Map<String, dynamic>))
          .toList(),
      grupos: ((j['grupos'] as List?) ?? const [])
          .map((e) => Grupo.fromJson(e as Map<String, dynamic>))
          .toList(),
      porPagina: (j['camarasPorPagina'] as num?)?.toInt() ?? 9,
      substream: j['substream'] as bool? ?? true,
      completaAlta: j['pantallaCompletaAlta'] as bool? ?? true,
      hardware: j['decodificacionHardware'] as bool? ?? true,
      rotacionSegundos: (j['rotacionSegundos'] as num?)?.toInt() ?? 0,
      pin: pinTxt.isEmpty ? null : pinTxt,
    );
  }

  /// Si un DVR llega con "clave" vacía, conserva la guardada para la misma IP y
  /// usuario (así las contraseñas no viajan de ida y vuelta). Si la IP cambió no
  /// se reutiliza: la contraseña nunca se envía a otro equipo.
  ConfigApp conClavesDe(ConfigApp? anterior) {
    if (anterior == null) return this;
    String? previa(Dvr d) {
      final mismos = anterior.dvrs
          .where((p) => p.host == d.host && p.usuario == d.usuario);
      return (mismos.where((p) => p.nombre == d.nombre).firstOrNull ??
              mismos.firstOrNull)
          ?.clave;
    }

    return copiar(dvrs: [
      for (final d in dvrs)
        if (d.clave.isEmpty && previa(d) != null) d.conClave(previa(d)!) else d,
    ]);
  }

  /// Quita un DVR por nombre (y sus cámaras de los grupos) sin tocar
  /// credenciales de los demás. Un grupo que queda vacío se elimina.
  ConfigApp sinDvr(String nombre) => copiar(
        dvrs: dvrs.where((d) => d.nombre != nombre).toList(),
        grupos: [
          for (final g in grupos)
            if (g.camaras.any((c) => c.dvr != nombre))
              Grupo(g.nombre, g.camaras.where((c) => c.dvr != nombre).toList()),
        ],
      );

  /// Se exige al guardar desde la web. Al arrancar no: una referencia vieja
  /// no debe dejar la TV sin configuración (se omite al mostrar).
  void validarGrupos() {
    final nombres = <String>{};
    for (final g in grupos) {
      if (g.nombre.isEmpty) {
        throw const FormatException('Cada grupo necesita un nombre');
      }
      if (!nombres.add(g.nombre)) {
        throw FormatException('Nombre de grupo repetido: ${g.nombre}');
      }
      if (g.camaras.isEmpty) {
        throw FormatException('El grupo "${g.nombre}" no tiene cámaras');
      }
      final vistos = <String>{};
      for (final r in g.camaras) {
        final d = dvrs.where((d) => d.nombre == r.dvr).firstOrNull;
        if (d == null) {
          throw FormatException(
              'Grupo "${g.nombre}": no existe el DVR "${r.dvr}"');
        }
        if (!d.camaras.any((c) => c.canal == r.canal)) {
          throw FormatException(
              'Grupo "${g.nombre}": el DVR "${r.dvr}" no tiene el canal ${r.canal}');
        }
        if (!vistos.add('${r.dvr}#${r.canal}')) {
          throw FormatException(
              'Grupo "${g.nombre}": la cámara ${r.canal} de "${r.dvr}" está repetida');
        }
      }
    }
  }

  /// Lanza FormatException con un mensaje claro si algo está mal.
  /// Con [exigirCanales] en falso se acepta un DVR sin canales (aún por descubrir).
  void validar({bool exigirCanales = true}) {
    if (dvrs.isEmpty) throw const FormatException('Agrega al menos un DVR');
    if (![1, 4, 6, 9, 16].contains(porPagina)) {
      throw const FormatException('camarasPorPagina debe ser 1, 4, 6, 9 o 16');
    }
    if (rotacionSegundos != 0 && rotacionSegundos < 10) {
      throw const FormatException(
          'rotacionSegundos debe ser 0 (apagado) o al menos 10');
    }
    if (pin != null && !RegExp(r'^\d{4,6}$').hasMatch(pin!)) {
      throw const FormatException('El PIN debe tener de 4 a 6 dígitos');
    }
    final nombres = <String>{};
    for (final d in dvrs) {
      if (d.nombre.isEmpty) {
        throw const FormatException('Cada DVR necesita un "nombre"');
      }
      if (!nombres.add(d.nombre)) {
        throw FormatException('Nombre de DVR repetido: ${d.nombre}');
      }
      if (!esIpPrivada(d.host)) {
        throw FormatException('${d.nombre}: la IP debe ser de red local');
      }
      if (d.puerto < 1 || d.puerto > 65535) {
        throw FormatException('${d.nombre}: puerto inválido');
      }
      if (d.puertoHttp < 1 || d.puertoHttp > 65535) {
        throw FormatException('${d.nombre}: puertoHttp inválido');
      }
      if (d.usuario.isEmpty) {
        throw FormatException('${d.nombre}: falta el usuario');
      }
      if (d.clave.isEmpty) {
        throw FormatException('${d.nombre}: falta la contraseña');
      }
      if (exigirCanales && d.camaras.isEmpty) {
        throw FormatException('${d.nombre}: no tiene canales');
      }
    }
  }
}

/// Solo acepta IPs de red local (10.x, 172.16-31.x, 192.168.x).
bool esIpPrivada(String ip) {
  final partes = ip.trim().split('.');
  if (partes.length != 4) return false;
  final n = partes.map(int.tryParse).toList();
  if (n.any((x) => x == null || x < 0 || x > 255)) return false;
  final a = n[0]!, b = n[1]!;
  return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
}

/// Convierte "1:Entrada, 3:Patio, 5, 8-12" en una lista de cámaras.
/// Un canal sin nombre queda con nombre vacío: se completa con el nombre
/// que tiene puesto el DVR (ver hikvision.dart). Los repetidos se ignoran.
List<Camara> parsearCamaras(String texto) {
  final resultado = <Camara>[];
  final vistos = <int>{};
  final rango = RegExp(r'^(\d+)\s*-\s*(\d+)$');
  for (final item in texto.split(',')) {
    final t = item.trim();
    if (t.isEmpty) continue;
    final r = rango.firstMatch(t);
    if (r != null) {
      final desde = int.parse(r.group(1)!), hasta = int.parse(r.group(2)!);
      if (desde < 1 || hasta > 64 || desde > hasta) {
        throw FormatException('rango de canales inválido "$t"');
      }
      for (var n = desde; n <= hasta; n++) {
        if (vistos.add(n)) resultado.add(Camara(n, ''));
      }
      continue;
    }
    final i = t.indexOf(':');
    final canal = int.tryParse(i == -1 ? t : t.substring(0, i).trim());
    if (canal == null || canal < 1 || canal > 64) {
      throw FormatException('canal inválido "$t"');
    }
    final nombre = i == -1 ? '' : t.substring(i + 1).trim();
    if (vistos.add(canal)) resultado.add(Camara(canal, nombre));
  }
  return resultado;
}
