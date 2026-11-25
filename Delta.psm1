Set-StrictMode -Version 2
$ErrorActionPreference='Stop'
$script:DeltaRoot=$PSScriptRoot

function Get-NexoDeltaManifest([string]$BundleRoot=(Join-Path $script:DeltaRoot 'private-payloads\DELTA13')) {
    $file=Join-Path $BundleRoot 'manifest.json'
    if(!(Test-Path -LiteralPath $file -PathType Leaf)){throw 'El paquete DELTA no está incluido. Ejecuta Import-Delta.ps1 con tus archivos originales.'}
    $manifest=[IO.File]::ReadAllText($file) | ConvertFrom-Json
    if($manifest.Schema -ne 1 -or $manifest.Product -ne 'DELTA Pro 13'){throw 'Manifiesto DELTA no compatible.'}
    $expected=@{Setup='Setup.exe';Data='DELTA13.DTA'}
    if(@($manifest.Files).Count -ne 2){throw 'El paquete debe contener instalador y datos.'}
    foreach($role in $expected.Keys){
        $entries=@($manifest.Files | Where-Object Role -eq $role)
        if($entries.Count -ne 1){throw ('Entrada DELTA inválida: '+$role)}
        $entry=$entries[0]
        if($entry.Name -cne $expected[$role] -or $entry.SHA256 -notmatch '^[A-Fa-f0-9]{64}$' -or [long]$entry.Bytes -le 0){throw ('Archivo DELTA inválido: '+$role)}
    }
    return $manifest
}

function Test-NexoDeltaBundle([string]$BundleRoot=(Join-Path $script:DeltaRoot 'private-payloads\DELTA13'),[ValidateSet('All','Setup')][string]$Role='All') {
    $manifest=Get-NexoDeltaManifest $BundleRoot
    $roles=@('Setup','Data')
    foreach($entry in $manifest.Files | Where-Object {$_.Role -in $roles}){
        $path=Join-Path $BundleRoot $entry.Name
        if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw ('Falta '+$entry.Name+'. Vuelve a importar el paquete original.')}
        $item=Get-Item -LiteralPath $path
        if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'No se admiten enlaces en el paquete DELTA.'}
        if($item.Length -ne [long]$entry.Bytes -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $entry.SHA256){throw ($entry.Name+' cambió o está incompleto. No se ejecutará.')}
    }
    return $manifest
}

function Get-NexoDeltaStatePath {
    Join-Path $env:LOCALAPPDATA 'NexoAssistant\DELTA\installed.json'
}

function Get-NexoDeltaExecutable([string]$Path) {
    if(!$Path -or ![IO.Path]::IsPathRooted($Path) -or [IO.Path]::GetExtension($Path) -ine '.exe' -or !(Test-Path -LiteralPath $Path -PathType Leaf)){throw 'Selecciona el ejecutable de DELTA ya instalado.'}
    $file=Get-Item -LiteralPath $Path
    $info=$file.VersionInfo
    $identity=([string]$info.ProductName)+' '+([string]$info.FileDescription)
    if($identity -notmatch '(?i)DELTA' -or $identity -match '(?i)GenID|Generador|Installer|Instalador' -or $info.CompanyName -notmatch '(?i)DProjects|Daniel Rodriguez'){
        throw 'El archivo no se identifica como la aplicación DELTA de DProjects. Selecciona la aplicación DELTA instalada.'
    }
    [pscustomobject]@{Path=$file.FullName;SHA256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash;Product=$info.ProductName;Version=$info.FileVersion}
}

