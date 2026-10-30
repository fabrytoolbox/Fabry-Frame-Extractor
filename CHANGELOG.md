# Changelog
## [2.6.0] - 2026-10-30

### Fixed
- Risolto il conflitto di formati (errore -40) quando si usa CUDA insieme al filtro `fps`.
- Migliorata la gestione dello scarico dei frame dalla GPU alla CPU per il salvataggio in JPG.

## [1.0.0] - 2025-01-25

### Added
- GUI Matrix per estrazione frame da video (singolo o multipli)
- CLI per batch da CSV
- CSV-Architect per generare configurazioni
- Auto-download FFmpeg
- Supporto CUDA per upscale (scale_cuda)
- Sharpening delegato a Topaz (avviso in GUI)
- Log su file per GUI e CLI
- Stima frame prima di partire
- Pulsante ANNULLA in GUI
- Gestione path con spazi
- Validazione CSV
- Default: Interval=1, Resolution=0 (Originale)
