# CSV-Architect.ps1 - v2.0
# Genera un CSV di configurazione per Fabry-Frame-Extractor-CLI
# Default: Interval=1, Resolution=0 (Originale)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================
# VALORI DEFAULT (corretti)
# ============================================================
$DefaultValues = @{
    Interval     = 1      # 1 frame/secondo (cattura tutto)
    Quality      = 2      # alta qualità
    Sharpen      = "FALSE"
    Denoise      = "FALSE"
    Resolution   = 0      # 0 = Originale
    ColorBalance = 0      # 0 = OFF
}

# ============================================================
# UI
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "CSV ARCHITECT v2.0 - FFMPEG CONFIG GENERATOR"
$form.Size = '650,600'
$form.BackColor = "Black"
$form.ForeColor = "Lime"
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.Font = New-Object System.Drawing.Font("Consolas", 9)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "CSV CONFIGURATION PROTOCOL"
$lblTitle.Font = New-Object System.Drawing.Font("Consolas", 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.TextAlign = "MiddleCenter"
$lblTitle.Size = '610,40'
$lblTitle.Location = '10,10'
$form.Controls.Add($lblTitle)

# Lista file
$listView = New-Object System.Windows.Forms.ListBox
$listView.Location = '20,60'
$listView.Size = '590,200'
$listView.BackColor = "Black"
$listView.ForeColor = "Lime"
$listView.Font = New-Object System.Drawing.Font("Consolas", 9)
$listView.BorderStyle = "FixedSingle"
$form.Controls.Add($listView)

# Log/Status
$logBox = New-Object System.Windows.Forms.Label
$logBox.Location = '20,270'
$logBox.Size = '590,50'
$logBox.ForeColor = "DarkGreen"
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$logBox.Text = "Status: Awaiting directory selection..."
$form.Controls.Add($logBox)

# Pannello valori default
$lblDefaults = New-Object System.Windows.Forms.Label
$lblDefaults.Text = "DEFAULT VALUES (modificabili nel CSV dopo la generazione):"
$lblDefaults.Location = '20,330'
$lblDefaults.Size = '590,20'
$lblDefaults.ForeColor = "Cyan"
$form.Controls.Add($lblDefaults)

$lblD1 = New-Object System.Windows.Forms.Label
$lblD1.Text = "Interval (sec):"
$lblD1.Location = '20,360'
$lblD1.Size = '120,20'
$form.Controls.Add($lblD1)

$txtD1 = New-Object System.Windows.Forms.TextBox
$txtD1.Text = $DefaultValues.Interval
$txtD1.Location = '140,360'
$txtD1.Size = '50,20'
$txtD1.BackColor = "Black"
$txtD1.ForeColor = "Lime"
$form.Controls.Add($txtD1)

$lblD2 = New-Object System.Windows.Forms.Label
$lblD2.Text = "Quality (1-31):"
$lblD2.Location = '210,360'
$lblD2.Size = '120,20'
$form.Controls.Add($lblD2)

$txtD2 = New-Object System.Windows.Forms.TextBox
$txtD2.Text = $DefaultValues.Quality
$txtD2.Location = '330,360'
$txtD2.Size = '50,20'
$txtD2.BackColor = "Black"
$txtD2.ForeColor = "Lime"
$form.Controls.Add($txtD2)

$lblD3 = New-Object System.Windows.Forms.Label
$lblD3.Text = "Resolution (0=Orig, 1=1080p, 2=4K):"
$lblD3.Location = '20,390'
$lblD3.Size = '280,20'
$form.Controls.Add($lblD3)

$txtD3 = New-Object System.Windows.Forms.TextBox
$txtD3.Text = $DefaultValues.Resolution
$txtD3.Location = '300,390'
$txtD3.Size = '50,20'
$txtD3.BackColor = "Black"
$txtD3.ForeColor = "Lime"
$form.Controls.Add($txtD3)

$chkDSharpen = New-Object System.Windows.Forms.CheckBox
$chkDSharpen.Text = "Sharpen"
$chkDSharpen.Location = '370,390'
$chkDSharpen.Size = '100,20'
$chkDSharpen.ForeColor = "Lime"
$form.Controls.Add($chkDSharpen)

$chkDDenoise = New-Object System.Windows.Forms.CheckBox
$chkDDenoise.Text = "Denoise"
$chkDDenoise.Location = '470,390'
$chkDDenoise.Size = '100,20'
$chkDDenoise.ForeColor = "Lime"
$form.Controls.Add($chkDDenoise)

# Pulsanti
$btnSelect = New-Object System.Windows.Forms.Button
$btnSelect.Text = "SELECT FOLDER"
$btnSelect.Location = '20,440'
$btnSelect.Size = '280,45'
$btnSelect.FlatStyle = "Flat"
$btnSelect.FlatAppearance.BorderColor = "Lime"
$btnSelect.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnSelect)

