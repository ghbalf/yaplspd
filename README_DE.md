# YAPLSPD — Yet Another Perl Language Server Protocol Daemon

*English version: [README.md](README.md)*

Ein vollständiger Perl Language Server Protocol (LSP) Daemon in purem Perl.

## Features

### Implementierte LSP-Features (19)

| Feature | Methode | Status |
|---------|---------|--------|
| **Autovervollständigung** | `textDocument/completion` | ✅ |
| **Hover-Informationen** | `textDocument/hover` | ✅ |
| **Definition** | `textDocument/definition` | ✅ |
| **Referenzen** | `textDocument/references` | ✅ |
| **Dokument-Symbole** | `textDocument/documentSymbol` | ✅ |
| **Code-Formatierung** | `textDocument/formatting` | ✅ |
| **Range-Formatierung** | `textDocument/rangeFormatting` | ✅ |
| **Signatur-Hilfe** | `textDocument/signatureHelp` | ✅ |
| **Umbenennen** | `textDocument/rename` | ✅ |
| **Code-Actions** | `textDocument/codeAction` | ✅ |
| **Faltbereiche** | `textDocument/foldingRange` | ✅ |
| **Dokument-Highlight** | `textDocument/documentHighlight` | ✅ |
| **Code-Linsen** | `textDocument/codeLens` | ✅ |
| **Auswahlbereiche** | `textDocument/selectionRange` | ✅ |
| **Workspace-Symbole** | `workspace/symbol` | ✅ |
| **Konfiguration** | `workspace/didChangeConfiguration` | ✅ |
| **Datei-Überwachung** | `workspace/didChangeWatchedFiles` | ✅ |
| **Dokument-Sync** | `textDocument/didOpen/didChange/didClose` | ✅ |
| **Diagnostik** | `textDocument/publishDiagnostics` | ✅ |

### YAPLSPD vs. Konkurrenz

| Feature | YAPLSPD | Perl::LS | PLS | Navigator |
|---------|---------|----------|-----|-----------|
| completion | ✅ | ✅ | ✅ | ✅ |
| hover | ✅ | ✅ | ✅ | ✅ |
| definition | ✅ | ✅ | ✅ | ✅ |
| references | ✅ | ✅ | ✅ | ✅ |
| documentSymbol | ✅ | ✅ | ✅ | ✅ |
| formatting | ✅ | ✅ | ✅ | ✅ |
| rangeFormatting | ✅ | ✅ | ✅ | ✅ |
| signatureHelp | ✅ | ✅ | ❌ | ✅ |
| rename | ✅ | ✅ | ⚠️ | ✅ |
| codeAction | ✅ | ❌ | ❌ | ⚠️ |
| foldingRange | ✅ | ✅ | ❌ | ✅ |
| documentHighlight | ✅ | ✅ | ❌ | ✅ |
| codeLens | ✅ | ❌ | ❌ | ❌ |
| selectionRange | ✅ | ❌ | ❌ | ✅ |
| workspace/symbol | ✅ | ✅ | ✅ | ✅ |
| workspace/configuration | ✅ | ✅ | ✅ | ✅ |
| **Pure Perl** | ✅ | ⚠️ (XS) | ✅ | ❌ (Node.js) |

## Installation

### Voraussetzungen

- Perl 5.20 oder höher
- `cpanm` (App::cpanminus)

### Abhängigkeiten

```bash
# Automatische Installation aller Abhängigkeiten
cpanm --installdeps .
```

**Manuelle Installation der Core-Dependencies:**
- `JSON::PP` (Core-Modul)
- `PPI` - Perl-Parsing
- `Perl::Tidy` - Code-Formatierung

### YAPLSPD Installieren

```bash
git clone https://github.com/ghbalf/yaplspd.git
cd yaplspd
cpanm --installdeps .
```

## Editor-Setup

### Neovim

**Mit nvim-lspconfig:**

```lua
local lspconfig = require('lspconfig')
local configs = require('lspconfig.configs')

if not configs.yaplspd then
  configs.yaplspd = {
    default_config = {
      cmd = {'/pfad/zu/yaplspd/bin/yaplspd'},
      filetypes = {'perl'},
      root_dir = function(fname)
        return lspconfig.util.find_git_ancestor(fname)
      end,
    },
  }
end

lspconfig.yaplspd.setup{}
```

**Mit vim-lsp:**

