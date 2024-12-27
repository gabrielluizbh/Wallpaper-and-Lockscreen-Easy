# Carregar as assemblies necessárias
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Adicionando um ícone personalizado ao formulário
$iconPath = "https://vhdxgabrielluiz.blob.core.windows.net/vhdx/gabrielluiz-icone.ico"
$iconTempPath = [System.IO.Path]::GetTempFileName() + ".ico"
$webClient = New-Object System.Net.WebClient
$webClient.DownloadFile($iconPath, $iconTempPath) # Baixe o ícone e salve-o temporariamente
$icon = New-Object System.Drawing.Icon($iconTempPath)

# Função para selecionar um arquivo de imagem
function Select-ImageFile {
    $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog
    $fileBrowser.Filter = "Image Files (*.jpg;*.jpeg;*.png)|*.jpg;*.jpeg;*.png"
    if ($fileBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $fileBrowser.FileName
    }
    return $null
}

# Função para criar um label
function New-Label {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y
    )
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    return $label
}

# Função para criar um TextBox
function New-TextBox {
    param(
        [int]$Width,
        [int]$Height,
        [int]$X,
        [int]$Y
    )
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Size = New-Object System.Drawing.Size($Width, $Height)
    $textBox.Location = New-Object System.Drawing.Point($X, $Y)
    return $textBox
}

# Função para criar um Button
function New-Button {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [scriptblock]$OnClick
    )
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, $Height)
    if ($OnClick) {
        $button.Add_Click($OnClick)
    }
    return $button
}

# Função para criar os scripts necessários
function Create-Scripts {
    param(
        [string]$Version,
        [string]$WallpaperFile,
        [string]$LockscreenFile,
        [string]$BaseFolderPath
    )

    $dataFolderPath = "$BaseFolderPath\data"

    # Garantir que os diretórios existam
    New-Item -Path $dataFolderPath -ItemType Directory -Force | Out-Null

    # Copiar e renomear as imagens
    Copy-Item -Path $WallpaperFile -Destination "$dataFolderPath\background.jpg" -Force
    Copy-Item -Path $LockscreenFile -Destination "$dataFolderPath\Lockscreen.jpg" -Force

    # Conteúdo do install.ps1
    $installScriptContent = @"
`$PackageName = "Wallpaper"
`$Version = "$Version"

`$WallpaperIMG = "background.jpg"
`$LockscreenIMG = "Lockscreen.jpg"

Start-Transcript -Path "`$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\`$PackageName-install.log" -Force
`$ErrorActionPreference = "Stop"

`$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
`$DesktopPath = "DesktopImagePath"
`$DesktopStatus = "DesktopImageStatus"
`$DesktopUrl = "DesktopImageUrl"
`$LockScreenPath = "LockScreenImagePath"
`$LockScreenStatus = "LockScreenImageStatus"
`$LockScreenUrl = "LockScreenImageUrl"
`$StatusValue = "1"

`$WallpaperLocalIMG = "C:\Windows\System32\Desktop.jpg"
`$LockscreenLocalIMG = "C:\Windows\System32\Lockscreen.jpg"

if (!`$LockscreenIMG -and !`$WallpaperIMG){
    Write-Warning "Either LockscreenIMG or WallpaperIMG must have a value."
}
else{
    if(!(Test-Path `$RegKeyPath)){
        Write-Host "Creating registry path: `$(`$RegKeyPath)."
        New-Item -Path `$RegKeyPath -Force | Out-Null
    }
    if (`$LockscreenIMG){
        Write-Host "Copy lockscreen `$(`$LockscreenIMG)` to `$(`$LockscreenLocalIMG)`"
        Copy-Item ".\Data\`$LockscreenIMG" `$LockscreenLocalIMG -Force
        Write-Host "Creating regkeys for lockscreen"
        New-ItemProperty -Path `$RegKeyPath -Name `$LockScreenStatus -Value `$StatusValue -PropertyType DWORD -Force | Out-Null
        New-ItemProperty -Path `$RegKeyPath -Name `$LockScreenPath -Value `$LockscreenLocalIMG -PropertyType STRING -Force | Out-Null
        New-ItemProperty -Path `$RegKeyPath -Name `$LockScreenUrl -Value `$LockscreenLocalIMG -PropertyType STRING -Force | Out-Null
    }
    if (`$WallpaperIMG){
        Write-Host "Copy wallpaper `$(`$WallpaperIMG)` to `$(`$WallpaperLocalIMG)`"
        Copy-Item ".\Data\`$WallpaperIMG" `$WallpaperLocalIMG -Force
        Write-Host "Creating regkeys for wallpaper"
        New-ItemProperty -Path `$RegKeyPath -Name `$DesktopStatus -Value `$StatusValue -PropertyType DWORD -Force | Out-Null
        New-ItemProperty -Path `$RegKeyPath -Name `$DesktopPath -Value `$WallpaperLocalIMG -PropertyType STRING -Force | Out-Null
        New-ItemProperty -Path `$RegKeyPath -Name `$DesktopUrl -Value `$WallpaperLocalIMG -PropertyType STRING -Force | Out-Null
    }  
}

New-Item -Path "C:\ProgramData\scloud\Validation\`$PackageName" -ItemType "file" -Force -Value `$Version | Out-Null

Stop-Transcript
"@

    # Criar o install.ps1
    Set-Content -Path "$BaseFolderPath\install.ps1" -Value $installScriptContent

    # Conteúdo do check.ps1
    $checkScriptContent = @"
`$PackageName = "Wallpaper"
`$Version = "$Version"

`$ValidationFile = "C:\ProgramData\scloud\Validation\`$PackageName"

if (Test-Path `$ValidationFile) {
    `$ProgramVersion_current = (Get-Content -Path `$ValidationFile -Raw).Trim()
    if (`$ProgramVersion_current -eq `$Version) {
        Write-Host "Found it!"
        exit 0
    } else {
        Write-Host "Version mismatch. Expected `$Version, found `$ProgramVersion_current."
        exit 1
    }
} else {
    Write-Host "Validation file not found."
    exit 1
}
"@
    # Criar o check.ps1
    Set-Content -Path "$BaseFolderPath\check.ps1" -Value $checkScriptContent

    # Conteúdo do uninstall.ps1
    $uninstallScriptContent = @"
