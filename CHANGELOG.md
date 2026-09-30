# Cambios

Todas las versiones de SentriCam. Los APK de cada versión están en [Releases](https://github.com/4lanPz/SentriCam/releases).

[English below](#changelog-english)

## [1.0.1] - 2026-09-30

Versión de correcciones. Se instala encima de la 1.0.0 sin perder la configuración.

### Estabilidad
- Las cámaras de una página ya no se abren todas a la vez: se abren de una en una, repartidas en unos 3 segundos. Evita que algunas TV se cuelguen o se reinicien al cambiar de página o al ampliar una cámara.
- Al ampliar una cámara (y al volver a la cuadrícula) la app espera a que los videos anteriores se cierren antes de abrir el siguiente.
- Nuevas opciones en **Pantalla**:
  - **Pantalla completa en calidad alta**: si se desactiva, la pantalla completa usa la calidad liviana.
  - **Decodificación por hardware**: si se desactiva, el video se decodifica por software. Para TV que se cuelgan o se reinician.

### Control remoto
- Al cambiar de página con las flechas de la barra superior, el cursor se queda en la flecha para seguir cambiando (antes saltaba a la primera cámara). El cambio automático de página tampoco mueve el cursor de la barra.
- Lo que está seleccionado se resalta en ámbar (botones con fondo ámbar), para verlo de lejos.

### Configuración desde el navegador
- Formulario de DVR más compacto: cada campo ocupa el ancho que necesita (IP, puerto, usuario, contraseña) y en el celular ocupa menos filas.
- Resultado de **Probar** más claro: si todo está bien solo se muestra "✓ funciona · N cámaras"; si algo falla se muestran solo los errores. Los mensajes se borran al editar el DVR, al guardarlo o con la ✕.
- Mensajes de la prueba de conexión más cortos (también en "Administrar DVRs" de la TV).

## [1.0.0] - 2026-09-25

Primera versión pública.

- Cuadrícula de cámaras por páginas (1, 4, 6, 9 o 16), con cambio automático de página opcional.
- Varios DVR a la vez, con los nombres de las cámaras tomados del propio DVR.
- Grupos de cámaras de distintos DVR y selector de qué ver: todo, un grupo o un DVR.
- Pantalla completa en calidad principal.
- Configuración desde el navegador de otro equipo en la misma red, con prueba de conexión por DVR.
- PIN opcional.

---

## Changelog (English)

## [1.0.1] - 2026-09-30

Bug-fix release. Installs over 1.0.0 keeping your settings.

### Stability
- Cameras on a page are no longer opened all at once: they open one by one over about 3 seconds. This prevents some TVs from freezing or rebooting when changing page or opening a camera full screen.
- When opening a camera full screen (and when going back to the grid), the app waits for the previous videos to close before opening the next one.
- New options under **Pantalla** (Display):
  - **High quality in full screen**: when turned off, full screen uses the light-quality stream.
  - **Hardware decoding**: when turned off, video is decoded in software. For TVs that freeze or reboot.

### Remote control
- When changing page with the arrows in the top bar, the cursor stays on the arrow so you can keep going (it used to jump to the first camera). Automatic page switching doesn't move the cursor out of the bar either.
- The selected item is highlighted in amber (buttons get an amber background), so it's visible from a distance.

### Browser setup
- More compact DVR form: each field is only as wide as it needs to be (IP, port, username, password), and it takes fewer rows on phones.
- Clearer **Probar** (Test) result: if everything works only "✓ funciona · N cámaras" is shown; if something fails only the errors are shown. Messages are cleared when you edit the DVR, save it, or press ✕.
- Shorter connection-test messages (also in "Administrar DVRs" on the TV).

## [1.0.0] - 2026-09-25

First public release.

- Paged camera grid (1, 4, 6, 9 or 16 per page), with optional automatic page switching.
- Several DVRs at once, with camera names taken from the DVR itself.
- Camera groups across different DVRs, and a picker for what to watch: everything, a group or a single DVR.
- Full screen in main-stream quality.
- Setup from a browser on another device on the same network, with a connection test per DVR.
- Optional PIN.
