# 🎬 Fabry Frame Extractor

Estrae frame da video (singolo o batch) con GUI Matrix o CLI.

## ✨ Feature

### GUI
- ✅ Estrazione da singolo o multipli video
- ✅ **CUDA** per upscale (scale_cuda)
- ✅ Stima frame prima di partire
- ✅ Anteprima configurazione
- ✅ Log a schermo
- ✅ Pulsante ANNULLA
- ✅ Preset salvabili

### CLI
- ✅ Batch da CSV
- ✅ Log su file
- ✅ Gestione path con spazi
- ✅ Validazione CSV

### Comune
- ✅ **Auto-download FFmpeg** (nessuna installazione manuale)
- ✅ Filtri: scale, sharpen, denoise, color balance
- ✅ Formati: MP4, MKV, AVI, MOV, WMV, FLV, TS
- ✅ Default ottimizzati per qualità e velocità

## 📋 Requisiti

- **Windows 10 / 11**
- **PowerShell 7+**
- **FFmpeg** (scaricato automaticamente al primo avvio)
- **GPU NVIDIA** (opzionale, per CUDA)

Scarica PowerShell 7 da: https://aka.ms/powershell

## 🚀 Quick start

### GUI (per uso interattivo)

```powershell
git clone https://github.com/fabrytoolbox/Fabry-Frame-Extractor.git
cd Fabry-Frame-Extractor
Unblock-File .\Fabry-Frame-Extractor-GUI.ps1
.\Fabry-Frame-Extractor-GUI.ps1