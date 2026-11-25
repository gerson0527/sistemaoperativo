param([switch]$SmokeTest,[string]$ScreenshotPath)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
Import-Module (Join-Path $PSScriptRoot 'Delta.psm1') -Force
$reader=[Xml.XmlReader]::Create((Join-Path $PSScriptRoot 'Delta.xaml'))
try{$window=[Windows.Markup.XamlReader]::Load($reader)}finally{$reader.Dispose()}
$window.Height=[math]::Min(650,[Windows.SystemParameters]::WorkArea.Height-24)
$ui=@{};foreach($name in @('OpenDelta','InstallDelta','DetectDelta','LocateDelta','VerifyDelta','BundleStatus','Busy','Status','InstalledStatus')){$ui[$name]=$window.FindName($name)}
$script:job=$null;$script:resultPath=$null
try{$manifest=Get-NexoDeltaManifest;$size=($manifest.Files|Measure-Object Bytes -Sum).Sum/1GB;$ui.BundleStatus.Text=('Paquete incluido · {0:N2} GiB · se verifica antes de ejecutarlo' -f $size)}catch{$ui.BundleStatus.Text=$_.Exception.Message;$ui.InstallDelta.IsEnabled=$false;$ui.VerifyDelta.IsEnabled=$false}
function Update-DeltaInstalled {
 try{$app=Get-NexoDeltaRegistered;$ui.InstalledStatus.Text=if($app){'Vinculado: '+$app.Path}else{'Aún no se ha vinculado un DELTA instalado.'}}catch{$ui.InstalledStatus.Text=$_.Exception.Message}
}
function Start-DeltaAction([string]$Action,[string]$SelectedPath) {
 try{
 if($script:job -and !$script:job.HasExited){return}
 $script:resultPath=Join-Path $env:LOCALAPPDATA ('NexoAssistant\DELTA\runs\'+[guid]::NewGuid().ToString('N')+'.json')
 $arguments='-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'DeltaWorker.ps1')+'" -Action '+$Action+' -OutputPath "'+$script:resultPath+'"'
 if($SelectedPath){$arguments+=' -SelectedPath "'+$SelectedPath+'"'}
 $script:job=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -WindowStyle Hidden -PassThru
 $ui.Busy.Visibility='Visible';$ui.Status.Text='Procesando… La verificación del paquete de 4 GB puede tardar. La ventana permanece disponible.'
 foreach($name in @('OpenDelta','InstallDelta','DetectDelta','LocateDelta','VerifyDelta')){$ui[$name].IsEnabled=$false}
 $timer.Start()
 }catch{$ui.Status.Text=$_.Exception.Message;$ui.Busy.Visibility='Collapsed'}
}
$timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(300)
$timer.Add_Tick({
 if(!$script:job.HasExited){return}
 $timer.Stop();$ui.Busy.Visibility='Collapsed'
 try{
  if(!(Test-Path -LiteralPath $script:resultPath)){throw 'La operación terminó sin devolver resultado. No se puede confirmar su ejecución.'}
  $result=[IO.File]::ReadAllText($script:resultPath)|ConvertFrom-Json
  $ui.Status.Text=if($result.Ok){$result.Result.Message}else{$result.Error}
 }catch{$ui.Status.Text=$_.Exception.Message}
 foreach($name in @('OpenDelta','InstallDelta','DetectDelta','LocateDelta','VerifyDelta')){$ui[$name].IsEnabled=$true}
 Update-DeltaInstalled
})
$ui.OpenDelta.Add_Click({Start-DeltaAction 'Open'})
$ui.InstallDelta.Add_Click({Start-DeltaAction 'Setup'})
$ui.VerifyDelta.Add_Click({Start-DeltaAction 'Verify'})
$ui.DetectDelta.Add_Click({Start-DeltaAction 'Detect'})
$ui.LocateDelta.Add_Click({
 $dialog=New-Object Microsoft.Win32.OpenFileDialog;$dialog.Title='Selecciona DELTA instalado';$dialog.Filter='Aplicación DELTA (*.exe)|*.exe';$dialog.CheckFileExists=$true
 if($dialog.ShowDialog($window)){Start-DeltaAction 'Locate' $dialog.FileName}
})
$window.Add_Closing({param($sender,$eventArgs) if($script:job -and !$script:job.HasExited){$eventArgs.Cancel=$true;$ui.Status.Text='Espera a que termine la comprobación o se abra el programa antes de cerrar.'}})
Update-DeltaInstalled
if($SmokeTest){
 $window.Add_ContentRendered({
  if($ScreenshotPath){
   $window.UpdateLayout();$bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap([int]$window.ActualWidth,[int]$window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($window)
   $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create($ScreenshotPath);try{$encoder.Save($stream)}finally{$stream.Dispose()}
  }
  $window.Close()
 })
}
$null=$window.ShowDialog()
