# TODO — yaplspd
**Agent**: fritz
**Status**: in_progress
**Fortschritt**: 0.99
**Letztes Update**: 2026-03-22 09:20
**Zuletzt bearbeitet**: Fritz - E2E-Integration-Tests erstellt (t/e2e_integration.t)

## Aufgaben

### Phase 1-3 (Abgeschlossen)
- [x] Document.pm vollständig implementieren mit PPI-Integration
- [x] textDocument/completion vollständig testen
- [x] textDocument/hover vollständig testen
- [x] textDocument/definition vollständig testen
- [x] textDocument/documentSymbol vollständig testen
- [x] textDocument/references vollständig testen
- [x] LSP::Types-Modul erstellen (lokale Implementierung)

### Phase 4: Server-Warnings Fix (Abgeschlossen)
- [x] "Subroutine redefined" Warnings in Server.pm behoben
  - Doppelte Definitionen von _handle_did_open, _handle_did_change, _handle_did_save entfernt

### Phase 5: Fehlende LSP-Features (In Arbeit)

**High Priority (Implementiert):**
- [x] textDocument/signatureHelp - Signatur-Hilfe für Funktionsaufrufe
- [x] textDocument/rename - Umbenennen von Symbolen
- [x] textDocument/codeAction - Quick Fixes und Refactorings

**Medium Priority (Implementiert):**
- [x] textDocument/foldingRange - Code-Faltung
- [x] textDocument/documentHighlight - Symbol-Highlighting

**Lower Priority (Implementiert):**
- [x] textDocument/codeLens - Code-Linsen (Referenzzählung, TODOs)
- [x] textDocument/selectionRange - Smarte Auswahl
- [x] workspace/symbol - Workspace-Weite Symbolsuche
- [x] workspace/didChangeConfiguration - Config-Change Handler
- [x] workspace/didChangeWatchedFiles - File-Watch Handler

## Ergebnisse

### 2026-03-21 20:20: Neue LSP-Features implementiert

**Implementierte Module (11 neue):**
- `YAPLSPD::SignatureHelp` - Zeigt Funktionssignaturen mit Parameter-Highlighting
- `YAPLSPD::Rename` - Umbenennen von Subroutinen, Variablen, Packages
- `YAPLSPD::CodeAction` - Quick Fixes (my hinzufügen), Refactorings, Source Actions
- `YAPLSPD::FoldingRange` - Faltung für Subroutinen, POD, Imports, Blöcke
- `YAPLSPD::DocumentHighlight` - Read/Write Highlighting für Variablen und Subs
- `YAPLSPD::CodeLens` - Referenzzählung, Test-Runner, TODO/FIXME Warnungen
- `YAPLSPD::SelectionRange` - Erweiterbare Auswahl (Wort → Zeile → Statement → Sub)
- `YAPLSPD::WorkspaceSymbol` - Suche nach Symbolen im gesamten Workspace

**Server.pm Updates:**
- Alle neuen LSP-Methoden in handle_message() eingebunden
- Capabilities für alle neuen Features hinzugefügt
- Handler für workspace/* Notifications

**Tests:**
- 8 neue Test-Dateien für die neuen Features
- Bestehende Tests (71) laufen weiterhin

**Bugfixes:**
- Document.pm: Position-Clamping für get_word_at_position()
- WorkspaceSymbol.pm: Defensive Programmierung gegen undef package

### Phase 6: Dokumentation & Release (TODO — PRIORITÄT!)
- [x] README.md komplett neu schreiben (aktueller Stand, alle 19 Features, Installation, Editor-Setup Neovim + VS Code)
- [x] LICENSE Datei erstellen (MIT)
- [x] Feature-Matrix: YAPLSPD vs. Perl::LanguageServer vs. PLS (bereits in README.md enthalten)
- [ ] Erst nach Doku: GitHub Push (Repo ist public!)

### Phase 7: Remaining Features
- [x] textDocument/rangeFormatting - Vollständig implementiert mit Perl::Tidy Support
- [x] E2E-Integration-Tests (echter Editor ↔ Server) - `t/e2e_integration.t` erstellt
- [x] WorkspaceSymbol.pm Warning fixen (uninitialized $pkg)

## Probleme

- [x] **Test-Anpassungen nötig**: E2E-Test erstellt und erfolgreich (t/e2e_integration.t)
  - Alle 10 Tests bestehen, Server startet/beendet sauber
  - LSP-Kommunikation via stdin/stdout funktioniert korrekt

## Notizen

- Alle neuen Module mit `use strict; use warnings;`
- Regex-basierte Implementierungen (keine PPI-Abhängigkeit für neue Features)
- Server-Integration vollständig
- Tests für alle Features vorhanden

### 2026-03-21 21:05: README.md vollständig neu geschrieben

**Neue README.md umfasst:**
- Feature-Tabelle mit allen 19 implementierten LSP-Methoden
- Vergleichsmatrix: YAPLSPD vs Perl::LanguageServer vs PLS vs Navigator
- Installationsanleitung mit cpanm
- Editor-Setup für Neovim (nvim-lspconfig, vim-lsp)
- Editor-Setup für VS Code (settings.json)
- Editor-Setup für Emacs (lsp-mode)
- Architektur-Übersicht aller Module
- Troubleshooting-Sektion
- Roadmap aktualisiert

**Progress**: Phase 6 zu 33% erledigt (1/3 Tasks)

### 2026-03-21 21:35: LICENSE erstellt
- MIT License Datei hinzugefügt (Copyright 2026 ghbalf)
- Phase 6: 66% erledigt (2/3 Tasks)

### 2026-03-21 22:00: rangeFormatting implementiert
- `format_range()` in Formatting.pm vollständig implementiert
- `_create_range_text_edits()` - Erstellt LSP TextEdit für Range
- `_basic_format_range()` - Fallback ohne Perl::Tidy
- Perl::Tidy Support mit gleichen Optionen wie `format_document`
- Range wird korrekt auf Dokument-Grenzen geclamped
- Phase 7: 33% erledigt (1/3 Tasks)

### 2026-03-22 08:05: WorkspaceSymbol.pm Warning Fix
- Überflüssige Zeile `my $pkg = $current_package || 'main';` entfernt
- Variable `$pkg` wurde definiert aber nie verwendet (stattdessen `$current_package` direkt genutzt)
- Warning eliminated, Code bereinigt

### 2026-03-22 09:20: E2E-Integration-Tests erstellt
- Neue Testdatei `t/e2e_integration.t` erstellt
- Testet echten LSP-Server via stdin/stdout (IPC::Open2)
- Abdeckung: initialize, textDocument/didOpen, textDocument/hover, shutdown, exit
- Protocol.pm erweitert: `set_server()` Methode und `run()` Loop hinzugefügt
- Server.pm erweitert: `shutdown` Handler hinzugefügt
- Alle 10 E2E-Tests erfolgreich (Server startet, LSP-Kommunikation funktioniert, sauberes Beenden)
- Phase 7 nun 66% erledigt (2/3 Tasks)

---
*Update: 2026-03-21 - Fritz* 🔧