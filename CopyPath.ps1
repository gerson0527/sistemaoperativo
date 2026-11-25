param([Parameter(Mandatory=$true)][string]$Path)
$ErrorActionPreference='Stop'
Set-Clipboard -Value $Path
