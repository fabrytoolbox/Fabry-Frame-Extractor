# Fabry-Frame-Extractor-GUI.ps1 - v2.5
# Estrae frame da video con GUI Matrix
# CUDA per upscale, sharpening delegato a Topaz, gestione spazi e bugfix

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================
# AUTO-FFMPEG
# ============================================================
$script:workDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$ffmpegPath = Join-Path $script:workDir "ffmpeg.exe"

function Initialize-FFmpeg {
    if (-not (Test-Path $ffmpegPath)) {
        $resp = [Windows.Forms.MessageBox]::Show("FFmpeg non trovato. Vuoi scaricarlo automaticamente?", "FFmpeg Missing", [Windows.Forms.MessageBoxButtons]::YesNo)
        if ($resp -eq "No") { return $false }

        $zipPath = Join-Path $env:TEMP "ffmpeg_dl.zip"
        $extractPath = Join-Path $env:TEMP "ffmpeg_temp"
        $url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
        
        try {
            Write-Host "Download FFmpeg in corso..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
            Get-ChildItem -Path $extractPath -Include "ffmpeg.exe", "ffprobe.exe" -Recurse | ForEach-Object {
                Move-Item $_.FullName $script:workDir -Force
            }
            Remove-Item $zipPath -Force
            Remove-Item $extractPath -Recurse -Force
            [Windows.Forms.MessageBox]::Show("FFmpeg scaricato con successo!")
            return $true
        } catch {
            [Windows.Forms.MessageBox]::Show("Errore download: $($_.Exception.Message)")
            return $false
        }
    }
    return $true
}

if (-not (Initialize-FFmpeg)) { exit }

# ============================================================
# DURATA VIDEO
# ============================================================
function Get-VideoDuration {
    param([string]$VideoPath)
    try {
        $output = & $ffmpegPath -i $VideoPath -hide_banner 2>&1 | Out-String
        if ($output -match 'Duration:\s*(\d{2}):(\d{2}):(\d{2})\.(\d{2})') {
            $h = [int]$Matches[1]
            $m = [int]$Matches[2]
            $s = [int]$Matches[3]
            $cs = [int]$Matches[4]
            return ($h * 3600) + ($m * 60) + $s + ($cs / 100)
        }
        return 0
    } catch {
        return 0
    }
}

# ============================================================
# CONFIGURAZIONE
# ============================================================
$script:videoFiles = @()
$script:outDir = ""
$script:logFile = $null
$script:currentProcess = $null
$script:totalFiles = 0
$script:currentFileIndex = 0
$script:isWorking = $false
$presetFile = Join-Path $script:workDir "matrix_settings.json"

$ColorBalanceMap = @{
    "Off" = $null
    "Luminoso/Bilanciato" = "colorbalance=gm=0.1:bs=-0.05" 
    "Caldo/Saturato" = "colorbalance=rs=0.15:rh=0.1:bs=-0.1"
}

# ============================================================
# LOGGING
# ============================================================
function Start-Log {
    param([string]$Folder)
    if (-not (Test-Path $Folder)) { New-Item -ItemType Directory -Path $Folder -Force | Out-Null }
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:logFile = Join-Path $Folder "frame_extractor_$timestamp.log"
    @(
        "============================================================",
        " FRAME EXTRACTOR - LOG",
        "============================================================",
        "Data inizio: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "Output: $Folder",
        "============================================================",
        ""
    ) | Set-Content -Path $script:logFile -Encoding UTF8
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    if (-not $script:logFile) { return }
    $line = "[$(Get-Date -Format 'HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $script:logFile -Value $line -Encoding UTF8
}

# ============================================================
# UI MATRIX STYLE
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "FABRY FRAME EXTRACTOR v2.5"
$form.Size = New-Object System.Drawing.Size(680,780) 
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::Black
$form.ForeColor = [System.Drawing.Color]::Lime
$form.Font = New-Object System.Drawing.Font("Consolas", 9)

function New-MatrixButton($txt, $x, $y, $w, $h) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $txt; $btn.Location = New-Object System.Drawing.Point($x,$y); $btn.Size = New-Object System.Drawing.Size($w,$h)
    $btn.FlatStyle = "Flat"; $btn.FlatAppearance.BorderColor = "Lime"; $btn.BackColor = "Black"; $btn.ForeColor = "Lime"
    return $btn
}

