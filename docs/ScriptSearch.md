# Script mínimo con buscador integrado

La versión actual se amplió a seis secciones con etiquetas, filtros y biblioteca
local. Consulta [Script Hub Remastered](HubRemastered.md) para el recorrido actual
y el conteo actualizado de 74.252 registros informados por el proveedor.

`dist/script-hub.lua` es un script completo que incorpora esta versión modificada
de WindUI, el fondo animado y un buscador de ScriptBlox en la misma ventana.

## Ejecutar

Con la carpeta modificada `WindUI` en el workspace de tu executor:

```lua
loadstring(readfile("WindUI/dist/script-hub.lua"))()
```

También puedes cargar directamente el contenido de `dist/script-hub.lua` en tu
executor. No requiere publicar el archivo en GitHub. El punto de entrada editable
es `examples/MinimalScriptHub.lua`; `examples/ScriptSearch.lua` contiene el buscador.
Estos dos archivos fuente se unen al compilar, por lo que no se ejecutan directamente
mediante el `require` de un executor.

## Uso

1. En **Scripts**, escribe el nombre de un script o juego y pulsa **Buscar**.
   Con el campo vacío se consulta el catálogo general.
2. Pulsa un script de la lista visible de 20 resultados. Su título queda marcado
   y aparecen sus detalles y tres acciones: **Ver**, **Copiar** y **Ejecutar**.
3. **Ver** muestra el código en la misma pestaña, sustituyendo temporalmente la lista.
   **Volver a resultados** recupera la lista y conserva la selección.
4. **Copiar** copia el código completo. **Ejecutar** compila y ejecuta
   únicamente el resultado seleccionado al pulsar el botón.
5. Usa **Anterior** y **Siguiente**, agrupados junto a **Buscar**, para pasar de página.
   Desplázate por la lista para consultar todos los resultados.

No se ejecuta ningún resultado al buscar, seleccionar, visualizar o copiar. Si el
listado no incluye el código, se consulta el endpoint de detalles. Los fallos HTTP,
ausencia de código y errores de compilación/ejecución se muestran en la interfaz.
Los scripts con clave o de pago mantienen los requisitos de sus autores.

## Catálogo y mínimo de 10.000

Comprobado el 24 de octubre de 2026 desde el cliente conectado del usuario:

- `/api/script/fetch?page=1&max=20` devolvió 20 scripts y **3.713 páginas**.
- Las páginas 2, 50 y **500** también devolvieron 20 scripts.
- La consulta `blox fruits` devolvió 20 resultados en la primera página y 42 páginas.

Estos datos acreditan que el catálogo informado por el proveedor supera los 10.000
registros solicitados. No son 10.000 scripts incluidos o descargados en el archivo,
ni se certificó que cada registro contenga código diferente, válido o actualizado.
El buscador consulta el catálogo remoto; solo muestra una página de 20 resultados.

El proveedor rechazó una consulta general a la página 501 con «Too many results».
Su número total de páginas no implica que todas puedan recorrerse sin filtros.
La interfaz conserva ese error y propone afinar el término de búsqueda. El tamaño
del catálogo, disponibilidad y límites dependen de ScriptBlox y pueden cambiar.

## Recursos y comportamiento

- Se mantienen seis páginas en caché como máximo, con vigencia de 60 segundos.
  **Buscar** vacía esa caché.
- Las búsquedas son asíncronas. Una respuesta antigua no reemplaza una búsqueda
  o selección posterior. A los 20 segundos se invalida la solicitud sin respuesta;
  la llamada HTTP subyacente depende de los límites del executor.
- Las peticiones se hacen al dominio oficial `scriptblox.com` y los términos se
  codifican con UrlEncode. La integración muestra la atribución requerida.
- Se limita la vista de código a los primeros 16.000 bytes para no bloquear el
  resaltado de sintaxis. Copiar y ejecutar usan el código completo recibido.
- No se crean miles de controles: se reutilizan 20 filas visibles, los detalles y el visor.
- Las acciones permanecen ocultas hasta seleccionar un resultado y se habilitan
  cuando su código termina de cargar. La selección vuelve al principio de la lista
  para mostrar inmediatamente el título y sus acciones.
- Todo el recorrido ocurre en una sola pestaña de la ventana original.

## Fondo seleccionado de Giphy

El fondo es [el GIF proporcionado por el usuario](https://media4.giphy.com/media/TrVla4Z2PYEkU/giphy.gif).
Se conservaron sus **16 fotogramas, 10 FPS y 1,6 segundos**, en una hoja de
1000 × 560 píxeles con 4 × 4 celdas de 250 × 140. El PNG está incluido en el script
compilado, se prepara una sola vez en `WindUI/assets/` y se carga mediante
`getcustomasset` o `getsynasset`. No hay subida a Roblox ni reproducción nativa de GIF.

El executor debe ofrecer esa función y `writefile`. La caché evita escribir el PNG
en cada arranque. La imagen se ajusta con Crop para conservar sus proporciones y
se usa transparencia 0,6 para mantener legibles los textos sobre las flores claras.
El módulo editable `examples/GiphyBackground.lua` se genera con:

```powershell
python build/giphy-background.py
```

## Verificación

En el cliente real se comprobaron carga de catálogo, página 2, búsqueda de texto,
selección, vista de código, portapapeles y ejecución. Para probar **Ejecutar** se
usó un fragmento local conocido que incrementa un marcador, y se restauró después
el resultado seleccionado. No se ejecutaron scripts remotos del catálogo durante
la prueba ni se certificó su funcionamiento. No se añadió ninguna segunda ventana.

También pasaron **29 comprobaciones Luau** del navegador con dobles de red y UI:
caché limitada, codificación de consultas, respuestas obsoletas, error HTTP 429,
timeout, vista parcial/copia completa, carga de detalles y ejecución solo explícita.
El bundle completo compila. Tras simplificar el menú se repitieron en el cliente
real la búsqueda con el botón, selección desde una fila, aparición de acciones,
vista de código y regreso a la lista. La textura local cargó y avanzó fotogramas;
en una muestra breve de 2 segundos se midieron 119,9 FPS. Esto no sustituye un perfil
prolongado en distintos dispositivos.

La prueba `tests/GiphyBackground.luau` verificó que el PNG embebido se recupera
idéntico byte por byte y que se conserva su metadata, URI local y caché. Las
comprobaciones del controlador ahora son 44 e incluyen la URI `rbxasset://`.

```powershell
darklua process examples/MinimalScriptHub.lua dist/script-hub.lua --config build/darklua.dev.config.json
lune run tests/ScriptSearch.luau
lune run tests/GiphyBackground.luau
```

Documentación oficial consultada:

- [Listado y paginación](https://docs.scriptblox.com/docs/scripts/fetch)
- [Búsqueda](https://docs.scriptblox.com/docs/scripts/search)
- [Detalles de un script](https://docs.scriptblox.com/docs/scripts/individual)
- [Atribución requerida](https://scriptblox.com/docs)
