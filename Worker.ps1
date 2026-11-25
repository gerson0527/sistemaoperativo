param([ValidateSet('Scan','Apply','Restore')][string]$Mode='Scan',[string]$InputPath,[Parameter(Mandatory=$true)][string]$OutputPath,[string]$RunFolder)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Core.psm1') -Force
$lock=$null; $held=$false
try {
    if($Mode -ne 'Scan'){
        $lock=New-Object Threading.Mutex($false,'Global\NexoAssistantMutation')
        try{$held=$lock.WaitOne(0)}catch [Threading.AbandonedMutexException]{$held=$true}
        if(-not $held){throw 'Ya hay otra operacion de Nexo aplicando cambios.'}
    }
    switch($Mode){
        'Scan' {$result=Get-NexoInventory}
        'Apply' {$result=Invoke-NexoPlan $InputPath $RunFolder}
        'Restore' {$result=Restore-NexoRun $InputPath}
    }
    Save-NexoJson ([pscustomobject]@{Ok=$true;Result=$result}) $OutputPath
}catch{
    Save-NexoJson ([pscustomobject]@{Ok=$false;Error=$_.Exception.Message}) $OutputPath
    exit 1
}finally{if($held){$lock.ReleaseMutex()};if($lock){$lock.Dispose()}}