# --- Selezione File e Cartella ---
$btnVideo = New-MatrixButton "SELECT SOURCE" 20 20 120 30
$lblVideo = New-Object System.Windows.Forms.Label; $lblVideo.Text = "WAITING FOR INPUT..."; $lblVideo.Location = New-Object System.Drawing.Point(150,25); $lblVideo.Size = New-Object System.Drawing.Size(500,30)
$btnVideo.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Multiselect = $true
    $dialog.Filter = "Video files (*.mp4;*.mkv;*.avi;*.mov;*.wmv;*.flv;*.ts)|*.mp4;*.mkv;*.avi;*.mov;*.wmv;*.flv;*.ts|All files (*.*)|*.*"
    if ($dialog.ShowDialog() -eq "OK") {
        $script:videoFiles = @($dialog.FileNames)
        $lblVideo.Text = "FILES LOADED: $($script:videoFiles.Count)"
    }
})

$btnOutput = New-MatrixButton "DESTINATION" 20 60 120 30
$lblOutput = New-Object System.Windows.Forms.Label; $lblOutput.Text = "SET OUTPUT PATH..."; $lblOutput.Location = New-Object System.Drawing.Point(150,65); $lblOutput.Size = New-Object System.Drawing.Size(500,30)
$btnOutput.Add_Click({ 
    $f = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($f.ShowDialog() -eq "OK") { 
        $script:outDir = $f.SelectedPath
        $lblOutput.Text = $script:outDir
    } 
})

# --- Settings ---
$lblQual = New-Object System.Windows.Forms.Label; $lblQual.Text = "QUALITY (1-31):"; $lblQual.Location = New-Object System.Drawing.Point(20,110); $lblQual.Size = New-Object System.Drawing.Size(140,20)
$txtQuality = New-Object System.Windows.Forms.TextBox; $txtQuality.Text = "2"; $txtQuality.Location = New-Object System.Drawing.Point(160,110); $txtQuality.Size = New-Object System.Drawing.Size(50,20); $txtQuality.BackColor = "Black"; $txtQuality.ForeColor = "Lime"

$chkCuda = New-Object System.Windows.Forms.CheckBox; $chkCuda.Text = "USE CUDA (GPU)"; $chkCuda.Location = New-Object System.Drawing.Point(250,110); $chkCuda.Size = New-Object System.Drawing.Size(180,20); $chkCuda.ForeColor = "Lime"

$chkInterval = New-Object System.Windows.Forms.CheckBox; $chkInterval.Text = "FPS ESTRAZIONE (1/X):"; $chkInterval.Checked = $true; $chkInterval.Location = New-Object System.Drawing.Point(20,140); $chkInterval.Size = New-Object System.Drawing.Size(180,20); $chkInterval.ForeColor = "Lime"
$txtInterval = New-Object System.Windows.Forms.TextBox; $txtInterval.Text = "1"; $txtInterval.Location = New-Object System.Drawing.Point(200,140); $txtInterval.Size = New-Object System.Drawing.Size(50,20); $txtInterval.BackColor = "Black"; $txtInterval.ForeColor = "Lime"

$chkSharpen = New-Object System.Windows.Forms.CheckBox; $chkSharpen.Text = "SHARPEN (CPU only):"; $chkSharpen.Location = New-Object System.Drawing.Point(20,170); $chkSharpen.Size = New-Object System.Drawing.Size(160,20); $chkSharpen.ForeColor = "Lime"
$txtSharpenParams = New-Object System.Windows.Forms.TextBox; $txtSharpenParams.Text = "5:5:1.0"; $txtSharpenParams.Location = New-Object System.Drawing.Point(180,170); $txtSharpenParams.Size = New-Object System.Drawing.Size(80,20); $txtSharpenParams.BackColor = "Black"; $txtSharpenParams.ForeColor = "Lime"

$lblRes = New-Object System.Windows.Forms.Label; $lblRes.Text = "OUTPUT RES:"; $lblRes.Location = New-Object System.Drawing.Point(20,205); $lblRes.Size = New-Object System.Drawing.Size(120,20)
$comboResolution = New-Object System.Windows.Forms.ComboBox; $comboResolution.Location = New-Object System.Drawing.Point(140,200); $comboResolution.Size = New-Object System.Drawing.Size(180,20); $comboResolution.DropDownStyle = "DropDownList"; $comboResolution.Items.AddRange(@("Originale", "1920x1080 (1080p)", "3840x2160 (4K)")); $comboResolution.SelectedIndex = 0; $comboResolution.BackColor = "Black"; $comboResolution.ForeColor = "Lime"

