param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
Import-Module (Join-Path (Split-Path $PSScriptRoot) 'Core.psm1') -Force
[IO.Directory]::CreateDirectory($OutputDirectory)|Out-Null
& (Get-Module Core) {
 param($dir)
 $script:testCount=0
 function Assert($ok,$text){if(-not $ok){throw "TEST FAILED: $text"};$script:testCount++;"PASS $text"}
 function Throws([scriptblock]$body,$text){$caught=$false;try{& $body|Out-Null}catch{$caught=$true};Assert $caught $text}
 function Request([string[]]$ids){[pscustomobject]@{Schema=1;Ids=$ids;DriverFolder='';SxsFolder=''}}
 $script:fake=[pscustomobject]@{Computer=$env:COMPUTERNAME;UserSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;Build=17763;X64=$true;Winget=$false;Laptop=$true}
 $p=New-NexoPlan (Request @('explorer.extensions')) $script:fake
 Assert ($p.Steps.Count -eq 1 -and -not $p.Steps[0].Blocked) 'Plan conservador en LTSC 1809'
 foreach($id in @('power.performance','network.drivers')){
  $p=New-NexoPlan (Request @($id)) $script:fake
  Assert ([bool]$p.Steps[0].Blocked) "Bloqueo correcto: $id"
 }
 $p=New-NexoPlan (Request @('app.vlc')) $script:fake
 Assert (-not $p.Steps[0].Blocked) 'WinGet se prepara antes de instalar'
 Throws {New-NexoPlan (Request @('unknown.command')) $script:fake} 'Accion desconocida'
 Throws {New-NexoPlan (Request @('theme.dark','theme.light')) $script:fake} 'Temas contradictorios'
 Throws {New-NexoPlan (Request @('power.balanced','power.performance')) $script:fake} 'Planes contradictorios'
 Throws {New-NexoPlan (Request @('theme.dark','theme.dark')) $script:fake} 'Duplicados'
 Throws {New-NexoPlan (Request @()) $script:fake} 'Plan vacio'
 $script:fake.Build=10240;$p=New-NexoPlan (Request @('explorer.extensions')) $script:fake
 Assert ([bool]$p.Steps[0].Blocked) 'Build antigua';$script:fake.Build=17763
 $driverDir=Join-Path $dir 'unsigned';[IO.Directory]::CreateDirectory($driverDir)|Out-Null
 "[Version]`r`nClass=Net`r`nCatalogFile=fake.cat" | Set-Content -LiteralPath (Join-Path $driverDir 'fake.inf')
 Throws {Get-NexoDriverFiles $driverDir} 'Driver sin catalogo firmado'

 # Unica escritura real de pruebas: clave temporal propia de HKCU, eliminada al salir.
 $regPath='Software\NexoAssistantTests\'+[guid]::NewGuid().ToString('N')
 $script:testAction=[pscustomobject]@{Id='test.registry';Kind='Registry';Undo=$true;Keys=@(@($regPath,'Existing',0),@($regPath,'Missing',1))}
 $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($regPath)
 $key.SetValue('Existing','original',[Microsoft.Win32.RegistryValueKind]::String);$key.Close()
 $originalCatalog=${function:Get-NexoCatalog}
 try {
  $backup=@(Get-NexoRegistryBackup $script:testAction)
  Assert ($backup.Count -eq 2 -and $backup[0].Kind -eq 'String' -and -not $backup[1].Exists) 'Backup conserva tipo y ausencia'
  $null=Invoke-NexoAction $script:testAction $null $null (Join-Path $dir 'registry.log')
  $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($regPath)
  Assert ($key.GetValue('Missing') -eq 1 -and $key.GetValue('Existing') -eq 0) 'Escritura limitada a valores seleccionados';$key.Close()
  function Test-NexoAdmin {return $true}
  function Get-NexoCatalog {return $script:testAction}
  $j=[pscustomobject]@{Schema=1;Computer=$script:fake.Computer;UserSid=$script:fake.UserSid;State='Completed';Entries=@([pscustomobject]@{Id='test.registry';Kind='Registry';Reversible=$true;Backup=$backup;UndoState='';UndoError=''})}
  $jp=Join-Path $dir 'registry-journal.json';Save-NexoJson $j $jp
  $restored=Restore-NexoRun $jp
  $key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($regPath)
  Assert ($key.GetValue('Existing') -eq 'original' -and $key.GetValueKind('Existing') -eq 'String' -and $key.GetValueNames() -notcontains 'Missing') 'Restauracion exacta de valores y tipos';$key.Close()
  Assert ($restored.Entries[0].UndoState -eq 'Restored') 'Diario de restauracion'
  $null=Restore-NexoRun $jp
  Assert ((Read-NexoJson $jp).Entries[0].UndoState -eq 'Restored') 'Restauracion idempotente'
 }finally{${function:Get-NexoCatalog}=$originalCatalog;[Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($regPath,$false)}

 # El resto de cambios se simula; se prueba el diario real en archivos temporales.
 function Get-NexoInventory {return $script:fake}
 function Get-NexoBackup($Action){return [pscustomobject]@{Marker='saved-before-write'}}
 $script:calls=@();$script:run=Join-Path $dir 'failure-run'
 function Invoke-NexoAction($Action,$Step,$Request,[string]$Log){
  $j=Read-NexoJson (Join-Path $script:run 'journal.json')
  if($j.Entries[-1].State -ne 'Pending' -or $j.Entries[-1].Backup.Marker -ne 'saved-before-write'){throw 'Backup no persistido'}
  $script:calls+=$Action.Id
  if($Action.Id -eq 'privacy.suggestions'){throw 'Fallo de prueba en segunda accion'}
  return 0
 }
 $p=New-NexoPlan (Request @('explorer.extensions','privacy.suggestions','gaming.capture')) $script:fake
 $pp=Join-Path $dir 'plan.json';Save-NexoJson $p $pp
 $j=Invoke-NexoPlan $pp $script:run
 Assert ($j.State -eq 'Failed' -and $j.Entries.Count -eq 3 -and $script:calls.Count -eq 3) 'Fallo se registra y continúa acciones independientes'
 Assert ($j.Entries[0].State -eq 'Completed' -and $j.Entries[1].State -eq 'Failed') 'Diario distingue exito y fallo parcial'
 Assert ($j.Entries[1].Backup.Marker -eq 'saved-before-write') 'Backup conservado tras fallo'
 $p.UserSid='other-user';Save-NexoJson $p $pp
 Throws {Invoke-NexoPlan $pp $script:run} 'Otro usuario rechazado'
 $p.UserSid=$script:fake.UserSid;$p.Steps[0].Id='theme.dark';Save-NexoJson $p $pp
 Throws {Invoke-NexoPlan $pp $script:run} 'Plan alterado rechazado'
 $script:run=Join-Path $dir 'stop-run';[IO.Directory]::CreateDirectory($script:run)|Out-Null
 [IO.File]::WriteAllText((Join-Path $script:run 'stop.request'),'stop')
 $p=New-NexoPlan (Request @('explorer.extensions')) $script:fake;Save-NexoJson $p $pp
 $j=Invoke-NexoPlan $pp $script:run
 Assert ($j.State -eq 'Stopped' -and $j.Entries.Count -eq 0) 'Parada evita iniciar otra accion'
 Save-NexoJson ([pscustomobject]@{Passed=$script:testCount;Failed=0;ActualWrites='Clave temporal HKCU propia, eliminada';OtherMutations='Simuladas';Timestamp=(Get-Date).ToString('o')}) (Join-Path $dir 'results.json')
 "TOTAL: $script:testCount pruebas superadas"
} $OutputDirectory
