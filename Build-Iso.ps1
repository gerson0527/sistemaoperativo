param([Parameter(Mandatory=$true)][string]$SourceIso,[Parameter(Mandatory=$true)][string]$WorkDirectory,[Parameter(Mandatory=$true)][string]$OutputIso,[Parameter(Mandatory=$true)][string]$SevenZipPath,[Parameter(Mandatory=$true)][string]$OscdimgPath)
$ErrorActionPreference='Stop'
if(Test-Path -LiteralPath $WorkDirectory){throw 'Selecciona una carpeta de trabajo nueva.'}
if(Test-Path -LiteralPath $OutputIso){throw 'La ISO de destino ya existe; no se sobrescribe.'}
foreach($path in @($SourceIso,$SevenZipPath,$OscdimgPath)){if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw ('No existe '+$path)}}
$baseHash=(Get-FileHash -LiteralPath $SourceIso -Algorithm SHA256).Hash
if($baseHash -ne '16A4272BCE4DD616C2EE48C92EB4E64C5A740C7565AF5EDE47AFAB6FB1A01AAB'){throw 'Esta integración se ha preparado para la ISO MiniOS11 analizada. La ISO seleccionada es diferente.'}
[IO.Directory]::CreateDirectory($WorkDirectory)|Out-Null
$media=Join-Path $WorkDirectory 'media'
& $SevenZipPath x '-y' ('-o'+$media) $SourceIso | Out-File -LiteralPath (Join-Path $WorkDirectory 'extraction.log') -Encoding UTF8
if($LASTEXITCODE -ne 0){throw 'Falló la extracción de la ISO base.'}
& (Join-Path $PSScriptRoot 'Prepare-Media.ps1') -MediaRoot $media -FirstLogonNexo
$bios=Join-Path $media 'boot\etfsboot.com';$efi=Join-Path $media 'efi\microsoft\boot\efisys.bin'
foreach($path in @($bios,$efi)){if(!(Test-Path -LiteralPath $path)){throw 'Falta un archivo de arranque BIOS/UEFI.'}}
[IO.Directory]::CreateDirectory((Split-Path ([IO.Path]::GetFullPath($OutputIso))))|Out-Null
$boot='-bootdata:2#p0,e,b'+$bios+'#pEF,e,b'+$efi
$arguments=(@('-m','-o','-u2','-udfver102','-lNEXO_OS',$boot,$media,$OutputIso)|ForEach-Object {'"'+$_+'"'}) -join ' '
$process=Start-Process -FilePath $OscdimgPath -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $WorkDirectory 'oscdimg.log') -RedirectStandardError (Join-Path $WorkDirectory 'oscdimg-progress.log')
if($process.ExitCode -ne 0 -or !(Test-Path -LiteralPath $OutputIso)){throw 'Falló la construcción de la ISO.'}
$result=[pscustomobject]@{Name='Nexo OS - base MiniOS11';BuiltUtc=[DateTime]::UtcNow.ToString('o');Source=$SourceIso;SourceSHA256=$baseHash;Iso=$OutputIso;Bytes=(Get-Item -LiteralPath $OutputIso).Length;SHA256=(Get-FileHash -LiteralPath $OutputIso -Algorithm SHA256).Hash;Boot=@('BIOS','UEFI');FirstLogon='Nexo Assistant';Delta='Original, sin GenID; conserva sus requisitos propios';WindowsImage='Imagen MiniOS original, sin modificación de install.esd';DiskSelection='Interactiva; la ISO no borra ni particiona automáticamente';TestedBoot=$false;TestedInstall=$false}
[IO.File]::WriteAllText(($OutputIso+'.json'),($result|ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText(($OutputIso+'.sha256'),($result.SHA256+'  '+[IO.Path]::GetFileName($OutputIso)+[Environment]::NewLine),[Text.Encoding]::ASCII)
$result