function Register-NexoDelta([string]$Path,[string]$StatePath=(Get-NexoDeltaStatePath)) {
    $app=Get-NexoDeltaExecutable $Path
    $state=[pscustomobject]@{Schema=1;Computer=$env:COMPUTERNAME;Path=$app.Path;SHA256=$app.SHA256;Product=$app.Product;Version=$app.Version}
    [IO.Directory]::CreateDirectory((Split-Path $StatePath))|Out-Null
    [IO.File]::WriteAllText($StatePath,($state|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
    return $state
}

function Get-NexoDeltaRegistered([string]$StatePath=(Get-NexoDeltaStatePath)) {
    if(!(Test-Path -LiteralPath $StatePath)){return $null}
    $state=[IO.File]::ReadAllText($StatePath)|ConvertFrom-Json
    if($state.Schema -ne 1 -or $state.Computer -ne $env:COMPUTERNAME){throw 'Localiza DELTA en este equipo para vincularlo a Nexo.'}
    $app=Get-NexoDeltaExecutable $state.Path
    if($app.SHA256 -ne $state.SHA256){throw 'DELTA cambió desde que se vinculó. Si lo actualizaste, vuelve a localizarlo.'}
    return $app
}

function Find-NexoDeltaInstalled {
    $candidates=New-Object 'Collections.Generic.List[string]'
    $shell=New-Object -ComObject WScript.Shell
    foreach($location in @('Programs','CommonPrograms','DesktopDirectory','CommonDesktopDirectory')){
        $folder=[Environment]::GetFolderPath($location)
        if($folder -and (Test-Path -LiteralPath $folder)){
            foreach($link in Get-ChildItem -LiteralPath $folder -Filter '*DELTA*.lnk' -File -Recurse -ErrorAction SilentlyContinue){
                try{$target=$shell.CreateShortcut($link.FullName).TargetPath;if($target){$candidates.Add($target)}}catch{}
            }
        }
    }
    $apps=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue
    foreach($app in $apps){
        if($app.PSObject.Properties.Name -contains 'DisplayName' -and $app.DisplayName -match '(?i)DELTA' -and $app.PSObject.Properties.Name -contains 'InstallLocation' -and $app.InstallLocation -and (Test-Path -LiteralPath $app.InstallLocation -PathType Container)){
            foreach($exe in Get-ChildItem -LiteralPath $app.InstallLocation -Filter '*.exe' -File -ErrorAction SilentlyContinue){$candidates.Add($exe.FullName)}
        }
    }
    foreach($path in $candidates | Select-Object -Unique){try{Get-NexoDeltaExecutable $path}catch{}}
}

function Start-NexoDeltaProcess([string]$Path) {
    $existing=@(Get-Process -Name ([IO.Path]::GetFileNameWithoutExtension($Path)) -ErrorAction SilentlyContinue | Where-Object {try{$_.Path -ieq $Path}catch{$false}})
    if($existing.Count){throw 'Este programa ya está abierto. Completa o cierra su ventana antes de volver a abrirlo.'}
    # El ejecutable original controla su elevación y su interfaz. Sin parámetros no documentados.
    Start-Process -FilePath $Path -WorkingDirectory (Split-Path $Path) -PassThru
}

function Invoke-NexoDelta([ValidateSet('Verify','Setup','Open','Locate','Detect')][string]$Action,[string]$BundleRoot=(Join-Path $script:DeltaRoot 'private-payloads\DELTA13'),[string]$SelectedPath,[string]$StatePath=(Get-NexoDeltaStatePath)) {
    if($Action -eq 'Verify'){
        $null=Test-NexoDeltaBundle $BundleRoot
        return [pscustomobject]@{State='Verified';Message='El instalador y los datos coinciden con el paquete importado.'}
    }
    if($Action -eq 'Locate'){
        $app=Register-NexoDelta $SelectedPath $StatePath
        return [pscustomobject]@{State='Located';Message=('DELTA vinculado: '+$app.Path)}
    }
    if($Action -eq 'Detect'){
        $found=@(Find-NexoDeltaInstalled)
        if($found.Count -eq 1){return Invoke-NexoDelta -Action Locate -SelectedPath $found[0].Path -StatePath $StatePath}
        return [pscustomobject]@{State='NeedsInput';Message='Usa Localizar DELTA y selecciona su ejecutable instalado.'}
    }
    if($Action -eq 'Setup'){
        $null=Test-NexoDeltaBundle $BundleRoot $Action
        $name='Setup.exe'
        $path=Join-Path $BundleRoot $name
    }else{
        $app=Get-NexoDeltaRegistered $StatePath
        if(!$app){throw 'Instala DELTA o usa Localizar DELTA antes de abrirlo.'}
        $path=$app.Path
    }
    $process=Start-NexoDeltaProcess $path
    if(!$process){throw 'Windows no devolvió un proceso para DELTA.'}
    # Abrir o cerrar un instalador no demuestra instalación, activación ni aplicación de ajustes.
    [pscustomobject]@{State='Started';ProcessId=$process.Id;Message=if($Action -eq 'Setup'){'Instalador original abierto. Completa sus pasos; después pulsa Buscar instalado.'}else{'DELTA abierto con su interfaz original. Selecciona y aplica allí sus módulos; Nexo no confirma sus resultados internos.'}}
}

Export-ModuleMember -Function *-NexoDelta*
