$ErrorActionPreference = 'Stop'
Import-Module (Join-Path (Split-Path $PSScriptRoot) 'Core.psm1') -Force
function Assert($Value, [string]$Message) { if (!$Value) { throw $Message }; "PASS $Message" }
$catalog = @(Get-NexoCatalog)
Assert (($catalog.Id | Select-Object -Unique).Count -eq $catalog.Count) 'Identificadores únicos'
$wizard = Get-Content (Join-Path (Split-Path $PSScriptRoot) 'WizardCatalog.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($check in $wizard.checks | Where-Object action) {
    Assert (@($catalog | Where-Object Id -eq $check.action).Count -eq 1) ('Selección válida '+$check.label)
}
Assert (@($wizard.checks | Where-Object { $_.group -eq 'Debloat' -and !$_.action }).Count -eq 0) 'Todas las casillas Debloat tienen acción'
$office = New-NexoOfficeConfiguration @('Word','Excel','Visio')
Assert ($office.Configuration.Add.Product.Count -eq 2) 'Office y Visio generan productos independientes'
$suite = $office.Configuration.Add.Product | Where-Object ID -eq 'O365ProPlusRetail'
Assert ('Word' -notin $suite.ExcludeApp.ID -and 'Excel' -notin $suite.ExcludeApp.ID -and 'Outlook' -in $suite.ExcludeApp.ID) 'Office incluye exactamente los componentes elegidos'
Assert ($office.Configuration.Display.AcceptEULA -eq 'FALSE') 'Office muestra los términos al usuario'
$rejected = $false
try { $null = New-NexoOfficeConfiguration @('ProductoInexistente') } catch { $rejected = $true }
Assert $rejected 'Office rechaza componentes desconocidos'
$visio = New-NexoOfficeConfiguration @('Visio')
Assert ($visio.Configuration.Add.Product.ID -eq 'VisioProRetail') 'Visio solo conserva la selección'
& (Get-Module Core) {
    $script:calls = @()
    function Install-NexoWinget { return 'winget-test.exe' }
    function Invoke-NexoNative($File,$Arguments,$Log,$SuccessCodes) {
        $script:calls += ,$Arguments
        if ($Arguments[0] -eq 'install') { return -1978335189 }
        return 0
    }
    $action = Get-NexoCatalog | Where-Object Id -eq 'app.chrome'
    $result = Invoke-NexoAction $action $null $null 'unused.log'
    if ($result -ne 0 -or $script:calls.Count -ne 2 -or $script:calls[1][0] -ne 'list') { throw 'La instalación repetida requiere verificar el programa.' }
    'PASS Instalación repetida verifica presencia antes de informar éxito'
}
