# YAPLSPD — Yet Another Perl Language Server Protocol Daemon

*Deutsche Version: [README_DE.md](README_DE.md)*

A complete Perl Language Server Protocol (LSP) daemon written in pure Perl.

## Features

### Implemented LSP Features (19)

| Feature | Method | Status |
|---------|--------|--------|
| **Autocompletion** | `textDocument/completion` | ✅ |
| **Hover Information** | `textDocument/hover` | ✅ |
| **Go to Definition** | `textDocument/definition` | ✅ |
| **Find References** | `textDocument/references` | ✅ |
| **Document Symbols** | `textDocument/documentSymbol` | ✅ |
| **Code Formatting** | `textDocument/formatting` | ✅ |
| **Range Formatting** | `textDocument/rangeFormatting` | ✅ |
| **Signature Help** | `textDocument/signatureHelp` | ✅ |
| **Rename** | `textDocument/rename` | ✅ |
| **Code Actions** | `textDocument/codeAction` | ✅ |
| **Folding Ranges** | `textDocument/foldingRange` | ✅ |
| **Document Highlight** | `textDocument/documentHighlight` | ✅ |
| **Code Lens** | `textDocument/codeLens` | ✅ |
| **Selection Range** | `textDocument/selectionRange` | ✅ |
| **Workspace Symbols** | `workspace/symbol` | ✅ |
| **Configuration** | `workspace/didChangeConfiguration` | ✅ |
| **File Watching** | `workspace/didChangeWatchedFiles` | ✅ |
| **Document Sync** | `textDocument/didOpen/didChange/didClose` | ✅ |
| **Diagnostics** | `textDocument/publishDiagnostics` | ✅ |

### YAPLSPD vs. Competition

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

### Requirements

- Perl 5.20 or higher
- `cpanm` (App::cpanminus)

### Dependencies

```bash
# Automatic installation of all dependencies
cpanm --installdeps .
```

**Manual installation of core dependencies:**
- `JSON::PP` (core module)
- `PPI` - Perl parsing
- `Perl::Tidy` - Code formatting

### Installing YAPLSPD

```bash
git clone https://github.com/ghbalf/yaplspd.git
cd yaplspd
cpanm --installdeps .
```

## Editor Setup

### Neovim

**With nvim-lspconfig:**

```lua
local lspconfig = require('lspconfig')
local configs = require('lspconfig.configs')

if not configs.yaplspd then
  configs.yaplspd = {
    default_config = {
      cmd = {'/path/to/yaplspd/bin/yaplspd'},
      filetypes = {'perl'},
      root_dir = function(fname)
        return lspconfig.util.find_git_ancestor(fname)
      end,
    },
  }
end

lspconfig.yaplspd.setup{}
```

**With vim-lsp:**

```vim
if executable('yaplspd')
    au User lsp_setup call lsp#register_server({
        \ 'name': 'yaplspd',
        \ 'cmd': {server_info->['/path/to/yaplspd/bin/yaplspd']},
        \ 'whitelist': ['perl'],
        \ })
endif
```

### VS Code

Create `.vscode/settings.json` in your project root:

```json
{
  "perl.perlCmd": "perl",
  "perl.perlInc": ["lib", "local/lib/perl5"],
  "perl.trace.server": "verbose",
  "perl.debugAdapter": "null"
}
```

For direct YAPLSPD integration, install the extension and configure:

```json
{
  "perl.languageServer": "/path/to/yaplspd/bin/yaplspd",
  "perl.languageServerEnabled": true
}
```

### Emacs

**With lsp-mode:**

```elisp
(require 'lsp-mode)

(add-to-list 'lsp-language-id-configuration '(perl-mode . "perl"))
(add-to-list 'lsp-language-id-configuration '(cperl-mode . "perl"))

(lsp-register-client
 (make-lsp-client :new-connection (lsp-stdio-connection '("/path/to/yaplspd/bin/yaplspd"))
                  :major-modes '(perl-mode cperl-mode)
                  :server-id 'yaplspd))
```

## Usage

### Starting the Server

```bash
# Direct
./bin/yaplspd

# With logging
PERL_YAPLSPD_LOG=1 ./bin/yaplspd 2>/tmp/yaplspd.log
```

### Running Tests

```bash
# All tests
prove -l

# With verbose output
prove -lv

# Single test file
prove -l t/completion.t
```

### Code Formatting

```bash
# Format project
perltidy lib/**/*.pm
```

## Architecture

```
lib/YAPLSPD/
├── Server.pm           # Main server (LSP protocol)
├── Protocol.pm         # LSP protocol handler
├── Document.pm         # Document management (PPI)
├── Completion.pm       # Autocompletion
├── Hover.pm            # Hover information
├── Definition.pm       # Go-to-definition
├── References.pm       # Find-all-references
├── DocumentSymbol.pm   # Document symbols (outline)
├── Formatting.pm       # Code formatting (Perl::Tidy)
├── Diagnostics.pm      # Syntax diagnostics
├── SignatureHelp.pm    # Function signatures
├── Rename.pm           # Symbol renaming
├── CodeAction.pm       # Quick-fixes & refactorings
├── FoldingRange.pm     # Code folding
├── DocumentHighlight.pm # Symbol highlighting
├── CodeLens.pm         # Code lenses (references, tests)
├── SelectionRange.pm   # Smart selection
└── WorkspaceSymbol.pm  # Workspace-wide symbol search
```

## Roadmap

### Completed (Phase 1-5)
- [x] Basic LSP protocol
- [x] textDocument/* features (Completion, Hover, Definition, References)
- [x] Document synchronization
- [x] Diagnostics & formatting
- [x] Advanced features (Signature Help, Rename, Code Actions)
- [x] Workspace features (Symbols, Configuration)
- [x] 155+ tests

### Phase 6 (Current)
- [ ] README.md & documentation
- [ ] LICENSE (MIT)
- [ ] GitHub release

### Phase 7 (Planned)
- [ ] E2E integration tests
- [ ] Call hierarchy
- [ ] Type hierarchy
- [ ] Semantic tokens

## Troubleshooting

### "Can't locate PPI.pm"

```bash
cpanm PPI
```

### Server won't start

Check the logs:
```bash
PERL_YAPLSPD_LOG=1 ./bin/yaplspd 2>&1 | tee /tmp/yaplspd.log
```

### No autocompletion

Make sure the `lib/` directory is in `@INC`:
```perl
# In .vscode/settings.json or your editor config
"perl.perlInc": ["lib", "local/lib/perl5"]
```

## License

MIT License — See [LICENSE](LICENSE)

## Contributing

Pull requests welcome! Please:
1. Write tests for new features
2. Run `perltidy` before committing
3. Ensure existing tests pass: `prove -l`

---

*YAPLSPD — Because Perl deserves a modern LSP.*
