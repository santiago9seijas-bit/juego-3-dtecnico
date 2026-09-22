# Juego 3D Técnico — Simulador de Servicio Técnico Informático

Videojuego 3D interactivo de primera persona para practicar el diagnóstico y la reparación de computadoras. El jugador debe examinar equipos con fallas, buscar los repuestos correctos en las estanterías y completar minijuegos de desarme e instalación bajo un límite de tiempo.

Desarrollado en **Godot Engine 4** con **GDScript**, y modelos/escenarios realizados en **Blender**.

---

## Características

- **Primera persona**: movimiento con `WASD` y cámara con el ratón.
- **Interacción**: tecla `E` para examinar computadoras y estaciones de repuestos.
- **Estanterías de repuestos**: RAM, Disco Duro, Fuente, Tarjeta Gráfica, Placa Madre, Procesador y Fancooler.
- **Diagnóstico**: examina los slots para descubrir qué pieza está dañada (las examinaciones son limitadas).
- **Inventario / mochila**: capacidad máxima de 3 repuestos.
- **Minijuegos**:
  - Deslizar piezas para instalar o extraer.
  - Desatornillado con destornillador llana (tecla `1`) y cruz (tecla `2`).
  - Multiplicador de puntos por rachas perfectas.
- **Sistema de progresión**: 3 niveles de dificultad, con más secretos, más tornillos y menos tiempo.
- **Puntuación**: puntos por reparación, bono de tiempo, penalización por errores y estrellas al final (1 a 3).
- **Tutorial interactivo** integrado para aprender a jugar.
- **Guardado de configuración** (volumen y tutorial visto) en `user://settings.cfg`.

## Áreas de práctica

- Hardware: ensamblaje y desarme de componentes.
- Software: mantenimiento y reemplazo de piezas según síntomas.
- Servidores: diagnóstico de fallas bajo presión de tiempo.

## Estructura del proyecto

```
juego-3-dtecnico/
├── project.godot            # Configuración del proyecto Godot 4 (versión 0.2)
├── icon.svg                 # Ícono del juego
├── scenes/
│   ├── main.tscn            # Escena principal (nivel)
│   ├── minigame/            # Minijuegos de reparación (slots y piezas)
│   ├── parts/               # Estaciones de repuestos
│   ├── pc/                  # Computadoras reparables
│   ├── player/              # Jugador (CharacterBody3D)
│   └── ui/                  # HUD, menú principal, pausa, tutorial
├── scripts/
│   ├── game.gd              # Lógica central del juego (autoload)
│   ├── interactable.gd      # Base para objetos interactuables
│   ├── holo_title.gd        # Título de neón con glitch (HoloTitle)
│   ├── holo_card.gd         # Tarjeta holográfica de los menús (HoloCard)
│   ├── orbit_menu.gd        # Menú en arco alrededor del agujero negro (OrbitMenu)
│   ├── trash_bin.gd         # Papelera para botar piezas dañadas (TrashBin)
│   └── ui_style.gd          # Look ciberpunk compartido (UiStyle)
├── shaders/
│   └── menu_grid.gdshader   # Retícula técnica de fondo de los menús
├── versions/
│   ├── CHANGELOG.md         # Historial de versiones (0.1, 0.2)
│   ├── linux-version/       # Builds de Linux por versión
│   └── windows-version/     # Builds de Windows por versión
└── tests/                   # Pruebas automatizadas de escenas y lógica
```

## Versiones

Historial completo y notas de cada versión en **[versions/CHANGELOG.md](versions/CHANGELOG.md)**.

| Versión | Plataforma | Archivo | Fecha |
|---------|------------|---------|-------|
| **0.2** | Linux x86_64 | [versions/linux-version/0.2.zip](versions/linux-version/0.2.zip) | 2026-09-22 |
| **0.2** | Windows x86_64 | [versions/windows-version/0.2.zip](versions/windows-version/0.2.zip) | 2026-09-22 |
| 0.1 | Linux x86_64 | [versions/linux-version/0.1.zip](versions/linux-version/0.1.zip) | 2026-08-06 |
| 0.1 | Windows x86_64 | [versions/windows-version/0.1.zip](versions/windows-version/0.1.zip) | 2026-08-06 |

Cómo jugar una build descargada:

1. Descarga el ZIP de tu plataforma y descomprímelo.
2. **Linux:** dale permiso de ejecución y ábrelo:
   ```bash
   unzip 0.2.zip && chmod +x juego_3d_tecnico.x86_64 && ./juego_3d_tecnico.x86_64
   ```
   (o doble clic en el archivo si tu escritorio lo permite)
3. **Windows:** descomprime y haz doble clic en `juego_3d_tecnico.exe`.

Ambos ejecutables traen el `.pck` embebido: no necesitan archivos extra.

## Requisitos

- [Godot Engine 4.x](https://godotengine.org/download) (versión con soporte Forward Plus).
- Git (para clonar el repositorio).

## Cómo ejecutar

1. Clona el repositorio:
   ```bash
   git clone git@github.com:santiago9seijas-bit/juego-3-dtecnico.git
   ```
2. Abre Godot Engine.
3. Importa el proyecto: selecciona `project.godot`.
4. Presiona **F5** (ejecutar) o **F6** (ejecutar escena actual).

## Controles

| Acción           | Tecla |
|------------------|-------|
| Moverse          | `W A S D` |
| Mirar alrededor  | Ratón |
| Interactuar      | `E` |
| Destornillador llana | `1` |
| Destornillador cruz | `2` |
| Pausa            | `ESC` |

## Pruebas

El proyecto incluye pruebas automatizadas en la carpeta `tests/`. Puedes ejecutarlas con:

```bash
./tests/run_tests.sh
```

## Tecnologías

- [Godot Engine 4](https://godotengine.org) — motor de videojuegos.
- [GDScript](https://docs.godotengine.org) — lenguaje de programación.
- [Blender](https://www.blender.org) — modelado 3D y escenarios.

## Licencia

Este proyecto es de uso académico/educativo. No se distribuye con fines comerciales salvo autorización de los autores.

---

**Autores:** Santiago Seijas · Jeremías Robles · Zuleymar Lugo
**Coordinación:** Ing. Elizabeth C. Duarte P. · **Tutor:** Ing. Miguel Mejías
Universidad Politécnica Territorial del Estado Aragua "Federico Brito Figueroa" — La Victoria, Estado Aragua, Venezuela.
