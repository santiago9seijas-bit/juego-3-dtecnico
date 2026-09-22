#!/usr/bin/env bash
# Corridas headless de verificacion para el juego Godot.
# Uso: ./tests/run_tests.sh
set -e

# Usa el Godot del sistema si no existe el binario local fijado antes.
GODOT="${GODOT:-$HOME/tools/godot/Godot_v4.6.2-stable_linux.x86_64}"
if [ ! -x "$GODOT" ]; then
    GODOT="$(command -v godot)"
fi
DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "== 1/7 import headless =="
"$GODOT" --headless --import --path "$DIR" >/dev/null

echo "== 2/7 test de mecanica (reparacion) =="
"$GODOT" --headless --path "$DIR" res://tests/test_mechanics.tscn

echo "== 3/7 test de niveles (unlock, tareas, aleatorio) =="
"$GODOT" --headless --path "$DIR" res://tests/test_levels.tscn

echo "== 4/7 test de partida (timer, puntaje, fin) =="
"$GODOT" --headless --path "$DIR" res://tests/test_game.tscn

echo "== 5/7 test de input (el mouse rota la camara al jugar) =="
"$GODOT" --headless --path "$DIR" res://tests/test_input.tscn

echo "== 6/7 test de fisica (piso solido, no caer al vacio) =="
"$GODOT" --headless --path "$DIR" res://tests/test_floor.tscn

echo "== 7/7 run del juego (300 frames, sin crash) =="
timeout 60 "$GODOT" --headless --quit-after 300 --path "$DIR" 2>&1 | grep -iE "ERROR|SCRIPT ERROR" && exit 1 || true

echo "TODO OK"
