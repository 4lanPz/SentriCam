import 'package:camaras_tv/hikvision.dart';
import 'package:camaras_tv/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lee canales y nombres de las entradas de video del DVR', () {
    const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<VideoInputChannelList version="2.0" xmlns="http://www.hikvision.com/ver20/XMLSchema">
<VideoInputChannel version="2.0" xmlns="http://www.hikvision.com/ver20/XMLSchema">
<id>2</id><inputPort>2</inputPort><name>Patio &amp; Bodega</name>
</VideoInputChannel>
<VideoInputChannel><id>1</id><inputPort>1</inputPort><name>Entrada</name></VideoInputChannel>
<VideoInputChannel><id>3</id><name></name></VideoInputChannel>
</VideoInputChannelList>''';
    final r = parsearCanalesXml(xml, 'VideoInputChannel');
    expect(r.map((c) => c.canal), [1, 2, 3]);
    expect(r.map((c) => c.nombre), ['Entrada', 'Patio & Bodega', '']);
  });

  test('lee las cámaras IP de un grabador (InputProxy)', () {
    const xml =
        '<InputProxyChannelList><InputProxyChannel><id>5</id><name>Andén 1</name>'
        '<sourceInputPortDescriptor><ipAddress>10.0.0.9</ipAddress></sourceInputPortDescriptor>'
        '</InputProxyChannel></InputProxyChannelList>';
    final r = parsearCanalesXml(xml, 'InputProxyChannel');
    expect(r.single.canal, 5);
    expect(r.single.nombre, 'Andén 1');
  });

  test('un canal sin nombre queda vacío para completarse con el del DVR', () {
    final r = parsearCamaras('1, 3:Patio, 5');
    expect(r.map((c) => c.canal), [1, 3, 5]);
    expect(r.map((c) => c.nombre), ['', 'Patio', '']);
    expect(parsearCamaras(''), isEmpty);
  });

  group('autenticación con el DVR', () {
    test('digest con qop=auth coincide con el ejemplo del RFC 2617', () {
      final h = cabeceraAutorizacion(
        [
          'Digest realm="testrealm@host.com", qop="auth,auth-int", '
              'nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", opaque="5ccc069c403ebaf9f0171e9517f40e41"'
        ],
        usuario: 'Mufasa',
        clave: 'Circle Of Life',
        metodo: 'GET',
        uri: '/dir/index.html',
        cnonce: '0a4f113b',
      )!;
      expect(h, contains('response="6629fae49393a05397450978507c4ef1"'));
      expect(h, contains('qop=auth, nc=00000001, cnonce="0a4f113b"'));
      expect(h, contains('opaque="5ccc069c403ebaf9f0171e9517f40e41"'));
    });

    test('con Digest y Basic a la vez (Hikvision) usa Digest', () {
      final h = cabeceraAutorizacion(
        ['Basic realm="DVR"', 'Digest realm="DVR", nonce="abc", qop="auth"'],
        usuario: 'admin',
        clave: 'x',
        metodo: 'GET',
        uri: '/ISAPI/System/Video/inputs/channels',
      )!;
      expect(h, startsWith('Digest '));
    });

    test('con SHA-256 y MD5 prefiere MD5', () {
      final h = cabeceraAutorizacion(
        [
          'Digest realm="r", nonce="n", qop="auth", algorithm=SHA-256',
          'Digest realm="r", nonce="n", qop="auth", algorithm=MD5',
        ],
        usuario: 'u',
        clave: 'c',
        metodo: 'GET',
        uri: '/',
      )!;
      expect(h, contains('algorithm=MD5'));
    });

    test('solo Basic (DVR antiguos)', () {
      final h = cabeceraAutorizacion(['Basic realm="Hikvision"'],
          usuario: 'admin',
          clave: '12345',
          metodo: 'DESCRIBE',
          uri: 'rtsp://x/');
      expect(h, 'Basic YWRtaW46MTIzNDU=');
    });
  });
}
