# Fondo animado interno de WindUI

Implementación sobre el código original de `Footagesus/WindUI`, commit
`d2c9bac5f96f997418d680d19cb759892542e492`. Submódulo oficial de iconos:
`46d30c19ba7bc601d6ec794a48dc3a89568b1eec`.

## Uso

Carga **esta versión modificada** de `dist/main.lua`. La versión publicada en la
rama principal de GitHub todavía no contiene estos cambios.

```lua
local Window = WindUI:CreateWindow({
    Title = "My Script Hub",
    GIFBackground = {
        Enabled = true,
        Type = "SpriteSheet", -- opcional; es el único modo implementado
        Asset = "rbxassetid://848623155", -- sprite sheet de ejemplo de Roblox
        FrameSize = Vector2.new(256, 256),
        Columns = 4,
        Rows = 4,
        FrameCount = 12,
        FPS = 24,
        Transparency = 0.3,
        Loop = true,
    },
})
```

`Asset` es el ID **de una imagen con los fotogramas distribuidos en una cuadrícula**,
o una URI `rbxasset://` de imagen local devuelta por `getcustomasset` en un executor.
No acepta directamente un GIF, un vídeo ni una URL HTTP. La cuadrícula se recorre de
izquierda a derecha y de arriba abajo. Los últimos espacios pueden quedar vacíos;
`FrameCount` especifica cuántos se reproducen. `FrameSize` debe coincidir con los
píxeles del recurso que Roblox sirve después de subirlo.

| Propiedad | Comportamiento |
| --- | --- |
| `Asset`, `FrameSize`, `Columns`, `Rows`, `FrameCount` | Obligatorios al activar el fondo. Dimensiones y cantidades deben ser enteros positivos. |
| `Enabled` | `true` por defecto. `false` elimina la animación y restaura el fondo anterior. |
| `FPS` | 24 por defecto; se limita al intervalo 1–60. |
| `Transparency` | 0 por defecto; se limita a 0–1. 0 es opaco; 1 es invisible y pausa la actualización. |
| `Loop` | `true` por defecto. Con `false`, termina en el último fotograma. |

```lua
Window:SetGIFBackground({
    Asset = "rbxassetid://848623155",
    FrameSize = Vector2.new(256, 256),
    Columns = 4, Rows = 4, FrameCount = 12,
    FPS = 12, Transparency = 0.5, Loop = true,
})
Window:SetGIFBackgroundTransparency(0.45)
Window:RemoveGIFBackground()
-- Equivalentes: Window:SetGIFBackground(nil), false, o { Enabled = false }
```

`SetGIFBackground` recibe la configuración completa y reinicia el reproductor.
Una configuración inválida lanza un error antes de retirar la animación activa.
`SetGIFBackgroundTransparency` conserva la precisión del número; el método original
`SetBackgroundImageTransparency` sigue afectando únicamente a la imagen anterior.
Los campos `Window.GIFBackground` y `Window.UIElements.GIFBackground` permiten
consultar la configuración normalizada y el ImageLabel; usa los métodos para editar.

## Convertir tu GIF

Desde la raíz del repositorio, con Python y Pillow instalados:

```powershell
python -m pip install Pillow
python tools/gif_to_sheet.py mi_fondo.gif mi_fondo.png --fps 24 --width 128 --height 128
```

El conversor produce el PNG, metadatos JSON y una tabla Lua. Compone los
fotogramas del GIF con Pillow y remuestrea sus duraciones a FPS uniformes. Mantiene
la proporción de cada fotograma dentro de su celda, con relleno transparente.
Si la animación no cabe en una sola hoja de 1024 × 1024, informa el error; reduce
dimensiones, duración o FPS. No recorta silenciosamente la animación.

Sube el PNG como imagen a Roblox y sustituye el ID indicado en la tabla Lua.
El conversor no sube recursos ni modifica tu cuenta. La duración de la conversión
puede diferir del GIF en menos de un fotograma debido al remuestreo.

## Demostración

1. Abre un lugar de prueba en Roblox Studio.
2. Inserta `examples/WindUI-GIF-Demo.rbxm` mediante **Insert from File** y mueve la
   carpeta `WindUIGIFDemo` a `StarterPlayer > StarterPlayerScripts`.
3. Inicia **Play**. La carpeta contiene el ModuleScript con la librería completa
   modificada y el LocalScript `Demo`. No hace falta habilitar `LoadStringEnabled`.
4. En la pestaña **Animation**, prueba transparencia, bucle, sustitución, eliminación
   y cierre/reapertura. Usa **Check texture and layer** y revisa Output.
5. Arrastra y redimensiona la ventana; cambia a **Controls** y prueba clics y scroll.

La demo usa el sprite sheet de animación de la documentación de Roblox, no una
captura estática. Es una muestra de reproducción, no un fondo artístico. El recurso
debe seguir disponible y accesible para tu experiencia. Si queda vacío, comprueba
la carga del asset y sustituye el ID y sus metadatos por tu propio recurso.

La biblioteca original elige CoreGui como contenedor. Solo el ModuleScript de la
demo añade una función local `gethui` que devuelve PlayerGui, aprovechando el hook
existente para ejecutarla como LocalScript normal en Studio. El código de la
biblioteca y su diseño se conservan. Se crea **una sola ventana de WindUI**; las
ScreenGuis auxiliares de notificaciones y menús son las originales.

