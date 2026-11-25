# Nexo Assistant 0.3 y Nexo OS

Nexo es un asistente de personalización y mantenimiento para Windows, junto con herramientas para preparar una ISO de instalación basada en MiniOS11. El repositorio contiene el código fuente, documentación, guía visual y pruebas; los instaladores comerciales y las imágenes ISO se mantienen fuera de Git.

La interfaz tiene 14 pantallas con diseño renovado, navegación adaptable, guardado de preferencias y resumen de acciones. El motor revisa compatibilidad y pide confirmación antes de modificar el sistema. Incluye perfiles propios, opciones de privacidad y ajustes, instalación selectiva de aplicaciones, Microsoft 365 y Visio, CompactOS, optimización de disco, inventario, registro y restauración de ciertos ajustes. Las funciones disponibles y sus límites están detallados en [LEEME.md](LEEME.md).

La entrega local puede incorporar **DELTA Pro original**, accesible mediante el botón **DELTA Pro**. Incluye importación del paquete, verificación SHA-256, instalación interactiva y apertura de DELTA instalado. Nexo no incluye un paso de claves ni GenID; DELTA conserva sus propios requisitos. Los binarios comerciales no se publican en Git. Consulta [la integración y sus límites](DELTA-Integracion.html).

![Personalización de Nexo](guia/entrega/09-Custom.png)

## Ejecutar desde este repositorio

En Windows x64, abre PowerShell en la carpeta del repositorio y ejecuta:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build.ps1
.\NexoAssistant.exe
```

El lanzador se compila con .NET Framework de Windows. La interfaz utiliza Windows PowerShell 5.1 y WPF; no necesita Python ni Node. El ejecutable compilado se genera localmente y no se versiona.

Recorrer las pantallas guarda preferencias. Las acciones disponibles se envían al motor para una revisión y confirmación separadas antes de modificar Windows. La migración de edición, Publisher, ajustes de GPU y temas completos siguen pendientes. Consulta LEEME.md para conocer requisitos, alcance y pruebas.

## Documentación

- [Instrucciones, funciones disponibles y limitaciones](LEEME.md).
- [Guía visual y comparador con la referencia](guia/Guia-del-cliente.html): abre el archivo descargado en un navegador.
- [Procedencia de las imágenes de referencia](REFERENCIAS.md).
- [Resultados de validación](validacion.json): 71 comprobaciones superadas en la entrega del 11 de noviembre de 2026. Las instalaciones reales en máquinas de prueba siguen pendientes.

Los gráficos de referencia pertenecen a sus respectivos autores. Consulta su procedencia antes de reutilizarlos o distribuirlos.

## Código

`Nexo.ps1`, `Window.xaml` y `WizardCatalog.json` implementan la experiencia. `Engine.ps1`, `Engine.xaml`, `Core.psm1` y `Worker.ps1` validan y ejecutan acciones. `Features.ps1`, `Extended.ps1` y `DesktopPanel.ps1` agrupan funciones del motor y paneles adicionales. `Delta.ps1`, `Delta.psm1`, `Delta.xaml` e `Import-Delta.ps1` gestionan la integración opcional de DELTA. `tests/` contiene pruebas automatizadas.


## ISO arrancable con Nexo

`Build-Iso.ps1` prepara una ISO BIOS/UEFI a partir de la ISO MiniOS11 elegida. Verifica su SHA-256, extrae el medio, agrega Nexo y el paquete DELTA si está disponible e integra `SetupComplete.cmd`. `Nexo-Setup.ps1` configura el primer inicio y `FirstStart.ps1` abre Nexo una vez por usuario. `Prepare-Media.ps1` también permite integrar Nexo manualmente en un medio extraído.

La ISO generada se entrega como archivo local y se excluye de Git por su tamaño. En este equipo está en `C:\Users\gerson\Documents\Nexo-OS-Profesional.iso`; también se había generado `Nexo-OS-MiniOS11.iso`. El informe JSON junto a la imagen describe las verificaciones. La integración no automatiza credenciales ni selección de disco.

Para reconstruir, ejecuta `Build-Iso.ps1` con `-SourceIso`, `-WorkDirectory` (carpeta nueva), `-OutputIso` (ruta nueva), `-SevenZipPath` y `-OscdimgPath`. Se necesita la herramienta oficial Oscdimg del ADK. Los scripts no distribuyen Windows ni sustituyen la licencia de la imagen base.
