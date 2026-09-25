#!/usr/bin/env python3
"""Diagnóstico rápido de un DVR Hikvision desde la PC (solo desarrollo; no entra al APK).

Uso:
  python tool/probar_dvr.py 192.168.1.64 -u visor
  python tool/probar_dvr.py 192.168.1.64 -u visor --canal 3 --rtsp 554
  python tool/probar_dvr.py 192.168.1.64 --puertos 554,8000,10554
  python tool/probar_dvr.py 192.168.1.64 -u visor --escanear   (busca RTSP en todos los puertos)

Qué hace, en orden:
  0. Identifica el equipo por su página web (servidor, título), sin credenciales.
  1. Prueba puertos y dice cuál habla RTSP (no necesita contraseña).
  2. Con -u pide la contraseña (oculta, nunca se imprime ni se guarda) y prueba el
     acceso web (ISAPI): usuario/clave y nombres de los canales.
  3. Pide el video por RTSP como lo hace la app (TCP) y mide cuánto tarda en llegar.
Solo librería estándar de Python 3.
"""
import argparse
import base64
import concurrent.futures
import getpass
import hashlib
import http.client
import ipaddress
import re
import socket
import subprocess
import sys
import time

PUERTOS_COMUNES = [554, 8554, 10554, 555, 7070, 8000, 80, 8080, 443]


def md5(s):
    return hashlib.md5(s.encode("latin-1")).hexdigest()


# ---------------------------------------------------------------- puertos

def hablar(host, puerto, datos, espera=3.0):
    """Envía bytes y devuelve lo que responda; None si no se pudo conectar."""
    try:
        s = socket.create_connection((host, puerto), timeout=espera)
    except OSError:
        return None
    buf = b""
    try:
        s.sendall(datos)
        s.settimeout(espera)
        while len(buf) < 4096:
            d = s.recv(4096)
            if not d:
                break
            buf += d
            if b"\r\n\r\n" in buf:
                break
    except OSError:
        # Timeout o conexión cortada por el DVR: se devuelve lo que llegó (posiblemente nada).
        pass
    finally:
        s.close()
    return buf


def clasificar(host, p):
    """Devuelve (habla_rtsp, descripción) para un puerto."""
    r = hablar(host, p, f"OPTIONS rtsp://{host}:{p}/ RTSP/1.0\r\nCSeq: 1\r\n\r\n".encode())
    if r is None:
        return False, "cerrado o sin respuesta"
    if r.startswith(b"RTSP/"):
        return True, "RTSP   <-- este habla video"
    if r.startswith(b"HTTP/"):
        return False, "servicio web (HTTP), no es video"
    if not r:
        return False, "abre pero no contesta o corta la conexión (típico del puerto de servidor/SDK de iVMS)"
    return False, "responde algo que no es RTSP ni HTTP"


def buscar_puerto_rtsp(host, puertos):
    print(f"== 1. Buscando el puerto de video (RTSP) en {host} ==")
    encontrado = None
    for p in puertos:
        es_rtsp, texto = clasificar(host, p)
        print(f"  {p:>5}: {texto}")
        if es_rtsp:
            encontrado = encontrado or p
    return encontrado


def escanear(host):
    """Busca todos los puertos TCP abiertos y clasifica cada uno."""
    print(f"== 1. Escaneando todos los puertos de {host} (tarda 1-2 minutos) ==")

    def abierto(p):
        try:
            with socket.create_connection((host, p), timeout=0.35):
                return p
        except OSError:
            return None

    abiertos = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=250) as ex:
        for p in ex.map(abierto, range(1, 65536), chunksize=128):
            if p:
                abiertos.append(p)
    print(f"  Puertos abiertos: {', '.join(map(str, abiertos)) or 'ninguno'}")
    encontrado = None
    for p in abiertos:
        es_rtsp, texto = clasificar(host, p)
        print(f"  {p:>5}: {texto}")
        if es_rtsp:
            encontrado = encontrado or p
    return encontrado