`$PackageName = "Wallpaper"

`$WallpaperIMG = "background.jpg"
`$LockscreenIMG = "Lockscreen.jpg"

Start-Transcript -Path "`$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\`$PackageName-uninstall.log" -Force
`$ErrorActionPreference = "Stop"

`$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
`$DesktopPath = "DesktopImagePath"
`$DesktopStatus = "DesktopImageStatus"
`$DesktopUrl = "DesktopImageUrl"
`$LockScreenPath = "LockScreenImagePath"
`$LockScreenStatus = "LockScreenImageStatus"
`$LockScreenUrl = "LockScreenImageUrl"

if (!`$LockscreenIMG -and !`$WallpaperIMG){
    Write-Warning "Either LockscreenIMG or WallpaperIMG must have a value."
}
else{
    if(!(Test-Path `$RegKeyPath)){
        Write-Warning "The path `$RegKeyPath does not exist. Therefore, no wallpaper or lockscreen is set by this package."
    }
    if (`$LockscreenIMG){
        Write-Host "Deleting registry keys for lockscreen"
        Remove-ItemProperty -Path `$RegKeyPath -Name `$LockScreenStatus -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path `$RegKeyPath -Name `$LockScreenPath -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path `$RegKeyPath -Name `$LockScreenUrl -Force -ErrorAction SilentlyContinue
    }
    if (`$WallpaperIMG){
        Write-Host "Deleting registry keys for wallpaper"
        Remove-ItemProperty -Path `$RegKeyPath -Name `$DesktopStatus -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path `$RegKeyPath -Name `$DesktopPath -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path `$RegKeyPath -Name `$DesktopUrl -Force -ErrorAction SilentlyContinue
    }  
}

Write-Host "Deleting Validation file."
Remove-Item -Path "C:\ProgramData\scloud\Validation\`$PackageName" -Force -ErrorAction SilentlyContinue

Stop-Transcript
"@

    # Criar o uninstall.ps1
    Set-Content -Path "$BaseFolderPath\uninstall.ps1" -Value $uninstallScriptContent
}

# Criar o formulário principal
$form = New-Object System.Windows.Forms.Form
$form.Text = "Configuração de Wallpaper e Lockscreen"
$form.Size = New-Object System.Drawing.Size(660, 330)
$form.StartPosition = "CenterScreen"

# Definir o ícone do formulário
$form.Icon = $icon

