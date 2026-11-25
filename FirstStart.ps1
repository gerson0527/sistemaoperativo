$ErrorActionPreference='Stop'
$stateRoot=Join-Path $env:LOCALAPPDATA 'NexoAssistant'
[IO.Directory]::CreateDirectory($stateRoot)|Out-Null
$marker=Join-Path $stateRoot 'first-start.json'
if(Test-Path -LiteralPath $marker){exit 0}
try{
 $launcher=Join-Path $PSScriptRoot 'NexoAssistant.exe'
 if(!(Test-Path -LiteralPath $launcher)){throw 'No se encontró NexoAssistant.exe.'}
 $wallpaper=Join-Path $PSScriptRoot 'assets\Nexo-Wallpaper.bmp'
 if(Test-Path -LiteralPath $wallpaper){
  Add-Type 'using System; using System.Runtime.InteropServices; public class NexoFirstDesktop { [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern bool SystemParametersInfo(int action,int value,string path,int flags); }'
  $null=[NexoFirstDesktop]::SystemParametersInfo(20,0,$wallpaper,3)
 }
 $process=Start-Process -FilePath $launcher -WorkingDirectory $PSScriptRoot -PassThru
 [IO.File]::WriteAllText($marker,([pscustomobject]@{StartedUtc=[DateTime]::UtcNow.ToString('o');ProcessId=$process.Id}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
}catch{
 [IO.File]::WriteAllText((Join-Path $stateRoot 'first-start-error.txt'),$_.Exception.ToString())
 exit 1
}
