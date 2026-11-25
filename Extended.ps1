function Get-NexoExtendedCatalog {
    $packages = @(
        @('directx','DirectX','Microsoft.DirectX'),
        @('afterburner','MSI Afterburner','Guru3D.Afterburner'),
        @('fdm','Free Download Manager','SoftDeluxe.FreeDownloadManager'),
        @('chrome','Google Chrome','Google.Chrome'),
        @('opera','Opera','Opera.Opera'),
        @('brave','Brave','Brave.Brave'),
        @('aimp','AIMP','AIMP.AIMP'),
        @('potplayer','PotPlayer','Daum.PotPlayer'),
        @('klite','K-Lite Standard','CodecGuide.K-LiteCodecPack.Standard'),
        @('winrar','WinRAR','RARLab.WinRAR'),
        @('greenshot','Greenshot','Greenshot.Greenshot'),
        @('hwinfo','HWiNFO','REALiX.HWiNFO'),
        @('java8','Java 8','Oracle.JavaRuntimeEnvironment')
    )
    foreach ($p in $packages) {
        [pscustomobject]@{Id='app.'+$p[0];Group='Programas';Name=$p[1];Detail='Descarga e instala con WinGet. Si falta, Nexo prepara WinGet desde Microsoft. Requiere Internet y las condiciones del programa.';Kind='Package';Undo=$false;Package=$p[2]}
    }
    $apps = @(
        @('news','Noticias','Microsoft.BingNews'), @('feedback','Comentarios','Microsoft.WindowsFeedbackHub'),
        @('getstarted','Primeros Pasos','Microsoft.Getstarted'), @('camera','Cámara','Microsoft.WindowsCamera'),
        @('teams','Teams','MicrosoftTeams','MSTeams'), @('phone','Tu Teléfono','Microsoft.YourPhone'),
        @('help','Obtener Ayuda','Microsoft.GetHelp'), @('people','Contactos','Microsoft.People'),
        @('maps','Mapas','Microsoft.WindowsMaps'), @('skype','Skype','Microsoft.SkypeApp'),
        @('onenote','OneNote de Microsoft Store','Microsoft.Office.OneNote'),
        @('mail','Correo y Calendario','microsoft.windowscommunicationsapps'),
        @('designer','Designer','Microsoft.Designer'), @('music','Reproductor multimedia','Microsoft.ZuneMusic'),
        @('officehub','Office Hub','Microsoft.MicrosoftOfficeHub'), @('paint3d','Paint 3D','Microsoft.MSPaint'),
        @('mixedreality','Realidad Mixta','Microsoft.MixedReality.Portal'), @('todo','To Do','Microsoft.Todos'),
        @('movies','Películas y TV','Microsoft.ZuneVideo'), @('viewer3d','Visor 3D','Microsoft.Microsoft3DViewer')
    )
    foreach ($a in $apps) {
        [pscustomobject]@{Id='remove.'+$a[0];Group='Aplicaciones opcionales';Name='Quitar '+$a[1];Detail='Retira el paquete de Microsoft Store para el usuario actual. Reinstalación manual desde Store.';Kind='Appx';Undo=$false;Appx=@($a[2..($a.Count-1)])}
    }
    [pscustomobject]@{Id='system.compact';Group='Ajustes';Name='Compactar archivos de Windows';Detail='Ejecuta CompactOS para ahorrar espacio. Puede tardar y aumentar el uso de CPU al leer archivos. Reversión manual con compact /compactos:never.';Kind='Compact';Undo=$false}
    [pscustomobject]@{Id='disk.optimize';Group='Ajustes';Name='Optimizar unidad de Windows';Detail='Windows elige TRIM o desfragmentación según el dispositivo real mediante defrag /O.';Kind='Optimize';Undo=$false}
    [pscustomobject]@{Id='office.install';Group='Programas';Name='Office seleccionado (365 / Visio / Publisher 2021)';Detail='Instalador oficial de Microsoft en español y 64 bits. Necesita licencia del usuario. Conserva aplicaciones de Office existentes y bloquea cambios si ya hay Office instalado.';Kind='Office';Undo=$false}
}