```vim
if executable('yaplspd')
    au User lsp_setup call lsp#register_server({
        \ 'name': 'yaplspd',
        \ 'cmd': {server_info->['/pfad/zu/yaplspd/bin/yaplspd']},
        \ 'whitelist': ['perl'],
        \ })
endif
```

### VS Code

Erstelle `.vscode/settings.json` im Projekt-Root:

```json
{
  "perl.perlCmd": "perl",
  "perl.perlInc": ["lib", "local/lib/perl5"],
  "perl.trace.server": "verbose",
  "perl.debugAdapter": "null"
}
```

Für direkte YAPLSPD-Integration installiere die Extension und konfiguriere:

```json
{
  "perl.languageServer": "/pfad/zu/yaplspd/bin/yaplspd",
  "perl.languageServerEnabled": true
}
```

### Emacs

**Mit lsp-mode:**

```elisp
(require 'lsp-mode)

(add-to-list 'lsp-language-id-configuration '(perl-mode . "perl"))
(add-to-list 'lsp-language-id-configuration '(cperl-mode . "perl"))

(lsp-register-client
 (make-lsp-client :new-connection (lsp-stdio-connection '("/pfad/zu/yaplspd/bin/yaplspd"))
                  :major-modes '(perl-mode cperl-mode)
                  :server-id 'yaplspd))
```

## Verwendung

### Server Starten

```bash
# Direkt
./bin/yaplspd

# Mit Logging
PERL_YAPLSPD_LOG=1 ./bin/yaplspd 2>/tmp/yaplspd.log
```

### Tests Ausführen

```bash
# Alle Tests
prove -l

# Mit Verbose-Ausgabe
prove -lv

# Einzelne Test-Datei
prove -l t/completion.t
```

### Code Formatieren

```bash
# Projekt formatieren
perltidy lib/**/*.pm
```

## Architektur

```
lib/YAPLSPD/
├── Server.pm           # Haupt-Server (LSP-Protokoll)
├── Protocol.pm         # LSP-Protokoll-Handler
├── Document.pm         # Dokument-Verwaltung (PPI)
├── Completion.pm       # Autovervollständigung
├── Hover.pm            # Hover-Informationen
├── Definition.pm       # Go-to-Definition
├── References.pm       # Find-All-References
├── DocumentSymbol.pm   # Dokument-Symbole (Outline)
├── Formatting.pm       # Code-Formatierung (Perl::Tidy)
├── Diagnostics.pm      # Syntax-Diagnostik
├── SignatureHelp.pm    # Funktions-Signaturen
├── Rename.pm           # Symbol-Umbenennen
├── CodeAction.pm       # Quick-Fixes & Refactorings
├── FoldingRange.pm     # Code-Faltung
├── DocumentHighlight.pm # Symbol-Highlighting
├── CodeLens.pm         # Code-Linsen (Referenzen, Tests)
├── SelectionRange.pm   # Smarte Auswahl
└── WorkspaceSymbol.pm  # Workspace-weite Symbol-Suche
```

## Roadmap

### Erledigt (Phase 1-5)
- [x] Basis-LSP Protokoll
- [x] textDocument/* Features (Completion, Hover, Definition, References)
- [x] Dokument-Synchronisation
- [x] Diagnostik & Formatierung
- [x] Erweiterte Features (Signature Help, Rename, Code Actions)
- [x] Workspace Features (Symbols, Configuration)
- [x] 155+ Tests

### Phase 6 (Aktuell)
- [ ] README.md & Dokumentation
- [ ] LICENSE (MIT)
- [ ] GitHub Release

### Phase 7 (Geplant)
- [ ] E2E-Integration-Tests
- [ ] Call Hierarchy
- [ ] Type Hierarchy
- [ ] Semantic Tokens

## Troubleshooting

### "Can't locate PPI.pm"

```bash
cpanm PPI
```

### Server startet nicht

Prüfe die Logs:
```bash
PERL_YAPLSPD_LOG=1 ./bin/yaplspd 2>&1 | tee /tmp/yaplspd.log
```

### Keine Autovervollständigung

Stelle sicher, dass das `lib/` Verzeichnis im `@INC` ist:
```perl
# In .vscode/settings.json oder Editor-Config
"perl.perlInc": ["lib", "local/lib/perl5"]
```

## Lizenz

MIT License — Siehe [LICENSE](LICENSE)

## Contributing

Pull Requests willkommen! Bitte:
1. Tests schreiben für neue Features
2. `perltidy` vor Commit ausführen
3. Bestehende Tests müssen passen: `prove -l`

---

*YAPLSPD — Weil Perl einen modernen LSP verdient.*