def identificar(host, puerto_http):
    """Muestra qué servidor web tiene el equipo (sin credenciales), para saber qué es."""
    print(f"== 0. Identificando el equipo (web en el puerto {puerto_http}) ==")
    try:
        c = http.client.HTTPConnection(host, puerto_http, timeout=6)
        try:
            c.request("GET", "/")
            r = c.getresponse()
            cuerpo = r.read(65536).decode("utf-8", "replace")
            print(f"  Respuesta: {r.status}   Servidor: {r.getheader('Server') or '(no lo indica)'}")
            if r.getheader("Location"):
                print(f"  Redirige a: {r.getheader('Location')}")
        finally:
            c.close()
    except (OSError, http.client.HTTPException):
        print("  La web no respondió.")
        return
    titulo = re.search(r"<title[^>]*>(.*?)</title>", cuerpo, re.I | re.S)
    if titulo:
        print(f"  Título de la página: {titulo.group(1).strip()[:80]}")
    pistas = [p for p in ("hikvision", "hiwatch", "webcomponents", "activex", "ocx", "plugin",
                          "doc/page", "login.asp", "psia", "isapi", "dahua", "xvr", "nvr", "dvr")
              if p in cuerpo.lower()]
    if pistas:
        print(f"  Pistas en la página: {', '.join(pistas)}")
    m = re.search(r'(?:location(?:\.href)?\s*=|url=)\s*["\']?([^"\'>\s;]+)', cuerpo, re.I)
    if m:
        print(f"  La página envía a: {m.group(1)[:80]}")


# ------------------------------------------------------- autenticación
# Misma lógica que cabeceraAutorizacion() en lib/hikvision.dart, para que el
# script dé el mismo resultado que la app.

def _params(texto):
    return {k.lower(): (a if a or not b else b)
            for k, a, b in re.findall(r'(\w+)\s*=\s*(?:"([^"]*)"|([^\s,]+))', texto)}


def resumen_desafios(desafios):
    partes = []
    for d in desafios:
        esquema = d.strip().split(" ", 1)[0]
        if esquema.lower() == "digest":
            p = _params(d.strip()[6:])
            partes.append(f"Digest ({p.get('algorithm', 'MD5')}, qop={p.get('qop', 'ninguno')})")
        else:
            partes.append(esquema)
    return " | ".join(partes) or "(ninguno)"


class Autenticacion:
    """Calcula la cabecera Authorization (digest o basic) a partir del 401 del DVR."""

    ALGORITMOS = {"MD5", "MD5-SESS", "SHA-256", "SHA-256-SESS"}

    def __init__(self, usuario, clave):
        self.usuario, self.clave = usuario, clave
        self.p = None
        self.basic = False
        self.nc = 0

    def cargar(self, www_authenticate):
        self.p, self.basic = None, False
        for v in www_authenticate:
            t = v.strip()
            esquema = t.split(" ", 1)[0].lower()
            if esquema == "basic":
                self.basic = True
            elif esquema == "digest" and " " in t:
                p = _params(t.split(" ", 1)[1])
                alg = p.get("algorithm", "MD5").upper()
                if alg not in self.ALGORITMOS:
                    continue
                actual_md5 = self.p is None or self.p.get("algorithm", "MD5").upper().startswith("MD5")
                if self.p is None or (not actual_md5 and alg.startswith("MD5")):
                    self.p = p

    def disponible(self):
        return self.p is not None or self.basic

    def cabecera(self, metodo, uri):
        if self.p is None:
            return "Basic " + base64.b64encode(f"{self.usuario}:{self.clave}".encode()).decode()
        p = self.p
        alg = p.get("algorithm", "MD5").upper()
        fn = hashlib.sha256 if alg.startswith("SHA-256") else hashlib.md5

        def h(v):
            return fn(v.encode("utf-8")).hexdigest()

        cnonce = md5(str(time.time()))[:16]
        ha1 = h(f"{self.usuario}:{p.get('realm', '')}:{self.clave}")
        if alg.endswith("-SESS"):
            ha1 = h(f"{ha1}:{p.get('nonce', '')}:{cnonce}")
        ha2 = h(f"{metodo}:{uri}")
        base = (f'Digest username="{self.usuario}", realm="{p.get("realm", "")}", '
                f'nonce="{p.get("nonce", "")}", uri="{uri}"')
        con_qop = "auth" in [q.strip().lower() for q in p.get("qop", "").split(",")]
        if con_qop:
            self.nc += 1
            nc = f"{self.nc:08x}"
            resp = h(f"{ha1}:{p.get('nonce', '')}:{nc}:{cnonce}:auth:{ha2}")
        else:
            resp = h(f"{ha1}:{p.get('nonce', '')}:{ha2}")
        b = f'{base}, response="{resp}"'
        if "algorithm" in p:
            b += f", algorithm={p['algorithm']}"
        if "opaque" in p:
            b += f', opaque="{p["opaque"]}"'
        if con_qop:
            b += f', qop=auth, nc={nc}, cnonce="{cnonce}"'
        return b


