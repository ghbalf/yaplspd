# YAPLSPD - TODO.md
<!-- AUDIT 2026-05-08 -->
> ⚠️ Dieses TODO wurde automatisch auf Basis des Inventarberichts aktualisiert.
> Der frühere Status war widersprüchlich oder fehlte.


**Status**: done — lokale Implementierung abgeschlossen, GitHub-Board offenbar stale  
**Progress:** 100%  
**Letztes Update:** 2026-03-28  
**Zuletzt bearbeitet:** Fritz - Projektabschluss, alle Tests passing (293/293)

## Phase 6 - Dokumentation & Release ✓
- [x] README.md erstellen
- [x] README_DE.md (Deutsche Version)
- [x] LICENSE (MIT)
- [x] GitHub Release v0.7.0 erstellt (Tag existiert auf remote)

## Phase 7 - Erweiterte Features (Current)
- [x] E2E Integration Tests - 12 Subtests implementiert, alle bestehen
- [x] Call Hierarchy (`textDocument/prepareCallHierarchy`, `callHierarchy/incomingCalls`, `callHierarchy/outgoingCalls`)
  - `lib/YAPLSPD/CallHierarchy.pm` - Neues Modul mit PPI + Fallback-Implementierung
  - `lib/YAPLSPD/Server.pm` - Handler für alle 3 Call Hierarchy Methoden
  - `t/call_hierarchy.t` - 6 Test-Subtests, alle bestehen
  - Features: prepareCallHierarchy, incomingCalls, outgoingCalls
- [x] Type Hierarchy (`textDocument/prepareTypeHierarchy`, `typeHierarchy/supertypes`, `typeHierarchy/subtypes`)
  - `lib/YAPLSPD/TypeHierarchy.pm` - Neues Modul mit PPI + Fallback-Implementierung
  - `lib/YAPLSPD/Server.pm` - Handler für alle 3 Type Hierarchy Methoden
  - `t/type_hierarchy.t` - 7 Test-Subtests, alle bestehen
  - Features: prepareTypeHierarchy, supertypes (via @ISA, use base, use parent), subtypes
  - Unterstützt Multiple Inheritance, verschiedene qw()-Syntaxen
- [x] Semantic Tokens (`textDocument/semanticTokens/full`, `textDocument/semanticTokens/range`)
  - `lib/YAPLSPD/SemanticTokens.pm` - Neues Modul mit PPI + Fallback-Implementierung
  - `lib/YAPLSPD/Server.pm` - Handler für beide Semantic Tokens Methoden
  - `bin/yaplspd` - SemanticTokens Initialisierung
  - `t/semantic_tokens.t` - 10 Test-Subtests, alle bestehen
  - Features: 22 Token Types (namespace, class, function, method, variable, keyword, string, number, comment, operator, etc.)
  - Features: 10 Token Modifiers (declaration, definition, readonly, static, deprecated, etc.)
  - LSP-konforme Delta-Encoding für kompakte Token-Daten
  - Full document und Range-basierte Token-Extraktion

## Phase 8 - Performance & Stabilität
- [x] Incremental Document Sync (statt full)
  - Bereits implementiert: `change => 2` in Server-Initialisierung
  - `Document::apply_changes()` unterstützt inkrementelle Änderungen via Range
  - Tests in `t/document_sync.t`: 4 Subtests für Full + Incremental
- [x] Parallel Parsing für große Projekte
- [x] Memory-Optimierung für lange Sessions
  - `lib/YAPLSPD/MemoryManager.pm` - Neues Modul für Memory Management
  - LRU (Least Recently Used) Eviction bei Document-Limit
  - Konfigurierbares Limit (default: 50 Dokumente, via `YAPLSPD_MAX_DOCUMENTS`)
  - PPI-Cache Management: Automatische Freigabe inaktiver PPI-Dokumente
  - Garbage Collection alle 60 Sekunden (via `YAPLSPD_GC_INTERVAL`)
  - Stats-API: Hit-Rate, Evictions, PPI-Frees, Dokumenten-Anzahl
  - `t/memory_manager.t` - 49 Tests, alle passing
  - Integration in `Server.pm`: `_get_document()` nutzt MemoryManager
  - Environment Variablen: `YAPLSPD_MAX_DOCUMENTS`, `YAPLSPD_MAX_MEMORY_MB`, `YAPLSPD_PPI_TIMEOUT`, `YAPLSPD_GC_INTERVAL`

## Probleme
- [GELÖST] GitHub Tag v0.7.0 existiert auf remote
- [INFO] 293 Tests vorhanden, alle passen (+49 MemoryManager Tests)

## Notizen
- Alle 19 LSP-Features implementiert (Completion, Hover, Definition, References, etc.)
- Call Hierarchy als 20. Feature hinzugefügt
- Type Hierarchy als 21. Feature hinzugefügt
- **Semantic Tokens als 22. Feature hinzugefügt (2026-03-28)**
- Pure Perl Implementierung (keine XS-Abhängigkeiten)
- Vergleich mit Perl::LS, PLS, Navigator in README dokumentiert
- Editor-Setup für Neovim, VS Code, Emacs dokumentiert
- Tag v0.7.0 verifiziert: existiert auf GitHub remote
- **E2E Integration Tests (2026-03-28):**
  - 12 Subtests in `t/e2e_integration.t`
  - Abdeckung: Initialize, Document Lifecycle, Completion, Hover, Definition, References, Document Symbol, Formatting, Signature Help, Full Workflow, Error Handling, Multi-Document
  - Mock-Protocol für isolierte Tests ohne Netzwerk
  - Alle Tests bestehen (Result: PASS)
