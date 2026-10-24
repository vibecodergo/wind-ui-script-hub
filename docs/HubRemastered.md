# Script Hub Remastered

La ventana original de WindUI ahora tiene seis secciones. Se conserva el GIF de
flores, la lista visible y las acciones explícitas Ver, Copiar y Ejecutar.

| Sección | Funciones |
| --- | --- |
| Inicio | Conteo del catálogo, favoritos y recientes; accesos a Explorar, este juego y Editor. |
| Explorar | Búsqueda paginada, etiquetas, filtros, orden, vista de código y guardado de favoritos. |
| Favoritos | Lista local con paginación; abre cada script en Explorar. |
| Historial | Últimos 100 scripts vistos o ejecutados, sin duplicar el mismo ID; opción para vaciarlo. |
| Editor | Escribir/pegar Lua, cargar el seleccionado, copiar, ejecutar, guardar y recuperar un borrador. |
| Ajustes | Activar/desactivar el GIF, transparencia, FPS, restaurar el fondo, vaciar caché y guardar la biblioteca. |

## Catálogo superior a 50.000

El 24 de octubre de 2026, desde el cliente del usuario, la consulta oficial
`/api/script/fetch?page=1&max=1` respondió `max=1` y `totalPages=74252`.
Con un resultado por página, el proveedor informa de **74.252 registros**.
La consulta normal de 20 por página respondió 3.713 páginas. Inicio usa la consulta
de un resultado para mostrar el conteo informado sin descargar miles de scripts.

La cifra depende del proveedor y puede variar. No significa que se descargaron o
validaron 74.252 scripts ni certifica código distinto o funcional en cada registro.
El archivo consulta el catálogo remoto y conserva 20 resultados por página. Se
mantienen los límites de ScriptBlox para consultas generales demasiado amplias;
usa búsquedas y filtros para acotar resultados.

## Etiquetas y filtros

Las filas muestran chips reutilizados dentro del contenedor de etiquetas original
de WindUI. Se usan los campos reales `isUniversal`, `key`, `verified` y `updatedAt`:

- Universal.
- Sin clave o Con clave.
- Verificado, cuando ScriptBlox lo marca como tal.
- Actualizado + fecha, únicamente si la respuesta incluye una fecha válida.

El juego se muestra debajo del título. **Filtros y orden** abre los controles para
universales, sin clave, verificados y solo el juego actual. Se envían a la API como
`universal=1`, `key=0`, `verified=1` y `placeId`. También se puede ordenar por
actualización reciente, vistas o valoraciones. «Actualización reciente» es un orden,
no una afirmación de que todos los resultados se actualizaron recientemente.

La ausencia de una fecha no se rellena con la fecha de publicación ni con una fecha
inventada. Verificado es un estado del proveedor, no una certificación independiente.

## Biblioteca y borrador locales

Favoritos, historial y ajustes se guardan en `WindUI/script-hub/state-v1.json` dentro
del workspace del executor. Se conservan como máximo 500 favoritos y 100 recientes.
Solo se guardan metadatos; al abrir un favorito se vuelve a consultar su código.
Esto evita guardar automáticamente código remoto ejecutable en la biblioteca.

El editor guarda el borrador manualmente en `WindUI/script-hub/editor-draft.lua`.
Para guardar/abrir o cargar el seleccionado se limita el texto a 200.000 bytes. La
vista de código de Explorar sigue limitada a 16.000 bytes; Copiar y Ejecutar conservan
el código completo recibido. No hay ejecución automática al abrir un favorito,
historial, borrador o resultado.

Si el executor no permite leer/escribir archivos, la biblioteca funciona en memoria
durante la sesión y la interfaz lo indica. Si falla una escritura, se conservan los
datos en memoria. Los ajustes se guardan tras una pausa breve del control, para no
escribir a disco por cada movimiento del slider.

## Fondo y compatibilidad

Se conserva el GIF de Giphy seleccionado, con 16 fotogramas y 10 FPS por defecto.
El PNG va embebido, se prepara una sola vez y se carga mediante `getcustomasset` o
`getsynasset`. Ajustes permite cambiar FPS entre 1 y 30 y transparencia entre 0 y 1.
Restaurar fondo vuelve a 10 FPS y transparencia 0,6. Desactivarlo retira el reproductor;
reactivarlo vuelve a aplicar el recorte Crop y los valores guardados.

El cliente probado no ofrecía `debug.traceback`. Se corrigió el manejador de errores
para usar `tostring` cuando esa función no está disponible. La ejecución del editor
se verificó de nuevo con un fragmento local conocido.

## Pruebas

- 36 comprobaciones del navegador: consultas, filtros enviados al servidor, conteo
  independiente de filtros, etiquetas reales, respuestas obsoletas, caché y errores.
- 18 comprobaciones del almacenamiento: persistencia, deduplicación, límites,
  archivos inválidos, fallo de escritura, UTF-8 y exclusión del código remoto.
- Se mantienen las pruebas del reproductor y del PNG embebido.
- En el cliente real: seis secciones, 74.252 registros informados, chips visibles,
  búsqueda con sin clave + verificado, filtro de juego, favorito escrito a JSON,
  historial recuperado después de recargar, borrador guardado y recuperado,
  ejecución local conocida, transparencia persistente y cambio de FPS.
- Se probó desactivar/reactivar el fondo y se confirmó que volvía a cargar y animar
  con Crop. No se ejecutaron scripts remotos del catálogo para hacer estas pruebas.

Compilar y comprobar desde la raíz del repositorio:

```powershell
darklua process examples/MinimalScriptHub.lua dist/script-hub.lua --config build/darklua.dev.config.json
lune run tests/ScriptSearch.luau
lune run tests/HubStore.luau
```

Ejecutar el archivo completo en el executor, o con la carpeta en su workspace:

```lua
loadstring(readfile("WindUI/dist/script-hub.lua"))()
```

Fuentes oficiales: [listado y filtros](https://docs.scriptblox.com/docs/scripts/fetch),
[búsqueda y orden](https://docs.scriptblox.com/docs/scripts/search),
[campos del script](https://docs.scriptblox.com/docs/scripts/individual).