# ------------------------------------------------------------------ web

def http_get(host, puerto, ruta, auth=None):
    c = http.client.HTTPConnection(host, puerto, timeout=8)
    try:
        c.request("GET", ruta, headers={"Authorization": auth} if auth else {})
        r = c.getresponse()
        cuerpo = r.read(1024 * 1024).decode("utf-8", "replace")
        return r.status, r.headers.get_all("WWW-Authenticate") or [], cuerpo
    finally:
        c.close()


class No404(RuntimeError):
    pass


def consultar(host, puerto_http, usuario, clave, ruta, informar):
    try:
        estado, desafios, cuerpo = http_get(host, puerto_http, ruta)
        if estado == 401:
            if informar:
                print(f"  El DVR pide autenticación: {resumen_desafios(desafios)}")
            a = Autenticacion(usuario, clave)
            a.cargar(desafios)
            if a.disponible():
                estado, _, cuerpo = http_get(host, puerto_http, ruta, a.cabecera("GET", ruta))
    except (OSError, http.client.HTTPException):
        raise RuntimeError(f"no se pudo conectar a {host}:{puerto_http} (revisa la IP, la red y el puerto HTTP)")
    if estado == 200:
        return cuerpo
    if estado == 401:
        raise RuntimeError("usuario o contraseña incorrectos, o ESTE equipo está bloqueado por intentos "
                           "fallidos (el DVR bloquea por IP ~30 min)")
    if estado == 403:
        raise RuntimeError("el usuario no tiene permiso")
    if estado == 404:
        raise No404()
    if 300 <= estado < 400:
        raise RuntimeError(f"el DVR redirige la web (código {estado}), posiblemente a HTTPS")
    raise RuntimeError(f"el DVR respondió con error {estado}")


def parsear_canales(xml, etiqueta):
    canales = {}
    for m in re.finditer(rf"<{etiqueta}(?:\s[^>]*)?>(.*?)</{etiqueta}>", xml, re.S):
        cuerpo = m.group(1)
        i = re.search(r"<id>\s*(\d+)\s*</id>", cuerpo)
        n = re.search(r"<name>(.*?)</name>", cuerpo, re.S)
        if i:
            nombre = (n.group(1) if n else "").strip()
            nombre = nombre.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
            canales.setdefault(int(i.group(1)), nombre)
    return dict(sorted(canales.items()))


CONSULTAS = [
    ("/ISAPI/System/Video/inputs/channels", "VideoInputChannel", "ISAPI"),
    ("/ISAPI/ContentMgmt/InputProxy/channels", "InputProxyChannel", "ISAPI cámaras IP"),
    ("/PSIA/System/Video/inputs/channels", "VideoInputChannel", "PSIA (modelo antiguo)"),
]