# Campo de texto para a versão
$labelVersion = New-Label -Text "Versão:" -X 10 -Y 20
$form.Controls.Add($labelVersion)

$textBoxVersion = New-TextBox -Width 100 -Height 20 -X 150 -Y 20
$form.Controls.Add($textBoxVersion)

# Campo de texto para o caminho da imagem de wallpaper
$labelWallpaper = New-Label -Text "Imagem do Wallpaper:" -X 10 -Y 60
$form.Controls.Add($labelWallpaper)

$textBoxWallpaper = New-TextBox -Width 400 -Height 20 -X 150 -Y 60
$form.Controls.Add($textBoxWallpaper)

$buttonWallpaper = New-Button -Text "Selecionar" -X 560 -Y 58 -Width 75 -Height 23 -OnClick {
    $wallpaperFile = Select-ImageFile
    if ($wallpaperFile) {
        $textBoxWallpaper.Text = $wallpaperFile
    }
}
$form.Controls.Add($buttonWallpaper)

# Campo de texto para o caminho da imagem de lockscreen
$labelLockscreen = New-Label -Text "Imagem da Lockscreen:" -X 10 -Y 100
$form.Controls.Add($labelLockscreen)

$textBoxLockscreen = New-TextBox -Width 400 -Height 20 -X 150 -Y 100
$form.Controls.Add($textBoxLockscreen)

$buttonLockscreen = New-Button -Text "Selecionar" -X 560 -Y 98 -Width 75 -Height 23 -OnClick {
    $lockscreenFile = Select-ImageFile
    if ($lockscreenFile) {
        $textBoxLockscreen.Text = $lockscreenFile
    }
}
$form.Controls.Add($buttonLockscreen)

# Botão para executar a configuração
$buttonExecute = New-Button -Text "Executar" -X 200 -Y 140 -Width 75 -Height 23 -OnClick {
    $version = $textBoxVersion.Text
    $wallpaperFile = $textBoxWallpaper.Text
    $lockscreenFile = $textBoxLockscreen.Text

    if ($version -and $wallpaperFile -and $lockscreenFile) {
        $baseFolderPath = "C:\wallpaper-gabrielluiz"
        Create-Scripts -Version $version -WallpaperFile $wallpaperFile -LockscreenFile $lockscreenFile -BaseFolderPath $baseFolderPath

        [System.Windows.Forms.MessageBox]::Show("Scripts e imagens configurados com sucesso!", "Sucesso")
    } else {
        [System.Windows.Forms.MessageBox]::Show("Por favor, preencha todos os campos corretamente.", "Erro")
    }
}
$form.Controls.Add($buttonExecute)

# Botão para limpar os campos
$buttonClear = New-Button -Text "Limpar" -X 320 -Y 140 -Width 75 -Height 23 -OnClick {
    $textBoxVersion.Clear()
    $textBoxWallpaper.Clear()
    $textBoxLockscreen.Clear()
}
$form.Controls.Add($buttonClear)

# Botão para abrir o link IntuneWinAppUtilGUI
$buttonIntuneWinAppUtilGUI = New-Button -Text "IntuneWinAppUtilGUI" -X 250 -Y 180 -Width 150 -Height 23 -OnClick {
    Start-Process "https://github.com/gabrielluizbh/IntuneWinAppUtilGUI"
}
$form.Controls.Add($buttonIntuneWinAppUtilGUI)

# Adicionar a imagem abaixo do botão
try {
    $imageURL = "https://vhdxgabrielluiz.blob.core.windows.net/vhdx/perfil.png"
    $webClient = New-Object System.Net.WebClient
    $stream = $webClient.OpenRead($imageURL)
    $iconImage = [System.Drawing.Image]::FromStream($stream)
    $stream.Close()
    $webClient.Dispose()

    $pictureBox = New-Object System.Windows.Forms.PictureBox
    $pictureBox.Image = $iconImage
    $pictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
    $pictureBox.Size = New-Object System.Drawing.Size(64, 64)
    $pictureBox.Location = New-Object System.Drawing.Point(290, 210)
    $pictureBox.Cursor = [System.Windows.Forms.Cursors]::Hand
    $pictureBox.Add_Click({
        Start-Process "https://gabrielluiz.com"
    })
    $form.Controls.Add($pictureBox)
} catch {
    Write-Host "Não foi possível carregar a imagem: $_"
}

# Executar o formulário
[System.Windows.Forms.Application]::Run($form)
