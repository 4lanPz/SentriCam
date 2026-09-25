/// Página que se abre desde la computadora o el celular para configurar la TV.
/// Todo el texto que viene de la TV o de los DVR se inserta con textContent/value
/// (nunca innerHTML) para no ejecutar nada que venga en un nombre de cámara.
const paginaWeb = r'''<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SentriCam · Configuración</title>
<style>
:root{--fondo:#111;--tarjeta:#1a1a1a;--borde:#333;--texto:#eee;--suave:#9a9a9a;--acento:#e0a100;--ok:#5fd35f;--mal:#ff6b6b}
*{box-sizing:border-box}
body{font-family:system-ui,sans-serif;background:var(--fondo);color:var(--texto);max-width:1100px;margin:0 auto;padding:16px;line-height:1.4}
h1{margin:0;font-size:22px}h2{margin:0 0 6px;font-size:18px}
header{display:flex;align-items:baseline;gap:12px;margin-bottom:16px}header span{color:var(--suave)}
.tarjeta{background:var(--tarjeta);border:1px solid var(--borde);border-radius:10px;padding:16px;margin-bottom:16px}
.ayuda{color:var(--suave);font-size:14px;margin:0 0 12px}
input,select,button{font:inherit;color:var(--texto)}
input,select{background:#0d0d0d;border:1px solid #444;border-radius:6px;padding:7px 9px;width:100%}
input:focus,select:focus{outline:2px solid var(--acento);border-color:transparent}
input[type=checkbox]{width:auto;accent-color:var(--acento)}
button{background:#2b2b2b;border:1px solid #444;border-radius:6px;padding:7px 12px;cursor:pointer;white-space:nowrap}
button:hover{border-color:var(--acento)}button:disabled{opacity:.5;cursor:wait}
button.primario{background:var(--acento);border-color:var(--acento);color:#000;font-weight:600}
button.grande{padding:12px 20px;font-size:17px}
button.peligro:hover{border-color:var(--mal);color:var(--mal)}
.fila-acceso{display:flex;gap:10px;align-items:flex-end;flex-wrap:wrap}
.fila-acceso label{flex:0 0 14em}
label{display:block;font-size:14px;color:var(--suave)}
label>input,label>select{margin-top:4px;color:var(--texto)}
.check{display:flex;align-items:center;gap:8px;margin:10px 0;color:var(--texto)}
.check input[type=number]{width:6em}
.opciones{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:12px 20px}
.msg{margin-top:10px;white-space:pre-wrap}.msg.ok{color:var(--ok)}.msg.error{color:var(--mal)}
table{width:100%;border-collapse:collapse}
th{text-align:left;font-size:13px;color:var(--suave);font-weight:500;padding:4px 6px}
td{padding:6px;vertical-align:top}
tr.fila>td{border-top:1px solid var(--borde)}
td.acciones{display:flex;gap:6px;flex-wrap:wrap}
td.texto{padding-top:13px}
.estado{display:inline-block;font-size:12px;border-radius:10px;padding:1px 8px;margin-top:4px;border:1px solid var(--borde);color:var(--suave)}
.estado.ok{color:var(--ok);border-color:var(--ok)}.estado.mal{color:var(--mal);border-color:var(--mal)}
.detalle td{padding-top:0}
.pasos{background:#0d0d0d;border:1px solid var(--borde);border-radius:6px;padding:8px 10px;font-size:14px}
.pasos div{margin:2px 0}.pasos .ok{color:var(--ok)}.pasos .mal{color:var(--mal)}
.error-fila{color:var(--mal);font-size:14px}
.grupo{border:1px solid var(--borde);border-radius:8px;padding:12px;margin-bottom:12px}
.grupo-cabecera{display:flex;gap:10px;align-items:center;margin-bottom:8px;flex-wrap:wrap}
.grupo-cabecera input{flex:1 1 14em}.contador{color:var(--acento);font-size:14px;white-space:nowrap}
details{border-top:1px solid var(--borde);padding:6px 0}
summary{cursor:pointer;display:flex;gap:10px;align-items:center}
summary .nombre{flex:1}summary button{padding:2px 8px;font-size:13px}
.camaras{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:2px 12px;padding:6px 0 4px 18px}
.camaras label{display:flex;gap:6px;align-items:center;color:var(--texto);font-size:14px}
.vacio{color:var(--suave);font-size:14px;padding:6px 0 4px 18px}
@media (max-width:820px){
  table,thead,tbody,tr,td{display:block}thead{display:none}
  tr.fila{border:1px solid var(--borde);border-radius:8px;padding:6px;margin-top:10px}
  tr.fila>td{border-top:0;padding:4px 6px}
  td[data-l]::before{content:attr(data-l);display:block;font-size:12px;color:var(--suave)}
  td.texto{padding-top:4px}
}
</style></head>
<body>
<header><h1>SentriCam</h1><span>Configuración de la TV</span></header>

<section class="tarjeta">
  <div class="fila-acceso">
    <label>Código que aparece en la TV
      <input id="codigo" inputmode="numeric" maxlength="6" autocomplete="off" placeholder="6 dígitos">
    </label>
    <button id="conectar" class="primario">Conectar</button>
  </div>
  <div id="msgAcceso" class="msg"></div>
</section>

<main id="editor" hidden>
  <section class="tarjeta">
    <h2>DVRs</h2>
    <p class="ayuda">Llena los datos y pulsa <b>Probar</b> para comprobar la conexión; luego <b>Guardar</b> para dejarlo en la lista.
      Puerto: el de video RTSP (normalmente 554). Canales: vacío = todos, o por ejemplo <i>1-8, 12</i>.
      Los nombres de las cámaras se toman del DVR.</p>
    <table>
      <thead><tr><th>Nombre</th><th>IP</th><th>Puerto</th><th>Usuario</th><th>Contraseña</th><th>Canales</th><th></th></tr></thead>
      <tbody id="dvrs"></tbody>
    </table>
    <p><button id="anadirDvr">+ Añadir DVR</button></p>
  </section>

  <section class="tarjeta">
    <h2>Grupos</h2>
    <p class="ayuda">Un grupo junta cámaras de uno o varios DVR, por ejemplo las de una planta.
      En la TV se elige con el botón de cuadrícula (arriba a la derecha). Para ver las cámaras de un DVR nuevo, pruébalo primero.</p>
    <div id="grupos"></div>
    <button id="anadirGrupo">+ Añadir grupo</button>
  </section>

  <section class="tarjeta">
    <h2>Pantalla</h2>
    <div class="opciones">
      <label>Cámaras por página
        <select id="porPagina"><option>1</option><option>4</option><option>6</option><option>9</option><option>16</option></select>
      </label>
      <label>PIN para abrir la app y la configuración (opcional, 4 a 6 dígitos)
        <input id="pin" type="password" inputmode="numeric" maxlength="6" autocomplete="new-password">
      </label>
    </div>
    <label class="check"><input type="checkbox" id="rotar"> Cambiar de página automáticamente cada
      <input type="number" id="segundos" min="10" step="5" value="30"> segundos</label>
    <label class="check"><input type="checkbox" id="substream"> Calidad liviana en la cuadrícula (recomendado; la pantalla completa usa calidad alta)</label>
  </section>

  <section class="tarjeta">
    <button id="guardarTodo" class="primario grande">Guardar configuración en la TV</button>
    <div id="msgGuardar" class="msg"></div>
  </section>
</main>

<script>
"use strict";
const $ = id => document.getElementById(id);
let sigId = 1;
let dvrs = [];
let grupos = [];
let sinGuardar = false;

function el(tag, props, ...hijos) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(props || {})) {
    if (k === "clase") e.className = v;
    else if (k === "texto") e.textContent = v;
    else if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
    else if (k in e) e[k] = v;
    else e.setAttribute(k, v);
  }
  for (const h of hijos) if (h != null && h !== false) e.append(h);
  return e;
}

function aviso(id, texto, ok) {
  const m = $(id);
  m.textContent = texto;
  m.className = "msg " + (ok ? "ok" : "error");
}

async function api(ruta, cuerpo) {
  let r;
  try {
    r = await fetch(ruta, {method: "POST", headers: {"Content-Type": "application/json"},
      body: JSON.stringify(Object.assign({codigo: $("codigo").value.trim()}, cuerpo))});
  } catch (e) {
    throw new Error("No se pudo conectar con la TV. ¿Sigue abierta su pantalla de configuración?");
  }
  const d = await r.json().catch(() => ({error: "Respuesta inválida de la TV"}));
  if (!r.ok) throw new Error(d.error || "Error");
  return d;
}

// ---------- canales: mismo formato que la app ("1, 3:Patio, 8-12")
function parsearCanales(txt) {
  const res = [], vistos = new Set();
  for (const item of txt.split(",")) {
    const t = item.trim();
    if (!t) continue;
    const r = /^(\d+)\s*-\s*(\d+)$/.exec(t);
    if (r) {
      const a = +r[1], b = +r[2];
      if (a < 1 || b > 64 || a > b) throw new Error(`rango de canales inválido "${t}"`);
      for (let n = a; n <= b; n++) if (!vistos.has(n)) { vistos.add(n); res.push({canal: n, nombre: ""}); }
      continue;
    }
    const i = t.indexOf(":");
    const num = (i === -1 ? t : t.slice(0, i)).trim();
    if (!/^\d+$/.test(num) || +num < 1 || +num > 64) throw new Error(`canal inválido "${t}"`);
    if (!vistos.has(+num)) { vistos.add(+num); res.push({canal: +num, nombre: i === -1 ? "" : t.slice(i + 1).trim()}); }
  }
  return res;
}

function compactar(nums) {
  const partes = [];
  for (let i = 0; i < nums.length;) {
    let j = i;
    while (j + 1 < nums.length && nums[j + 1] === nums[j] + 1) j++;
    partes.push(j - i >= 2 ? `${nums[i]}-${nums[j]}` : nums.slice(i, j + 1).join(", "));
    i = j + 1;
  }
  return partes.join(", ");
}

function ipPrivada(ip) {
  const p = ip.trim().split(".");
  if (p.length !== 4 || p.some(x => !/^\d{1,3}$/.test(x) || +x > 255)) return false;
  const a = +p[0], b = +p[1];
  return a === 10 || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168);
}

// Cámaras que puede mostrar un DVR: las elegidas en "Canales" o, si está vacío,
// todas las que informó el DVR al probarlo (o las que ya tenía guardadas la TV).
function camarasDe(d) {
  let lista;
  try { lista = d.canales.trim() ? parsearCanales(d.canales).map(c => c.canal) : null; }
  catch (e) { return []; }
  if (lista === null) lista = [...d.conocidos.keys()].sort((a, b) => a - b);
  return lista.map(n => ({canal: n, nombre: d.conocidos.get(n) || `Canal ${n}`}));
}

// ---------- carga
function cargar(c) {
  dvrs = (c.dvrs || []).map(d => {
    let lista = [];
    try { lista = parsearCanales(d.canales || ""); } catch (e) {}
    return {id: sigId++, nombre: d.nombre, host: d.host, puerto: d.puerto || 554, puertoHttp: d.puertoHttp || 80,
      usuario: d.usuario, clave: "", canales: compactar(lista.map(x => x.canal)),
      conocidos: new Map(lista.map(x => [x.canal, x.nombre])),
      claveGuardada: true, hostOriginal: d.host, usuarioOriginal: d.usuario,
      editando: false, prueba: null, error: ""};
  });
  const idDe = nombre => (dvrs.find(d => d.nombre === nombre) || {}).id;
  grupos = (c.grupos || []).map(g => ({id: sigId++, nombre: g.nombre,
    sel: new Set((g.camaras || []).filter(r => idDe(r.dvr)).map(r => `${idDe(r.dvr)}#${r.canal}`))}));
  $("porPagina").value = String(c.camarasPorPagina || 9);
  $("substream").checked = c.substream !== false;
  $("rotar").checked = (c.rotacionSegundos || 0) > 0;
  $("segundos").value = (c.rotacionSegundos || 0) > 0 ? c.rotacionSegundos : 30;
  $("pin").value = c.pin || "";
  if (dvrs.length === 0) nuevoDvr();
  pintarDvrs();
  pintarGrupos();
  sinGuardar = false;
}

async function conectar() {
  const b = $("conectar");
  b.disabled = true;
  try {
    const d = await api("/actual", {});
    cargar(d.config);
    $("editor").hidden = false;
    aviso("msgAcceso", "Conectado. Los cambios se aplican en la TV al pulsar \"Guardar configuración en la TV\".", true);
  } catch (e) {
    aviso("msgAcceso", e.message, false);
  } finally {
    b.disabled = false;
  }
}

// ---------- DVRs
function nuevoDvr() {
  dvrs.push({id: sigId++, nombre: "", host: "", puerto: 554, puertoHttp: 80, usuario: "admin", clave: "", canales: "",
    conocidos: new Map(), claveGuardada: false, hostOriginal: "", usuarioOriginal: "",
    editando: true, prueba: null, error: ""});
}

function validarDvr(d) {
  const nombre = d.nombre.trim();
  if (!nombre) return "Escribe un nombre para el DVR.";
  if (dvrs.some(o => o !== d && o.nombre.trim().toLowerCase() === nombre.toLowerCase())) return `Ya hay un DVR llamado "${nombre}".`;
  if (!ipPrivada(d.host)) return "La IP debe ser de red local (10.x, 172.16-31.x o 192.168.x).";
  const p = Number(d.puerto);
  if (!Number.isInteger(p) || p < 1 || p > 65535) return "Puerto inválido.";
  if (!d.usuario.trim()) return "Escribe el usuario.";
  if (!d.clave) {
    const mismaCuenta = d.claveGuardada && d.host.trim() === d.hostOriginal && d.usuario.trim() === d.usuarioOriginal;
    if (!mismaCuenta) return d.claveGuardada ? "Cambiaste la IP o el usuario: escribe la contraseña de nuevo." : "Escribe la contraseña.";
  }
  try { parsearCanales(d.canales); } catch (e) { return "Canales: " + e.message; }
  return "";
}

function datosDvr(d) {
  return {nombre: d.nombre.trim(), host: d.host.trim(), puerto: Number(d.puerto), puertoHttp: d.puertoHttp,
    usuario: d.usuario.trim(), clave: d.clave, canales: d.canales.trim()};
}

async function probarDvr(d) {
  d.error = validarDvr(d);
  if (d.error) { pintarDvrs(); return; }
  d.prueba = {cargando: true};
  pintarDvrs();
  try {
    const r = await api("/probar", {dvr: datosDvr(d)});
    d.prueba = {pasos: r.pasos};
    for (const c of r.canales || []) d.conocidos.set(c.canal, c.nombre || `Cámara ${c.canal}`);
  } catch (e) {
    d.prueba = {pasos: [{ok: false, texto: e.message}]};
  }
  pintarDvrs();
  pintarGrupos();
}

function guardarDvr(d) {
  d.error = validarDvr(d);
  if (!d.error) { d.editando = false; d.respaldo = null; }
  pintarDvrs();
  pintarGrupos();
}

function editarDvr(d) {
  d.respaldo = {nombre: d.nombre, host: d.host, puerto: d.puerto, usuario: d.usuario, clave: d.clave, canales: d.canales};
  d.editando = true;
  pintarDvrs();
}

function cancelarDvr(d) {
  Object.assign(d, d.respaldo);
  d.respaldo = null;
  d.editando = false;
  d.error = "";
  pintarDvrs();
}

function eliminarDvr(d) {
  if ((d.nombre || d.host) && !confirm(`¿Eliminar el DVR "${d.nombre || d.host}"? Sus cámaras también salen de los grupos.`)) return;
  dvrs = dvrs.filter(o => o !== d);
  for (const g of grupos) for (const k of [...g.sel]) if (k.startsWith(d.id + "#")) g.sel.delete(k);
  sinGuardar = true;
  pintarDvrs();
  pintarGrupos();
}

function estadoPrueba(d) {
  if (!d.prueba) return el("span", {clase: "estado", texto: "sin probar"});
  if (d.prueba.cargando) return el("span", {clase: "estado", texto: "probando…"});
  const ok = d.prueba.pasos.every(p => p.ok);
  return el("span", {clase: "estado " + (ok ? "ok" : "mal"), texto: ok ? "✓ funciona" : "✗ revisar"});
}

function campo(d, clave, etiqueta, extra) {
  return el("td", {"data-l": etiqueta}, el("input", Object.assign({
    value: d[clave], "aria-label": etiqueta,
    oninput: e => { d[clave] = e.target.value; sinGuardar = true; },
  }, extra || {})));
}

function pintarDvrs() {
  // Un aviso de error de "Guardar configuración" queda viejo al cambiar la tabla.
  if ($("msgGuardar").classList.contains("error")) $("msgGuardar").textContent = "";
  const tb = $("dvrs");
  tb.replaceChildren();
  for (const d of dvrs) {
    const ocupado = !!(d.prueba && d.prueba.cargando);
    const probar = el("button", {texto: ocupado ? "Probando…" : "Probar", disabled: ocupado, onclick: () => probarDvr(d)});
    let fila;
    if (d.editando) {
      fila = el("tr", {clase: "fila"},
        el("td", {"data-l": "Nombre"},
          el("input", {value: d.nombre, "aria-label": "Nombre", placeholder: "Ej.: Planta 1",
            oninput: e => { d.nombre = e.target.value; sinGuardar = true; }}), estadoPrueba(d)),
        campo(d, "host", "IP", {placeholder: "192.168.1.64", inputMode: "decimal"}),
        campo(d, "puerto", "Puerto", {inputMode: "numeric", size: 5}),
        campo(d, "usuario", "Usuario", {autocomplete: "off"}),
        campo(d, "clave", "Contraseña", {type: "password", autocomplete: "new-password",
          placeholder: d.claveGuardada ? "(sin cambios)" : ""}),
        campo(d, "canales", "Canales", {placeholder: "todos"}),
        el("td", {clase: "acciones"}, probar,
          el("button", {clase: "primario", texto: "Guardar", onclick: () => guardarDvr(d)}),
          d.respaldo
            ? el("button", {texto: "Cancelar", onclick: () => cancelarDvr(d)})
            : el("button", {clase: "peligro", texto: "Eliminar", onclick: () => eliminarDvr(d)})));
    } else {
      fila = el("tr", {clase: "fila"},
        el("td", {clase: "texto", "data-l": "Nombre"}, el("b", {texto: d.nombre}), el("br"), estadoPrueba(d)),
        el("td", {clase: "texto", "data-l": "IP", texto: d.host}),
        el("td", {clase: "texto", "data-l": "Puerto", texto: d.puerto}),
        el("td", {clase: "texto", "data-l": "Usuario", texto: d.usuario}),
        el("td", {clase: "texto", "data-l": "Contraseña", texto: d.clave || d.claveGuardada ? "••••••" : "—"}),
        el("td", {clase: "texto", "data-l": "Canales", texto: d.canales || "todos"}),
        el("td", {clase: "acciones"}, probar,
          el("button", {texto: "Editar", onclick: () => editarDvr(d)}),
          el("button", {clase: "peligro", texto: "Eliminar", onclick: () => eliminarDvr(d)})));
    }
    tb.append(fila);
    const extra = [];
    if (d.error) extra.push(el("div", {clase: "error-fila", texto: d.error}));
    if (d.prueba && d.prueba.pasos) {
      extra.push(el("div", {clase: "pasos"}, ...d.prueba.pasos.map(p =>
        el("div", {clase: p.ok ? "ok" : "mal", texto: (p.ok ? "✓ " : "✗ ") + p.texto}))));
    }
    if (extra.length) tb.append(el("tr", {clase: "detalle"}, el("td", {colSpan: 7}, ...extra)));
  }
}

// ---------- grupos
function nuevoGrupo() {
  grupos.push({id: sigId++, nombre: "", sel: new Set()});
  sinGuardar = true;
  pintarGrupos();
  const inputs = $("grupos").querySelectorAll(".grupo-cabecera input");
  if (inputs.length) inputs[inputs.length - 1].focus();
}

function pintarGrupos() {
  const cont = $("grupos");
  const abiertos = new Set([...cont.querySelectorAll("details[open]")].map(x => x.dataset.clave));
  cont.replaceChildren();
  for (const g of grupos) {
    const contador = el("span", {clase: "contador"});
    const actualizar = () => { contador.textContent = `${g.sel.size} cámaras`; };
    actualizar();
    const caja = el("div", {clase: "grupo"},
      el("div", {clase: "grupo-cabecera"},
        el("input", {value: g.nombre, placeholder: "Nombre del grupo (ej.: Planta baja)", "aria-label": "Nombre del grupo",
          oninput: e => { g.nombre = e.target.value; sinGuardar = true; }}),
        contador,
        el("button", {clase: "peligro", texto: "Eliminar grupo", onclick: () => {
          if (g.sel.size && !confirm(`¿Eliminar el grupo "${g.nombre}"?`)) return;
          grupos = grupos.filter(o => o !== g); sinGuardar = true; pintarGrupos();
        }})));
    for (const d of dvrs) {
      if (!d.nombre.trim()) continue;
      const camaras = camarasDe(d);
      const clave = `${g.id}-${d.id}`;
      const marcas = [];
      const resumen = el("span", {clase: "contador"});
      const contar = () => { resumen.textContent = `${camaras.filter(c => g.sel.has(`${d.id}#${c.canal}`)).length} de ${camaras.length}`; };
      const todas = (valor) => (e) => {
        e.preventDefault();
        for (const c of camaras) { const k = `${d.id}#${c.canal}`; if (valor) g.sel.add(k); else g.sel.delete(k); }
        for (const m of marcas) m.checked = valor;
        sinGuardar = true; contar(); actualizar();
      };
      const detalles = el("details", {open: abiertos.has(clave)},
        el("summary", {}, el("span", {clase: "nombre", texto: d.nombre}), resumen,
          camaras.length ? el("button", {texto: "Todas", onclick: todas(true)}) : null,
          camaras.length ? el("button", {texto: "Ninguna", onclick: todas(false)}) : null));
      detalles.dataset.clave = clave;
      if (!camaras.length) {
        detalles.append(el("div", {clase: "vacio", texto: "Pulsa \"Probar\" en este DVR para ver sus cámaras."}));
      } else {
        const lista = el("div", {clase: "camaras"});
        for (const c of camaras) {
          const k = `${d.id}#${c.canal}`;
          const m = el("input", {type: "checkbox", checked: g.sel.has(k), onchange: e => {
            if (e.target.checked) g.sel.add(k); else g.sel.delete(k);
            sinGuardar = true; contar(); actualizar();
          }});
          marcas.push(m);
          lista.append(el("label", {}, m, `${c.canal}. ${c.nombre}`));
        }
        detalles.append(lista);
      }
      contar();
      caja.append(detalles);
    }
    cont.append(caja);
  }
}

// ---------- guardar todo
function armarConfig() {
  const enEdicion = dvrs.find(d => d.editando);
  if (enEdicion) throw new Error(`Primero pulsa "Guardar" (o elimina) el DVR "${enEdicion.nombre || "nuevo"}" que está en edición.`);
  if (!dvrs.length) throw new Error("Agrega al menos un DVR.");
  const nombres = new Set();
  const salida = [];
  for (const g of grupos) {
    const nombre = g.nombre.trim();
    if (!nombre) throw new Error("Hay un grupo sin nombre.");
    if (nombres.has(nombre.toLowerCase())) throw new Error(`Hay dos grupos llamados "${nombre}".`);
    nombres.add(nombre.toLowerCase());
    const camaras = [];
    for (const d of dvrs) for (const c of camarasDe(d)) {
      if (g.sel.has(`${d.id}#${c.canal}`)) camaras.push({dvr: d.nombre.trim(), canal: c.canal});
    }
    if (!camaras.length) throw new Error(`El grupo "${nombre}" no tiene cámaras marcadas.`);
    salida.push({nombre, camaras});
  }
  const pin = $("pin").value.trim();
  if (pin && !/^\d{4,6}$/.test(pin)) throw new Error("El PIN debe tener de 4 a 6 dígitos (o dejarse vacío).");
  let rotacion = 0;
  if ($("rotar").checked) {
    rotacion = Number($("segundos").value);
    if (!Number.isInteger(rotacion) || rotacion < 10) throw new Error("El cambio automático de página debe ser de al menos 10 segundos.");
  }
  return {camarasPorPagina: Number($("porPagina").value), substream: $("substream").checked,
    rotacionSegundos: rotacion, pin, dvrs: dvrs.map(datosDvr), grupos: salida};
}

async function guardarTodo() {
  let config;
  try { config = armarConfig(); } catch (e) { aviso("msgGuardar", e.message, false); return; }
  const b = $("guardarTodo");
  b.disabled = true;
  aviso("msgGuardar", "Guardando… la TV está consultando cada DVR, puede tardar unos segundos.", true);
  try {
    await api("/guardar", {config});
    sinGuardar = false;
    for (const d of dvrs) d.clave = "";
    $("editor").hidden = true;
    aviso("msgAcceso", "Guardado. La TV ya está mostrando las cámaras. Para cambiar algo más, abre la configuración en la TV y usa el nuevo código.", true);
    window.scrollTo(0, 0);
  } catch (e) {
    aviso("msgGuardar", e.message, false);
  } finally {
    b.disabled = false;
  }
}

$("conectar").addEventListener("click", conectar);
$("codigo").addEventListener("keydown", e => { if (e.key === "Enter") conectar(); });
$("anadirDvr").addEventListener("click", () => { nuevoDvr(); sinGuardar = true; pintarDvrs(); });
$("anadirGrupo").addEventListener("click", nuevoGrupo);
$("guardarTodo").addEventListener("click", guardarTodo);
for (const id of ["porPagina", "rotar", "segundos", "substream", "pin"]) $(id).addEventListener("change", () => { sinGuardar = true; });
window.addEventListener("beforeunload", e => { if (sinGuardar) { e.preventDefault(); e.returnValue = ""; } });
</script>
</body></html>''';
