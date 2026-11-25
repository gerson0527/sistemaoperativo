function Get-NexoFeatureCatalog {
    [pscustomobject]@{Id='desktop.custom';Group='Apariencia';Name='Personalización Nexo';Kind='Desktop';Undo=$false;Detail='Aplica un fondo original, iconos de Este equipo/Papelera, transparencia de Windows y paneles Nexo de widgets, lanzador y dock. Los paneles elegidos disponen de acceso en el escritorio y se abren al iniciar sesión.'}
    $menuKeys=@(foreach($entry in Get-NexoMenuActions){,@(('Software\Classes\*\shell\'+$entry[0]),'',$entry[1]);,@(('Software\Classes\*\shell\'+$entry[0]+'\command'),'',$entry[2])})
    [pscustomobject]@{Id='menu.extended';Group='Ajustes';Name='Menú de herramientas Nexo';Kind='Menu';Undo=$true;Keys=$menuKeys;Detail='Agrega Abrir con Bloc de notas y Copiar ruta al menú contextual de archivos. En Windows 11 aparecen en Mostrar más opciones.'}
    foreach($vendor in @('INTEL','NVIDIA','AMD')){
        [pscustomobject]@{Id='gpu.'+$vendor.ToLower();Group='Red';Name='Controlador gráfico '+$vendor;Kind='GPU';Undo=$false;Vendor=$vendor;Detail='Busca controladores Display compatibles en Windows Update para el fabricante y hardware detectados. Requiere Internet. Puede pedir reinicio.'}
    }
    foreach($edition in @('Professional','Enterprise','Workstation')){
        $target=if($edition -eq 'Workstation'){'ProfessionalWorkstation'}else{$edition}
        [pscustomobject]@{Id='edition.'+$edition.ToLower();Group='Ajustes';Name='Cambio de edición a '+$edition;Kind='Edition';Undo=$false;Target=$target;Detail='Comprueba la edición actual y los destinos admitidos por Windows. Solicita una clave propia mediante el diálogo de Windows. Puede requerir reinicio y una licencia de la edición destino.'}
    }
}

function Test-NexoDesktopRequest($Settings) {
    if(!$Settings){throw 'Falta la selección de personalización.'}
    $catalog=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'WizardCatalog.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach($property in $catalog.combos.PSObject.Properties){
        if($Settings.PSObject.Properties.Name -notcontains $property.Name -or $Settings.($property.Name) -notin @($property.Value)){throw ('Selección visual desconocida: '+$property.Name)}
    }
    foreach($flag in @('MenuTranslucent','ExplorerTranslucent')){
        if($Settings.PSObject.Properties.Name -notcontains $flag -or $Settings.$flag -isnot [bool]){throw 'La selección de transparencia no es válida.'}
    }
}

function Initialize-NexoDesktopApi {
    if('NexoDesktopNative' -as [type]){return}
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class NexoDesktopNative {
 [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
 public static extern bool SystemParametersInfo(int action, int value, string path, int flags);
 [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr icon);
 [DllImport("shell32.dll")] public static extern void SHChangeNotify(uint eventId, uint flags, IntPtr item1, IntPtr item2);
}
'@
}

function New-NexoWallpaper([string]$Choice,[string]$Path) {
    Add-Type -AssemblyName System.Drawing
    $colors=switch($Choice){
        'Wallpaper Hojas'{@('#0C3029','#5C9870')}
        'Wallpaper Neon'{@('#110A32','#B8329E')}
        'Wallpaper Ice'{@('#152E50','#74C5DB')}
        default{@('#101B2B','#265E9E')}
    }
    $bitmap=New-Object Drawing.Bitmap(1920,1080);$graphics=[Drawing.Graphics]::FromImage($bitmap)
    $brush=New-Object Drawing.Drawing2D.LinearGradientBrush([Drawing.Rectangle]::new(0,0,1920,1080),[Drawing.ColorTranslator]::FromHtml($colors[0]),[Drawing.ColorTranslator]::FromHtml($colors[1]),35)
    $pen=New-Object Drawing.Pen([Drawing.Color]::FromArgb(45,255,255,255),2)
    try{
        $graphics.FillRectangle($brush,0,0,1920,1080)
        foreach($radius in @(220,340,460,580)){$graphics.DrawEllipse($pen,1250-$radius,540-$radius,2*$radius,2*$radius)}
        $bitmap.Save($Path,[Drawing.Imaging.ImageFormat]::Bmp)
    }finally{$pen.Dispose();$brush.Dispose();$graphics.Dispose();$bitmap.Dispose()}
}

function New-NexoIcon([string]$Choice,[string]$Letter,[string]$Path) {
    Add-Type -AssemblyName System.Drawing;Initialize-NexoDesktopApi
    $color=switch($Choice){'Icons Vivid'{'#8C48DB'}'Icons Numix'{'#D45A44'}default{'#2586D6'}}
    $bitmap=New-Object Drawing.Bitmap(64,64);$graphics=[Drawing.Graphics]::FromImage($bitmap)
    $brush=New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml($color));$font=New-Object Drawing.Font('Segoe UI',28,[Drawing.FontStyle]::Bold)
    $handle=[IntPtr]::Zero;$stream=$null
    try{
        $graphics.Clear([Drawing.Color]::Transparent);$graphics.FillEllipse($brush,2,2,60,60);$graphics.DrawString($Letter,$font,[Drawing.Brushes]::White,12,8)
        $handle=$bitmap.GetHicon();$icon=[Drawing.Icon]::FromHandle($handle);$stream=[IO.File]::Create($Path);$icon.Save($stream)
    }finally{if($stream){$stream.Dispose()};if($handle -ne [IntPtr]::Zero){$null=[NexoDesktopNative]::DestroyIcon($handle)};$font.Dispose();$brush.Dispose();$graphics.Dispose();$bitmap.Dispose()}
}

function Install-NexoDesktop($Settings,[string]$Log) {
    Test-NexoDesktopRequest $Settings;Initialize-NexoDesktopApi
    $folder=Join-Path $env:LOCALAPPDATA 'NexoAssistant\Desktop';[IO.Directory]::CreateDirectory($folder)|Out-Null
    $snapshot=Join-Path $folder 'original.json'
    $iconSnapshot=Join-Path $folder 'original-icons.json'
    if(!(Test-Path -LiteralPath $iconSnapshot)){
        $keys=@(foreach($clsid in @('{20D04FE0-3AEA-1069-A2D8-08002B30309D}','{645FF040-5081-101B-9F08-00AA002F954E}')){foreach($name in @('','empty','full')){,@(('Software\Microsoft\Windows\CurrentVersion\Explorer\CLSID\'+$clsid+'\DefaultIcon'),$name,0)}})
        Save-NexoJson @(Get-NexoRegistryBackup ([pscustomobject]@{Keys=$keys})) $iconSnapshot
    }
    $originalIcons=@(Read-NexoJson $iconSnapshot)
    if(!(Test-Path -LiteralPath $snapshot)){
        $wall=(Get-ItemProperty 'HKCU:\Control Panel\Desktop' -Name Wallpaper).Wallpaper
        Save-NexoJson ([pscustomobject]@{Wallpaper=$wall}) $snapshot
    }
    $wallpaper=(Read-NexoJson $snapshot).Wallpaper
    if($Settings.Wallpaper -ne 'Default'){$wallpaper=Join-Path $folder 'wallpaper.bmp';New-NexoWallpaper $Settings.Wallpaper $wallpaper}
    if($wallpaper -and !(Test-Path -LiteralPath $wallpaper)){throw 'El fondo original ya no está disponible.'}
    if(![NexoDesktopNative]::SystemParametersInfo(20,0,$wallpaper,3)){throw 'Windows no pudo aplicar el fondo.'}
    $transparency=[int]($Settings.MenuTranslucent -or $Settings.ExplorerTranslucent)
    $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize')
    try{$key.SetValue('EnableTransparency',$transparency,[Microsoft.Win32.RegistryValueKind]::DWord)}finally{$key.Dispose()}
    foreach($entry in @(@('{20D04FE0-3AEA-1069-A2D8-08002B30309D}','PC'),@('{645FF040-5081-101B-9F08-00AA002F954E}','R'))){
        $path='Software\Microsoft\Windows\CurrentVersion\Explorer\CLSID\'+$entry[0]+'\DefaultIcon'
        $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($path)
        try{
            if($Settings.Icons -eq 'Default'){
                foreach($name in @('','empty','full')){
                    $before=@($originalIcons | Where-Object {$_.Path -eq $path -and $_.Name -eq $name})
                    if($before.Count -ne 1){throw 'La copia de iconos no es válida.'}
                    if($before[0].Exists){$key.SetValue($name,$before[0].Value,[Enum]::Parse([Microsoft.Win32.RegistryValueKind],$before[0].Kind))}else{$key.DeleteValue($name,$false)}
                }
            }else{
                $iconPath=Join-Path $folder ($entry[1]+'.ico');New-NexoIcon $Settings.Icons $entry[1] $iconPath
                $key.SetValue('',$iconPath,[Microsoft.Win32.RegistryValueKind]::String)
                if($entry[1] -eq 'R'){foreach($name in @('empty','full')){$key.SetValue($name,$iconPath,[Microsoft.Win32.RegistryValueKind]::String)}}
            }
        }finally{$key.Dispose()}
    }
    [NexoDesktopNative]::SHChangeNotify(0x08000000,0,[IntPtr]::Zero,[IntPtr]::Zero)
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'DesktopPanel.ps1') -Destination $folder -Force
    $shell=New-Object -ComObject WScript.Shell
    foreach($item in @(@('Widget','Rainmeter','Ninguno'),@('Menu','StartMenu','Default'),@('Dock','Dock','Default'))){
        $mode=$item[0];$style=$Settings.($item[1]);$enabled=$style -ne $item[2]
        foreach($location in @('Desktop','Startup')){
            $link=Join-Path ([Environment]::GetFolderPath($location)) ('Nexo '+$mode+'.lnk')
            if(!$enabled){if(Test-Path -LiteralPath $link){Remove-Item -LiteralPath $link};continue}
            $shortcut=$shell.CreateShortcut($link);$shortcut.TargetPath="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
            $shortcut.Arguments='-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $folder 'DesktopPanel.ps1')+'" -Mode '+$mode+' -Style "'+$style+'"'
            $shortcut.WorkingDirectory=$folder;$shortcut.WindowStyle=7;$shortcut.Save()
        }
    }
    Save-NexoJson $Settings (Join-Path $folder 'selection.json')
    'Personalización aplicada. Los paneles elegidos tienen acceso en el escritorio y se abren al iniciar sesión.' | Out-File -LiteralPath $Log -Append -Encoding utf8
    return 0
}

function Get-NexoMenuActions {
    @(
        @('NexoNotepad','Abrir con Bloc de notas',('"'+$env:SystemRoot+'\System32\notepad.exe" "%1"')),
        @('NexoCopyPath','Copiar ruta',('"'+$env:SystemRoot+'\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $env:LOCALAPPDATA 'NexoAssistant\Tools\CopyPath.ps1')+'" -Path "%1"'))
    )
}

function Install-NexoMenu {
    $folder=Join-Path $env:LOCALAPPDATA 'NexoAssistant\Tools';[IO.Directory]::CreateDirectory($folder)|Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'CopyPath.ps1') -Destination $folder -Force
    foreach($entry in Get-NexoMenuActions){
        $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Classes\*\shell\'+$entry[0])
        try{$key.SetValue('',$entry[1]);$command=$key.CreateSubKey('command');try{$command.SetValue('',$entry[2])}finally{$command.Dispose()}}finally{$key.Dispose()}
    }
    return 0
}

function Update-NexoGpu([string]$Vendor,[string]$Log) {
    $vendorId=@{INTEL='8086';NVIDIA='10DE';AMD='1002'}[$Vendor]
    $devices=@(Get-CimInstance Win32_VideoController | Where-Object PNPDeviceID -Match ('VEN_'+$vendorId))
    if(!$devices.Count){'El equipo no presenta una GPU '+$Vendor+'.' | Out-File $Log -Append -Encoding utf8;return 10001}
    $session=New-Object -ComObject Microsoft.Update.Session;$session.ClientApplicationID='Nexo Assistant'
    $search=$session.CreateUpdateSearcher().Search("IsInstalled=0 and IsHidden=0 and Type='Driver'")
    $updates=New-Object -ComObject Microsoft.Update.UpdateColl
    foreach($update in $search.Updates){
        if($update.DriverClass -eq 'Display' -and $update.DriverHardwareID -match ('VEN_'+$vendorId)){
            if(!$update.EulaAccepted){throw 'El controlador requiere aceptar sus términos en Windows Update.'}
            $null=$updates.Add($update)
        }
    }
    if(!$updates.Count){'Windows Update no ofrece un controlador gráfico más reciente compatible.' | Out-File $Log -Append -Encoding utf8;return 10001}
    $download=$session.CreateUpdateDownloader();$download.Updates=$updates;$result=$download.Download()
    if($result.ResultCode -ne 2){throw 'Falló la descarga de los controladores. Revisa Windows Update.'}
    $installer=$session.CreateUpdateInstaller();$installer.Updates=$updates;$result=$installer.Install()
    if($result.ResultCode -ne 2){throw 'Windows Update no pudo instalar todos los controladores.'}
    if($result.RebootRequired){return 3010};return 0
}

function Invoke-NexoEdition([string]$Target,[string]$Log) {
    $current=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
    if($current -eq $Target){'La edición solicitada ya está instalada.' | Out-File $Log -Append -Encoding utf8;return 10001}
    $targets=@(Get-WindowsEdition -Online -Target -ErrorAction Stop | Select-Object -ExpandProperty Edition)
    if($Target -notin $targets){('Windows no permite cambiar '+$current+' a '+$Target+' desde esta instalación.') | Out-File $Log -Append -Encoding utf8;return 10002}
    $message='Destino solicitado: '+$Target+'. Introduce tu clave en el diálogo de Windows. Windows puede pedir reiniciar para completar el cambio.'
    $message | Out-File $Log -Append -Encoding utf8
    Start-Process -FilePath "$env:SystemRoot\System32\changepk.exe" -ErrorAction Stop | Out-Null
    return 10002
}
