param([Parameter(Mandatory=$true)][ValidateSet('Verify','Setup','Open','Locate','Detect')][string]$Action,[Parameter(Mandatory=$true)][string]$OutputPath,[string]$SelectedPath)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Delta.psm1') -Force
try{$result=[pscustomobject]@{Ok=$true;Result=(Invoke-NexoDelta -Action $Action -SelectedPath $SelectedPath)}}
catch{$result=[pscustomobject]@{Ok=$false;Error=$_.Exception.Message}}
[IO.Directory]::CreateDirectory((Split-Path $OutputPath))|Out-Null
[IO.File]::WriteAllText($OutputPath,($result|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
if(!$result.Ok){exit 1}
