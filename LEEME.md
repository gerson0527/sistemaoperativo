# Nexo Assistant 0.3

Esta entrega reconstruye el recorrido visual del asistente de DELTA v13 bajo el nombre **Nexo**. Utiliza controles reales de Windows: puedes seleccionar, volver, cambiar opciones, guardar tus preferencias y enviar las acciones disponibles al motor de Nexo.

Es una versión de evaluación de la interfaz, no una implementación completa de DELTA ni una ISO nueva. Office, migración, perfiles de GPU/disco, modos Seguro/Medio/Extremo, compresión y paquetes de personalización siguen pendientes. Se identifican como tales en las pantallas y en el resumen.

## Abrir y recorrer

1. Extrae la carpeta completa y abre **NexoAssistant.exe**. No necesita Python ni Node.
2. Lee la presentación y pulsa **Aceptar**. Abrir el asistente solo consulta el hardware.
3. Recorre bienvenida, migración, gráficos, almacenamiento, equipo, Office, aplicaciones, personalización, modos y Debloatware.
4. En las tarjetas, **Seleccionar** guarda la preferencia y avanza. **Volver**, bajo el panel, permite corregirla.
5. Los botones **Instalar** de Office y Personalización conservan la posición de la referencia. En esta vista guardan la selección y continúan; no ejecutan una instalación.
6. El resumen muestra las acciones disponibles y las pendientes. **Guardar selección** conserva ambas en `%LOCALAPPDATA%\NexoAssistant\wizard-selection.json`; se recuperan al abrir de nuevo.
7. **Revisar acciones disponibles** abre el motor con esas acciones exactas. El motor vuelve a analizar el equipo, comprueba compatibilidad y solicita la confirmación del plan antes de aplicar.
8. **Ver pantalla de proceso** permite inspeccionar esa pantalla. Está marcada como vista previa y no simula progreso ni resultados. **Finalizar** guarda las preferencias; no afirma haber optimizado Windows.

La [guía visual](guia/Guia-del-cliente.html) contiene las 14 capturas de la aplicación y un comparador de las pantallas Gráficos y Personalización con su referencia. Las capturas muestran selecciones de prueba; no representan instalaciones realizadas.

## Qué cambió visualmente

Se reconstruyeron las coordenadas del panel, la cabecera, el pie del hardware, las tarjetas, botones, casillas, desplegables y grupos de cada página. El lienzo de 1920 × 1080 se adapta al tamaño de la ventana. Personalización incluye los cinco desplegables, dos transparencias, selección aleatoria, restablecer y seis temas.

Las imágenes de escritorio son **referencias visuales**: no son temas instalables ni una vista generada de cada combinación. Algunos presets cambian las preferencias conservando una imagen ilustrativa. Las listas de opciones reflejan las visibles en las referencias examinadas; no se afirma haber recuperado todo el catálogo interno del producto original.

Hay diferencias intencionadas: marca Nexo y versión real 0.3, descripciones del alcance disponible, regreso a pasos anteriores y revisión de acciones. Los términos describen esta evaluación; no se copió una licencia comercial. No es una copia exacta píxel por píxel. Consulta [la procedencia de los gráficos](REFERENCIAS.md).

## Motor disponible

Desde el nuevo recorrido se pueden preparar .NET Framework 3.5, .NET Desktop Runtime 8, Visual C++ v14 x64, 7-Zip, Firefox, VLC y la retirada de Clipchamp, Tiempo y Solitario para el usuario actual. Son las únicas opciones de ese recorrido que se envían a ejecución.

**Motor y herramientas** conserva el acceso a las funciones de la versión anterior:

- Temas claro/oscuro, reducir transparencias, mostrar extensiones, reducir sugerencias y desactivar captura Game DVR del usuario.
- Plan Equilibrado y Alto rendimiento; este último se bloquea si se detecta un portátil o no se identifica el tipo de equipo.
- Preparar WLAN AutoConfig e instalar paquetes locales firmados de controladores de red.
- Inventario, herramientas nativas, historial, registro de resultados, parada entre acciones y restauración de ajustes con copia.

Los perfiles Conservador/Ligero/Juegos de ese motor son distintos de los tres modos mostrados en el nuevo recorrido. No se sustituye silenciosamente un modo pendiente por uno de ellos.

Las aplicaciones de WinGet necesitan Internet y que WinGet esté disponible. Si falta —posible en LTSC o imágenes modificadas— esas acciones se bloquean. .NET 3.5 usa DISM con Windows Update o `sources\sxs` de la misma versión de Windows. Los controladores requieren una carpeta con paquetes completos INF/CAT/SYS del fabricante; no se incluyen drivers universales.

## Registro, restauración y compatibilidad

El motor escribe un diario antes de modificar ajustes. Puede restaurar los valores del Registro, el plan de energía y la configuración del servicio guardados. Instalar programas, drivers o .NET y quitar aplicaciones no tiene deshacer automático. Tras un fallo puede haber acciones anteriores completadas; consulta el diario.

El lanzador abre sin elevación. Solo aplicar/restaurar puede solicitar permisos de administrador de la misma cuenta. El motor exige Windows x64 build 17763 o posterior. Las pruebas de interfaz se hicieron en Windows 11 build 26200; falta validar instalaciones reales en máquinas de prueba y en LTSC. CPU, RAM y disco son una lectura al abrir, no un monitor en vivo.

## Archivos y pruebas

- `Nexo.ps1`, `Window.xaml` y `WizardCatalog.json`: nuevo recorrido y persistencia de preferencias.
- `Engine.ps1`, `Engine.xaml`, `Core.psm1` y `Worker.ps1`: revisión y ejecución de acciones disponibles.
- `Launcher.cs`, `app.manifest`, `Build.ps1`: código y compilación del ejecutable local sin firma comercial.
- `validacion.json` y `tests/resultados/`: resultados de la validación entregada.

Para capturar la interfaz sin ejecutar ajustes:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Nexo.ps1 -SmokeTest -TestUi -CaptureFolder C:\ruta\capturas -StatePath C:\ruta\seleccion-prueba.json
```

Usa una carpeta nueva de capturas y un archivo de estado de prueba. Las pruebas del motor (`tests/Test-Core.ps1`) simulan las operaciones de instalación; la comprobación de restauración crea y elimina una clave temporal propia del Registro.

## Instalación local y medio Windows

`Install-Portable.ps1` copia la aplicación, el motor y sus imágenes a `%LOCALAPPDATA%\Programs\NexoAssistant` y crea un acceso en el escritorio. No se ejecutó como parte de esta entrega.

`Prepare-Media.ps1 -MediaRoot <carpeta>` incorpora los archivos al árbol OEM de un medio de Windows extraído. No reconstruye una ISO ni valida Windows Setup. Esta versión no está integrada en la ISO Nexo OS 0.1 existente.
