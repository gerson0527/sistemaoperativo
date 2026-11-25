param([ValidateSet('Widget','Menu','Dock')][string]$Mode='Menu',[string]$Style='NEXO',[switch]$SmokeTest,[string]$ScreenshotPath)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$mutex=New-Object Threading.Mutex($false,('Local\NexoDesktop'+$Mode))
$held=$false
try {
    try {$held=$mutex.WaitOne(0)} catch [Threading.AbandonedMutexException] {$held=$true}
    if(!$held -and !$SmokeTest){exit 0}
    $window=New-Object Windows.Window
    $window.Title='Nexo '+$Mode
    $window.Width=420; $window.Height=500
    $window.Background='#101B2B';$window.Foreground='White';$window.FontFamily='Segoe UI'
    $window.WindowStartupLocation='CenterScreen'
    $panel=New-Object Windows.Controls.StackPanel;$panel.Margin=18
    $scroll=New-Object Windows.Controls.ScrollViewer;$scroll.Content=$panel;$scroll.VerticalScrollBarVisibility='Auto';$window.Content=$scroll
    $heading=New-Object Windows.Controls.TextBlock;$heading.Text='Nexo · '+$Mode;$heading.FontSize=22;$heading.Margin='0,0,0,14';$null=$panel.Children.Add($heading)
    if($Style -match 'Fluent|Canopy|Win7'){$window.Background='#193A34'}
    if($Style -match 'MAC|Round|Win11'){$window.Background='#313440'}
    if($Style -match 'Neon'){$window.Background='#28173D'}
    if($Mode -eq 'Widget'){
        $window.Width=310;$window.Height=230;$window.ResizeMode='NoResize'
        $clock=New-Object Windows.Controls.TextBlock;$clock.FontSize=36;$null=$panel.Children.Add($clock)
        $metrics=New-Object Windows.Controls.TextBlock;$metrics.FontSize=16;$metrics.TextWrapping='Wrap';$null=$panel.Children.Add($metrics)
        $timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromSeconds(10)
        $update={
            $clock.Text=Get-Date -Format 'HH:mm:ss'
            try{
                $os=Get-CimInstance Win32_OperatingSystem
                $load=(Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average
                $metrics.Text=('CPU {0}% · RAM {1}%'+"`n"+'{2}') -f [int]$load,[int](100*(1-$os.FreePhysicalMemory/$os.TotalVisibleMemorySize)),(Get-Date -Format 'dddd dd MMMM')
            }catch{$metrics.Text='Lectura de hardware no disponible'}
        }
        $timer.Add_Tick($update);$window.Add_ContentRendered($update);$timer.Start()
        $window.Add_Closed({$timer.Stop()})
    }else{
        $search=New-Object Windows.Controls.TextBox;$search.Margin='0,0,0,12';$search.ToolTip='Buscar aplicaciones';$null=$panel.Children.Add($search)
        $list=New-Object Windows.Controls.StackPanel;$null=$panel.Children.Add($list)
        $entries=@(
            [pscustomobject]@{Name='Archivos';Path='explorer.exe'},
            [pscustomobject]@{Name='Configuración';Path='ms-settings:'},
            [pscustomobject]@{Name='Calculadora';Path='calc.exe'}
        )
        $folders=@([Environment]::GetFolderPath('Programs'),[Environment]::GetFolderPath('CommonPrograms'))
        $entries+=@(Get-ChildItem -LiteralPath $folders -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue | Sort-Object BaseName -Unique | ForEach-Object {[pscustomobject]@{Name=$_.BaseName;Path=$_.FullName}})
        foreach($entry in $entries){
            $button=New-Object Windows.Controls.Button;$button.Content=$entry.Name;$button.Tag=$entry.Path;$button.Margin='0,0,0,6';$button.Padding=8;$button.HorizontalContentAlignment='Left'
            $button.Add_Click({try{Start-Process -FilePath ([string]$this.Tag) -ErrorAction Stop}catch{[Windows.MessageBox]::Show($_.Exception.Message,'Nexo')|Out-Null}})
            $null=$list.Children.Add($button)
        }
        $search.Add_TextChanged({foreach($button in $list.Children){$button.Visibility=if(([string]$button.Content).IndexOf($search.Text,[StringComparison]::OrdinalIgnoreCase) -ge 0){'Visible'}else{'Collapsed'}}})
        if($Mode -eq 'Dock'){$window.Width=280;$window.Height=440;$window.Left=[Windows.SystemParameters]::WorkArea.Right-300;$window.Top=[Windows.SystemParameters]::WorkArea.Bottom-460;$window.WindowStartupLocation='Manual'}
    }
    if($SmokeTest){
        $window.Add_ContentRendered({
            $window.UpdateLayout()
            if($ScreenshotPath){
                $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap([int]$window.ActualWidth,[int]$window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($window)
                $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create($ScreenshotPath)
                try{$encoder.Save($stream)}finally{$stream.Dispose()}
            }
            $window.Close()
        })
    }
    $null=$window.ShowDialog()
}finally{if($held){$mutex.ReleaseMutex()};$mutex.Dispose()}