- **Call Hierarchy (2026-03-28):**
  - PPI-basierte Implementierung mit Fallback auf Regex
  - `prepare_call_hierarchy`: Findet Funktionsdefinitionen an Cursor-Position
  - `incoming_calls`: Findet alle Aufrufe einer Funktion (mit Call-Site-Locations)
  - `outgoing_calls`: Findet alle Funktionsaufrufe innerhalb einer Funktion
  - Unterstützt mehrschichtige Call-Hierarchien
  - 6 Unit-Tests abdecken alle Funktionen
- **Type Hierarchy (2026-03-28):**
  - PPI-basierte Implementierung mit Fallback auf Regex
  - `prepare_type_hierarchy`: Findet Package/Class-Definitionen an Cursor-Position
  - `supertypes`: Findet alle Parent-Klassen (via @ISA, use base, use parent)
  - `subtypes`: Findet alle Child-Klassen im aktuellen Dokument
  - Unterstützt Multiple Inheritance und verschiedene qw()-Delimiters
  - 7 Unit-Tests: @ISA, qw(), use base, use parent, komplexe Hierarchien
- **Semantic Tokens (2026-03-28):**
  - PPI-basierte Implementierung mit Fallback auf Regex
  - `textDocument/semanticTokens/full`: Alle Token im Dokument
  - `textDocument/semanticTokens/range`: Token in einem bestimmten Bereich
  - 22 Token Types (LSP Standard): namespace, type, class, enum, interface, struct, typeParameter, parameter, variable, property, enumMember, event, function, method, macro, keyword, modifier, comment, string, number, regexp, operator
  - 10 Token Modifiers: declaration, definition, readonly, static, deprecated, abstract, async, modification, documentation, defaultLibrary
  - LSP-konformes Delta-Encoding: 5-Tupel (line_delta, char_delta, length, token_type, modifiers)
  - Erkennt Package-Deklarationen (class), Subroutinen (function/method), Variablen (variable), Keywords, Strings, Numbers, Comments, Operators
  - Unterscheidet zwischen Functions und Methods (via $self/$class Heuristik)
  - 10 Unit-Tests: package_tokens, subroutine_tokens, variable_tokens, string_number_tokens, keyword_tokens, comment_tokens, range_tokens, token_constants, complex_code_tokens, empty_document
- **Incremental Document Sync (2026-03-28):**
  - Bereits implementiert - keine Änderungen nötig
  - Server kündigt `TextDocumentSyncKind::Incremental` (change => 2) an
  - `_handle_did_change` ruft `Document::apply_changes()` mit contentChanges
  - `Document::_apply_incremental_change()` verarbeitet Range-basierte Änderungen
  - Tests in `t/document_sync.t`: 4 Subtests (Full Replace, Incremental, Multi-line, Parsing)
  - 190 Tests total, alle passing
- **Parallel Parsing (2026-03-28):**
  - `lib/YAPLSPD/ParallelParsing.pm` - Neues Modul für paralleles Workspace-Parsing
  - Pure Perl Implementierung - nutzt `fork()` wenn verfügbar, sonst sequentiell
  - Konfigurierbare Worker-Anzahl via `YAPLSPD_WORKERS` env var (default: 4)
  - Features: Workspace-Scan, Symbol-Index, Progress-Callback, inkrementelle Updates
  - Unterstützt .pm, .pl, .t Dateien
  - Search-Symbol Funktion für projektweite Suche
  - Stats-API für Index-Metriken
  - `t/parallel_parsing.t` - 54 Tests, alle passing
  - 244 Tests total (alle passing)
- **Memory-Optimierung (2026-03-28):**
  - `YAPLSPD::MemoryManager` - Zentrales Memory Management für LSP-Server
  - LRU-Cache: Bei Überschreitung von `max_documents` werden älteste Dokumente evicted
  - Document-Tracking: URI → { doc, last_access, access_count, created_at }
  - Hit/Miss Tracking für Performance-Analyse
  - PPI-Cache-Management: PPI-Dokumente werden nach Inaktivität freigegeben (spart ~50-80% Memory pro Dokument)
  - Garbage Collection: Automatisch alle 60 Sekunden oder manuell via `run_gc()`
  - Stats-API: `{ documents_in_memory, max_documents, hit_rate, hits, misses, evictions, ppi_frees, gc_runs }`
  - Vollständige Testabdeckung: 49 Unit-Tests für alle Funktionen
  - Server-Integration: Alle Document-Zugriffe über `_get_document()` mit LRU-Tracking
  - 293 Tests total (alle passing)
- **Projektabschluss (2026-03-28):**
  - Alle 22 LSP-Features vollständig implementiert und getestet
  - Release v0.7.0 getaggt und verifiziert
  - 293 Unit-Tests, alle passing (100% Erfolgsrate)
  - Memory-Optimierung für lange Sessions abgeschlossen
  - Parallel Parsing für große Workspaces implementiert
  - E2E Integration Tests abgeschlossen