function Resolve-NexoWinget {
    $command = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $package = Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($package) {
        $path = Join-Path $package.InstallLocation 'winget.exe'
        if (Test-Path -LiteralPath $path) { return $path }
    }
    return $null
}

function Install-NexoWinget([string]$Log) {
    $existing = Resolve-NexoWinget
    if ($existing) { return $existing }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $gallery = Get-PSRepository -Name PSGallery -ErrorAction Stop
    if ($gallery.SourceLocation.TrimEnd('/') -ne 'https://www.powershellgallery.com/api/v2') {
        throw 'La fuente PSGallery no corresponde al repositorio oficial.'
    }
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force -ErrorAction Stop | Out-Null
    Install-Module -Name Microsoft.WinGet.Client -Repository PSGallery -Scope CurrentUser -Force -ErrorAction Stop
    Import-Module Microsoft.WinGet.Client -ErrorAction Stop
    Repair-WinGetPackageManager -AllUsers -ErrorAction Stop | Out-File -LiteralPath $Log -Append -Encoding utf8
    $path = Resolve-NexoWinget
    if (!$path) { throw 'Microsoft no pudo preparar WinGet en este Windows. Consulta el registro de la acción.' }
    return $path
}

function New-NexoOfficeConfiguration([string[]]$Apps) {
    $allowed = @('Word','Excel','PowerPoint','Outlook','Access','OneNote','Visio','Publisher')
    if (!$Apps.Count -or @($Apps | Where-Object { $_ -notin $allowed }).Count) { throw 'Selecciona aplicaciones de Office admitidas.' }
    $xml = New-Object Xml.XmlDocument
    $root = $xml.CreateElement('Configuration'); $null = $xml.AppendChild($root)
    $add = $xml.CreateElement('Add'); $add.SetAttribute('OfficeClientEdition','64'); $add.SetAttribute('Channel','Current'); $null = $root.AppendChild($add)
    $products = @()
    if (@($Apps | Where-Object { $_ -notin @('Visio','Publisher') }).Count) { $products += 'O365ProPlusRetail' }
    if ('Visio' -in $Apps) { $products += 'VisioProRetail' }
    if ('Publisher' -in $Apps) { $products += 'Publisher2021Retail' }
    foreach ($id in $products) {
        $product = $xml.CreateElement('Product'); $product.SetAttribute('ID',$id); $null = $add.AppendChild($product)
        $language = $xml.CreateElement('Language'); $language.SetAttribute('ID','es-es'); $null = $product.AppendChild($language)
        if ($id -eq 'O365ProPlusRetail') {
            foreach ($app in @('Word','Excel','PowerPoint','Outlook','Access','OneNote','Publisher','Groove','Lync','OneDrive','Teams','OutlookForWindows')) {
                if ($app -notin $Apps -or $app -eq 'Publisher') { $exclude=$xml.CreateElement('ExcludeApp'); $exclude.SetAttribute('ID',$app); $null=$product.AppendChild($exclude) }
            }
        }
    }
    $display=$xml.CreateElement('Display'); $display.SetAttribute('Level','Full'); $display.SetAttribute('AcceptEULA','FALSE'); $null=$root.AppendChild($display)
    return $xml
}

function Install-NexoOffice($Request,[string]$Log) {
    $xml = New-NexoOfficeConfiguration @($Request.OfficeApps)
    $folder = Join-Path (Split-Path $Log) 'office'
    [IO.Directory]::CreateDirectory($folder) | Out-Null
    $installer = Join-Path $folder 'odt.exe'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri 'https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_20527-20150.exe' -OutFile $installer
    if ((Get-FileHash -LiteralPath $installer).Hash -ne '28BC762075C758B5EF841FE94487565168DEEED59F78DED5D5DFDFB08A9E827A') { throw 'El instalador de Office no coincide con la descarga verificada.' }
    if ((Get-AuthenticodeSignature -LiteralPath $installer).Status -ne 'Valid') { throw 'Firma del instalador de Office inválida.' }
    $null = Invoke-NexoNative $installer @('/quiet',('/extract:'+$folder)) $Log
    $config = Join-Path $folder 'configuration.xml'; $xml.Save($config)
    return Invoke-NexoNative (Join-Path $folder 'setup.exe') @('/configure',$config) $Log
}
