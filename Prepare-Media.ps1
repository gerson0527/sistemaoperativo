param([Parameter(Mandatory=$true)][string]$MediaRoot)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $MediaRoot).Path
if(-not(Test-Path -LiteralPath (Join-Path $root 'sources\boot.wim'))){throw 'Selecciona la carpeta de un medio de instalacion de Windows extraido.'}
if(-not(Test-Path -LiteralPath (Join-Path $root 'sources\install.esd')) -and -not(Test-Path -LiteralPath (Join-Path $root 'sources\install.wim'))){throw 'No se encontro install.wim o install.esd.'}
$oem=Join-Path $root 'sources\$OEM$'
$target=Join-Path $oem '$1\NexoAssistant'
if(Test-Path -LiteralPath $target){throw 'Ya existe NexoAssistant en el medio. No se sobrescribe automaticamente.'}
[IO.Directory]::CreateDirectory($target)|Out-Null
foreach($name in @('NexoAssistant.exe','Nexo.ps1','Core.psm1','Worker.ps1','Window.xaml','Engine.ps1','Engine.xaml','WizardCatalog.json','REFERENCIAS.md','LEEME.md')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $target $name)}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'assets') -Destination $target -Recurse
$public=Join-Path $oem '$Users\Public\Desktop'
[IO.Directory]::CreateDirectory($public)|Out-Null
$shortcut=Join-Path $public 'Nexo Assistant.cmd'
if(Test-Path -LiteralPath $shortcut){throw 'Ya existe un acceso Nexo en el medio.'}
[IO.File]::WriteAllText($shortcut,"@echo off`r`nstart `"`" `"%SystemDrive%\NexoAssistant\NexoAssistant.exe`"`r`n",[Text.Encoding]::ASCII)
Write-Host 'Asistente agregado al medio. Se ofrece un acceso en el escritorio; no se ejecuta automaticamente durante Setup.'
