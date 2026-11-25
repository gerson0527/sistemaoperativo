# Se ejecuta como SYSTEM dentro de Windows Setup, no durante la construcción en el host.
$ErrorActionPreference='Stop'
$appRoot=Join-Path $env:SystemDrive 'NexoAssistant'
if(!(Test-Path -LiteralPath (Join-Path $appRoot 'FirstStart.ps1')) -or !(Test-Path -LiteralPath (Join-Path $appRoot 'iso-deployment.json'))){throw 'No es un despliegue de la ISO Nexo.'}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
if($identity.User.Value -ne 'S-1-5-18'){throw 'Este script solo se ejecuta como SYSTEM durante el despliegue.'}
$logRoot=Join-Path $env:ProgramData 'NexoAssistant\Setup'
[IO.Directory]::CreateDirectory($logRoot)|Out-Null
$log=Join-Path $logRoot 'setup.log'
function Write-SetupLog([string]$Message){Add-Content -LiteralPath $log -Encoding UTF8 -Value ((Get-Date).ToString('o')+' '+$Message)}
function Configure-NexoUserHive([string]$HiveName){
 $root=[Microsoft.Win32.Registry]::Users.OpenSubKey($HiveName,$true)
 if(!$root){throw ('No se pudo abrir el perfil '+$HiveName)}
 try{
  $run=$root.CreateSubKey('Software\Microsoft\Windows\CurrentVersion\RunOnce')
  try{
   # Sustituir únicamente el asistente de MiniOS; conservar los scripts NTLite del sistema.
   $run.DeleteValue('MTOOLKIT',$false)
   $command='"'+$env:SystemRoot+'\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $appRoot 'FirstStart.ps1')+'"'
   $run.SetValue('NexoAssistant',$command,[Microsoft.Win32.RegistryValueKind]::String)
  }finally{$run.Dispose()}
 }finally{$root.Dispose()}
 Write-SetupLog ('Perfil preparado: '+$HiveName)
}
function Configure-NexoProfile([string]$ProfilePath,[string]$Sid){
 if($Sid){
  $loaded=[Microsoft.Win32.Registry]::Users.OpenSubKey($Sid)
  if($loaded){$loaded.Dispose();Configure-NexoUserHive $Sid;return}
 }
 $hive=Join-Path $ProfilePath 'NTUSER.DAT'
 if(!(Test-Path -LiteralPath $hive)){return}
 $mount='NexoDeploy_'+[guid]::NewGuid().ToString('N')
 & "$env:SystemRoot\System32\reg.exe" load ('HKU\'+$mount) $hive >> $log 2>&1
 if($LASTEXITCODE -ne 0){throw ('No se pudo cargar el perfil '+$ProfilePath)}
 try{Configure-NexoUserHive $mount}
 finally{
  [GC]::Collect();[GC]::WaitForPendingFinalizers()
  & "$env:SystemRoot\System32\reg.exe" unload ('HKU\'+$mount) >> $log 2>&1
  if($LASTEXITCODE -ne 0){Write-SetupLog ('ERROR al descargar '+$mount)}
 }
}
try{
 Write-SetupLog 'Inicio de integración Nexo'
 $profiles='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
 $defaults=Get-ItemProperty -LiteralPath $profiles
 $defaultPath=[Environment]::ExpandEnvironmentVariables([string]$defaults.Default)
 Configure-NexoProfile $defaultPath ''
 foreach($key in Get-ChildItem -LiteralPath $profiles){
  if($key.PSChildName -match '^S-1-5-21-'){
   $info=Get-ItemProperty -LiteralPath $key.PSPath
   Configure-NexoProfile ([Environment]::ExpandEnvironmentVariables([string]$info.ProfileImagePath)) $key.PSChildName
  }
 }
 $shell=New-Object -ComObject WScript.Shell
 $desktop=[Environment]::GetFolderPath('CommonDesktopDirectory')
 $link=$shell.CreateShortcut((Join-Path $desktop 'Nexo Assistant.lnk'))
 $link.TargetPath=Join-Path $appRoot 'NexoAssistant.exe';$link.WorkingDirectory=$appRoot;$link.Save()
 $fallback=Join-Path $desktop 'Nexo Assistant.cmd'
 if(Test-Path -LiteralPath $fallback){Remove-Item -LiteralPath $fallback}
 [IO.File]::WriteAllText((Join-Path $logRoot 'completed.json'),([pscustomobject]@{CompletedUtc=[DateTime]::UtcNow.ToString('o');AppRoot=$appRoot;FirstLogon='NexoAssistant';ReplacedRunOnce='MTOOLKIT'}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
 Write-SetupLog 'Integración terminada'
}catch{Write-SetupLog ('ERROR '+$_.Exception.ToString());exit 1}
