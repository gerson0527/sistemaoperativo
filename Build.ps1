$ErrorActionPreference='Stop'
$compiler=Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(-not(Test-Path -LiteralPath $compiler)){throw 'Se requiere el compilador .NET Framework x64 de Windows.'}
& $compiler /nologo /target:winexe /platform:x64 /optimize+ (('/out:')+(Join-Path $PSScriptRoot 'NexoAssistant.exe')) (('/win32manifest:')+(Join-Path $PSScriptRoot 'app.manifest')) /reference:System.Windows.Forms.dll (Join-Path $PSScriptRoot 'Launcher.cs')
if($LASTEXITCODE -ne 0){throw 'Fallo la compilacion.'}
'NexoAssistant.exe compilado.'
