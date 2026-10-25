# WindUI Script Hub Remastered

Hub para explorar el catálogo de ScriptBlox desde una interfaz basada en WindUI. Incluye búsqueda paginada, filtros, favoritos e historial locales, editor de código y fondo animado.

## Inicio rápido

Ejecuta el cargador en un executor compatible con Roblox:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/vibecodergo/wind-ui-script-hub/main/loader.lua"))()
```

El cargador obtiene y ejecuta [`dist/script-hub.lua`](dist/script-hub.lua). Necesita que el executor permita `game:HttpGet` y `loadstring`. Para persistir biblioteca y borrador también se requieren `readfile` y `writefile`; sin ellas, el estado disponible en memoria dura solo la sesión. El fondo personalizado usa `getcustomasset` o `getsynasset`; si no están disponibles, el hub puede funcionar sin ese fondo.

Los resultados del catálogo no se ejecutan al buscar, seleccionar, ver o copiar. La ejecución requiere pulsar **Ejecutar** en un resultado seleccionado o en el editor. Revisa el código antes de ejecutarlo.

## Funciones

- **Inicio y Explorar:** búsqueda paginada, filtros por metadatos y juego, orden, etiquetas y vista previa.
- **Favoritos e Historial:** guardan metadatos localmente y vuelven a consultar el código al abrir un elemento.
- **Editor:** permite pegar código, cargar el resultado seleccionado, guardar y recuperar un borrador, copiar y ejecutar manualmente.
- **Ajustes:** controlan el fondo animado, sus parámetros, la caché y el guardado de la biblioteca.

El hub consulta ScriptBlox en línea. El contenido y la disponibilidad dependen de ese proveedor. Las etiquetas «verificado» reflejan metadatos de ScriptBlox y no son una auditoría independiente. Las cifras de catálogo documentadas son mediciones del proveedor en la fecha indicada, no una validación de cada script.

## Documentación

- [Guía del hub, límites y comprobaciones](docs/HubRemastered.md)
- [Buscador ScriptBlox](docs/ScriptSearch.md)
- [API y demo del fondo animado](docs/GIFBackground.md)
- [Registro de prueba en cliente](docs/GIFBackground-live-test.md)

## Desarrollo

El punto de entrada editable del hub es [`examples/MinimalScriptHub.lua`](examples/MinimalScriptHub.lua). Para recompilar y ejecutar las comprobaciones principales desde la raíz del repositorio:

```sh
darklua process examples/MinimalScriptHub.lua dist/script-hub.lua --config build/darklua.dev.config.json
lune run tests/ScriptSearch.luau
lune run tests/HubStore.luau
```

La guía [del fondo animado](docs/GIFBackground.md) documenta sus comprobaciones y comandos de compilación. WindUI conserva la licencia MIT del proyecto original; consulta [LICENSE](LICENSE) y las licencias de las dependencias.
