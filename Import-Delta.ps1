param([Parameter(Mandatory=$true)][string]$SourceFolder,[string]$Destination)
$ErrorActionPreference='Stop'
if(!$Destination){$Destination=Join-Path $PSScriptRoot 'private-payloads\DELTA13'}
Import-Module (Join-Path $PSScriptRoot 'Delta.psm1') -Force
if(Test-Path -LiteralPath $Destination){throw 'El destino ya existe. Usa una carpeta nueva para conservar la copia anterior.'}
$source=(Resolve-Path -LiteralPath $SourceFolder).Path
$items=@(@('Setup','Setup.exe',(Join-Path $source 'Setup.exe')),@('Data','DELTA13.DTA',(Join-Path $source 'DELTA13.DTA')))
$files=@(foreach($item in $items){
 $file=Get-Item -LiteralPath $item[2]
 if($file.PSIsContainer -or $file.Length -le 0){throw ('Archivo inválido: '+$item[1])}
 [pscustomobject]@{Role=$item[0];Name=$item[1];Bytes=$file.Length;SHA256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}
})
$stage=[IO.Path]::GetFullPath($Destination)+'.import-'+[guid]::NewGuid().ToString('N')
[IO.Directory]::CreateDirectory($stage)|Out-Null
foreach($item in $items){Copy-Item -LiteralPath $item[2] -Destination (Join-Path $stage $item[1])}
$manifest=[pscustomobject]@{Schema=1;Product='DELTA Pro 13';Publisher='DProjects';ImportedUtc=[DateTime]::UtcNow.ToString('o');License='Licencia del usuario vinculada al equipo. No se incluyen claves ni activaciones.';Files=$files}
[IO.File]::WriteAllText((Join-Path $stage 'manifest.json'),($manifest|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
$null=Test-NexoDeltaBundle $stage
Move-Item -LiteralPath $stage -Destination $Destination
Write-Output ('Paquete DELTA importado y verificado: '+[IO.Path]::GetFullPath($Destination))