$lblCol = New-Object System.Windows.Forms.Label; $lblCol.Text = "COLOR:"; $lblCol.Location = New-Object System.Drawing.Point(20,240); $lblCol.Size = New-Object System.Drawing.Size(120,20)
$comboColor = New-Object System.Windows.Forms.ComboBox; $comboColor.Location = New-Object System.Drawing.Point(140,235); $comboColor.Size = New-Object System.Drawing.Size(180,20); $comboColor.DropDownStyle = "DropDownList"; $comboColor.Items.AddRange(@("Off", "Luminoso/Bilanciato", "Caldo/Saturato")); $comboColor.SelectedIndex = 0; $comboColor.BackColor = "Black"; $comboColor.ForeColor = "Lime"

# --- Range Temporale ---
$lblRange = New-Object System.Windows.Forms.Label; $lblRange.Text = "RANGE [START/END]:"; $lblRange.Location = New-Object System.Drawing.Point(20,280); $lblRange.Size = New-Object System.Drawing.Size(160,20); $lblRange.ForeColor = "Cyan"
$txtStart = New-Object System.Windows.Forms.TextBox; $txtStart.Text = "00:00:00"; $txtStart.Location = New-Object System.Drawing.Point(180,280); $txtStart.Size = New-Object System.Drawing.Size(80,20); $txtStart.BackColor = "Black"; $txtStart.ForeColor = "Lime"
$txtEnd = New-Object System.Windows.Forms.TextBox; $txtEnd.PlaceholderText = "EOF"; $txtEnd.Location = New-Object System.Drawing.Point(270,280); $txtEnd.Size = New-Object System.Drawing.Size(80,20); $txtEnd.BackColor = "Black"; $txtEnd.ForeColor = "Lime"

# --- Progress e Log ---
$progressBar = New-Object System.Windows.Forms.ProgressBar; $progressBar.Location = New-Object System.Drawing.Point(20,320); $progressBar.Size = New-Object System.Drawing.Size(620,20); $progressBar.Minimum = 0; $progressBar.Maximum = 100
$txtLog = New-Object System.Windows.Forms.TextBox; $txtLog.Multiline = $true; $txtLog.ScrollBars = "Vertical"; $txtLog.Location = New-Object System.Drawing.Point(20,350); $txtLog.Size = New-Object System.Drawing.Size(620,260); $txtLog.ReadOnly = $true; $txtLog.BackColor = "Black"; $txtLog.ForeColor = "Lime"; $txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)

# --- Pulsanti ---
$btnStart = New-MatrixButton ">> EXECUTE_EXTRACTION <<" 200 630 280 45
$btnStart.BackColor = "DarkGreen"; $btnStart.Font = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Bold)

$btnCancel = New-MatrixButton "ANNULLA" 200 630 280 45
$btnCancel.BackColor = "DarkRed"; $btnCancel.Font = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Bold); $btnCancel.Visible = $false

$btnSaveCfg = New-MatrixButton "SAVE PRESET" 20 690 150 30
$btnLoadCfg = New-MatrixButton "LOAD PRESET" 180 690 150 30
$btnOpen = New-MatrixButton "OPEN OUTPUT" 340 690 150 30
$btnExit = New-MatrixButton "TERMINATE" 500 690 140 30

# ============================================================
# AZIONI
# ============================================================
$btnSaveCfg.Add_Click({
    $cfg = @{ 
        Qual=$txtQuality.Text; Int=$txtInterval.Text; IntEnabled=$chkInterval.Checked
        Sharp=$txtSharpenParams.Text; SharpEnabled=$chkSharpen.Checked
        Res=$comboResolution.SelectedIndex; Col=$comboColor.SelectedIndex; Cuda=$chkCuda.Checked
    }
    $cfg | ConvertTo-Json | Out-File $presetFile -Encoding UTF8
    $txtLog.AppendText("[i] Preset salvato in: $presetFile`r`n")
})

$btnLoadCfg.Add_Click({
    if (Test-Path $presetFile) {
        $cfg = Get-Content $presetFile -Raw | ConvertFrom-Json
        $txtQuality.Text = $cfg.Qual; $txtInterval.Text = $cfg.Int
        $chkInterval.Checked = $cfg.IntEnabled; $txtSharpenParams.Text = $cfg.Sharp
        $chkSharpen.Checked = $cfg.SharpEnabled; $comboResolution.SelectedIndex = $cfg.Res
        $comboColor.SelectedIndex = $cfg.Col; $chkCuda.Checked = $cfg.Cuda
        $txtLog.AppendText("[i] Preset caricato da: $presetFile`r`n")
    } else {
        [Windows.Forms.MessageBox]::Show("Nessun preset trovato.", "INFO")
    }
})

