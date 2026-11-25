param([Parameter(Mandatory=$true)][string]$Destination,[switch]$IncludeDelta)
$ErrorActionPreference='Stop'
if(Test-Path -LiteralPath $Destination){throw 'Usa una carpeta de entrega nueva.'}
$required=@('NexoAssistant.exe','Nexo.ps1','Core.psm1','Extended.ps1','Features.ps1','DesktopPanel.ps1','CopyPath.ps1','Worker.ps1','Window.xaml','Engine.ps1','Engine.xaml','WizardCatalog.json','Delta.psm1','Delta.ps1','Delta.xaml','DeltaWorker.ps1','Import-Delta.ps1','Install-Portable.ps1','Prepare-Media.ps1','FirstStart.ps1','Nexo-Setup.ps1','Build-Iso.ps1','REFERENCIAS.md','LEEME.md','DELTA-Integracion.html')
foreach($file in $required){if(!(Test-Path -LiteralPath (Join-Path $PSScriptRoot $file))){throw ('Falta '+$file+'. Compila Nexo antes de empaquetar.')}}
if($IncludeDelta){Import-Module (Join-Path $PSScriptRoot 'Delta.psm1') -Force;$null=Test-NexoDeltaBundle}
[IO.Directory]::CreateDirectory($Destination)|Out-Null
foreach($file in $required){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $Destination}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'assets') -Destination $Destination -Recurse
if($IncludeDelta){
 $target=Join-Path $Destination 'private-payloads';[IO.Directory]::CreateDirectory($target)|Out-Null
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'private-payloads\DELTA13') -Destination $target -Recurse
 $null=Test-NexoDeltaBundle (Join-Path $target 'DELTA13')
}
$entries=@(foreach($file in Get-ChildItem -LiteralPath $Destination -File -Recurse){[pscustomobject]@{File=$file.FullName.Substring([IO.Path]::GetFullPath($Destination).TrimEnd('\').Length+1);Bytes=$file.Length;SHA256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}})
[IO.File]::WriteAllText((Join-Path $Destination 'package-sha256.json'),($entries|ConvertTo-Json -Depth 3),[Text.UTF8Encoding]::new($false))
Write-Output ('Entrega creada: '+[IO.Path]::GetFullPath($Destination))
