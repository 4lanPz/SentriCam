"""Genera los iconos de Android a partir de assets/icono/SentriCam.png.

Uso (desde la raíz del proyecto, requiere Pillow: pip install pillow):
  python tool/generar_iconos.py

Crea el icono clásico, el icono adaptable (Android 8+), el banner de Android TV
y el logo de la pantalla de arranque. Los recortes están ajustados a
SentriCam.png; si cambias el icono, revísalos.
"""
import pathlib
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = pathlib.Path(__file__).resolve().parent.parent
RES = RAIZ / "android/app/src/main/res"
FONDO = (11, 16, 26)
FONDO_HEX = "#0B101A"

orig = Image.open(RAIZ / "assets/icono/SentriCam.png").convert("RGB")
baldosa = orig.crop((101, 89, 1151, 1139))            # la baldosa redondeada
contenido = orig.crop((146, 110, 1106, 1070))         # mira + cámara, sin la baldosa


def redondeada(img, radio_rel=0.19):
    n = img.size[0]
    mascara = Image.new("L", (n * 4, n * 4), 0)
    ImageDraw.Draw(mascara).rounded_rectangle((0, 0, n * 4 - 1, n * 4 - 1), radius=int(n * 4 * radio_rel), fill=255)
    out = img.convert("RGBA")
    out.putalpha(mascara.resize((n, n), Image.LANCZOS))
    return out


def cargar_fuente(tam):
    """Primera fuente en negrita disponible (Windows, Linux o macOS)."""
    for ruta in (r"C:\Windows\Fonts\segoeuib.ttf",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                 "/System/Library/Fonts/Supplemental/Arial Bold.ttf"):
        if pathlib.Path(ruta).exists():
            return ImageFont.truetype(ruta, tam)
    raise SystemExit("No se encontró una fuente en negrita; edita cargar_fuente().")


# 1) Iconos clásicos (lanzadores que no usan el icono adaptable).
legado = redondeada(baldosa)
tamanos = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
for dens, px in tamanos.items():
    legado.resize((px, px), Image.LANCZOS).save(RES / f"mipmap-{dens}/ic_launcher.png", optimize=True)
# Logo de la pantalla de arranque (launch_background.xml).
legado.resize((144, 144), Image.LANCZOS).save(RES / "drawable-xxhdpi/logo_arranque.png", optimize=True)

# 2) Icono adaptable (Android 8+): fondo liso + primer plano con el contenido en la zona segura.
for dens, px in tamanos.items():
    lado = px * 108 // 48
    frente = Image.new("RGBA", (lado, lado), FONDO + (255,))
    tam = int(lado * 70 / 108)
    pieza = contenido.resize((tam, tam), Image.LANCZOS).convert("RGBA")
    # Bordes difuminados para que no se note el corte sobre el fondo.
    borde = Image.new("L", (tam, tam), 0)
    m = max(2, tam // 14)
    ImageDraw.Draw(borde).rectangle((m, m, tam - m - 1, tam - m - 1), fill=255)
    pieza.putalpha(borde.filter(ImageFilter.GaussianBlur(m / 2)))
    frente.alpha_composite(pieza, ((lado - tam) // 2, (lado - tam) // 2))
    frente.save(RES / f"mipmap-{dens}/ic_launcher_foreground.png", optimize=True)

anydpi = RES / "mipmap-anydpi-v26"
anydpi.mkdir(exist_ok=True)
(anydpi / "ic_launcher.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@color/icono_fondo"/>\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
    '</adaptive-icon>\n', encoding="utf-8")
(RES / "values/colors.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
    f'    <color name="icono_fondo">{FONDO_HEX}</color>\n</resources>\n', encoding="utf-8")


# 3) Banner de Android TV (320x180 en xhdpi, 160x90 en mdpi).
def banner(ancho, alto):
    esc = 4
    W, H = ancho * esc, alto * esc
    img = Image.new("RGBA", (W, H), FONDO + (255,))
    # degradado suave de arriba hacia abajo
    capa = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(capa)
    for y in range(H):
        t = y / H
        d.line((0, y, W, y), fill=(int(22 - 10 * t), int(30 - 12 * t), int(46 - 18 * t), 255))
    img.alpha_composite(capa)
    lado = int(H * 0.66)
    margen = int(H * 0.12)
    img.alpha_composite(legado.resize((lado, lado), Image.LANCZOS), (margen, (H - lado) // 2))
    texto = "SentriCam"
    x = margen + lado + int(H * 0.08)
    disponible = W - x - margen
    tam = int(H * 0.28)
    while True:
        fuente = cargar_fuente(tam)
        c = ImageDraw.Draw(img).textbbox((0, 0), texto, font=fuente)
        if c[2] - c[0] <= disponible:
            break
        tam -= 2
    caja = ImageDraw.Draw(img).textbbox((0, 0), texto, font=fuente)
    alto_txt = caja[3] - caja[1]
    ImageDraw.Draw(img).text((x, (H - alto_txt) // 2 - caja[1]), texto, font=fuente, fill=(235, 242, 255, 255))
    return img.resize((ancho, alto), Image.LANCZOS).convert("RGB")


for carpeta, (a, b) in {"drawable-mdpi": (160, 90), "drawable-xhdpi": (320, 180), "drawable-xxhdpi": (480, 270)}.items():
    (RES / carpeta).mkdir(exist_ok=True)
    banner(a, b).save(RES / carpeta / "banner.png", optimize=True)

print("Iconos generados en", RES)
