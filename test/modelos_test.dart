import 'package:camaras_tv/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

Dvr _dvr(String nombre, String host,
        {String clave = 'x', String canales = '1, 2, 3'}) =>
    Dvr(
      nombre: nombre,
      host: host,
      puerto: 554,
      usuario: 'admin',
      clave: clave,
      camaras: parsearCamaras(canales),
    );

void main() {
  test('rangos de canales y repetidos', () {
    expect(parsearCamaras('1-4, 3, 8').map((c) => c.canal), [1, 2, 3, 4, 8]);
    expect(() => parsearCamaras('5-2'), throwsFormatException);
    expect(() => parsearCamaras('1-65'), throwsFormatException);
  });

  test('grupos: ida y vuelta por JSON y cámaras en el orden del grupo', () {
    final c = ConfigApp.fromJson(ConfigApp(
      dvrs: [_dvr('A', '192.168.1.10'), _dvr('B', '192.168.1.11')],
      grupos: const [
        Grupo('Planta 1',
            [CamaraRef('B', 2), CamaraRef('A', 1), CamaraRef('A', 9)]),
      ],
    ).toJson());
    final vistas = c.vistasDe(const Seleccion.grupo('Planta 1'));
    // La referencia al canal 9 (que no existe) se omite al mostrar.
    expect(vistas.map((v) => v.id), ['B#2', 'A#1']);
    expect(c.vistasDe(const Seleccion.dvr('A')).length, 3);
    expect(c.vistasDe(null).length, 6);
    expect(c.vistasDe(const Seleccion.grupo('No existe')), isEmpty);
    expect(() => c.validarGrupos(), throwsFormatException);
  });

  test('eliminar un DVR lo quita de los grupos y borra grupos vacíos', () {
    final c = ConfigApp(
      dvrs: [_dvr('A', '192.168.1.10'), _dvr('B', '192.168.1.11')],
      grupos: const [
        Grupo('Mixto', [CamaraRef('A', 1), CamaraRef('B', 1)]),
        Grupo('Solo B', [CamaraRef('B', 2)]),
      ],
    ).sinDvr('B');
    expect(c.grupos.map((g) => g.nombre), ['Mixto']);
    expect(c.grupos.single.camaras.map((r) => r.dvr), ['A']);
  });

  test('la contraseña guardada solo se reutiliza con la misma IP y usuario',
      () {
    final anterior =
        ConfigApp(dvrs: [_dvr('A', '192.168.1.10', clave: 'secreta')]);
    final renombrado =
        ConfigApp(dvrs: [_dvr('Nuevo nombre', '192.168.1.10', clave: '')])
            .conClavesDe(anterior);
    expect(renombrado.dvrs.single.clave, 'secreta');
    final otraIp = ConfigApp(dvrs: [_dvr('A', '192.168.1.99', clave: '')])
        .conClavesDe(anterior);
    expect(otraIp.dvrs.single.clave, isEmpty);
  });

  test('validación de grupos al guardar', () {
    ConfigApp grupos(List<Grupo> g) =>
        ConfigApp(dvrs: [_dvr('A', '192.168.1.10')], grupos: g);
    grupos(const [
      Grupo('Ok', [CamaraRef('A', 1)])
    ]).validarGrupos();
    expect(() => grupos(const [Grupo('Vacío', [])]).validarGrupos(),
        throwsFormatException);
    expect(
        () => grupos(const [
              Grupo('X', [CamaraRef('A', 1)]),
              Grupo('X', [CamaraRef('A', 2)])
            ]).validarGrupos(),
        throwsFormatException);
    expect(
        () => grupos(const [
              Grupo('Y', [CamaraRef('Z', 1)])
            ]).validarGrupos(),
        throwsFormatException);
  });

  test('la selección se guarda y se recupera', () {
    for (final s in const [
      Seleccion.grupo('Planta: 1'),
      Seleccion.dvr('DVR A')
    ]) {
      expect(Seleccion.desdeClave(s.clave), s);
    }
    expect(Seleccion.desdeClave('basura'), isNull);
    expect(Seleccion.desdeClave(null), isNull);
  });

  test('opciones de video: por defecto activas y se conservan por JSON', () {
    final vieja = ConfigApp.fromJson({'dvrs': []});
    expect(vieja.completaAlta, isTrue);
    expect(vieja.hardware, isTrue);

    final c = ConfigApp.fromJson({
      'pantallaCompletaAlta': false,
      'decodificacionHardware': false,
      'dvrs': [_dvr('A', '192.168.1.10').toJson()],
    });
    final vuelta = ConfigApp.fromJson(c.toJson());
    expect(vuelta.completaAlta, isFalse);
    expect(vuelta.hardware, isFalse);
    expect(vuelta.sinDvr('A').hardware, isFalse);
  });

  group('equipo genérico', () {
    Dvr generico(
            {String alta = '/cam/realmonitor?channel={canal}&subtype=0',
            String liviana = '/cam/realmonitor?channel={canal}&subtype=1',
            String canales = '1, 3:Porton'}) =>
        Dvr.fromJson({
          'nombre': 'G',
          'marca': 'generico',
          'host': '192.168.1.80',
          'puerto': 554,
          'usuario': 'admin',
          'clave': 'a@b',
          'canales': canales,
          'rutaPrincipal': alta,
          'rutaLiviana': liviana,
        });

    test('arma la URL con la ruta escrita y el número de canal', () {
      final d = generico();
      expect(d.urlRtsp(3, substream: false),
          'rtsp://admin:a%40b@192.168.1.80:554/cam/realmonitor?channel=3&subtype=0');
      expect(d.rutaVideo(3, substream: true),
          '/cam/realmonitor?channel=3&subtype=1');
      // Sin ruta liviana usa la de calidad alta.
      expect(generico(liviana: '').rutaVideo(2, substream: true),
          '/cam/realmonitor?channel=2&subtype=0');
    });

    test('se conserva por JSON y un DVR sin marca es Hikvision', () {
      final vuelta = Dvr.fromJson(generico().toJson());
      expect(vuelta.marca, Marca.generico);
      expect(vuelta.rutaLiviana, '/cam/realmonitor?channel={canal}&subtype=1');
      final hik = _dvr('H', '192.168.1.10');
      expect(Dvr.fromJson(hik.toJson()).marca, Marca.hikvision);
      expect(hik.toJson().containsKey('rutaPrincipal'), isFalse);
      expect(
          hik.urlRtsp(3, substream: true), endsWith('/Streaming/Channels/302'));
      expect(() => Dvr.fromJson({'nombre': 'X', 'marca': 'otra'}),
          throwsFormatException);
    });

    test('exige ruta válida y canales escritos', () {
      ConfigApp config(Dvr d) => ConfigApp(dvrs: [d]);
      expect(() => config(generico()).validar(), returnsNormally);
      for (final mala in ['', 'cam/1', '/con espacio', '/u@x']) {
        expect(() => config(generico(alta: mala)).validar(exigirCanales: false),
            throwsFormatException,
            reason: mala);
      }
      expect(() => config(generico(canales: '')).validar(exigirCanales: false),
          throwsFormatException);
    });
  });
}