def probar_web(host, puerto_http, usuario, clave):
    print(f"\n== 2. Acceso web (puerto {puerto_http}) y canales ==")
    alguna = False
    for i, (ruta, etiqueta, nombre) in enumerate(CONSULTAS):
        try:
            canales = parsear_canales(consultar(host, puerto_http, usuario, clave, ruta, i == 0), etiqueta)
        except No404:
            print(f"  {nombre}: no disponible (404)")
            continue
        except RuntimeError as e:
            print(f"  FALLA: {e}")
            return None
        alguna = True
        if canales:
            print(f"  OK vía {nombre}: usuario y contraseña correctos. {len(canales)} canales:")
            for c, n in canales.items():
                print(f"    {c}: {n or '(sin nombre)'}")
            return canales
    if alguna:
        print("  OK: usuario y contraseña correctos, pero el DVR no devolvió canales.")
        return {}
    print("  El DVR no permite consultar su lista de canales (modelo antiguo). En la app, "
          "escribe los números de canal a mano, por ejemplo \"1, 2, 3\".")
    return {}


# ------------------------------------------------------------------- RTSP

class Rtsp:
    def __init__(self, host, puerto):
        self.s = socket.create_connection((host, puerto), timeout=6)
        self.buf = b""
        self.cseq = 0

    def _mas(self, timeout=6):
        self.s.settimeout(timeout)
        d = self.s.recv(65536)
        if not d:
            raise ConnectionError("el DVR cerró la conexión")
        self.buf += d

    def pedir(self, metodo, uri, extra=None, auth=None):
        self.cseq += 1
        lineas = [f"{metodo} {uri} RTSP/1.0", f"CSeq: {self.cseq}", "User-Agent: probar_dvr"]
        if auth:
            lineas.append("Authorization: " + auth)
        for k, v in (extra or {}).items():
            lineas.append(f"{k}: {v}")
        self.s.sendall(("\r\n".join(lineas) + "\r\n\r\n").encode())
        return self._respuesta()

    def _saltar_interleaved(self):
        while self.buf[:1] == b"$":
            while len(self.buf) < 4:
                self._mas()
            n = int.from_bytes(self.buf[2:4], "big")
            while len(self.buf) < 4 + n:
                self._mas()
            self.buf = self.buf[4 + n:]

    def _respuesta(self):
        self._saltar_interleaved()
        while b"\r\n\r\n" not in self.buf:
            self._mas()
        cab, _, resto = self.buf.partition(b"\r\n\r\n")
        lineas = cab.decode("latin-1").split("\r\n")
        estado = lineas[0]
        headers = {}
        for l in lineas[1:]:
            if ":" in l:
                k, v = l.split(":", 1)
                headers.setdefault(k.strip().lower(), []).append(v.strip())
        largo = int((headers.get("content-length") or ["0"])[0])
        self.buf = resto
        while len(self.buf) < largo:
            self._mas()
        cuerpo, self.buf = self.buf[:largo], self.buf[largo:]
        return estado, headers, cuerpo.decode("latin-1")

    def medir_video(self, segundos=4.0):
        """Lee los paquetes intercalados (canal 0 = video RTP). Devuelve (bytes, t_primer_dato)."""
        inicio, total, primero = time.time(), 0, None
        limite = inicio + segundos
        while time.time() < limite:
            try:
                while len(self.buf) < 4:
                    self._mas(max(0.2, limite - time.time()))
                if self.buf[:1] != b"$":
                    self.buf = self.buf[1:]
                    continue
                n = int.from_bytes(self.buf[2:4], "big")
                while len(self.buf) < 4 + n:
                    self._mas(max(0.2, limite - time.time()))
                if self.buf[1] == 0:
                    total += n
                    if primero is None:
                        primero = time.time() - inicio
                self.buf = self.buf[4 + n:]
            except socket.timeout:
                break
        return total, primero

    def cerrar(self):
        try:
            self.s.close()
        except OSError:
            pass


