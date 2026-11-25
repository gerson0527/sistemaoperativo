Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
$script:Version = '0.3.0'

. (Join-Path $PSScriptRoot 'Extended.ps1')
. (Join-Path $PSScriptRoot 'Features.ps1')

function Get-NexoCatalog {
    @(
        Get-NexoExtendedCatalog
        Get-NexoFeatureCatalog
        [pscustomobject]@{Id='theme.dark';Group='Apariencia';Name='Tema oscuro';Detail='Aplicaciones y sistema en modo oscuro. Puede requerir cerrar sesion.';Kind='Registry';Undo=$true;Keys=@(@('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize','AppsUseLightTheme',0),@('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize','SystemUsesLightTheme',0))}
        [pscustomobject]@{Id='theme.light';Group='Apariencia';Name='Tema claro';Detail='Aplicaciones y sistema en modo claro. Puede requerir cerrar sesion.';Kind='Registry';Undo=$true;Keys=@(@('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize','AppsUseLightTheme',1),@('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize','SystemUsesLightTheme',1))}
        [pscustomobject]@{Id='visual.transparency';Group='Apariencia';Name='Reducir transparencias';Detail='Desactiva transparencias del escritorio para el usuario actual.';Kind='Registry';Undo=$true;Keys=@(@('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize','EnableTransparency',0))}
        [pscustomobject]@{Id='explorer.extensions';Group='Ajustes';Name='Mostrar extensiones de archivos';Detail='Muestra .exe, .pdf y otras extensiones en el Explorador.';Kind='Registry';Undo=$true;Keys=@(@('Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced','HideFileExt',0))}
        [pscustomobject]@{Id='privacy.suggestions';Group='Ajustes';Name='Reducir sugerencias y promociones';Detail='Desactiva sugerencias de contenido para este usuario. No elimina toda la telemetria.';Kind='Registry';Undo=$true;Keys=@(@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager','SubscribedContent-338388Enabled',0),@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager','SubscribedContent-338389Enabled',0),@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager','SilentInstalledAppsEnabled',0))}
        [pscustomobject]@{Id='gaming.capture';Group='Ajustes';Name='Desactivar captura de juegos';Detail='Desactiva Game DVR para este usuario. No elimina Xbox ni modifica controladores.';Kind='Registry';Undo=$true;Keys=@(@('System\GameConfigStore','GameDVR_Enabled',0),@('Software\Microsoft\Windows\CurrentVersion\GameDVR','AppCaptureEnabled',0))}
        [pscustomobject]@{Id='power.balanced';Group='Energia';Name='Plan equilibrado';Detail='Selecciona el plan Equilibrado de Windows si esta disponible.';Kind='Power';Undo=$true;Guid='381b4222-f694-41f0-9685-ff5bb260df2e'}
        [pscustomobject]@{Id='power.performance';Group='Energia';Name='Alto rendimiento';Detail='Solo sobremesas. Puede aumentar consumo, temperatura y ruido. No garantiza mas FPS.';Kind='Power';Undo=$true;Guid='8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'}
        [pscustomobject]@{Id='network.wlan';Group='Red';Name='Preparar servicio Wi-Fi';Detail='Configura WLAN AutoConfig en automatico y lo inicia. Requiere un adaptador y su controlador.';Kind='Service';Undo=$true}
        [pscustomobject]@{Id='network.drivers';Group='Red';Name='Instalar paquetes locales de red';Detail='Busca INF Class=Net con catalogo firmado. Windows comprueba el paquete y selecciona el driver compatible. No incluye paquetes de fabricantes.';Kind='Driver';Undo=$false}
        [pscustomobject]@{Id='runtime.netfx3';Group='Bibliotecas';Name='.NET Framework 3.5';Detail='Habilita el componente con DISM. Usa Windows Update o sources\sxs de la MISMA version de Windows. Sin reinicio automatico.';Kind='Feature';Undo=$false}
        [pscustomobject]@{Id='app.7zip';Group='Programas';Name='7-Zip';Detail='Instala desde WinGet. Requiere Internet y aceptar las condiciones del programa.';Kind='Package';Undo=$false;Package='7zip.7zip'}
        [pscustomobject]@{Id='app.firefox';Group='Programas';Name='Mozilla Firefox';Detail='Instala desde WinGet. Requiere Internet y aceptar las condiciones del programa.';Kind='Package';Undo=$false;Package='Mozilla.Firefox'}
        [pscustomobject]@{Id='app.vlc';Group='Programas';Name='VLC';Detail='Instala desde WinGet. Requiere Internet y aceptar las condiciones del programa.';Kind='Package';Undo=$false;Package='VideoLAN.VLC'}
        [pscustomobject]@{Id='app.vcredist';Group='Bibliotecas';Name='Visual C++ v14 x64';Detail='Redistribuible x64 desde WinGet; no sustituye todas las generaciones de Visual C++.';Kind='Package';Undo=$false;Package='Microsoft.VCRedist.2015+.x64'}
        [pscustomobject]@{Id='app.dotnet8';Group='Bibliotecas';Name='.NET Desktop Runtime 8 x64';Detail='Runtime de escritorio .NET 8 desde WinGet. Es distinto de Framework 3.5.';Kind='Package';Undo=$false;Package='Microsoft.DotNet.DesktopRuntime.8'}
        [pscustomobject]@{Id='remove.clipchamp';Group='Aplicaciones opcionales';Name='Quitar Clipchamp';Detail='Solo usuario actual. No elimina el paquete de otros usuarios ni de la imagen. Reinstalacion manual desde Store.';Kind='Appx';Undo=$false;Appx='Clipchamp.Clipchamp'}
        [pscustomobject]@{Id='remove.weather';Group='Aplicaciones opcionales';Name='Quitar Tiempo';Detail='Solo usuario actual. Reinstalacion manual desde Store.';Kind='Appx';Undo=$false;Appx='Microsoft.BingWeather'}
        [pscustomobject]@{Id='remove.solitaire';Group='Aplicaciones opcionales';Name='Quitar Solitario';Detail='Solo usuario actual. Reinstalacion manual desde Store.';Kind='Appx';Undo=$false;Appx='Microsoft.MicrosoftSolitaireCollection'}
    )
}

function Get-NexoProfile([string]$Name) {
    switch ($Name) {
        'Conservador' { @('explorer.extensions','power.balanced') }
        'Ligero' { @('explorer.extensions','power.balanced','visual.transparency','privacy.suggestions') }
        'Juegos' { @('explorer.extensions','power.balanced','gaming.capture') }
        default { @() }
    }
}
function Test-NexoAdmin {
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Get-NexoInventory {
    $warnings=New-Object 'System.Collections.Generic.List[string]'
    $os=$null; $pc=$null; $gpus=@(); $disks=@(); $net=@(); $missing=@(); $battery=@()
    try { $os=Get-CimInstance Win32_OperatingSystem; $pc=Get-CimInstance Win32_ComputerSystem } catch { $warnings.Add($_.Exception.Message) }
    try { $gpus=@(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion) } catch { $warnings.Add('No se pudo consultar GPU.') }
    try { $disks=@(Get-CimInstance Win32_DiskDrive | Select-Object Model,MediaType,Size,InterfaceType) } catch { $warnings.Add('No se pudieron consultar discos.') }
    try { $net=@(Get-CimInstance Win32_NetworkAdapter | Where-Object PhysicalAdapter | Select-Object Name,NetEnabled,PNPDeviceID); $missing=@(Get-CimInstance Win32_PnPEntity | Where-Object {$_.ConfigManagerErrorCode -ne 0} | Select-Object Name,PNPDeviceID,ConfigManagerErrorCode) } catch { $warnings.Add('Consulta de dispositivos incompleta.') }
    $laptop=$null
    try { $battery=@(Get-CimInstance Win32_Battery); $chassis=Get-CimInstance Win32_SystemEnclosure; $laptop=($battery.Count -gt 0 -or @($chassis.ChassisTypes | Where-Object {$_ -in @(8,9,10,11,12,14,18,21,30,31,32)}).Count -gt 0) } catch { $warnings.Add('No se pudo determinar si es portatil.') }
    $build=0; $caption='Windows (sin datos)'; $ram=0; $model='Sin datos'
    if ($os) { $build=[int]$os.BuildNumber; $caption=$os.Caption }
    if ($pc) { $ram=[math]::Round($pc.TotalPhysicalMemory/1GB,1); $model=$pc.Model }
    $cpuName='Sin datos';$cpuPercent=$null;$memoryPercent=$null;$drivePercent=$null
    try{$cpus=@(Get-CimInstance Win32_Processor);$cpuName=($cpus.Name -join ', ');$cpuPercent=[int](($cpus | Measure-Object LoadPercentage -Average).Average)}catch{$warnings.Add('No se pudo consultar el procesador.')}
    if($os -and $os.TotalVisibleMemorySize -gt 0){$memoryPercent=[int](100*(1-$os.FreePhysicalMemory/$os.TotalVisibleMemorySize))}
    try{$drive=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'";if($drive.Size -gt 0){$drivePercent=[int](100*(1-$drive.FreeSpace/$drive.Size))}}catch{$warnings.Add('No se pudo consultar el espacio del sistema.')}
    $winget=Get-Command winget.exe -ErrorAction SilentlyContinue
    $services=@(foreach ($name in @('WlanSvc','wuauserv','WinDefend','MpsSvc')) { $s=Get-Service -Name $name -ErrorAction SilentlyContinue; if($s){[pscustomobject]@{Name=$name;Status=[string]$s.Status;StartType=[string]$s.StartType}} })
    [pscustomobject]@{Version=$script:Version;Computer=$env:COMPUTERNAME;UserSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;OS=$caption;Build=$build;X64=[Environment]::Is64BitOperatingSystem;RAMGB=$ram;Model=$model;Laptop=$laptop;CPUName=$cpuName;CPUPercent=$cpuPercent;MemoryPercent=$memoryPercent;DrivePercent=$drivePercent;SampleTime=(Get-Date).ToString('HH:mm:ss');GPU=$gpus;Disks=$disks;Network=$net;ProblemDevices=$missing;Services=$services;Winget=($null -ne $winget);Admin=(Test-NexoAdmin);Warnings=@($warnings)}
}
function Save-NexoJson($Value,[string]$Path) {
    $parent=Split-Path -Parent $Path
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    $temp=$Path+'.tmp'
    [IO.File]::WriteAllText($temp,($Value | ConvertTo-Json -Depth 16),(New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temp -Destination $Path -Force
}
function Read-NexoJson([string]$Path) { Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json }
function Get-NexoDriverFiles([string]$Folder) {
    if (-not $Folder -or -not (Test-Path -LiteralPath $Folder -PathType Container)) { throw 'Selecciona una carpeta con paquetes completos INF/CAT/SYS de red.' }
    $found=@(Get-ChildItem -LiteralPath $Folder -Filter *.inf -File -Recurse | Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match '(?im)^\s*Class\s*=\s*Net\s*(;.*)?$' })
    if ($found.Count -eq 0) { throw 'No se encontraron INF de clase Net en la carpeta.' }
    foreach ($inf in $found) {
        $body=Get-Content -LiteralPath $inf.FullName -Raw
        $matches=[regex]::Matches($body,'(?im)^\s*CatalogFile(?:\.[\w.]+)?\s*=\s*"?([^";\r\n]+)')
        $valid=$false
        foreach($m in $matches) {
            $file=$m.Groups[1].Value.Trim()
            if([IO.Path]::GetFileName($file) -ne $file) { continue }
            $cat=Join-Path $inf.DirectoryName $file
            if((Test-Path -LiteralPath $cat) -and (Get-AuthenticodeSignature -LiteralPath $cat).Status -eq 'Valid') { $valid=$true }
        }
        if (-not $valid) { throw "Catalogo firmado no verificable para $($inf.Name). No se desactiva la verificacion de firmas." }
        [pscustomobject]@{Path=$inf.FullName;Sha256=(Get-FileHash -LiteralPath $inf.FullName -Algorithm SHA256).Hash}
    }
}
function New-NexoPlan($Request,$Inventory) {
    if ($Request.Schema -ne 1) { throw 'Formato de solicitud no compatible.' }
    $ids=@($Request.Ids)
    if($ids.Count -eq 0){throw 'Selecciona al menos una accion.'}
    if (@($ids | Select-Object -Unique).Count -ne $ids.Count) { throw 'La seleccion contiene acciones duplicadas.' }
    foreach ($pair in @(@('theme.dark','theme.light'),@('power.balanced','power.performance'))) {
        if($pair[0] -in $ids -and $pair[1] -in $ids){throw 'Selecciona un solo tema y un solo plan de energia.'}
    }
    $catalog=@(Get-NexoCatalog); $steps=@()
    if(@($ids | Where-Object {$_ -like 'edition.*'}).Count -gt 1){throw 'Selecciona una sola edición de Windows.'}
    $ids=@($ids | Where-Object {$_ -notlike 'edition.*'})+@($ids | Where-Object {$_ -like 'edition.*'})
    foreach($id in $ids) {
        $action=@($catalog | Where-Object Id -eq $id)
        if($action.Count -ne 1){throw "Accion no permitida: $id"}
        $a=$action[0]; $reason=''; $drivers=@()
        if($Inventory.Build -lt 17763 -or -not $Inventory.X64){$reason='Esta version requiere Windows x64, build 17763 o posterior.'}
        elseif($a.Kind -eq 'Package' -and -not $Inventory.Winget -and $Inventory.Build -lt 17763){$reason='WinGet requiere Windows 10 1809 o posterior.'}
        elseif($a.Kind -eq 'Desktop') {
            if($Request.PSObject.Properties.Name -notcontains 'DesktopSettings'){$reason='Selecciona un tema en el asistente.'}
            else{try{Test-NexoDesktopRequest $Request.DesktopSettings}catch{$reason=$_.Exception.Message}}
        }
        elseif($a.Kind -eq 'Office') {
            if ($Request.PSObject.Properties.Name -notcontains 'OfficeApps') { $reason='Selecciona las aplicaciones de Office desde el asistente.' }
            else { try { $null=New-NexoOfficeConfiguration @($Request.OfficeApps) } catch { $reason=$_.Exception.Message } }
            if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration') { $reason='Office ya está instalado. Usa su instalador para cambiar aplicaciones.' }
            $existingOffice=@(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object { $_.PSObject.Properties.Name -contains 'DisplayName' -and $_.DisplayName -match '^Microsoft (Office|365|Visio)' })
            if($existingOffice.Count){$reason='Se detectó una instalación de Office. Revisa su edición y arquitectura antes de continuar.'}
        }
        elseif($id -eq 'power.performance' -and $Inventory.Laptop -ne $false){$reason='Alto rendimiento reservado a equipos identificados como sobremesa.'}
        elseif($a.Kind -eq 'Driver') { try { $drivers=@(Get-NexoDriverFiles $Request.DriverFolder) } catch { $reason=$_.Exception.Message } }
        elseif($a.Kind -eq 'Feature' -and $Request.SxsFolder -and -not(Test-Path -LiteralPath $Request.SxsFolder -PathType Container)){$reason='La carpeta sources\sxs no existe.'}
        elseif($a.Kind -eq 'Service' -and -not(Get-Service WlanSvc -ErrorAction SilentlyContinue)){$reason='WLAN AutoConfig no existe en este Windows.'}
        $steps += [pscustomobject]@{Id=$id;Name=$a.Name;Kind=$a.Kind;Reversible=$a.Undo;Detail=$a.Detail;Blocked=$reason;Drivers=$drivers}
    }
    [pscustomobject]@{Schema=1;Version=$script:Version;Created=(Get-Date).ToString('o');Computer=$Inventory.Computer;UserSid=$Inventory.UserSid;Build=$Inventory.Build;Request=$Request;Steps=$steps}
}

function Invoke-NexoNative([string]$File,[string[]]$Arguments,[string]$Log,[int[]]$SuccessCodes=@(0,3010,1641)) {
    $output=& $File @Arguments 2>&1
    $code=$LASTEXITCODE
    $output | Out-File -LiteralPath $Log -Append -Encoding utf8
    if($code -notin $SuccessCodes){throw "$([IO.Path]::GetFileName($File)) termino con codigo $code. Consulta $Log"}
    return $code
}
function Get-NexoRegistryBackup($Action) {
    $items=@()
    foreach($tuple in $Action.Keys) {
        $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey([string]$tuple[0])
        $exists=$false; $value=$null; $kind='DWord'
        if($key){$exists=$key.GetValueNames() -contains [string]$tuple[1]; if($exists){$value=$key.GetValue($tuple[1]);$kind=[string]$key.GetValueKind($tuple[1])}; $key.Close()}
        $items += [pscustomobject]@{Path=[string]$tuple[0];Name=[string]$tuple[1];Exists=$exists;Value=$value;Kind=$kind}
    }
    return $items
}
function Get-NexoBackup($Action) {
    switch($Action.Kind) {
        'Registry' { return @(Get-NexoRegistryBackup $Action) }
        'Menu' { return @(Get-NexoRegistryBackup $Action) }
        'Power' {
            $active=& "$env:SystemRoot\System32\powercfg.exe" /getactivescheme
            if($LASTEXITCODE -ne 0 -or ($active -join ' ') -notmatch '[a-fA-F0-9]{8}-(?:[a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}'){throw 'No se pudo leer el plan de energia anterior.'}
            return [pscustomobject]@{Guid=$Matches[0]}
        }
        'Service' {
            $svc=Get-Service WlanSvc
            $key=Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\WlanSvc'
            $delayed=0; if($key.PSObject.Properties.Name -contains 'DelayedAutoStart'){$delayed=$key.DelayedAutoStart}
            return [pscustomobject]@{Start=[int]$key.Start;Running=($svc.Status -eq 'Running');Delayed=$delayed}
        }
        default {return $null}
    }
}
function Invoke-NexoAction($Action,$Step,$Request,[string]$Log) {
    $code=0
    switch($Action.Kind) {
        'Registry' {
            foreach($tuple in $Action.Keys) {
                $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey([string]$tuple[0])
                try{$key.SetValue([string]$tuple[1],[int]$tuple[2],[Microsoft.Win32.RegistryValueKind]::DWord)}finally{$key.Close()}
            }
        }
        'Power' {$code=Invoke-NexoNative "$env:SystemRoot\System32\powercfg.exe" @('/setactive',$Action.Guid) $Log}
        'Service' {Set-Service WlanSvc -StartupType Automatic; Start-Service WlanSvc}
        'Driver' {
            foreach($driver in $Step.Drivers){
                if((Get-FileHash -LiteralPath $driver.Path -Algorithm SHA256).Hash -ne $driver.Sha256){throw 'El INF cambio desde la revision.'}
                $c=Invoke-NexoNative "$env:SystemRoot\System32\pnputil.exe" @('/add-driver',$driver.Path,'/install') $Log
                if($c -ne 0){$code=$c}
            }
        }
        'Feature' {
            $args=@('/Online','/Enable-Feature','/FeatureName:NetFx3','/All','/NoRestart')
            if($Request.SxsFolder){$args+=@('/LimitAccess',('/Source:'+$Request.SxsFolder))}
            $code=Invoke-NexoNative "$env:SystemRoot\System32\dism.exe" $args $Log
        }
        'Compact' { $code=Invoke-NexoNative "$env:SystemRoot\System32\compact.exe" @('/compactos:always') $Log }
        'Optimize' { $code=Invoke-NexoNative "$env:SystemRoot\System32\defrag.exe" @($env:SystemDrive,'/O','/U') $Log }
        'Office' { $code=Install-NexoOffice $Request $Log }
        'Desktop' { $code=Install-NexoDesktop $Request.DesktopSettings $Log }
        'Menu' { $code=Install-NexoMenu }
        'GPU' { $code=Update-NexoGpu $Action.Vendor $Log }
        'Edition' { $code=Invoke-NexoEdition $Action.Target $Log }
        'Package' {
            $winget=Install-NexoWinget $Log
            $code=Invoke-NexoNative $winget @('install','--id',$Action.Package,'--exact','--source','winget','--silent','--accept-package-agreements','--accept-source-agreements','--disable-interactivity') $Log @(0,3010,1641,-1978335189)
            $null=Invoke-NexoNative $winget @('list','--id',$Action.Package,'--exact','--accept-source-agreements','--disable-interactivity') $Log @(0)
            if($code -eq -1978335189){$code=0}
        }
        'Appx' {
            $packages=@(foreach($name in @($Action.Appx)){Get-AppxPackage -Name $name})
            foreach($p in $packages){Remove-AppxPackage -Package $p.PackageFullName -ErrorAction Stop}
            if($packages.Count -eq 0){'Ya estaba ausente para este usuario.' | Out-File -LiteralPath $Log -Append -Encoding utf8;$code=10001}
        }
        default { throw ('Acción sin ejecutor: '+$Action.Kind) }
    }
    return $code
}
function Invoke-NexoPlan([string]$PlanPath,[string]$RunFolder) {
    if(-not(Test-NexoAdmin)){throw 'Se requieren permisos de administrador para aplicar.'}
    $saved=Read-NexoJson $PlanPath; $inventory=Get-NexoInventory
    if($saved.Computer -ne $inventory.Computer -or $saved.UserSid -ne $inventory.UserSid -or $saved.Build -ne $inventory.Build){throw 'El plan debe aplicarse en el mismo equipo, usuario y build que lo reviso. No uses credenciales de otra cuenta.'}
    $plan=New-NexoPlan $saved.Request $inventory
    if(@($plan.Steps | Where-Object Blocked).Count -gt 0){throw 'El plan contiene acciones bloqueadas. Vuelve a revisarlo.'}
    if(($plan.Steps.Id -join '|') -ne ($saved.Steps.Id -join '|')){throw 'Las acciones del plan no coinciden con la solicitud.'}
    foreach($step in $plan.Steps | Where-Object Kind -eq 'Driver') {
        $previous=@($saved.Steps | Where-Object Id -eq $step.Id)[0]
        if(($step.Drivers | ConvertTo-Json -Compress) -ne ($previous.Drivers | ConvertTo-Json -Compress)){throw 'Los paquetes de red cambiaron. Revisa un plan nuevo.'}
    }
    [IO.Directory]::CreateDirectory($RunFolder) | Out-Null
    $journal=[pscustomobject]@{Schema=1;Computer=$inventory.Computer;UserSid=$inventory.UserSid;Build=$inventory.Build;Version=$script:Version;State='Running';RestartRequired=$false;Entries=@()}
    $journalPath=Join-Path $RunFolder 'journal.json'
    Save-NexoJson $journal $journalPath
    $catalog=Get-NexoCatalog
    foreach($step in $plan.Steps) {
        if(Test-Path -LiteralPath (Join-Path $RunFolder 'stop.request')){$journal.State='Stopped';break}
        $a=@($catalog | Where-Object Id -eq $step.Id)[0]
        $entry=[pscustomobject]@{Id=$a.Id;Name=$a.Name;Kind=$a.Kind;Reversible=$a.Undo;State='Preparing';Backup=$null;Error='';UndoState='';UndoError=''}
        $journal.Entries+= $entry
        try {
            $entry.Backup=Get-NexoBackup $a
            $entry.State='Pending'
            Save-NexoJson $journal $journalPath
            $code=Invoke-NexoAction $a $step $plan.Request (Join-Path $RunFolder ($a.Id+'.log'))
            if($code -in @(3010,1641)){$journal.RestartRequired=$true}
            $entry.State=switch($code){10001{'Skipped'}10002{'NeedsInput'}default{'Completed'}}
            if($code -in @(10001,10002)){
                $actionLog=Join-Path $RunFolder ($a.Id+'.log')
                if(Test-Path -LiteralPath $actionLog){$entry.Error=[IO.File]::ReadAllText($actionLog)}
            }
        }catch{
            $entry.Error=$_.Exception.Message; $entry.State='Failed'; $journal.State='Failed'
            Save-NexoJson $journal $journalPath
            # Las acciones son independientes; registra el fallo y sigue con las restantes.
        }
        Save-NexoJson $journal $journalPath
    }
    if($journal.State -eq 'Running'){$journal.State='Completed'}
    if($journal.State -eq 'Completed' -and @($journal.Entries | Where-Object State -eq 'NeedsInput').Count){$journal.State='NeedsInput'}
    Save-NexoJson $journal $journalPath
    return $journal
}
function Restore-NexoRun([string]$JournalPath) {
    if(-not(Test-NexoAdmin)){throw 'Se requieren permisos de administrador para restaurar.'}
    $j=Read-NexoJson $JournalPath
    if($j.Schema -ne 1 -or $j.Computer -ne $env:COMPUTERNAME -or $j.UserSid -ne [Security.Principal.WindowsIdentity]::GetCurrent().User.Value){throw 'El registro no corresponde a este equipo y usuario.'}
    $entries=@($j.Entries); [array]::Reverse($entries)
    foreach($e in $entries) {
        if(-not $e.Reversible -or $null -eq $e.Backup -or $e.UndoState -eq 'Restored'){continue}
        $a=@(Get-NexoCatalog | Where-Object Id -eq $e.Id)
        if($a.Count -ne 1 -or $a[0].Kind -ne $e.Kind){throw 'Accion desconocida en el registro.'}
        try{
            switch($e.Kind){
                {$_ -in @('Registry','Menu')} {
                    $allowed=@($a[0].Keys | ForEach-Object {$_[0]+'|'+$_[1]})
                    foreach($b in $e.Backup){
                        if(($b.Path+'|'+$b.Name) -notin $allowed){throw 'Clave de restauracion no permitida.'}
                        $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($b.Path)
                        try{if($b.Exists){$key.SetValue($b.Name,$b.Value,[Enum]::Parse([Microsoft.Win32.RegistryValueKind],$b.Kind))}else{$key.DeleteValue($b.Name,$false)}}finally{$key.Close()}
                    }
                }
                'Power' {
                    if($e.Backup.Guid -notmatch '^[a-fA-F0-9]{8}-(?:[a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}$'){throw 'GUID no valido.'}
                    $null=Invoke-NexoNative "$env:SystemRoot\System32\powercfg.exe" @('/setactive',$e.Backup.Guid) (Join-Path (Split-Path $JournalPath) 'restore.log')
                }
                'Service' {
                    $types=@{2='Automatic';3='Manual';4='Disabled'}
                    if(-not $types.ContainsKey([int]$e.Backup.Start)){throw 'Tipo de inicio no valido.'}
                    if(-not $e.Backup.Running){Stop-Service WlanSvc -ErrorAction Stop}
                    Set-Service WlanSvc -StartupType $types[[int]$e.Backup.Start]
                    if($e.Backup.Start -eq 2 -and $e.Backup.Delayed -eq 1){$null=Invoke-NexoNative "$env:SystemRoot\System32\sc.exe" @('config','WlanSvc','start=','delayed-auto') (Join-Path (Split-Path $JournalPath) 'restore.log')}
                    if($e.Backup.Running){Start-Service WlanSvc}
                }
                default {throw 'Tipo no reversible.'}
            }
            $e.UndoState='Restored';$e.UndoError=''
        }catch{$e.UndoState='Failed';$e.UndoError=$_.Exception.Message}
        Save-NexoJson $j $JournalPath
    }
    $j.State='RestoredAdjustments'
    if(@($j.Entries | Where-Object UndoState -eq 'Failed').Count -gt 0){$j.State='RestoreFailed'}
    Save-NexoJson $j $JournalPath; return $j
}
Export-ModuleMember -Function *-Nexo*