Para el entorno de carga habitual de WindUI, copia este repositorio modificado
como `WindUI` al workspace de tu entorno y ejecuta `examples/GIFBackground.lua`.
Este ejemplo lee `WindUI/dist/main.lua`, sin descargar la versión antigua de GitHub.

## Integración y rendimiento

- El ImageLabel animado es hijo de `Window.UIElements.Main.Background`, igual que
  las imágenes originales. No se crea una segunda ventana ni un fondo de ScreenGui.
- `Size = UDim2.fromScale(1, 1)` sigue el tamaño y las animaciones de la ventana.
  `ScaleType.Stretch` cubre toda la superficie; puede deformar una imagen si su
  proporción difiere de la ventana.
- Un `UICorner` en el propio ImageLabel usa `Window.UICorner`, como los fondos
  de imagen existentes. El fondo base y el borde original de WindUI permanecen.
  Este recorte es circular; no reproduce exactamente la máscara de textura
  «Squircle» del fondo base original. No se afirma igualdad píxel a píxel.
- La nueva capa tiene `Active = false`, `Selectable = false`, `ZIndex = 1`.
  Los controles originales permanecen en el contenedor `Main`, con ZIndex 97;
  redimensionado y efectos de pantalla conservan sus capas originales.
- La imagen/vídeo anterior y el gradiente personalizado se ocultan mientras está
  activo el sprite sheet. El vídeo anterior se pausa. Al retirar la animación se
  restauran visibilidad y estado de reproducción previos. El color del tema sigue
  detrás de la animación y se ve al aumentar la transparencia.
- Se usa una textura y una conexión Heartbeat como máximo. Solo se cambia
  `ImageRectOffset` cuando cambia el fotograma; los fotogramas atrasados se saltan.
  No se crean texturas o instancias por fotograma ni se hacen descargas por frame.
- No hay actualización antes de que `IsLoaded` sea verdadero, cuando se cierra la
  ventana, cuando un ancestro se oculta o la ScreenGui se desactiva, ni al llegar a
  transparencia 1. Reabrir continúa desde el punto de pausa. Una animación terminada
  con `Loop = false` permanece en el último fotograma; vuelve a usar
  `SetGIFBackground(config)` para reiniciarla.
- Cambiar, retirar o destruir la animación desconecta las señales. Destruir la
  ventana o su contenedor limpia el reproductor. Ocultar pausa la CPU, pero conserva
  la textura para reabrir; Roblox administra la caché GPU.

## Comprobaciones y límites

Ejecutado en esta entrega:

```powershell
darklua process src/Init.lua dist/main.lua --config build/darklua.dev.config.json
lune run tests/GIFBackground.luau
lune run build/gif-demo.luau
python -m unittest discover -s tests -p test_gif_to_sheet.py
```

Se utilizó Darklua 0.17.1 (versión fijada por el repositorio) y Lune 0.11.1. Las
pruebas Luau ejecutan el controlador real y los métodos reales de la ventana con
dobles de los servicios de Roblox. Comprueban reproducción, salto de frames, bucle,
pausa, visibilidad, validación, sustitución, restauración y liberación de conexiones.
También compilan la integración y `dist/main.lua`. El empaquetado compila los scripts
de la demo y verifica la lectura posterior del modelo serializado. Las pruebas Python
comprueban remuestreo de duración variable, disposición de frames y metadatos.

**Verificación posterior en el cliente real, 24 de octubre de 2026:** se ejecutó la
biblioteca compilada en el cliente conectado del usuario. Se confirmó carga del
recurso, avance de fotogramas, último frame sin bucle, transparencia, pausa/reapertura,
sustitución, eliminación, limpieza de conexiones, una sola capa y ajuste a 700 × 500.
La comprobación detectó una señal `IsLoaded` que no llegaba al sustituir la textura;
se añadió precarga explícita con `ContentProvider:PreloadAsync` y se repitió con éxito.
Las pruebas automatizadas locales ahora incluyen una regresión para este caso
(43 comprobaciones Luau). Consulta [el registro de la prueba real](GIFBackground-live-test.md).

En tres muestras Heartbeat de unos 2 segundos se midieron 119,9 FPS con animación,
118,1 sin ella y 120 al restaurarla. No se observó una caída en esta prueba breve;
no sustituye un perfil prolongado con MicroProfiler en los dispositivos de destino.
Se inspeccionaron capturas de la ventana real y se observaron eventos de botones y
toggle durante la sesión. No se automatizó entrada física de ratón/rueda ni se
compararon píxel a píxel los bordes durante los tweens.

Solo se implementa `SpriteSheet`; no hay decodificador GIF nativo ni backend nuevo
de VideoFrame. El soporte anterior `Background = "video:..."` se conserva. Una sola
hoja limita resolución y duración: animaciones largas o grandes consumen memoria y
deben reducirse. GIFs con duraciones variables se convierten a FPS uniformes.
Si un recurso no carga por permisos/moderación/red, no arranca el reloj de animación
y queda visible el fondo temático base; la validación de metadatos no puede verificar
permisos ni el tamaño real de la textura. No se subió ningún recurso ni se publicaron
cambios en el repositorio remoto.

Referencias primarias:

- [WindUI original](https://github.com/Footagesus/WindUI)
- [ImageLabel y sprite sheets](https://create.roblox.com/docs/reference/engine/classes/ImageLabel)
- [UICorner: recorta su propio objeto, no sus descendientes](https://create.roblox.com/docs/reference/engine/classes/UICorner)
- [VideoFrame](https://create.roblox.com/docs/reference/engine/classes/VideoFrame)
