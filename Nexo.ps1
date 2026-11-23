param([switch]$SmokeTest,[switch]$TestUi,[string]$CaptureFolder,[ValidateRange(0,13)][int]$SmokePage=0,[string]$ScreenshotPath,[string]$StatePath)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
Import-Module (Join-Path $PSScriptRoot 'Core.psm1') -Force
$script:catalog=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'WizardCatalog.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$script:dataRoot=Join-Path $env:LOCALAPPDATA 'NexoAssistant'
if(-not $StatePath){$StatePath=Join-Path $script:dataRoot 'wizard-selection.json'}
$script:state=[ordered]@{Schema=1;Version='0.3.0';Cards=@{};Checks=@{};Combos=@{};Theme='';CustomIncluded=$false;Compression=$false;MenuTranslucent=$false;ExplorerTranslucent=$false}
$script:page=0;$script:inventory=$null;$script:loading=$false;$script:started=$false
# Load with a base URI so the portable assets resolve even when launched elsewhere.
$settings=New-Object Xml.XmlReaderSettings
$reader=[Xml.XmlReader]::Create((Join-Path $PSScriptRoot 'Window.xaml'),$settings)
try{$script:window=[Windows.Markup.XamlReader]::Load($reader)}finally{$reader.Dispose()}
$window.Width=[math]::Min(1536,[Windows.SystemParameters]::WorkArea.Width-24)
$window.Height=[math]::Min(900,[Windows.SystemParameters]::WorkArea.Height-24)
[xml]$xml=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Window.xaml') -Raw -Encoding UTF8
$ns=New-Object Xml.XmlNamespaceManager($xml.NameTable);$ns.AddNamespace('x','http://schemas.microsoft.com/winfx/2006/xaml')
$script:ui=@{}
foreach($n in $xml.SelectNodes('//*[@x:Name]',$ns)){$name=$n.GetAttribute('Name','http://schemas.microsoft.com/winfx/2006/xaml');$ui[$name]=$window.FindName($name)}
$script:coreCatalog=@(Get-NexoCatalog)
function Notify-Error([string]$Message){
 if($SmokeTest){$script:smokeError=$Message;$window.Close()}else{[Windows.MessageBox]::Show($Message,'Nexo Assistant','OK','Warning')|Out-Null}
}
function Read-Selection {
 foreach($c in $catalog.checks){$state.Checks[$c.control]=($ui[$c.control].IsChecked -eq $true)}
 foreach($name in @('Word','Excel','PowerPoint','Outlook','Access','Visio','Publisher','OneNote')){$state.Checks['Office'+$name]=($ui['Office'+$name].IsChecked -eq $true)}
 foreach($property in $catalog.combos.PSObject.Properties){$key=$property.Name;$state.Combos[$key]=[string]$ui[$key].SelectedItem.Content}
 $state.Compression=($ui.Compression.IsChecked -eq $true);$state.MenuTranslucent=($ui.MenuTranslucent.IsChecked -eq $true);$state.ExplorerTranslucent=($ui.ExplorerTranslucent.IsChecked -eq $true)
}
function Save-Selection {
 Read-Selection;Save-NexoJson $state $StatePath
 $ui.Status.Text='Selección guardada · no se han aplicado cambios a Windows'
}
function Restore-Selection {
 if(-not(Test-Path -LiteralPath $StatePath)){return}
 try{
  $saved=Read-NexoJson $StatePath
  if($saved.Schema -ne 1 -or $saved.Version -ne '0.3.0'){return}
  $script:loading=$true
  foreach($group in $catalog.cards.PSObject.Properties){$v=[string]$saved.Cards.($group.Name);if($v -in @($group.Value|ForEach-Object value)){$state.Cards[$group.Name]=$v}}
  foreach($p in $saved.Checks.PSObject.Properties){if($ui.ContainsKey($p.Name) -and $ui[$p.Name] -is [Windows.Controls.CheckBox]){$ui[$p.Name].IsChecked=($p.Value -eq $true)}}
  foreach($p in $catalog.combos.PSObject.Properties){$key=$p.Name;$values=@($p.Value);$index=[array]::IndexOf($values,[string]$saved.Combos.$key);if($index -ge 0){$ui[$key].SelectedIndex=$index}}
  $state.Theme=[string]$saved.Theme;$state.CustomIncluded=($saved.CustomIncluded -eq $true)
  $ui.Compression.IsChecked=($saved.Compression -eq $true);$ui.MenuTranslucent.IsChecked=($saved.MenuTranslucent -eq $true);$ui.ExplorerTranslucent.IsChecked=($saved.ExplorerTranslucent -eq $true)
 }catch{$ui.Status.Text='No se pudo recuperar la selección anterior; puedes comenzar de nuevo.'}finally{$script:loading=$false}
 Update-Selection;Update-Preview
}
function Update-Selection {
 Read-Selection
 foreach($group in $catalog.cards.PSObject.Properties){foreach($card in $group.Value){$selected=$state.Cards[$group.Name] -eq $card.value;$ui[$card.control].Content=if($selected){'✓ Seleccionado'}else{'Seleccionar'};$ui[$card.control+'Card'].BorderBrush=if($selected){$ui[$card.control].BorderBrush}else{'#1B2C47'};$ui[$card.control+'Card'].BorderThickness=if($selected){2.5}else{1.5}}}
 $officeCount=0
 foreach($name in @('Word','Excel','PowerPoint','Outlook','Access','Visio','Publisher','OneNote')){$selected=$ui['Office'+$name].IsChecked -eq $true;if($selected){$officeCount++};$ui['OfficeLabel'+$name].Text=if($selected){'✓  '+$name}else{'○  '+$name};$ui['OfficeLabel'+$name].Foreground=if($selected){'#72A6FF'}else{'#AABCD4'};$ui['OfficeCard'+$name].BorderBrush=if($selected){'#4D80EF'}else{'#1B2C47'}}
 $ui.OfficeCount.Text="$officeCount de 8"
 $ac=@($catalog.checks|Where-Object {$_.group -eq 'Apps' -and $ui[$_.control].IsChecked}).Count
 $dc=@($catalog.checks|Where-Object {$_.group -eq 'Debloat' -and $ui[$_.control].IsChecked}).Count
 $ui.AppCount.Text="$ac de 20";$ui.DebloatCount.Text="$dc de 23"
 foreach($t in $catalog.themes){$ui['Theme'+$t].Background=if($state.Theme -eq $t){'#234C82'}else{'Transparent'}}
}
function Get-PreparedSelection {
 Read-Selection
 $ids=New-Object 'System.Collections.Generic.List[string]';$pending=New-Object 'System.Collections.Generic.List[string]'
 foreach($c in $catalog.checks){if($state.Checks[$c.control]){if($c.action){$ids.Add([string]$c.action)}else{$pending.Add([string]$c.label)}}}
 foreach($n in @('Word','Excel','PowerPoint','Outlook','Access','Visio','Publisher','OneNote')){if($state.Checks['Office'+$n]){$pending.Add('Office · '+$n)}}
 if($state.Compression){$pending.Add('Compresión de Windows')}
 foreach($g in @('Migration','Gpu','Disk','Mode')){if($state.Cards[$g]){$label=switch($g){'Migration'{'Migración'}'Gpu'{'Ajustes GPU'}'Disk'{'Ajustes de almacenamiento'}'Mode'{'Modo'}};$pending.Add($label+' · '+$state.Cards[$g])}}
 if($state.CustomIncluded){$pending.Add('Personalización · '+$(if($state.Theme){$state.Theme}else{'A medida'}));foreach($p in $state.Combos.GetEnumerator()){$label=switch($p.Key){'Icons'{'Iconos'}'StartMenu'{'Menú de Inicio'}'Dock'{'RocketDock'}default{$p.Key}};$pending.Add($label+' · '+$p.Value)};if($state.MenuTranslucent){$pending.Add('Menú traslúcido')};if($state.ExplorerTranslucent){$pending.Add('Explorer traslúcido')}}
 [pscustomobject]@{Request=[pscustomobject]@{Schema=1;Ids=@($ids);DriverFolder='';SxsFolder=''};Pending=@($pending);DevicePreference=$state.Cards['Device']}
}
function Show-Review {
 $prepared=Get-PreparedSelection
 $names=@(foreach($id in $prepared.Request.Ids){($script:coreCatalog|Where-Object Id -eq $id).Name})
 $ui.AvailableSummary.Text=if($names.Count){'• '+($names -join "`n`n• ")}else{'No has seleccionado acciones disponibles. Puedes volver a Aplicaciones o Debloatware, o abrir Motor y herramientas.'}
 $ui.PendingSummary.Text=if($prepared.Pending.Count){'• '+($prepared.Pending -join "`n• ")}else{'No has seleccionado funciones pendientes.'}
 $ui.ReviewEngine.IsEnabled=($names.Count -gt 0)
}
function Show-Page([int]$Index){
 $script:page=[math]::Max(0,[math]::Min(13,$Index))
 for($i=0;$i -lt $catalog.pages.Count;$i++){$ui['Page'+$catalog.pages[$i]].Visibility=if($i -eq $script:page){'Visible'}else{'Collapsed'}}
 $ui.Back.IsEnabled=($script:page -gt 0)
 $ui.HardwareFooter.Visibility=if($script:page -ge 12){'Collapsed'}else{'Visible'}
 if($script:page -eq 11){Show-Review}
 $ui.Status.Text=if($script:page -eq 12){'VISTA PREVIA DEL PROCESO · sin ejecución ni progreso simulado'}else{'Vista previa · las selecciones no aplican cambios'}
}
function Set-Combo([string]$Name,[string]$Value){foreach($item in $ui[$Name].Items){if([string]$item.Content -eq $Value){$ui[$Name].SelectedItem=$item;return}}}
function Update-Preview {
 if($script:loading){return}
 $wall=[string]$ui.Wallpaper.SelectedItem.Content
 $file='custom.png';$rect='0.45572917,0.28055556,0.38020833,0.37870370'
 if($wall -eq 'Wallpaper Neon'){$file='desktop-neon.png';$rect='0,0,1,1'}
 if($wall -eq 'Wallpaper Ice'){$file='desktop-ice.png';$rect='0.453125,0.32407407,0.40520833,0.30462963'}
 $bitmap=New-Object Windows.Media.Imaging.BitmapImage
 $bitmap.BeginInit();$bitmap.UriSource=New-Object Uri((Join-Path $PSScriptRoot ('assets\'+$file)),[UriKind]::Absolute);$bitmap.CacheOption='OnLoad';$bitmap.EndInit();$bitmap.Freeze()
 $brush=New-Object Windows.Media.ImageBrush($bitmap);$brush.Viewbox=[Windows.Rect]::Parse($rect);$brush.ViewboxUnits='RelativeToBoundingBox';$brush.Stretch='Fill';$ui.DesktopPreview.Fill=$brush
}
function Select-Theme([string]$Name){
 $script:loading=$true
 try{
  $state.Theme=$Name
  $map=switch($Name){
   'NEON'{@('Wallpaper Neon','Skin Neon','Icons Vivid','Inicio Launch','Dock Neon')}
   'SEVEN'{@('Wallpaper Ice','Skin Canopy','Default','Inicio Win7','Default')}
   'XP'{@('Default','Ninguno','Default','Inicio Win7','Default')}
   'BASIC'{@('Default','Ninguno','Default','Default','Default')}
   'MAC'{@('Wallpaper Ice','Skin Round','Icons Windows12','Inicio Launch','Dock MAC')}
   default{@('Wallpaper Hojas','Skin Neon','Icons Vivid','Inicio Launch','Dock Neon')}
  }
  $keys=@('Wallpaper','Rainmeter','Icons','StartMenu','Dock');for($i=0;$i -lt 5;$i++){Set-Combo $keys[$i] $map[$i]}
  $ui.MenuTranslucent.IsChecked=($Name -in @('NEXO','NEON','MAC'));$ui.ExplorerTranslucent.IsChecked=$ui.MenuTranslucent.IsChecked
 }finally{$script:loading=$false}
 Update-Selection;Update-Preview
}
function Set-Gauge([string]$Name,$Value){
 if($null -eq $Value){$ui['GaugeValue'+$Name].Text='—';return}
 $v=[math]::Max(0,[math]::Min(100,[double]$Value));$ui['GaugeValue'+$Name].Text=([int]$v).ToString()+'%'
 if($v -eq 0){$ui['Gauge'+$Name].Data=$null;return}
 $angle=2*[math]::PI*[math]::Min($v,99.99)/100
 $x=(33+30*[math]::Sin($angle)).ToString('0.00',[Globalization.CultureInfo]::InvariantCulture);$y=(33-30*[math]::Cos($angle)).ToString('0.00',[Globalization.CultureInfo]::InvariantCulture);$large=if($v -gt 50){1}else{0}
 $ui['Gauge'+$Name].Data=[Windows.Media.Geometry]::Parse("M 33,3 A 30,30 0 $large 1 $x,$y")
}
function Show-Inventory {
 $i=$script:inventory
 $ui.CPUText.Text='CPU: '+$i.CPUName;$ui.BoardText.Text='PCB: '+$i.Model;$ui.RAMText.Text='RAM: '+$i.RAMGB+' GB'
 Set-Gauge 'CPU' $i.CPUPercent;Set-Gauge 'RAM' $i.MemoryPercent;Set-Gauge 'Disk' $i.DrivePercent
 $ui.HardwareFooter.ToolTip='Lectura de hardware al abrir · '+$i.SampleTime+' · no es un monitor en tiempo real'
 $ui.ProcessOS.Text=$i.OS+' · build '+$i.Build;$ui.ProcessBoard.Text=$i.Model;$ui.ProcessProcessor.Text=$i.CPUName;$ui.ProcessMemory.Text=[string]$i.RAMGB+' GB';$ui.ProcessDrive.Text=$env:SystemDrive+' · '+$i.DrivePercent+'% ocupado'
}
function Open-Engine([switch]$WithSelection){
 if($SmokeTest){throw 'La prueba de interfaz no puede abrir el motor.'}
 $args='-NoProfile -STA -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'Engine.ps1')+'"'
 if($WithSelection){
  Save-Selection;$prepared=Get-PreparedSelection
  if($prepared.Request.Ids.Count -eq 0){throw 'No hay acciones disponibles seleccionadas.'}
  $path=Join-Path $script:dataRoot ('wizard-request-'+[guid]::NewGuid().ToString('N')+'.json');Save-NexoJson $prepared.Request $path
  $args+=' -SelectionPath "'+$path+'"'
 }
 Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $args -WindowStyle Hidden
}
# Buttons use their own tags/names, avoiding captured loop variables.
foreach($group in $catalog.cards.PSObject.Properties){foreach($card in $group.Value){$ui[$card.control].Add_Click({try{$parts=([string]$this.Tag).Split('|');$state.Cards[$parts[0]]=$parts[1];Update-Selection;Show-Page ($script:page+1)}catch{Notify-Error $_.Exception.Message}})}}
foreach($c in $catalog.checks){
 $ui[$c.control].ToolTip=if($c.action){($script:coreCatalog|Where-Object Id -eq $c.action).Detail}else{'Pendiente de implementación. La selección se guarda, pero no se ejecutará.'}
 $ui[$c.control].Add_Click({Update-Selection})
}
foreach($n in @('Word','Excel','PowerPoint','Outlook','Access','Visio','Publisher','OneNote')){$ui['Office'+$n].ToolTip='Selección de Office: instalación pendiente de implementación.';$ui['Office'+$n].Add_Click({Update-Selection})}
foreach($p in $catalog.combos.PSObject.Properties){$ui[$p.Name].Add_SelectionChanged({if(-not $script:loading){$state.Theme='';Update-Selection;Update-Preview}})}
foreach($t in $catalog.themes){$ui['Theme'+$t].Tag=$t;$ui['Theme'+$t].Add_Click({Select-Theme ([string]$this.Tag)})}
$ui.RandomTheme.Add_Click({Select-Theme ($catalog.themes|Get-Random)})
$ui.ResetTheme.Add_Click({Select-Theme 'BASIC';$state.Theme='';$state.CustomIncluded=$false;Update-Selection})
$ui.Back.Add_Click({Show-Page ($script:page-1)})
$ui.Decline.Add_Click({$window.Close()})
$ui.Accept.Add_Click({Show-Page 1})
$ui.WelcomeNext.Add_Click({Read-Selection;Show-Page 2})
$ui.OfficeNext.Add_Click({Update-Selection;Show-Page 7})
$ui.OfficeSkip.Add_Click({foreach($n in @('Word','Excel','PowerPoint','Outlook','Access','Visio','Publisher','OneNote')){$ui['Office'+$n].IsChecked=$false};Update-Selection;Show-Page 7})
$ui.AppsNext.Add_Click({Update-Selection;Show-Page 8})
$ui.OfficeNext.ToolTip='En esta vista guarda la selección y continúa; la instalación de Office está pendiente.'
$ui.CustomNext.ToolTip='En esta vista guarda las preferencias y continúa; los temas no se instalan.'
$ui.CustomNext.Add_Click({$state.CustomIncluded=$true;Update-Selection;Show-Page 9})
$ui.DebloatNext.Add_Click({Update-Selection;Show-Page 11})
$ui.SaveSelection.Add_Click({try{Save-Selection}catch{Notify-Error $_.Exception.Message}})
$ui.ReviewEngine.Add_Click({try{Open-Engine -WithSelection}catch{Notify-Error $_.Exception.Message}})
$ui.OpenEngine.Add_Click({try{Open-Engine}catch{Notify-Error $_.Exception.Message}})
$ui.PreviewProcess.Add_Click({Show-Page 12})
$ui.ProcessFinish.Add_Click({try{Save-Selection;Show-Page 13}catch{Notify-Error $_.Exception.Message}})
$ui.ReviewFinish.Add_Click({try{Save-Selection;Show-Page 13}catch{Notify-Error $_.Exception.Message}})
$ui.FinishExit.Add_Click({$window.Close()})
$ui.About.Add_Click({[Windows.MessageBox]::Show('Nexo Assistant 0.3. Interfaz de evaluación basada en las pantallas públicas de DELTA v13. Proyecto independiente. Consulta LEEME.md y REFERENCIAS.md para conocer el alcance, las imágenes de referencia y las acciones implementadas.','Acerca de Nexo','OK','Information')|Out-Null})
$ui.DateLabel.Text=(Get-Date).ToString('dd MMMM yyyy · h:mm tt',[Globalization.CultureInfo]::GetCultureInfo('es-CO'))
function Save-Capture([string]$Path){
 $window.UpdateLayout()
 $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap(1920,1080,96,96,[Windows.Media.PixelFormats]::Pbgra32)
 $visual=New-Object Windows.Media.DrawingVisual;$dc=$visual.RenderOpen();$brush=New-Object Windows.Media.VisualBrush($ui.Design)
 $dc.DrawRectangle($brush,$null,(New-Object Windows.Rect(0,0,1920,1080)));$dc.Close();$bitmap.Render($visual)
 $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create($Path);try{$encoder.Save($stream)}finally{$stream.Dispose()}
}
function Invoke-UiTests {
 $script:testResults=New-Object 'System.Collections.Generic.List[object]'
 function Assert-Ui([bool]$Ok,[string]$Name){if(-not $Ok){throw "Prueba fallida: $Name"};$script:testResults.Add([pscustomobject]@{Name=$Name;Passed=$true})}
 function Click($Control){$Control.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))}
 foreach($i in 0..13){Show-Page $i;$visible=@($catalog.pages|Where-Object {$ui['Page'+$_].Visibility -eq 'Visible'});Assert-Ui ($visible.Count -eq 1 -and $visible[0] -eq $catalog.pages[$i]) "Pantalla $i exclusiva"}
 Show-Page 0;Click $ui.Accept;Assert-Ui ($script:page -eq 1) 'Aceptar abre bienvenida';Click $ui.WelcomeNext;Assert-Ui ($script:page -eq 2) 'Bienvenida abre migración'
 Click $ui.Migration0;Assert-Ui ($script:page -eq 3 -and $state.Cards.Migration -eq 'Professional') 'Migración guarda y avanza'
 Click $ui.Gpu1;Click $ui.Back;Click $ui.Gpu2;Assert-Ui ($state.Cards.Gpu -eq 'AMD' -and $ui.Gpu1.Content -eq 'Seleccionar') 'GPU excluyente y corrección al volver'
 Click $ui.Disk0;Click $ui.Device1;Assert-Ui ($script:page -eq 6 -and $state.Cards.Device -eq 'Laptop') 'Disco y equipo siguen orden'
 $ui.OfficeWord.IsChecked=$true;Update-Selection;Assert-Ui ($ui.OfficeCount.Text -eq '1 de 8') 'Contador Office';Click $ui.OfficeSkip;Assert-Ui (-not $ui.OfficeWord.IsChecked -and $script:page -eq 7) 'Omitir limpia Office'
 $ui.App2_2.IsChecked=$true;$ui.App1_1.IsChecked=$true;Update-Selection;Assert-Ui ($ui.AppCount.Text -eq '2 de 20') 'Contador de aplicaciones'
 Click $ui.AppsNext;Click $ui.ThemeNEON;Assert-Ui ($ui.Wallpaper.SelectedItem.Content -eq 'Wallpaper Neon' -and $ui.Dock.SelectedItem.Content -eq 'Dock Neon') 'Tema actualiza controles'
 Click $ui.ResetTheme;Assert-Ui ($ui.Rainmeter.SelectedItem.Content -eq 'Ninguno' -and -not $ui.MenuTranslucent.IsChecked) 'Restablecer tema'
 Click $ui.ThemeNEXO;Click $ui.CustomNext;Click $ui.Mode0;$ui.Debloat13.IsChecked=$true;Click $ui.DebloatNext
 $prepared=Get-PreparedSelection;Assert-Ui ($prepared.Request.Ids.Count -eq 2 -and 'app.vlc' -in $prepared.Request.Ids -and 'remove.clipchamp' -in $prepared.Request.Ids) 'Solo acciones implementadas pasan al motor'
 Assert-Ui ('Google Chrome' -in $prepared.Pending -and @($prepared.Pending|Where-Object {$_ -like 'Modo*'}).Count -eq 1) 'Pendientes se explican sin traducirlos a otras acciones'
 Assert-Ui ($ui.ReviewEngine.IsEnabled -and $ui.PendingSummary.Text.Contains('Google Chrome')) 'Resumen separa capacidades'
 Save-Selection;$ui.App2_2.IsChecked=$false;$state.Cards.Clear();Restore-Selection
 Assert-Ui ($ui.App2_2.IsChecked -and $state.Cards.Gpu -eq 'AMD') 'Guardar y restaurar selecciones'
 foreach($c in $catalog.checks){$ui[$c.control].IsChecked=$false};Show-Review;Assert-Ui (-not $ui.ReviewEngine.IsEnabled) 'Plan vacío no abre ejecución'
 $ui.App2_2.IsChecked=$true;Update-Selection;Save-Selection;Show-Page 0
}
$window.Add_ContentRendered({
 if($script:started){return};$script:started=$true
 try{
  $script:inventory=Get-NexoInventory;Show-Inventory
  if(-not $SmokeTest){Restore-Selection}
  Update-Selection;Update-Preview;Show-Page 0
  if($SmokeTest){
   if($TestUi){Invoke-UiTests}
   if($CaptureFolder){[IO.Directory]::CreateDirectory($CaptureFolder)|Out-Null}
   $script:captureIndex=if($CaptureFolder){0}else{$SmokePage};$script:capturePhase='prepare'
   $script:captureTimer=New-Object Windows.Threading.DispatcherTimer;$captureTimer.Interval=[TimeSpan]::FromMilliseconds(260)
   $captureTimer.Add_Tick({try{
    if($script:capturePhase -eq 'prepare'){Show-Page $script:captureIndex;$script:capturePhase='save';return}
    $path=$ScreenshotPath;if($CaptureFolder){$path=Join-Path $CaptureFolder (('{0:00}' -f ($script:captureIndex+1))+'-'+$catalog.pages[$script:captureIndex]+'.png')}
    if($path){Save-Capture $path}
    if($CaptureFolder -and $script:captureIndex -lt 13){$script:captureIndex++;$script:capturePhase='prepare'}else{
     $captureTimer.Stop()
     if($TestUi){Save-NexoJson ([pscustomobject]@{Passed=$script:testResults.Count;Failed=0;Screens=14;Tests=$script:testResults.ToArray();ChangesToWindows='Ninguno; solo archivo de selección de prueba'}) (Join-Path $CaptureFolder 'ui-tests.json')}
     $window.Close()
    }
   }catch{$captureTimer.Stop();$script:smokeError=$_.Exception.ToString();$window.Close()}});$captureTimer.Start()
  }
 }catch{Notify-Error $_.Exception.ToString()}
})
Show-Page 0
$null=$window.ShowDialog()
if($script:smokeError){throw $script:smokeError}
