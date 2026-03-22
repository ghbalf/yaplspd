# Perl LSP Implementierungen — Feature-Matrix

*Erstellt: 2026-02-09, Analyse via Kimi K2.5 Sub-Agent*

## Untersuchte Projekte

| Projekt | Sprache | Stars | Contributors | Letzter Commit |
|---------|---------|-------|--------------|----------------|
| **Perl::LanguageServer** | Perl + XS | ~450+ | 15+ | Jan 2024 |
| **PLS** | Perl | — | 5-6 | Dez 2023 |
| **Perl Navigator** | TypeScript/Node.js | ~200+ | 8+ | Feb 2024 |

## textDocument/* Capabilities

| Feature | Perl::LS | PLS | Navigator | YAPLSPD Prio |
|---------|----------|-----|-----------|-------------|
| completion | ✅ | ✅ | ✅ | Must |
| hover | ✅ | ✅ | ✅ | Must |
| definition | ✅ | ✅ | ✅ | Must |
| declaration | ✅ | ❌ | ✅ | Should |
| implementation | ⚠️ | ❌ | ⚠️ | Could |
| typeDefinition | ❌ | ❌ | ⚠️ | Could |
| references | ✅ | ✅ | ✅ | Must |
| documentHighlight | ✅ | ❌ | ✅ | Should |
| documentSymbol | ✅ | ✅ | ✅ | Must |
| codeAction | ❌ | ❌ | ⚠️ | **Differentiator!** |
| codeLens | ❌ | ❌ | ❌ | **Differentiator!** |
| formatting | ✅ | ✅ | ✅ | Must (perltidy) |
| rangeFormatting | ✅ | ✅ | ✅ | Must |
| onTypeFormatting | ❌ | ❌ | ❌ | **Differentiator!** |
| rename | ✅ | ⚠️ | ✅ | Must |
| prepareRename | ✅ | ❌ | ✅ | Should |
| foldingRange | ✅ | ❌ | ✅ | Should |
| selectionRange | ❌ | ❌ | ✅ | Could |
| semanticTokens | ❌ | ❌ | ✅ | Should |
| callHierarchy | ❌ | ❌ | ❌ | **Differentiator!** |
| typeHierarchy | ❌ | ❌ | ❌ | **Differentiator!** |
| diagnostics | ✅ | ✅ | ✅ | Must |

## workspace/* Capabilities

| Feature | Perl::LS | PLS | Navigator |
|---------|----------|-----|-----------|
| symbol | ✅ | ✅ | ✅ |
| executeCommand | ✅ | ⚠️ | ✅ |
| configuration | ✅ | ✅ | ✅ |
| didChangeConfiguration | ✅ | ✅ | ✅ |
| didChangeWatchedFiles | ✅ | ✅ | ✅ |
| workspaceFolders | ✅ | ✅ | ✅ |
| semanticTokens/refresh | ❌ | ❌ | ✅ |
| codeLens/refresh | ❌ | ❌ | ❌ |

## YAPLSPD Differentiator-Features

Features die **KEINE** existierende Implementierung bietet:
1. **Call Hierarchy** — Wer ruft wen? Essentiell für große Codebasen
2. **Type Hierarchy** — OO-Vererbungsketten visualisieren
3. **Code Lens** — Inline-Referenzen, Test-Status, etc.
4. **On-Type Formatting** — Automatisches Formatieren beim Tippen
5. **Code Actions** — Automatische Fixes, Refactorings (nur Navigator hat Basics)

## Bekannte Schwächen der Konkurrenz

- **Perl::LS:** Performance bei großen Codebasen, Memory-Leaks bei langen Sessions
- **PLS:** Sehr limitiert, keine fortgeschrittenen Features
- **Navigator:** Node.js-Abhängigkeit (Electron), nicht nativ Perl

## Empfehlung für YAPLSPD

**MVP-Strategie:** Erst die "Must"-Features implementieren (das können alle), dann die "Differentiator"-Features die niemand hat. Das gibt YAPLSPD einen echten USP.

**Tech-Vorteil:** YAPLSPD in Perl geschrieben = versteht Perl nativ besser als Navigator (TypeScript).

---

*Nächster Schritt: LSP Spec lesen, Architektur entwerfen, MVP definieren*
