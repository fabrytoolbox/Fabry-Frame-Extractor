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

Oppure doppio click su avvia-GUI.bat.

Flusso:

Seleziona video (o più)

Seleziona cartella output

Scegli impostazioni (quality, risoluzione, ecc.)

Clicca EXECUTE_EXTRACTION

Conferma (mostra stima frame)

I frame vengono estratti

CLI (per batch)
Genera il CSV con CSV-Architect.ps1:

powershell
.\CSV-Architect.ps1
Seleziona cartella video

Scegli default

Genera ffmpeg_config.csv

Lancia il CLI:

powershell
.\Fabry-Frame-Extractor-CLI.ps1 -ConfigFilePath ".\ffmpeg_config.csv" -RootOutputPath ".\output"
Oppure doppio click su avvia-CLI.bat (con parametri).

🎚️ Impostazioni
Parametro	Valori	Default
Interval	Secondi tra frame	1 (1 frame/sec)
Quality	1-31 (1 = max qualità)	2
Sharpen	TRUE/FALSE	FALSE
Denoise	TRUE/FALSE	FALSE
Resolution	0=Orig, 1=1080p, 2=4K, o custom (es. 1280:720)	0
ColorBalance	0=OFF, 1=Luminoso, 2=Caldo	0

📝 CSV
Formato del file di configurazione:

InputFile,Interval,Quality,Sharpen,Denoise,Resolution,ColorBalance
C:\video1.mp4,1,2,FALSE,FALSE,0,0
C:\video2.mp4,1,2,FALSE,FALSE,1,0

Attenzione: i nomi delle colonne sono case-sensitive.

🎯 Casi d'uso
Thumbnail da video: 1 frame ogni 10-30 secondi, qualità alta

Dataset per AI: frame a intervalli regolari, risoluzione standardizzata

Analisi video: estrazione sistematica per studio

Backup visivo: screenshot da video di ricordi

🐛 Problemi comuni
"FFmpeg non trovato"
Il tool chiede se scaricarlo. Rispondi Sì. Se fallisce, scaricalo manualmente da https://www.gyan.dev/ffmpeg/builds/

"CUDA non funziona"
Verifica di avere GPU NVIDIA e driver aggiornati. Se non funziona, disattiva CUDA (usa CPU).

"I frame sono neri"
Potrebbe essere un problema del video di input. Verifica con VLC che il video sia riproducibile.

"L'estrazione è lenta"

Con CUDA + upscale: usa GPU (veloce)

Senza CUDA + upscale: usa CPU (lento, single-thread)

Riduci Quality per file più piccoli

Aumenta Interval per meno frame

📜 Licenza
MIT (vedi LICENSE).

🙏 Crediti
FFmpeg per l'elaborazione video

Topaz per lo sharpening (consigliato)
