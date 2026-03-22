# YAPLSPD — Yet Another Perl LSP Daemon

## Vision
Ein Perl LSP Server in Perl geschrieben, der das **komplette LSP-Protokoll** implementiert — nicht nur eine Teilmenge wie die existierenden Lösungen.

## Motivation
- Bestehende Perl-LSPs (Perl::LanguageServer, PLS) decken nur Teile des Protokolls ab
- Fredi wollte eine vollständige Implementierung
- Portfolio-Projekt auf GitHub: https://github.com/ghbalf/yaplspd

## Status
🚧 **Hintergrundprojekt** — schrittweise Implementierung

## Existierende Lösungen (Analyse ausstehend)
- `Perl::LanguageServer` — https://github.com/richterger/Perl-LanguageServer
- `PLS` — https://metacpan.org/pod/PLS
- Evtl. ein dritter? (recherchieren)

## TODO
- [x] Analysieren was die bestehenden LSPs NICHT implementieren → `perl-lsp-analysis.md`
- [x] Feature-Matrix erstellen (was implementiert wer?) → `perl-lsp-analysis.md`
- [ ] LSP Protokoll Spec lesen (https://microsoft.github.io/language-server-protocol/)
- [ ] Architektur entwerfen
- [ ] MVP definieren (Basis-Features zuerst)
- [ ] Schrittweise implementieren

## LSP Features (Protokoll)
Die vollständige Spec umfasst:
- [x] textDocument/didOpen, didChange, didClose, didSave
- [x] textDocument/completion
- [x] textDocument/hover
- [x] textDocument/signatureHelp
- [x] textDocument/definition
- [x] textDocument/references
- [x] textDocument/documentHighlight
- [x] textDocument/documentSymbol
- [x] textDocument/codeAction
- [x] textDocument/codeLens
- [x] textDocument/formatting
- [x] textDocument/rangeFormatting
- [x] textDocument/rename
- [x] textDocument/foldingRange
- [x] textDocument/selectionRange
- [x] textDocument/publishDiagnostics
- [x] workspace/symbol
- [x] workspace/didChangeConfiguration
- [x] workspace/didChangeWatchedFiles
- [ ] textDocument/implementation (optional)
- [ ] textDocument/typeDefinition (optional)
- [ ] textDocument/documentLink (optional)
- [ ] textDocument/colorPresentation (optional)

## Technologie
- Sprache: Perl
- LSP Transport: stdio (Standard)
- JSON-RPC 2.0

---

*Projekt von Fredi, implementiert von Siegfried 🐉*
