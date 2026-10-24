# Prueba en el cliente real — 24 de octubre de 2026

Cliente del usuario en «[UP] Solo una placa base.», place 123974602339071.
Se cargó el bundle local modificado mediante el conector del executor. No se descargó
la biblioteca publicada en GitHub ni se modificó el código del juego.

## Resultados

| Comprobación | Resultado |
| --- | --- |
| Textura `rbxassetid://848623155` | Cargó y se mostró en la ventana |
| Reproducción automática | Avance real de ImageRectOffset confirmado |
| Capa interna | `CoreGui.Main.WindUI.Window.Frame.Background.GIFBackground` |
| Controles sobre el fondo | ZIndex del fondo 1; contenedor de controles 97 |
| Entrada | ImageLabel con Active/Selectable false; se observaron eventos de botones y toggle |
| Transparencia 0,65 | Aplicada y conservada al reabrir |
| Cierre/reapertura | Reloj detenido al cerrar y reanudado al abrir |
| ScreenGui desactivada | Reloj detenido y reanudado al reactivar |
| Transparencia 1 | Sin conexión Heartbeat activa |
| Cambio de tamaño | Imagen 700 × 500, igual que el contenedor; restaurado después |
| Radio | UICorner de 16 px, según la ventana |
| Configuración inválida | Rechazada, conservando la animación activa |
| Sustitución en caliente | Animación nueva iniciada; anteriores instancias y conexiones liberadas |
| Loop=false | Detenido en offset (768, 512), último de los 12 frames |
| Eliminación/restauración | Referencias limpiadas y reproducción restaurada |
| Una sola capa | Un único hijo llamado GIFBackground tras sustituir/restaurar |

## Fallo detectado y corregido

Al cambiar el fondo, la textura podía pasar a IsLoaded=true sin activar la señal
esperada. El ImageLabel quedaba en el primer frame hasta otro cambio de visibilidad.
La versión corregida solicita `ContentProvider:PreloadAsync` una vez por animación y
reevalúa el inicio cuando termina. Conserva la señal y la comprobación inmediata.
No hay precarga ni descargas por fotograma. Se repitieron las pruebas con el bundle
completo corregido: arranque, sustitución, fin sin bucle y restauración pasaron.

## Muestra de rendimiento

| Estado | Frames Heartbeat | Segundos acumulados | FPS |
| --- | ---: | ---: | ---: |
| Animado | 240 | 2,001 | 119,9 |
| Animación retirada | 236 | 1,998 | 118,1 |
| Animación restaurada | 241 | 2,009 | 120,0 |

Muestras secuenciales cortas en el mismo cliente, sin controlar cámara, foco,
actividad del juego ni calentamiento de GPU. Son una comprobación inicial; no
demuestran rendimiento universal. No se realizó un perfil de GPU/MicroProfiler.

Se inspeccionaron capturas del cliente que muestran distintos fotogramas dentro de
la ventana original. No se automatizó entrada física de ratón ni scroll; las
comprobaciones de entrada por propiedades no sustituyen esas pruebas. Se deja la
demo abierta con la animación restaurada para continuar la revisión manual.