$btnGenerate = New-Object System.Windows.Forms.Button
$btnGenerate.Text = "GENERATE CSV"
$btnGenerate.Location = '320,440'
$btnGenerate.Size = '290,45'
$btnGenerate.FlatStyle = "Flat"
$btnGenerate.FlatAppearance.BorderColor = "Lime"
$btnGenerate.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
$btnGenerate.Enabled = $false
$form.Controls.Add($btnGenerate)

# ============================================================
# VARIABILI DI STATO
# ============================================================
$script:selectedPath = ""
$script:videoFiles = @()

# ============================================================
# LOGICA
# ============================================================
$btnSelect.Add_Click({
    $dialog = New-Object Windows.Forms.FolderBrowserDialog
    if ($dialog.ShowDialog() -eq "OK") {
        $script:selectedPath = $dialog.SelectedPath
        $listView.Items.Clear()
        
        $exts = @(".mp4", ".mkv", ".avi", ".mov", ".wmv", ".flv", ".ts")
        $script:videoFiles = Get-ChildItem -Path $script:selectedPath -File | Where-Object { 
            $exts -contains $_.Extension.ToLower() 
        }
        
        foreach ($file in $script:videoFiles) { [void]$listView.Items.Add($file.Name) }
        
        if ($script:videoFiles.Count -gt 0) {
            $logBox.Text = "Status: Found $($script:videoFiles.Count) video files."
            $btnGenerate.Enabled = $true
            $btnGenerate.BackColor = [Drawing.Color]::FromArgb(0, 40, 0)
        } else {
            $logBox.Text = "Status: No video files detected."
            $btnGenerate.Enabled = $false
        }
    }
})

$btnGenerate.Add_Click({
    $outputPath = Join-Path $script:selectedPath "ffmpeg_config.csv"
    try {
        $sharpenVal = if ($chkDSharpen.Checked) { "TRUE" } else { "FALSE" }
        $denoiseVal = if ($chkDDenoise.Checked) { "TRUE" } else { "FALSE" }
        
        $csvData = foreach ($file in $script:videoFiles) {
            [PSCustomObject]@{
                InputFile    = $file.FullName
                Interval     = $txtD1.Text
                Quality      = $txtD2.Text
                Sharpen      = $sharpenVal
                Denoise      = $denoiseVal
                Resolution   = $txtD3.Text
                ColorBalance = "0"
            }
        }
        $csvData | Export-Csv -Path $outputPath -NoTypeInformation -Delimiter "," -Encoding UTF8
        
        $resp = [Windows.Forms.MessageBox]::Show(
            "CSV Generated Successfully!`n`nLocation: $outputPath`n`nVuoi aprire il CSV?",
            "Matrix System",
            [Windows.Forms.MessageBoxButtons]::YesNo,
            [Windows.Forms.MessageBoxIcon]::Information
        )
        if ($resp -eq "Yes") {
            Invoke-Item $outputPath
        }
        $form.Close()
    } catch {
        [Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)")
    }
})

[void]$form.ShowDialog()