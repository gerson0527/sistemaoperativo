param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
Import-Module (Join-Path (Split-Path $PSScriptRoot) 'Delta.psm1') -Force
if(Test-Path -LiteralPath $OutputDirectory){throw 'Usa una carpeta de pruebas nueva.'}
[IO.Directory]::CreateDirectory($OutputDirectory)|Out-Null
& (Get-Module Delta) {
 param($folder)
 $script:checks=0
 function Assert($value,$message){if(!$value){throw ('FAIL '+$message)};$script:checks++;Write-Output ('PASS '+$message)}
 function Reject([scriptblock]$code,[string]$message){$caught=$false;try{& $code|Out-Null}catch{$caught=$true};Assert $caught $message}
 $entries=@(foreach($pair in @(@('Setup','Setup.exe'),@('Data','DELTA13.DTA'))){
  $file=Join-Path $folder $pair[1];[IO.File]::WriteAllText($file,('fixture-'+$pair[0]))
  [pscustomobject]@{Role=$pair[0];Name=$pair[1];Bytes=(Get-Item $file).Length;SHA256=(Get-FileHash $file).Hash}
 })
 $manifest=[pscustomobject]@{Schema=1;Product='DELTA Pro 13';Files=$entries}
 $manifestFile=Join-Path $folder 'manifest.json'
 function Write-Manifest {[IO.File]::WriteAllText($manifestFile,($manifest|ConvertTo-Json -Depth 5))}
 Write-Manifest
 Assert ((Test-NexoDeltaBundle $folder).Files.Count -eq 2) 'Acepta paquete íntegro'
 $data=Join-Path $folder 'DELTA13.DTA';[IO.File]::WriteAllText($data,'fixture-FAIL')
 Reject {Test-NexoDeltaBundle $folder 'Setup'} 'Bloquea instalación con datos modificados'
 Reject {Test-NexoDeltaBundle $folder 'GenId'} 'GenID ya no es un rol admitido'
 [IO.File]::WriteAllText($data,'fixture-Data')
 $manifest.Files[0].Name='..\Setup.exe';Write-Manifest
 Reject {Test-NexoDeltaBundle $folder} 'Rechaza rutas fuera del paquete'
 $manifest.Files[0].Name='Setup.exe';$manifest.Files[0].Role='Data';Write-Manifest
 Reject {Test-NexoDeltaBundle $folder} 'Rechaza roles duplicados'
 $manifest.Files[0].Role='Setup';Write-Manifest
 $script:launches=@()
 function Start-NexoDeltaProcess([string]$Path){$script:launches+=,$Path;[pscustomobject]@{Id=1234}}
 $result=Invoke-NexoDelta -Action Setup -BundleRoot $folder
 Assert ($result.State -eq 'Started' -and $result.ProcessId -eq 1234 -and $script:launches[0] -eq (Join-Path $folder 'Setup.exe')) 'Abre el instalador exacto sin afirmar que se instaló'
 Reject {Invoke-NexoDelta -Action GenId -BundleRoot $folder} 'No existe una acción para abrir GenID'
 $count=$script:launches.Count
 $null=Invoke-NexoDelta -Action Verify -BundleRoot $folder
 Assert ($script:launches.Count -eq $count) 'Verificar no ejecuta programas'
 Reject {Invoke-NexoDelta -Action Open -StatePath (Join-Path $folder 'missing.json')} 'No abre DELTA sin vincular instalación'
 $script:fakeHash=('A'*64)
 function Get-NexoDeltaExecutable([string]$Path){[pscustomobject]@{Path=$Path;SHA256=$script:fakeHash;Product='DELTA Pro';Version='13'}}
 $statePath=Join-Path $folder 'installed.json';$null=Register-NexoDelta 'C:\DELTA\DELTA.exe' $statePath
 Assert ((Get-NexoDeltaRegistered $statePath).Path -eq 'C:\DELTA\DELTA.exe') 'Vincula instalación y verifica hash'
 $script:fakeHash=('B'*64)
 Reject {Get-NexoDeltaRegistered $statePath} 'Rechaza ejecutable cambiado desde su vinculación'
 $state=[IO.File]::ReadAllText($statePath)|ConvertFrom-Json;$state.Computer='OTRO-EQUIPO';[IO.File]::WriteAllText($statePath,($state|ConvertTo-Json))
 Reject {Get-NexoDeltaRegistered $statePath} 'No reutiliza vínculo de otro equipo'
 [pscustomobject]@{Passed=$script:checks;Failed=0;RealProgramsExecuted=$false}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $folder 'results.json') -Encoding UTF8
} $OutputDirectory