$btnExit.Add_Click({ $form.Close() })
$btnOpen.Add_Click({ if (Test-Path $script:outDir) { Invoke-Item $script:outDir } })

$script:timer = New-Object System.Windows.Forms.Timer
$script:timer.Interval = 500

$btnCancel.Add_Click({
    if ($script:currentProcess -and -not $script:currentProcess.HasExited) {
        $script:currentProcess.Kill()
        $script:isWorking = $false
        $txtLog.AppendText("[!] Processo ANNULLATO dall'utente.`r`n")
        Write-Log "Processo ANNULLATO dall'utente" "WARN"
        $btnStart.Visible = $true
        $btnCancel.Visible = $false
    }
})

$btnStart.Add_Click({
    if ($script:videoFiles.Count -eq 0) { [Windows.Forms.MessageBox]::Show("Seleziona almeno un video!", "ERRORE"); return }
    if ([string]::IsNullOrWhiteSpace($script:outDir)) { [Windows.Forms.MessageBox]::Show("Seleziona la cartella di output!", "ERRORE"); return }
    
    $interval = [double]$txtInterval.Text
    if ($interval -le 0) { $interval = 1 }
    
    $totalFrames = 0
    $durations = @()
    
    $txtLog.AppendText("[i] Calcolo durata video...`r`n")
    $form.Refresh()
    
    foreach ($file in $script:videoFiles) {
        $dur = Get-VideoDuration -VideoPath $file
        $frames = if ($dur -gt 0) { [math]::Ceiling($dur / $interval) } else { 0 }
        $totalFrames += $frames
        $durations += [PSCustomObject]@{ Name = [System.IO.Path]::GetFileName($file); Duration = $dur; Frames = $frames }
    }
    
    $msg = "Verranno estratti i frame da $($script:videoFiles.Count) video.`n`n"
    $msg += "FPS: 1 frame ogni $interval secondo/i`nQualita: $($txtQuality.Text)`nRisoluzione: $($comboResolution.SelectedItem)`n"
    $msg += "CUDA: $(if ($chkCuda.Checked) { 'ATTIVO (GPU)' } else { 'DISATTIVO (CPU)' })`n"
    if ($chkCuda.Checked -and $chkSharpen.Checked) { $msg += "`n[!] NOTA: Con CUDA attivo, lo sharpening sara' ignorato.`n" }
    $msg += "`n--- STIMA FRAME ---`n"
    foreach ($d in $durations) {
        $durStr = if ($d.Duration -gt 0) { [TimeSpan]::FromSeconds($d.Duration).ToString("hh\:mm\:ss") } else { "??" }
        $msg += "$($d.Name): $durStr -> ~$($d.Frames) frame`n"
    }
    $msg += "`nTOTALE STIMATO: ~$totalFrames frame`n`nProcedere?"
    
    $resp = [Windows.Forms.MessageBox]::Show($msg, "CONFERMA ESTRAZIONE", [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Question)
    if ($resp -eq "No") { return }

    Start-Log -Folder $script:outDir
    $txtLog.Clear()
    $progressBar.Value = 0
    $btnStart.Visible = $false
    $btnCancel.Visible = $true
    $form.Refresh()

    $script:totalFiles = $script:videoFiles.Count
    $script:currentFileIndex = 0
    $script:isWorking = $true

    $script:ProcessNextVideo = {
        if ($script:currentFileIndex -ge $script:totalFiles -or -not $script:isWorking) {
            if ($script:isWorking) {
                $txtLog.AppendText("`r`n[MISSION ACCOMPLISHED]`r`n")
                Write-Log "Tutti i video processati." "INFO"
                $btnStart.Visible = $true
                $btnCancel.Visible = $false
                $progressBar.Value = 100
                [Windows.Forms.MessageBox]::Show("Estrazione completata!`n`nLog: $script:logFile", "DONE")
            }
            return
        }

        $file = $script:videoFiles[$script:currentFileIndex]
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($file)
        $outputPattern = Join-Path $script:outDir ("$($fileName)_%04d.jpg")
        
        $txtLog.AppendText("[!] Processing: $(Split-Path $file -Leaf)`r`n")
        Write-Log "Processing: $file" "INFO"

        $ffArgs = @()
        $ffArgs += "-err_detect"; $ffArgs += "ignore_err"
        $ffArgs += "-fflags"; $ffArgs += "+discardcorrupt"
        
        $useCuda = $chkCuda.Checked
        if ($useCuda) {
            $ffArgs += "-hwaccel"; $ffArgs += "cuda"
            $ffArgs += "-hwaccel_output_format"; $ffArgs += "cuda"
        }
        
        if ($txtStart.Text -ne "" -and $txtStart.Text -ne "00:00:00") { $ffArgs += "-ss"; $ffArgs += $txtStart.Text }
        if ($txtEnd.Text -ne "") { $ffArgs += "-to"; $ffArgs += $txtEnd.Text }
        $ffArgs += "-i"; $ffArgs += $file
        
        $vf = @()
        if ($comboColor.SelectedItem -ne "Off") { 
            if ($useCuda) { $vf += "hwdownload,format=yuv420p" }
            $vf += $ColorBalanceMap[$comboColor.SelectedItem]
        }
        
               $sc = switch($comboResolution.SelectedItem) { "1920x1080 (1080p)" {"1920:-1"} "3840x2160 (4K)" {"3840:-1"} default {$null} }
        if ($sc) {
            if ($useCuda) { 
                # 1. Upscale sulla GPU
                $vf += "scale_cuda=$sc" 
                # 2. Scarica dalla GPU alla CPU e converti nel formato giusto (nv12)
                $vf += "hwdownload,format=nv12"
                # 3. Converti in yuv420p per il salvataggio JPG
                $vf += "format=yuv420p"
            } else { 
                $vf += "scale=$sc" 
            }
        }
        
        if ($chkSharpen.Checked -and -not $useCuda) { $vf += "unsharp=$($txtSharpenParams.Text)" }
        elseif ($chkSharpen.Checked -and $useCuda) { $txtLog.AppendText("[!] CUDA attivo: sharpening ignorato`r`n") }
        
        if ($chkInterval.Checked) { $vf += "fps=1/$($txtInterval.Text)" }
        if ($vf.Count -gt 0) { $ffArgs += "-vf"; $ffArgs += ($vf -join ",") }
        
        $ffArgs += "-q:v"; $ffArgs += $txtQuality.Text
        $ffArgs += $outputPattern
        $ffArgs += "-y"

        # Costruzione stringa argomenti a prova di bomba per spazi e CUDA
        $argString = ""
        foreach ($a in $ffArgs) {
            if ($a -match '[\s\"]') {
                $argString += '"' + $a + '" '
            } else {
                $argString += $a + ' '
            }
        }

        $script:currentProcess = Start-Process -FilePath $ffmpegPath -ArgumentList $argString -PassThru -NoNewWindow

        $script:timer.Add_Tick({
            if ($script:currentProcess -and $script:currentProcess.HasExited) {
                $script:timer.Stop()
                if ($script:currentProcess.ExitCode -eq 0) {
                    $txtLog.AppendText("[OK] Completed: $fileName`r`n")
                    Write-Log "Completed: $file" "OK"
                } else {
                    $txtLog.AppendText("[X] FAILED (exit $($script:currentProcess.ExitCode)): $fileName`r`n")
                    Write-Log "FAILED (exit $($script:currentProcess.ExitCode)): $file" "ERROR"
                }
                
                $script:currentFileIndex++
                if ($script:totalFiles -gt 0 -and $script:currentFileIndex -le $script:totalFiles) {
                    $progressBar.Value = [Math]::Round(($script:currentFileIndex / $script:totalFiles) * 100)
                }
                & $script:ProcessNextVideo
            }
        })
        $script:timer.Start()
    }

    & $script:ProcessNextVideo
})

# ============================================================
# AVVIO
# ============================================================
$form.Controls.AddRange(@(
    $btnVideo, $lblVideo, $btnOutput, $lblOutput, 
    $lblQual, $txtQuality, $chkCuda, $chkInterval, $txtInterval, 
    $chkSharpen, $txtSharpenParams, $lblRes, $comboResolution, 
    $lblCol, $comboColor, $lblRange, $txtStart, $txtEnd, 
    $progressBar, $txtLog, $btnStart, $btnCancel, $btnSaveCfg, $btnLoadCfg, $btnOpen, $btnExit
))

$form.ShowDialog() | Out-Null