def probar_rtsp(host, puerto, usuario, clave, canal, flujo):
    ruta = f"/Streaming/Channels/{canal * 100 + flujo}"
    uri = f"rtsp://{host}:{puerto}{ruta}"
    nombre_flujo = "principal" if flujo == 1 else "substream"
    print(f"\n== 3. Video RTSP, canal {canal} ({nombre_flujo}) ==")
    try:
        r = Rtsp(host, puerto)
    except OSError as e:
        print(f"  FALLA: no se pudo conectar a {host}:{puerto} ({e.__class__.__name__})")
        return
    try:
        auth = Autenticacion(usuario, clave)
        estado, h, cuerpo = r.pedir("DESCRIBE", uri, {"Accept": "application/sdp"})
        print(f"  DESCRIBE sin credenciales: {estado}")
        if " 401" in estado:
            auth.cargar(h.get("www-authenticate", []))
            print(f"  El DVR pide autenticación: {resumen_desafios(h.get('www-authenticate', []))}")
            estado, h, cuerpo = r.pedir("DESCRIBE", uri, {"Accept": "application/sdp"},
                                        auth.cabecera("DESCRIBE", uri))
            print(f"  DESCRIBE con usuario y contraseña: {estado}")
        if " 401" in estado:
            print("  RESULTADO: usuario o contraseña rechazados para RTSP. Si en la web sí entras, "
                  "ESTE equipo puede estar bloqueado por intentos fallidos (~30 min).")
            return
        if " 404" in estado:
            antigua = f"rtsp://{host}:{puerto}/h264/ch{canal}/{'main' if flujo == 1 else 'sub'}/av_stream"
            e2, _, _ = r.pedir("DESCRIBE", antigua, {"Accept": "application/sdp"},
                               auth.cabecera("DESCRIBE", antigua) if auth.disponible() else None)
            if " 200" in e2:
                print("  RESULTADO: este DVR usa el formato ANTIGUO de dirección de video "
                      f"(/h264/ch{canal}/...). La app aún no lo soporta: avísame.")
            else:
                print("  RESULTADO: la clave sirve pero ese canal no existe (revisa el número de canal).")
            return
        if " 200" not in estado:
            print("  RESULTADO: respuesta inesperada. Revisa el puerto RTSP.")
            return

        codec = re.search(r"a=rtpmap:\d+\s+([\w\-]+)/90000", cuerpo)
        print(f"  Códec de video: {codec.group(1) if codec else 'desconocido'}"
              "  (H264 = compatible casi siempre; H265 puede fallar en tablets/TV)")

        base = (h.get("content-base") or [uri])[0].rstrip("/")
        pista = re.search(r"m=video.*?a=control:(\S+)", cuerpo, re.S)
        control = pista.group(1) if pista else "trackID=1"
        url_pista = control if control.startswith("rtsp://") else f"{base}/{control}"

        estado, h2, _ = r.pedir("SETUP", url_pista,
                                {"Transport": "RTP/AVP/TCP;unicast;interleaved=0-1"},
                                auth.cabecera("SETUP", url_pista) if auth.disponible() else None)
        print(f"  SETUP (TCP): {estado}")
        if " 200" not in estado:
            print("  RESULTADO: el DVR no acepta video por TCP en este canal.")
            return
        sesion = (h2.get("session") or [""])[0].split(";")[0]
        estado, _, _ = r.pedir("PLAY", base, {"Session": sesion, "Range": "npt=0.000-"},
                               auth.cabecera("PLAY", base) if auth.disponible() else None)
        print(f"  PLAY: {estado}")
        if " 200" not in estado:
            print("  RESULTADO: el DVR no inició el video.")
            return
        total, primero = r.medir_video(4.0)
        if total > 0:
            print(f"  RESULTADO: OK. Llegaron {total // 1024} KB de video en 4 s "
                  f"(primer dato a los {primero:.1f} s).")
        else:
            print("  RESULTADO: el DVR aceptó todo pero NO envió video en 4 s "
                  "(revisa límite de conexiones simultáneas, códec o permisos de vista en vivo).")
    except socket.timeout:
        print(f"  RESULTADO: el puerto {puerto} no contestó a tiempo. No parece ser el puerto RTSP: "
              "prueba sin --rtsp para que el script lo busque, o revisa el puerto RTSP en iVMS-2000.")
    except (ConnectionError, OSError) as e:
        print(f"  FALLA durante la prueba: {e}")
    finally:
        r.cerrar()


