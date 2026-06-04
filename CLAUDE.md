# pocimas — Godot 4 Web Project

Este proyecto es un juego web en Godot 4.6 con renderer GL Compatibility.

## Estructura del proyecto

- `scenes/` — una escena por archivo `.tscn`, subcarpetas por área de juego
- `scripts/` — scripts GDScript, un archivo por clase
- `assets/` — texturas, sonidos, fuentes; nunca en la raíz
- Nunca pongas lógica en la escena raíz del proyecto, usa escenas dedicadas

## Escenas y nodos

- Cada escena tiene un único propósito (jugador, enemigo, UI, etc.)
- Usa `Node2D` / `Node3D` como raíz de escenas de juego; `Control` para UI
- Instancia escenas en lugar de duplicar nodos
- Nombra los nodos en PascalCase y en inglés (`Player`, `HUD`, `MainCamera`)

## GDScript

- Un archivo = una clase; declara `class_name` si la clase se reutiliza
- Variables de exportación (`@export`) para todo lo que el diseñador deba tocar
- Usa señales (`signal`) para comunicación entre nodos; evita referencias directas entre escenas hermanas
- Conecta señales en código (`connect`) o en el editor, nunca mezcles ambos en el mismo nodo
- Evita `get_node()` con rutas largas; prefiere `@onready var` o referencias exportadas
- Tipado estático siempre: `var speed: float = 200.0`

## Rendimiento web (GL Compatibility)

- Este proyecto exporta a web → usa GL Compatibility, nunca Vulkan/Forward+
- Evita shaders complejos o post-procesado pesado
- Prefiere `AtlasTexture` / `SpriteFrames` sobre muchas texturas sueltas
- Prueba en Chrome/Firefox antes de declarar algo como funcional

## Al usar el MCP de Godot

1. Verifica la estructura con `get_project_info` antes de crear nada
2. `create_scene` con `rootNodeType` adecuado al propósito
3. `add_node` para añadir hijos; las propiedades de tipo Godot (Color, Vector2) no se aplican bien vía MCP — edita el `.tscn` directamente si es necesario
4. Tras cambios estructurales recuerda que el editor puede necesitar reimportar
