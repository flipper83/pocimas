# Godot Best Practices

Cuando trabajas en este proyecto Godot 4, sigue estas prácticas:

## Estructura del proyecto

- `scenes/` — una escena por archivo `.tscn`, subcarpetas por área de juego
- `scripts/` — scripts GDScript, un archivo por clase
- `assets/` — texturas, sonidos, fuentes; nunca en la raíz
- Nunca pongas lógica en la escena raíz del proyecto, usa escenas dedicadas

## Escenas y nodos

- Cada escena debe tener **un único propósito** (jugador, enemigo, UI, etc.)
- Usa `Node2D` / `Node3D` como raíz de escenas de juego; `Control` para UI
- Instancia escenas en lugar de duplicar nodos
- Nombra los nodos en PascalCase y en inglés (`Player`, `HUD`, `MainCamera`)
- Evita nodos sueltos sin tipo concreto (`Node` puro) salvo para agrupadores lógicos

## GDScript

- Un archivo = una clase; declara `class_name` si la clase se reutiliza
- Variables de exportación (`@export`) para todo lo que el diseñador deba tocar
- Usa señales (`signal`) para comunicación entre nodos; evita referencias directas entre escenas hermanas
- Conecta señales en código (`connect`) o en el editor, no mezcles ambas formas en el mismo nodo
- Evita `get_node()` con rutas largas; prefiere `@onready var` o referencias exportadas
- Tipado estático siempre que sea posible: `var speed: float = 200.0`

## Plataformas objetivo y orientación

- **Plataformas**: Web (primario), iOS y Android (próximos)
- **Orientación**: **portrait** en todas las plataformas
- Viewport base: **720×1280** — `stretch/mode="canvas_items"`, `stretch/aspect="expand"`
- `window/handheld/orientation="portrait"` en project.godot para iOS/Android
- El layout **siempre debe adaptarse al ancho real de pantalla**: usa `get_viewport().get_visible_rect()` en `_ready()` para obtener `_screen_w` y `_screen_h` dinámicamente
- Nunca hardcodees posiciones absolutas; calcula con porcentajes o márgenes sobre `_screen_w`/`_screen_h`
- El fondo (background) debe cubrir la pantalla con cover-crop: `scale = maxf(screen_w/tex_w, screen_h/tex_h)`

## Input multi-plataforma (mouse + touch)

- Maneja **siempre** `InputEventMouseButton`/`InputEventMouseMotion` Y `InputEventScreenTouch`/`InputEventScreenDrag` en el mismo `_input()`
- Extrae la posición del evento en un helper `_event_pos(event)` para evitar duplicación

## Rendimiento web (GL Compatibility)

- Este proyecto exporta a web → usa **GL Compatibility**, nunca Vulkan/Forward+
- Evita shaders complejos o post-procesado pesado
- Prefiere `AtlasTexture` / `SpriteFrames` sobre muchas texturas sueltas
- Mantén el tamaño del ejecutable bajo: desactiva módulos que no uses en Project Settings
- Prueba en Chrome/Firefox antes de declarar algo como funcional

## Exportación web

- Configura el export preset "Web" con GLES2/GL Compatibility
- Activa "CORS headers" si el servidor lo requiere
- El juego debe correr sin pantalla de carga larga: precarga solo lo esencial

## Convenciones de código

```gdscript
# Correcto
class_name PlayerController
extends CharacterBody2D

@export var speed: float = 200.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

signal died

func _physics_process(delta: float) -> void:
    _handle_movement(delta)

func _handle_movement(delta: float) -> void:
    # ...
    pass
```

## Al crear o modificar escenas con el MCP

1. Usa `get_project_info` para verificar la estructura antes de crear nada
2. `create_scene` con `rootNodeType` adecuado al propósito
3. `add_node` para añadir hijos; verifica que el `scenePath` es correcto
4. Tras cambios estructurales, recuerda que el editor Godot puede necesitar reimportar
