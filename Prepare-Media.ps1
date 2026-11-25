param([Parameter(Mandatory=$true)][string]$MediaRoot,[switch]$FirstLogonNexo)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $MediaRoot).Path
if(-not(Test-Path -LiteralPath (Join-Path $root 'sources\boot.wim'))){throw 'Selecciona la carpeta de un medio de instalacion de Windows extraido.'}
if(-not(Test-Path -LiteralPath (Join-Path $root 'sources\install.esd')) -and -not(Test-Path -LiteralPath (Join-Path $root 'sources\install.wim'))){throw 'No se encontro install.wim o install.esd.'}
$oem=Join-Path $root 'sources\$OEM$'
$target=Join-Path $oem '$1\NexoAssistant'
if(Test-Path -LiteralPath $target){throw 'Ya existe NexoAssistant en el medio. No se sobrescribe automaticamente.'}
[IO.Directory]::CreateDirectory($target)|Out-Null
foreach($name in @('NexoAssistant.exe','Nexo.ps1','Core.psm1','Extended.ps1','Features.ps1','DesktopPanel.ps1','CopyPath.ps1','Worker.ps1','Window.xaml','Engine.ps1','Engine.xaml','WizardCatalog.json','Delta.psm1','Delta.ps1','Delta.xaml','DeltaWorker.ps1','DELTA-Integracion.html','REFERENCIAS.md','LEEME.md')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $target $name)}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'assets') -Destination $target -Recurse
$deltaPayload=Join-Path $PSScriptRoot 'private-payloads\DELTA13'
if(Test-Path -LiteralPath (Join-Path $deltaPayload 'manifest.json')){
 Import-Module (Join-Path $PSScriptRoot 'Delta.psm1') -Force
 $null=Test-NexoDeltaBundle $deltaPayload
 $payloadTarget=Join-Path $target 'private-payloads'
 [IO.Directory]::CreateDirectory($payloadTarget)|Out-Null
 Copy-Item -LiteralPath $deltaPayload -Destination $payloadTarget -Recurse -Force
 $null=Test-NexoDeltaBundle (Join-Path $payloadTarget 'DELTA13')
}
$public=Join-Path $oem '$1\Users\Public\Desktop'
[IO.Directory]::CreateDirectory($public)|Out-Null
$shortcut=Join-Path $public 'Nexo Assistant.cmd'
if(Test-Path -LiteralPath $shortcut){throw 'Ya existe un acceso Nexo en el medio.'}
[IO.File]::WriteAllText($shortcut,"@echo off`r`nstart `"`" `"%SystemDrive%\NexoAssistant\NexoAssistant.exe`"`r`n",[Text.Encoding]::ASCII)
if($FirstLogonNexo){
 $scripts=Join-Path $oem '$$\Setup\Scripts'
 [IO.Directory]::CreateDirectory($scripts)|Out-Null
 $complete=Join-Path $scripts 'SetupComplete.cmd'
 if(Test-Path -LiteralPath $complete){throw 'Ya existe SetupComplete.cmd; integra su contenido antes de continuar.'}
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'FirstStart.ps1') -Destination $target
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Nexo-Setup.ps1') -Destination $scripts
 [IO.File]::WriteAllText((Join-Path $target 'iso-deployment.json'),'{"Product":"Nexo OS","Base":"MiniOS11 LTSC-26H2 v26.11","FirstLogon":true}',[Text.UTF8Encoding]::new($false))
 $command='@echo off'+"`r`n"+'"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%SystemRoot%\Setup\Scripts\Nexo-Setup.ps1"'+"`r`n"+'exit /b %errorlevel%'+"`r`n"
 [IO.File]::WriteAllText($complete,$command,[Text.Encoding]::ASCII)
 Import-Module (Join-Path $PSScriptRoot 'Core.psm1') -Force
 New-NexoWallpaper 'Wallpaper Nexo' (Join-Path $target 'assets\Nexo-Wallpaper.bmp')
 Write-Host 'Integrado: Nexo se abrirá en el primer inicio; sustituye el RunOnce del Toolkit de MiniOS.'
}else{Write-Host 'Asistente agregado al medio con acceso en el escritorio.'}