# ------------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description="Diagnóstico rápido de un DVR Hikvision")
    ap.add_argument("host")
    ap.add_argument("-u", "--usuario")
    ap.add_argument("--canal", type=int, default=1)
    ap.add_argument("--rtsp", type=int, help="fuerza el puerto RTSP en vez de buscarlo")
    ap.add_argument("--http", type=int, default=80, help="puerto web del DVR (por defecto 80)")
    ap.add_argument("--puertos", help="puertos extra a probar, separados por coma")
    ap.add_argument("--escanear", action="store_true",
                    help="busca el puerto RTSP entre TODOS los puertos (1-65535)")
    ap.add_argument("--principal", action="store_true", help="prueba calidad principal en vez de substream")
    ap.add_argument("--vlc", action="store_true", help="abre VLC con el video (usa la contraseña ingresada)")
    a = ap.parse_args()

    try:
        if not ipaddress.ip_address(a.host).is_private:
            raise ValueError
    except ValueError:
        sys.exit("La IP debe ser de red local (10.x, 172.16-31.x, 192.168.x).")

    identificar(a.host, a.http)
    print()

    extra = [int(p) for p in a.puertos.split(",")] if a.puertos else []
    puertos = list(dict.fromkeys(([a.rtsp] if a.rtsp else []) + extra + PUERTOS_COMUNES))
    if a.rtsp:
        rtsp = a.rtsp
    elif a.escanear:
        rtsp = escanear(a.host)
    else:
        rtsp = buscar_puerto_rtsp(a.host, puertos)
    if a.rtsp:
        print(f"== 1. Puerto RTSP forzado: {a.rtsp} ==")
        opciones = f"OPTIONS rtsp://{a.host}:{a.rtsp}/ RTSP/1.0\r\nCSeq: 1\r\n\r\n"
        r = hablar(a.host, a.rtsp, opciones.encode())
        if r is None:
            print(f"  AVISO: el puerto {a.rtsp} está cerrado.")
        elif not r.startswith(b"RTSP/"):
            print(f"  AVISO: el puerto {a.rtsp} responde, pero NO habla RTSP. Prueba sin --rtsp para buscarlo.")
        else:
            print(f"  El puerto {a.rtsp} habla RTSP.")

    if rtsp is None and a.escanear:
        print("\nNingún puerto del equipo habla RTSP: este DVR no ofrece video por RTSP "
              "(solo por su puerto de servidor/SDK, el que usa iVMS).")
    elif rtsp is None:
        print("\nNingún puerto probado habló RTSP. Búscalo en todos los puertos con --escanear, "
              "o revísalo en iVMS: Configuración remota > Red > Puerto > 'Puerto RTSP'.")
    else:
        print(f"\n>> Usa \"puerto\": {rtsp} en la configuración de la app.")

    if not a.usuario:
        print(f"\nAgrega el usuario para probar la contraseña:  python tool/probar_dvr.py {a.host} -u <usuario>")
        return

    clave = getpass.getpass(f"\nContraseña de {a.usuario} (no se muestra): ")
    canales = probar_web(a.host, a.http, a.usuario, clave)
    if rtsp is not None:
        probar_rtsp(a.host, rtsp, a.usuario, clave, a.canal, 1 if a.principal else 2)

    if a.vlc and rtsp is not None:
        from urllib.parse import quote
        url = (f"rtsp://{quote(a.usuario, safe='')}:{quote(clave, safe='')}@{a.host}:{rtsp}"
               f"/Streaming/Channels/{a.canal * 100 + (1 if a.principal else 2)}")
        vlc = r"C:\Program Files\VideoLAN\VLC\vlc.exe"
        subprocess.Popen([vlc, "--rtsp-tcp", url])
        print("\nAbriendo VLC...")

    if rtsp is not None and canales is not None:
        print("\n== Configuración sugerida para la app (pon tu contraseña en la página web) ==")
        print(f'  "host": "{a.host}", "puerto": {rtsp}, "puertoHttp": {a.http}, '
              f'"usuario": "{a.usuario}", "canales": ""')


if __name__ == "__main__":
    main()
