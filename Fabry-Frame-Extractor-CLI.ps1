# Fabry-Frame-Extractor-CLI.ps1 - v2.0
# Estrae frame da video in batch, leggendo un CSV di configurazione
# Gestisce path con spazi, log su file, validazione CSV

<#
    .SYNOPSIS
        Estrae frame da video in batch da un file CSV.
    
    .DESCRIPTION
        Legge un CSV con le colonne:
        InputFile,Interval,Quality,Sharpen,Denoise,Resolution,ColorBalance
        e processa ogni video in serie, estraendo i frame in JPG.
    
    .EXAMPLE
        .\Fabry-Frame-Extractor-CLI.ps1 -ConfigFilePath ".\config.csv" -RootOutputPath ".\output"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigFilePath,

    [Parameter(Mandatory=$true)]
    [string]$RootOutputPath
)

$script:workDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$ffmpegPath = Join-Path $script:workDir "ffmpeg.exe"
$script:logFile = $null

# ============================================================
# AUTO-FFMPEG
# ============================================================
function Initialize-FFmpeg {
    if (-not (Test-Path $ffmpegPath)) {
        Write-Host "[!] FFmpeg non trovato. Download in corso..." -ForegroundColor Yellow
        $zipPath = Join-Path $env:TEMP "ffmpeg_dl.zip"
        $extractPath = Join-Path $env:TEMP "ffmpeg_temp"
        $url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
        
        try {
            Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
            Get-ChildItem -Path $extractPath -Include "ffmpeg.exe", "ffprobe.exe" -Recurse | ForEach-Object {
                Move-Item $_.FullName $script:workDir -Force
            }
            Remove-Item $zipPath -Force
            Remove-Item $extractPath -Recurse -Force
            Write-Host "[OK] FFmpeg scaricato." -ForegroundColor Green
        } catch {
            Write-Host "[X] Errore download: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
}

Initialize-FFmpeg

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
        " FRAME EXTRACTOR CLI - LOG",
        "============================================================",
        "Data inizio: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "Config: $ConfigFilePath",
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
# VALIDAZIONE CSV
# ============================================================
function Test-CsvColumns {
    param([array]$Rows)
    if ($Rows.Count -eq 0) { return $false }
    
    $required = @("InputFile", "Interval", "Quality", "Sharpen", "Denoise", "Resolution", "ColorBalance")
    $actual = $Rows[0].PSObject.Properties.Name
    
    $missing = $required | Where-Object { $_ -notin $actual }
    if ($missing.Count -gt 0) {
        Write-Host "[X] Colonne mancanti nel CSV: $($missing -join ', ')" -ForegroundColor Red
        Write-Host "    Colonne trovate: $($actual -join ', ')" -ForegroundColor Yellow
        return $false
    }
    return $true
}

# ============================================================
# PROCESSAMENTO
# ============================================================
function Process-Video {
    param(
        [psobject]$ConfigRow,
        [string]$RootOutput,
        [int]$Index,
        [int]$Total
    )
    
    $InputFile = $ConfigRow.InputFile.Trim()
    $Interval  = [double]$ConfigRow.Interval
    $Quality   = [int]$ConfigRow.Quality
    $Denoise   = ($ConfigRow.Denoise -eq "TRUE")
    $Sharpen   = ($ConfigRow.Sharpen -eq "TRUE")
    $ResSetting = [string]$ConfigRow.Resolution
    $ColorBal  = $ConfigRow.ColorBalance.ToUpper().Trim()
    
    if ($Interval -le 0) { $Interval = 1 }
    
    Write-Host "`n[$Index/$Total] >>> $(Split-Path $InputFile -Leaf)" -ForegroundColor Yellow
    Write-Log "Processing [$Index/$Total]: $InputFile" "INFO"
    
    if (-not (Test-Path $InputFile)) {
        Write-Host " [!] File non trovato: $InputFile" -ForegroundColor Red
        Write-Log "File non trovato: $InputFile" "ERROR"
        return
    }
    
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $OutputDir = Join-Path $RootOutput $fileName
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    $outputPattern = Join-Path $OutputDir ("frame_$fileName" + "_%04d.jpg")
    
    # Costruzione filtri
    $vfFilters = @()
    if ($Denoise) { $vfFilters += "hqdn3d=3:3:4:4" }
    
    $ColorMap = @{ "LUMINOSO"="colorbalance=gm=0.1:bs=-0.05"; "CALDO"="colorbalance=rs=0.15:rh=0.1:bs=-0.1" }
    if ($ColorMap.ContainsKey($ColorBal)) { $vfFilters += $ColorMap[$ColorBal] }
    
    $ResMap = @{ "1"="1920:-1"; "2"="3840:-1" }
    $scale = if ($ResMap.ContainsKey($ResSetting)) { $ResMap[$ResSetting] } elseif ($ResSetting -match '^\d+:\d+$') { $ResSetting }
    if ($scale) { $vfFilters += "scale=$scale" }
    
    if ($Sharpen) { $vfFilters += "unsharp=5:5:1.0" }
    $vfFilters += "fps=1/$Interval"
    
    # Costruzione args
    $args = @()
    $args += "-err_detect"; $args += "ignore_err"
    $args += "-fflags"; $args += "+discardcorrupt"
    $args += "-i"; $args += $InputFile
    $args += "-vf"; $args += ($vfFilters -join ",")
    $args += "-q:v"; $args += $Quality
    $args += $outputPattern
    $args += "-y"
    
    # Esegui con & (gestisce path con spazi)
    try {
        $output = & $ffmpegPath @args 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host " [OK] Success" -ForegroundColor Green
            Write-Log "Completed: $InputFile" "OK"
        } else {
            Write-Host " [X] FAILED (exit $LASTEXITCODE)" -ForegroundColor Red
            Write-Log "FAILED (exit $LASTEXITCODE): $InputFile" "ERROR"
        }
    } catch {
        Write-Host " [!] Errore: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Errore: $($_.Exception.Message)" "ERROR"
    }
}

# ============================================================
# MAIN
# ============================================================
Clear-Host
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "      FABRY FRAME EXTRACTOR CLI v2.0                     " -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green

if (-not (Test-Path $ConfigFilePath -PathType Leaf)) {
    Write-Host "[X] ConfigFilePath non trovato: $ConfigFilePath" -ForegroundColor Red
    exit 1
}

# Leggi CSV
Write-Host "`n[i] Lettura CSV: $ConfigFilePath" -ForegroundColor Cyan
$ConfigData = Import-Csv -Path $ConfigFilePath -Encoding UTF8

if (-not (Test-CsvColumns -Rows $ConfigData)) {
    exit 1
}

$total = $ConfigData.Count
Write-Host "[OK] $total video da processare" -ForegroundColor Green

# Crea output
if (-not (Test-Path $RootOutputPath)) {
    New-Item -ItemType Directory -Path $RootOutputPath -Force | Out-Null
}
Start-Log -Folder $RootOutputPath

# Processa
$startTime = Get-Date
$index = 0
foreach ($row in $ConfigData) {
    $index++
    Process-Video -ConfigRow $row -RootOutput $RootOutputPath -Index $index -Total $total
}

$elapsed = ($(Get-Date) - $startTime).TotalMinutes
Write-Host "`n=========================================================" -ForegroundColor Magenta
Write-Host " ELABORAZIONE COMPLETATA in $([math]::Round($elapsed, 1)) min" -ForegroundColor Magenta
Write-Host " Log: $script:logFile" -ForegroundColor Magenta
Write-Host "=========================================================" -ForegroundColor Magenta
