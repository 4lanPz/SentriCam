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
}
