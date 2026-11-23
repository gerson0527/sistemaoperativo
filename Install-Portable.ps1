# Copia local por usuario; no necesita administrador ni modifica la ejecucion automatica.
$ErrorActionPreference='Stop'
$target=Join-Path $env:LOCALAPPDATA 'Programs\NexoAssistant'
if([IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\') -eq [IO.Path]::GetFullPath($target).TrimEnd('\')){throw 'Nexo ya esta en la carpeta de instalacion.'}
[IO.Directory]::CreateDirectory($target) | Out-Null
foreach($name in @('NexoAssistant.exe','Nexo.ps1','Core.psm1','Worker.ps1','Window.xaml','Engine.ps1','Engine.xaml','WizardCatalog.json','REFERENCIAS.md','LEEME.md')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $target $name) -Force}
[IO.Directory]::CreateDirectory((Join-Path $target 'assets'))|Out-Null
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'assets') -File | Copy-Item -Destination (Join-Path $target 'assets') -Force
$shell=New-Object -ComObject WScript.Shell
$shortcut=$shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Nexo Assistant.lnk'))
$shortcut.TargetPath=Join-Path $target 'NexoAssistant.exe';$shortcut.WorkingDirectory=$target;$shortcut.Save()
Write-Host "Instalado en $target. Acceso creado en el escritorio."
