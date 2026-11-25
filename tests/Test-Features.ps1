param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
Import-Module (Join-Path (Split-Path $PSScriptRoot) 'Core.psm1') -Force
[IO.Directory]::CreateDirectory($OutputDirectory)|Out-Null
& (Get-Module Core) {
 param($dir)
 $script:passed=0
 function Assert($ok,$name){if(!$ok){throw ('FAIL '+$name)};$script:passed++;'PASS '+$name}
 $settings=[pscustomobject]@{Wallpaper='Wallpaper Neon';Rainmeter='Skin Neon';Icons='Icons Vivid';StartMenu='Inicio Launch';Dock='Dock Neon';MenuTranslucent=$true;ExplorerTranslucent=$false}
 Test-NexoDesktopRequest $settings
 $settings.Dock='unknown';$rejected=$false;try{Test-NexoDesktopRequest $settings}catch{$rejected=$true};Assert $rejected 'Rechaza estilos arbitrarios';$settings.Dock='Dock Neon'
 New-NexoWallpaper 'Wallpaper Neon' (Join-Path $dir 'wallpaper.bmp')
 $bitmap=[Drawing.Bitmap]::FromFile((Join-Path $dir 'wallpaper.bmp'));try{Assert ($bitmap.Width -eq 1920 -and $bitmap.Height -eq 1080) 'Fondo original con dimensiones correctas'}finally{$bitmap.Dispose()}
 New-NexoIcon 'Icons Vivid' 'P' (Join-Path $dir 'icon.ico')
 $icon=New-Object Drawing.Icon((Join-Path $dir 'icon.ico'));try{Assert ($icon.Width -eq 64) 'Icono válido para Windows'}finally{$icon.Dispose()}
 $menu=Get-NexoCatalog | Where-Object Id -eq 'menu.extended'
 Assert ($menu.Keys.Count -eq 4 -and @($menu.Keys | Where-Object {$_.Count -ne 3}).Count -eq 0) 'Copia del menú contiene rutas, nombres y valores separados'
 $command=(Get-NexoMenuActions)[1][2]
 Assert ($command.Contains('-File "') -and $command.Contains('-Path "%1"') -and !$command.Contains('-Command')) 'Rutas de archivos se pasan como datos, no como código'
 $publisher=New-NexoOfficeConfiguration @('Publisher')
 Assert ($publisher.Configuration.Add.Product.ID -eq 'Publisher2021Retail') 'Publisher independiente no instala otra suite'
 $combined=New-NexoOfficeConfiguration @('Word','Publisher')
 Assert (@($combined.Configuration.Add.Product).Count -eq 2 -and 'Publisher' -in @($combined.Configuration.Add.Product | Where-Object ID -eq 'O365ProPlusRetail').ExcludeApp.ID) 'Publisher separado conserva Word seleccionado'
 $script:fake=[pscustomobject]@{Computer=$env:COMPUTERNAME;UserSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;Build=17763;X64=$true;Winget=$true;Laptop=$false}
 $req=[pscustomobject]@{Schema=1;Ids=@('edition.enterprise','desktop.custom','gpu.amd');DesktopSettings=$settings;OfficeApps=@();SxsFolder='';DriverFolder=''}
 $p=New-NexoPlan $req $script:fake
 Assert ($p.Steps[-1].Kind -eq 'Edition') 'Cambio de edición se procesa al final'
 Assert (!$p.Steps[0].Blocked) 'Configuración visual validada'
 $req.DesktopSettings=$null;$blocked=New-NexoPlan $req $script:fake
 Assert ([bool]$blocked.Steps[0].Blocked) 'Falta de selección visual bloquea la acción';$req.DesktopSettings=$settings
 $req.Ids=@('edition.enterprise','edition.professional');$rejected=$false;try{New-NexoPlan $req $script:fake|Out-Null}catch{$rejected=$true};Assert $rejected 'Rechaza ediciones incompatibles entre sí'
 function Get-CimInstance {return [pscustomobject]@{PNPDeviceID='PCI\VEN_80EE&DEV_BEEF'}}
 Assert ((Update-NexoGpu 'AMD' (Join-Path $dir 'gpu.log')) -eq 10001) 'VirtualBox no instala un controlador AMD incompatible'
 $rejected=$false;try{Invoke-NexoAction ([pscustomobject]@{Kind='Invalid'}) $null $null 'unused'}catch{$rejected=$true};Assert $rejected 'Un ejecutor desconocido no informa éxito'
 function Test-NexoAdmin {return $true}
 function Get-NexoInventory {return $script:fake}
 function Get-NexoBackup {return $null}
 function Invoke-NexoAction($Action,$Step,$Request,$Log){
  if($Action.Kind -eq 'GPU'){'GPU virtual, no aplicable'|Set-Content $Log;return 10001}
  if($Action.Kind -eq 'Edition'){'Necesita una clave'|Set-Content $Log;return 10002}
  return 0
 }
 $req.Ids=@('gpu.amd','desktop.custom','edition.enterprise');$plan=New-NexoPlan $req $script:fake
 $path=Join-Path $dir 'plan.json';Save-NexoJson $plan $path
 $journal=Invoke-NexoPlan $path (Join-Path $dir 'run')
 Assert ($journal.State -eq 'NeedsInput') 'Diario no da por completada una migración pendiente'
 Assert (($journal.Entries.State -join ',') -eq 'Skipped,Completed,NeedsInput') 'Distingue sin cambios, completado e intervención'
 Assert ($journal.Entries[-1].Error -like '*clave*') 'Muestra el motivo de la intervención'
 Save-NexoJson ([pscustomobject]@{Passed=$script:passed;Failed=0;Mutations='Solo archivos de prueba; instalaciones y GPU simuladas'}) (Join-Path $dir 'results.json')
} $OutputDirectory
