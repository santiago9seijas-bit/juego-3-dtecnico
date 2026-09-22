# Changelog — Juego 3D Técnico (Simulador de Servicio Técnico Informático)

Historial de versiones publicadas en [versions/](./).

| Versión | Fecha       | Linux                         | Windows                         |
| ------- | ----------- | ----------------------------- | ------------------------------- |
| **0.2** | 2026-09-22  | [linux-version/0.2.zip](./linux-version/0.2.zip) | [windows-version/0.2.zip](./windows-version/0.2.zip) |
| 0.1     | 2026-08-06  | [linux-version/0.1.zip](./linux-version/0.1.zip) | [windows-version/0.1.zip](./windows-version/0.1.zip) |

---

## 0.2 — 2026-09-22

Primer gran pulido de interfaz, mecánicas de reparación y contenido.

### 🎨 Interfaz y arte (nuevo look ciberpunk)

- Nuevo estilo global de UI con neón: `UiStyle` (paleta cian/magenta, paneles oscuros, botones animados).
- Título holográfico animado: aberración cromática, parpadeo por letra y saltos de glitch (`HoloTitle`).
- Tarjetas holográficas con luz recorriendo el borde, scanlines y esquinas con pulso (`HoloCard`).
- Menú principal rediseñado: botones que se curvan en un arco alrededor de una esfera tipo agujero negro (`OrbitMenu`).
- Fondo con retícula técnica mediante shader (`shaders/menu_grid.gdshader`).
- Menús de selección a dos columnas: botones a la izquierda y ficha informativa a la derecha.
- HUD renovado: cronómetro con urgencia (borde rojo latiente), puntaje con destello verde/rojo, mochila con aviso de pieza dañada (⚠) y mira central.

### 🔧 Mecánicas de reparación

- Tres tipos de falla por pieza: **sobretensión** (halo morado que respira), **quemada** (ceniza) y **daño normal** (rojo neón).
- Dos vías de reparación: **cambiar la pieza** o **soldar con cautín**.
- Minijuego de cautín: arrastrar el estaño por la pista sin salirse; 3 salidas = soldadura fallida y la pieza queda insalvable.
- **Medir antes de soldar** con el voltímetro: si se mide primero, un fallo al soldar ya no destruye la pieza.
- **Papelera** (`TrashBin`): hay que botar las piezas dañadas que salen de las computadoras; la mochila avisa cuándo llevas una.
- Botón de ayuda con bolita "?" de halo neón pulsante.

### 🗺️ Contenido y niveles

- **6 niveles** en salas cerradas: niveles 1–4 en sala pequeña (PCs en fila) y 5–6 en sala mediana (5 PCs).
- Sala de **tutorial** propia: habitación pequeña con una sola PC y una sola estación de repuestos.
- Menú con las secciones del taller: mecánicas (voltímetro, cautín, papelera) y los 6 niveles.
- La cámara queda **bloqueada** mientras hay un menú abierto (PC, estantería, pausa o tutorial).

### ✅ Calidad

- Suite de tests ampliada: mecánicas, niveles, partida (timer/puntaje/fin), input y física.
- `config/version="0.2"` agregado a `project.godot`.
- Builds **Linux x86_64** y **Windows x86_64** con el `.pck` embebido (ejecutables autónomos).

---

## 0.1 — 2026-08-06

- Proyecto inicial: simulador de servicio técnico en primera persona.
- Movimiento WASD + ratón, interacción con `E`, estanterías de repuestos y diagnóstico por examinación.
- Minijuego de deslizar piezas y desatornillado (llana `1`, cruz `2`).
- 3 niveles de dificultad, puntuación con estrellas, tutorial e inventario de 3 repuestos.
- Presets de exportación para Windows y Linux con `.pck` embebido.
- Los ejecutables de esta versión vivían en la raíz (`versions/linux-version.zip` y `versions/windows-version.zip`); en 0.2 se reorganizaron por plataforma y ahora están en `versions/linux-version/0.1.zip` y `versions/windows-version/0.1.zip`.
