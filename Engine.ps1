param([switch]$SmokeTest,[string]$ScreenshotPath,[ValidateRange(0,7)][int]$SmokePage=0,[string]$CaptureFolder,[switch]$TestUi,[string]$SelectionPath)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms
Import-Module (Join-Path $PSScriptRoot 'Core.psm1') -Force
$script:dataRoot=Join-Path $env:LOCALAPPDATA 'NexoAssistant'
[IO.Directory]::CreateDirectory($script:dataRoot)|Out-Null
$script:inventory=$null;$script:plan=$null;$script:busy=$false;$script:job=$null;$script:runFolder='';$script:checks=@{};$script:selectedProfile='Conservador';$script:page=0
[xml]$xaml=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Engine.xaml') -Raw -Encoding UTF8
$script:window=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xaml))
$window.Height=[math]::Min(820,[Windows.SystemParameters]::WorkArea.Height-32)
$window.Width=[math]::Min(1160,[Windows.SystemParameters]::WorkArea.Width-32)
$ns=New-Object Xml.XmlNamespaceManager($xaml.NameTable);$ns.AddNamespace('x','http://schemas.microsoft.com/winfx/2006/xaml')
$script:ui=@{};foreach($node in $xaml.SelectNodes('//*[@x:Name]',$ns)){$name=$node.GetAttribute('Name','http://schemas.microsoft.com/winfx/2006/xaml');$ui[$name]=$window.FindName($name)}
$script:titles=@('Bienvenido a Nexo','Modo de configuración','Software y bibliotecas','Personalización','Conectividad y controladores','Ajustes del sistema','Revisa tu selección','Resultado e historial')
$script:subtitles=@('Prepara Windows a tu gusto en un solo recorrido.','Selecciona un punto de partida. Podrás ajustar cada opción antes de aplicar.','Marca únicamente los componentes que necesitas. Los programas usan WinGet e Internet.','Elige el aspecto de Windows. Las vistas son orientativas; no incluyen fondos ni iconos.','Prepara Wi-Fi o instala paquetes locales compatibles de Wi-Fi y Ethernet.','Elige preferencias, energía y aplicaciones que quieres retirar para tu usuario.','Comprueba los cambios y su posibilidad de restauración antes de continuar.','Consulta lo que se aplicó y recupera los ajustes que tienen una copia guardada.')
function Show-Error($Message){
 if($SmokeTest){$script:smokeError=[string]$Message;$window.Close();return}
 [Windows.MessageBox]::Show([string]$Message,'Nexo Assistant','OK','Warning')|Out-Null
}
function Update-Navigation {
 $ui.Back.IsEnabled=(-not $script:busy -and $script:page -gt 0)
 $ui.Next.IsEnabled=(-not $script:busy -and $null -ne $script:inventory)
 $ui.Next.Visibility=if($script:page -eq 6){'Collapsed'}else{'Visible'}
 $ui.Apply.Visibility=if($script:page -eq 6){'Visible'}else{'Collapsed'}
 $ui.Apply.IsEnabled=(-not $script:busy -and $null -ne $script:plan -and $ui.Consent.IsChecked -eq $true -and @($script:plan.Steps|Where-Object Blocked).Count -eq 0)
 $ui.Stop.Visibility=if($script:busy -and $script:runFolder){'Visible'}else{'Collapsed'}
 $ui.Stop.IsEnabled=$true
 $ui.Next.Content=switch($script:page){0{'Comenzar →'}5{'Revisar selección →'}7{'Volver al inicio'}default{'Continuar →'}}
}
function Show-Page([int]$Index){
 $script:page=[math]::Max(0,[math]::Min(7,$Index));$ui.Tabs.SelectedIndex=$script:page
 $ui.PageTitle.Text=$script:titles[$script:page];$ui.PageSubtitle.Text=$script:subtitles[$script:page]
 $ui.StepLabel.Text='PASO '+($script:page+1)+' DE 8';$ui.StepProgress.Value=$script:page
 Update-Navigation
}
function Reset-Plan {
 $script:plan=$null;$ui.Consent.IsChecked=$false;$ui.PlanCards.Children.Clear();Update-Navigation
}
function Update-SelectionVisuals {
 foreach($entry in @(@('Safe','Conservador'),@('Light','Ligero'),@('Games','Juegos'))){
  $selected=$script:selectedProfile -eq $entry[1]
  $ui['Card'+$entry[0]].BorderBrush=if($selected){'#659EFF'}else{'#203453'}
  $ui['Card'+$entry[0]].BorderThickness=if($selected){2}else{1}
  $ui['Profile'+$entry[0]].Content=if($selected){'✓ Seleccionado'}else{'Seleccionar'}
 }
 $theme='Keep';if($script:checks['theme.dark'].IsChecked){$theme='Dark'}elseif($script:checks['theme.light'].IsChecked){$theme='Light'}
 foreach($id in @('Dark','Light','Keep')){$selected=$theme -eq $id;$ui['ThemeCard'+$id].BorderBrush=if($selected){'#659EFF'}else{'#203453'};$label=switch($id){'Dark'{'OSCURO'}'Light'{'CLARO'}default{'ACTUAL'}};$ui['Theme'+$id].Content=$label}
 $script:syncTheme=$true
 try{$ui.ThemeMode.SelectedIndex=switch($theme){'Dark'{1}'Light'{2}default{0}}}finally{$script:syncTheme=$false}
 $ui.ThemePreviewLabel.Text=switch($theme){'Dark'{'Tema oscuro'}'Light'{'Tema claro'}default{'Conservar actual'}}
}
function Select-Profile([string]$Name){
 $managed=@('explorer.extensions','power.balanced','power.performance','visual.transparency','privacy.suggestions','gaming.capture')
 $ids=@(Get-NexoProfile $Name)
 foreach($id in $managed){$script:checks[$id].IsChecked=($id -in $ids)}
 $script:selectedProfile=$Name;Reset-Plan;Update-SelectionVisuals
}
function Add-Text($Panel,[string]$Text,[int]$Size=13,[string]$Color='#A5B6D0'){
 $t=New-Object Windows.Controls.TextBlock;$t.Text=$Text;$t.TextWrapping='Wrap';$t.FontSize=$Size;$t.Foreground=$Color;$t.Margin='0,4,0,0';$Panel.Children.Add($t)|Out-Null
}
function Add-InfoCard($Panel,[string]$Title,[string]$Detail,[string]$Meta,[string]$Color='#609FFF'){
 $b=New-Object Windows.Controls.Border;$b.Background='#162640';$b.BorderBrush='#2B4262';$b.BorderThickness=1;$b.CornerRadius=10;$b.Padding=14;$b.Margin='0,0,8,10'
 $s=New-Object Windows.Controls.StackPanel;Add-Text $s $Title 16 '#EEF5FF';Add-Text $s $Detail 12;Add-Text $s $Meta 11 $Color;$b.Child=$s;$Panel.Children.Add($b)|Out-Null
}
function Set-Gauge([string]$Name,$Value){
 $ui['Gauge'+$Name].Data=$null
 if($null -eq $Value){$ui['Value'+$Name].Text='—';return}
 $v=[math]::Max(0,[math]::Min(100,[double]$Value));$ui['Value'+$Name].Text=([int]$v).ToString()+'%'
 if($v -le 0){return};$angle=2*[math]::PI*[math]::Min($v,99.9)/100
 $x=(26+22*[math]::Sin($angle)).ToString('0.00',[Globalization.CultureInfo]::InvariantCulture)
 $y=(26-22*[math]::Cos($angle)).ToString('0.00',[Globalization.CultureInfo]::InvariantCulture)
 $large=if($v -gt 50){1}else{0};$ui['Gauge'+$Name].Data=[Windows.Media.Geometry]::Parse("M 26,4 A 22,22 0 $large 1 $x,$y")
}
function Show-Inventory {
 $i=$script:inventory
 $type='Tipo no determinado';if($i.Laptop -eq $true){$type='Portátil'}elseif($i.Laptop -eq $false){$type='Sobremesa'}
 $ui.WelcomeOS.Text=$i.OS;$ui.WelcomeModel.Text=$i.Model+' · '+$type
 $ui.WelcomeGPU.Text=(@($i.GPU|ForEach-Object Name)-join ', ');$ui.WelcomeRAM.Text="$($i.RAMGB) GB RAM · Windows x64"
 $ui.WelcomeNetwork.Text="Red: $(@($i.Network).Count) adaptadores detectados"
 $ui.SystemCPU.Text='CPU: '+$i.CPUName;$ui.SystemModel.Text=$i.Model+' · RAM: '+$i.RAMGB+' GB'
 $ui.SampleTime.Text='Lectura al analizar · '+$i.SampleTime+' · no es un monitor en vivo'
 Set-Gauge 'CPU' $i.CPUPercent;Set-Gauge 'RAM' $i.MemoryPercent;Set-Gauge 'Disk' $i.DrivePercent
 $ui.Hardware.Text=($i|ConvertTo-Json -Depth 8)
 $ui.Status.Text='Equipo analizado. Elige tus opciones; los cambios se aplican al final.'
 Update-Navigation
}
function Set-Busy([bool]$Value){
 $script:busy=$Value
 foreach($name in @('Scan','Restore','HistoryLink','ToolsLink','BrowseDriver','BrowseSxs','DriverFolder','SxsFolder','ProfileSafe','ProfileLight','ProfileGames','ThemeDark','ThemeLight','ThemeKeep','ThemeMode')){$ui[$name].IsEnabled=-not $Value}
 foreach($check in $script:checks.Values){$check.IsEnabled=-not $Value}
 Update-Navigation
}
function Quote-Argument([string]$Text){if($Text.Contains('"')){throw 'La ruta contiene comillas no válidas.'};'"'+$Text.TrimEnd('\')+'"'}
function Start-Worker([string]$Mode,[string]$InputFile=''){
 $id=[guid]::NewGuid().ToString('N');$script:resultFile=Join-Path $script:dataRoot ($id+'.json');$script:runFolder=''
 $args='-NoProfile -ExecutionPolicy Bypass -File '+(Quote-Argument (Join-Path $PSScriptRoot 'Worker.ps1'))+' -Mode '+$Mode+' -OutputPath '+(Quote-Argument $script:resultFile)
 if($InputFile){$args+=' -InputPath '+(Quote-Argument $InputFile)}
 if($Mode -eq 'Apply'){$script:runFolder=Join-Path $script:dataRoot ('runs\'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+$id.Substring(0,6));[IO.Directory]::CreateDirectory($script:runFolder)|Out-Null;$args+=' -RunFolder '+(Quote-Argument $script:runFolder)}
 $start=@{FilePath="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe";ArgumentList=$args;WindowStyle='Hidden';PassThru=$true}
 if($Mode -ne 'Scan' -and -not(Test-NexoAdmin)){$start.Verb='RunAs'}
 $script:job=Start-Process @start;$script:jobMode=$Mode;Set-Busy $true
 $ui.Status.Text=if($Mode -eq 'Scan'){'Analizando el equipo…'}else{'Aplicando cambios. Espera el resultado; no cierres el asistente.'}
 $timer.Start()
}
function Build-Plan {
 if(-not $script:inventory){throw 'Primero espera al análisis del equipo.'}
 $ids=@(Get-NexoCatalog|Where-Object {$script:checks[$_.Id].IsChecked}|ForEach-Object Id)
 if($ids.Count -eq 0){throw 'Selecciona al menos una opción antes de revisar.'}
 $req=[pscustomobject]@{Schema=1;Ids=$ids;DriverFolder=$ui.DriverFolder.Text.Trim();SxsFolder=$ui.SxsFolder.Text.Trim()}
 $script:plan=New-NexoPlan $req $script:inventory
 $script:planPath=Join-Path $script:dataRoot ('plan-'+[guid]::NewGuid().ToString('N')+'.json');Save-NexoJson $script:plan $script:planPath
 $ui.PlanCards.Children.Clear()
 foreach($s in $script:plan.Steps){
  $meta=if($s.Reversible){'✓ Con copia para restaurar'}else{'Sin restauración automática'};$color='#61B9FF'
  if($s.Blocked){$meta='BLOQUEADO · '+$s.Blocked;$color='#FFB98D'}
  Add-InfoCard $ui.PlanCards $s.Name $s.Detail $meta $color
 }
 $ui.Consent.IsChecked=$false;Show-Page 6
 $ui.Status.Text="$($ids.Count) acciones seleccionadas. Todavía no se ha aplicado ningún cambio."
}
function Import-WizardSelection {
 if(-not $SelectionPath){return}
 $request=Read-NexoJson $SelectionPath
 $validated=New-NexoPlan $request $script:inventory
 foreach($c in $script:checks.Values){$c.IsChecked=$false}
 foreach($id in $request.Ids){$script:checks[$id].IsChecked=$true}
 $ui.DriverFolder.Text=[string]$request.DriverFolder;$ui.SxsFolder.Text=[string]$request.SxsFolder
 $script:selectedProfile='Personalizado';Update-SelectionVisuals;Build-Plan
 if($TestUi){
  $actual=@($script:checks.Keys|Where-Object {$script:checks[$_].IsChecked}|Sort-Object)
  $expected=@($request.Ids|Sort-Object)
  if(($actual -join '|') -ne ($expected -join '|')){throw 'Importación: se agregaron o perdieron acciones.'}
  if($ui.Consent.IsChecked -or $ui.Apply.IsEnabled){throw 'Importación: no debe permitir aplicar sin revisión y confirmación.'}
  if($script:page -ne 6 -or $script:plan.Steps.Count -ne $expected.Count){throw 'Importación: resumen no corresponde a las acciones recibidas.'}
  $script:uiTests+=3
 }
}
function Show-Journal($Journal){
 $ui.ResultCards.Children.Clear()
 $ui.ResultTitle.Text=switch($Journal.State){'Completed'{'Configuración finalizada'}'Failed'{'La ejecución encontró un problema'}'Stopped'{'Ejecución detenida'}'Running'{'Aplicando selección…'}'RestoredAdjustments'{'Ajustes restaurados'}'RestoreFailed'{'Revisa los errores de restauración'}default{'Resultado de la ejecución'}}
 foreach($e in $Journal.Entries){
  $status=switch($e.State){'Completed'{'Completado'}'Failed'{'Error'}'Pending'{'En curso'}default{$e.State}}
  if($e.UndoState){$status+=' · Restauración: '+$e.UndoState}
  $detail=$e.Error;if($e.UndoError){$detail+=' '+$e.UndoError}
  if(-not $detail){$detail=if($e.Reversible){'Copia del ajuste disponible en esta ejecución.'}else{'Esta acción no tiene restauración automática.'}}
  $color=if($e.State -eq 'Failed' -or $e.UndoState -eq 'Failed'){'#FFB98D'}else{'#54D2AE'}
  Add-InfoCard $ui.ResultCards $e.Name $detail $status $color
 }
 if($Journal.RestartRequired){Add-InfoCard $ui.ResultCards 'Reinicio pendiente' 'Guarda tu trabajo y reinicia Windows cuando lo decidas.' 'No se reinicia automáticamente' '#FFCD7F'}
}
function Refresh-History {
 $ui.History.Items.Clear();$runs=Join-Path $script:dataRoot 'runs'
 if(Test-Path -LiteralPath $runs){foreach($file in Get-ChildItem -LiteralPath $runs -Filter journal.json -Recurse|Sort-Object LastWriteTime -Descending){try{$j=Read-NexoJson $file.FullName;$item=New-Object Windows.Controls.ListBoxItem;$label=New-Object Windows.Controls.TextBlock;$label.Text=$file.Directory.Name+"`n"+$j.State;$label.TextWrapping='Wrap';$label.Margin=8;$item.Content=$label;$item.Tag=$file.FullName;$ui.History.Items.Add($item)|Out-Null}catch{}}}
}
# Cada casilla conserva su identificador del motor. Los temas se seleccionan con tarjetas.
foreach($a in Get-NexoCatalog){
 $check=New-Object Windows.Controls.CheckBox;$check.Tag=$a.Id;$check.Margin='0,0,0,18';$check.ToolTip=$a.Detail
 $s=New-Object Windows.Controls.StackPanel;Add-Text $s $a.Name 14 '#ECF3FF'
 $short=switch($a.Id){'app.7zip'{'Compresión de archivos'}'app.firefox'{'Navegador web'}'app.vlc'{'Reproductor multimedia'}'app.vcredist'{'Bibliotecas para aplicaciones x64'}'app.dotnet8'{'Runtime de escritorio'}'runtime.netfx3'{'Componente opcional de Windows'}'network.wlan'{'Inicio automático del servicio WLAN'}'network.drivers'{'La carpeta debe contener INF, CAT y SYS'}'visual.transparency'{''}default{$a.Detail}}
 if($short){Add-Text $s $short 11}
 $check.Content=$s;$script:checks[$a.Id]=$check
 $target=switch($a.Group){'Programas'{'ProgramsChoices'}'Bibliotecas'{'RuntimeChoices'}'Ajustes'{'SettingsChoices'}'Energia'{'PowerChoices'}'Aplicaciones opcionales'{'DebloatChoices'}'Red'{if($a.Id -eq 'network.wlan'){'WifiChoices'}else{'DriverChoices'}}'Apariencia'{if($a.Id -eq 'visual.transparency'){'VisualChoices'}else{''}}}
 if($target){$ui[$target].Children.Add($check)|Out-Null}
 $check.Add_Click({
  if($this.IsChecked){$other=switch($this.Tag){'power.balanced'{'power.performance'}'power.performance'{'power.balanced'}default{''}};if($other){$script:checks[$other].IsChecked=$false}}
  if($this.Tag -in @('explorer.extensions','power.balanced','power.performance','visual.transparency','privacy.suggestions','gaming.capture')){$script:selectedProfile='Personalizado'}
  Reset-Plan;Update-SelectionVisuals
 })
}
$ui.ProfileSafe.Add_Click({Select-Profile 'Conservador'});$ui.ProfileLight.Add_Click({Select-Profile 'Ligero'});$ui.ProfileGames.Add_Click({Select-Profile 'Juegos'})
$ui.ThemeDark.Add_Click({$script:checks['theme.dark'].IsChecked=$true;$script:checks['theme.light'].IsChecked=$false;Reset-Plan;Update-SelectionVisuals})
$ui.ThemeLight.Add_Click({$script:checks['theme.dark'].IsChecked=$false;$script:checks['theme.light'].IsChecked=$true;Reset-Plan;Update-SelectionVisuals})
$ui.ThemeKeep.Add_Click({$script:checks['theme.dark'].IsChecked=$false;$script:checks['theme.light'].IsChecked=$false;Reset-Plan;Update-SelectionVisuals})
$ui.ThemeMode.Add_SelectionChanged({
 if($script:syncTheme){return}
 $script:checks['theme.dark'].IsChecked=($ui.ThemeMode.SelectedIndex -eq 1)
 $script:checks['theme.light'].IsChecked=($ui.ThemeMode.SelectedIndex -eq 2)
 Reset-Plan;Update-SelectionVisuals
})
$ui.DriverFolder.Add_TextChanged({Reset-Plan});$ui.SxsFolder.Add_TextChanged({Reset-Plan})
function Choose-Folder($Target,[string]$Description){$d=New-Object System.Windows.Forms.FolderBrowserDialog;$d.Description=$Description;if($d.ShowDialog() -eq 'OK'){$Target.Text=$d.SelectedPath};$d.Dispose()}
$ui.BrowseDriver.Add_Click({Choose-Folder $ui.DriverFolder 'Paquetes completos de red del fabricante'})
$ui.BrowseSxs.Add_Click({Choose-Folder $ui.SxsFolder 'sources\sxs de la misma versión de Windows'})
$ui.Next.Add_Click({try{if($script:page -eq 5){Build-Plan}elseif($script:page -eq 7){Show-Page 0}else{Show-Page ($script:page+1)}}catch{Show-Error $_.Exception.Message}})
$ui.Back.Add_Click({Show-Page ($script:page-1)})
$ui.Consent.Add_Click({Update-Navigation})
$ui.Apply.Add_Click({try{if(-not $script:plan -or -not $ui.Consent.IsChecked){throw 'Revisa y confirma el plan.'};Start-Worker 'Apply' $script:planPath}catch{Set-Busy $false;Show-Error $_.Exception.Message}})
$ui.Stop.Add_Click({if($script:runFolder){[IO.File]::WriteAllText((Join-Path $script:runFolder 'stop.request'),'stop');$ui.Status.Text='Se detendrá al terminar la acción actual.';$ui.Stop.IsEnabled=$false}})
$ui.Scan.Add_Click({try{Reset-Plan;Start-Worker 'Scan'}catch{Show-Error $_.Exception.Message}})
$ui.Details.Add_Click({$ui.ToolsPanel.Visibility='Collapsed';$ui.HardwarePanel.Visibility='Visible';$ui.OverlayTitle.Text='Diagnóstico del equipo';$ui.Overlay.Visibility='Visible'})
$ui.ToolsLink.Add_Click({$ui.ToolsPanel.Visibility='Visible';$ui.HardwarePanel.Visibility='Collapsed';$ui.OverlayTitle.Text='Herramientas de Windows';$ui.Overlay.Visibility='Visible'})
$ui.CloseOverlay.Add_Click({$ui.Overlay.Visibility='Collapsed'})
$ui.Export.Add_Click({try{if(-not $script:inventory){throw 'Espera al análisis.'};$d=New-Object Microsoft.Win32.SaveFileDialog;$d.Filter='JSON|*.json';$d.FileName='Nexo-equipo.json';if($d.ShowDialog()){Save-NexoJson $script:inventory $d.FileName}}catch{Show-Error $_.Exception.Message}})
$ui.HistoryLink.Add_Click({Refresh-History;Show-Page 7})
$ui.RefreshHistory.Add_Click({Refresh-History})
$ui.History.Add_SelectionChanged({if($ui.History.SelectedItem){try{Show-Journal (Read-NexoJson $ui.History.SelectedItem.Tag)}catch{Show-Error $_.Exception.Message}}})
$ui.Restore.Add_Click({try{if(-not $ui.History.SelectedItem){throw 'Selecciona una ejecución del historial.'};if([Windows.MessageBox]::Show('Se restaurarán solo ajustes con copia. Programas, drivers y apps retiradas quedan como están. Restaura primero la ejecución más reciente.','Restaurar ajustes','OKCancel','Question') -eq 'OK'){Start-Worker 'Restore' ([string]$ui.History.SelectedItem.Tag)}}catch{Show-Error $_.Exception.Message}})
$ui.OpenLogs.Add_Click({Start-Process explorer.exe -ArgumentList (Quote-Argument $script:dataRoot)})
$ui.ToolDevices.Add_Click({Start-Process mmc.exe -ArgumentList 'devmgmt.msc'})
$ui.ToolNetwork.Add_Click({Start-Process control.exe -ArgumentList 'ncpa.cpl'})
$ui.ToolUpdate.Add_Click({Start-Process 'ms-settings:windowsupdate'})
$ui.ToolSecurity.Add_Click({try{Start-Process 'windowsdefender:'}catch{Show-Error 'Seguridad de Windows no está disponible.'}})
$ui.ToolApps.Add_Click({Start-Process control.exe -ArgumentList 'appwiz.cpl'})
$ui.ToolSystem.Add_Click({Start-Process msinfo32.exe})
$script:timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(600)
$timer.Add_Tick({
 try{
  if(-not $script:job){return}
  if(-not $script:job.HasExited){
   if($script:runFolder){$jp=Join-Path $script:runFolder 'journal.json';if(Test-Path -LiteralPath $jp){try{$j=Read-NexoJson $jp;$done=@($j.Entries|Where-Object State -eq 'Completed').Count;$ui.Status.Text="Aplicando selección · $done de $(@($script:plan.Steps).Count) acciones completadas"}catch{}}}
   return
  }
  $timer.Stop();Set-Busy $false
  if(-not(Test-Path -LiteralPath $script:resultFile)){throw 'El proceso terminó sin informe. Consulta los registros.'}
  $r=Read-NexoJson $script:resultFile;if(-not $r.Ok){throw $r.Error}
  if($script:jobMode -eq 'Scan'){$script:inventory=$r.Result;Show-Inventory;Import-WizardSelection}else{Refresh-History;Show-Journal $r.Result;Reset-Plan;Show-Page 7;$ui.Status.Text='Operación terminada. Revisa el resultado de cada acción.'}
  $script:job.Dispose();$script:job=$null
 }catch{$timer.Stop();Set-Busy $false;$ui.Status.Text='No se completó la operación.';Show-Error $_.Exception.Message}
})
$window.Add_Closing({if($script:busy){$_.Cancel=$true;Show-Error 'Hay una operación en curso. Puedes detenerla después de la acción actual.'}})
Select-Profile 'Conservador';Show-Page 0
$ui.HeaderDate.Text=(Get-Date).ToString('dd MMMM yyyy',[Globalization.CultureInfo]::GetCultureInfo('es-CO'))+' · Versión de prueba'
function Invoke-UiTests {
 $script:uiTests=0
 function Assert-Ui($Ok,[string]$Name){if(-not $Ok){throw "Prueba de interfaz fallida: $Name"};$script:uiTests++}
 function Click($Control){$Control.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))}
 Show-Page 0;Click $ui.Next;Assert-Ui ($script:page -eq 1) 'Comenzar navega a perfiles'
 $script:checks['app.vlc'].IsChecked=$true;Click $ui.ProfileLight
 Assert-Ui ($script:checks['app.vlc'].IsChecked -and $script:checks['visual.transparency'].IsChecked) 'Perfil conserva software elegido'
 Click $ui.ThemeDark;Click $ui.ThemeLight
 Assert-Ui ($script:checks['theme.light'].IsChecked -and -not $script:checks['theme.dark'].IsChecked) 'Temas excluyentes'
 Click $ui.ThemeKeep;Assert-Ui (-not $script:checks['theme.light'].IsChecked -and -not $script:checks['theme.dark'].IsChecked) 'Conservar no agrega cambio de tema'
 $script:checks['app.vlc'].IsChecked=$false;Show-Page 5;Click $ui.Next
 Assert-Ui ($script:page -eq 6 -and $null -ne $script:plan -and -not $ui.Apply.IsEnabled) 'Revision sin consentimiento bloquea aplicar'
 $ui.Consent.IsChecked=$true;Update-Navigation;Assert-Ui ($ui.Apply.IsEnabled) 'Consentimiento habilita plan valido'
 Click $ui.Back;Assert-Ui ($script:page -eq 5) 'Anterior conserva navegacion'
 $ui.SxsFolder.Text='cambio-de-prueba';Assert-Ui ($null -eq $script:plan -and -not $ui.Apply.IsEnabled) 'Cambio invalida plan y consentimiento';$ui.SxsFolder.Text=''
 $original=$script:inventory.Winget;$script:inventory.Winget=$false;$script:checks['app.vlc'].IsChecked=$true;Build-Plan;$ui.Consent.IsChecked=$true;Update-Navigation
 Assert-Ui (-not $ui.Apply.IsEnabled) 'Bloqueo de WinGet impide aplicar';$script:inventory.Winget=$original;$script:checks['app.vlc'].IsChecked=$false
 foreach($p in 0..7){Show-Page $p;Assert-Ui ($ui.Tabs.SelectedIndex -eq $p -and $ui.PageTitle.Text -eq $script:titles[$p]) "Pantalla $p"}
 Select-Profile 'Conservador';Show-Page 0
}
function Prepare-Capture([int]$Index){
 if($Index -eq 6){Build-Plan}
 if($Index -eq 7){$ui.ResultCards.Children.Clear();$ui.ResultTitle.Text='Así consultarás los resultados';Add-InfoCard $ui.ResultCards 'Ejemplo de una acción completada' 'Aquí aparecerán los ajustes, errores y copias de restauración de cada ejecución.' 'VISTA DE EJEMPLO · NO SE HAN APLICADO CAMBIOS' '#FFCD7F';Add-InfoCard $ui.ResultCards 'Restauración de ajustes' 'Los programas y drivers instalados no tienen deshacer automático.' 'Consulta siempre el detalle de la ejecución'}
 Show-Page $Index;$ui.Status.Text='VISTA PREVIA · Interfaz real · No se han aplicado cambios a Windows'
}
function Save-Capture([string]$Path){
 $window.UpdateLayout();$bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap([int]$window.ActualWidth,[int]$window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32)
 $bg=New-Object Windows.Media.DrawingVisual;$dc=$bg.RenderOpen()
 $brush=(New-Object Windows.Media.BrushConverter).ConvertFromString('#081321')
 $dc.DrawRectangle($brush,$null,(New-Object Windows.Rect(0,0,$window.ActualWidth,$window.ActualHeight)));$dc.Close();$bitmap.Render($bg)
 $bitmap.Render($window);$encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create($Path);try{$encoder.Save($stream)}finally{$stream.Dispose()}
}
$script:started=$false
$window.Add_ContentRendered({
 if($script:started){return};$script:started=$true
 try{
  if($SmokeTest){
   $script:inventory=Get-NexoInventory;Show-Inventory
   if($TestUi){Invoke-UiTests};Import-WizardSelection
   $script:captureIndex=if($CaptureFolder){0}else{$SmokePage};$script:capturePhase='prepare'
   if($CaptureFolder){[IO.Directory]::CreateDirectory($CaptureFolder)|Out-Null}
   $script:captureTimer=New-Object Windows.Threading.DispatcherTimer;$captureTimer.Interval=[TimeSpan]::FromMilliseconds(400)
   $captureTimer.Add_Tick({
    try{
     if($script:capturePhase -eq 'prepare'){Prepare-Capture $script:captureIndex;$script:capturePhase='save';return}
     $path=$ScreenshotPath;if($CaptureFolder){$path=Join-Path $CaptureFolder (('{0:00}' -f ($script:captureIndex+1))+'.png')}
     if($path){Save-Capture $path}
     if($CaptureFolder -and $script:captureIndex -lt 7){$script:captureIndex++;$script:capturePhase='prepare'}else{
      $captureTimer.Stop()
      if($TestUi){Save-NexoJson ([pscustomobject]@{Passed=$script:uiTests;Failed=0;Mutations='Ninguna; pruebas de seleccion y navegacion';Screens=8}) (Join-Path $CaptureFolder 'ui-tests.json')}
      $window.Close()
     }
    }catch{$captureTimer.Stop();$script:smokeError=$_.Exception.Message;$window.Close()}
   });$captureTimer.Start()
  }else{Start-Worker 'Scan';Refresh-History}
 }catch{Show-Error $_.Exception.Message}
})
$null=$window.ShowDialog()
if($script:smokeError){throw $script:smokeError}
