# Neovim Development Environment

This configuration provides a Roslyn-based C# environment, Elm language-server support, formatting, debugging, project search, Tree-sitter text objects, and the Tokyo Night theme.

## Getting started

Open Neovim from the root of a .NET project:

```sh
nvim .
```

`nvim .` restores the last file used in that project directory.

Saving does not format the file automatically. Use `Space c f` to format the current file (or only the Visual selection). C# formatting is provided by Roslyn and follows the project’s `.editorconfig`.

In Elm projects (directories containing `elm.json`), `elm-language-server` starts automatically. `Space c f` runs `elm-format`; use `elm make` and `elm-test` for builds and tests.

When a new `.cs` file is created, Neovim generates a file-scoped namespace from the nearest `.csproj` and directory path.

## CI

`.github/workflows/neovim.yml` runs on pushes to `main` and pull requests. It installs the pinned Lazy plugins and Tree-sitter parsers on macOS, then runs `bash tests/run.sh`.

## C# formatting

CSharpier is not used. `Space c f` applies Roslyn formatting rules from `.editorconfig`, for example:

```ini
[*.cs]
indent_style = space
indent_size = 4
csharp_new_line_before_open_brace = all
csharp_preserve_single_line_blocks = true
csharp_preserve_single_line_statements = true
```

## C# snippets

In Insert mode, type `ctor`, `prop`, `propg`, `if`, `for`, `foreach`, `dowhile`, `?:`, `lst`, `hset`, `arr`, `dict`, `queue`, `stack`, `swe`, `region`, `try`, or `cw`, then select the snippet with `Enter`. `Tab` moves to the next placeholder and `Shift-Tab` moves to the previous one. `ctor` uses the enclosing class name.

Collection snippets use C# 12 collection expressions where appropriate. `swe` creates a switch expression and supports adding or removing arms with `Tab`.

Inside a class, `Space c a` opens Roslyn code actions such as constructor generation. Select statements with `V` and use the same command for **Extract method**.

Place the cursor on a class, method, or property declaration and press `Space c d` to generate XML documentation. Method parameters receive `<param>` entries.

## Basic Vim commands

`<leader>` is mapped to `Space`.

| Key | Action |
| --- | --- |
| `i` | Enter Insert mode |
| `Esc` | Return to Normal mode |
| `:w` | Save |
| `:q` | Save all files, then quit |
| `:wq` | Save and quit |
| `u` / `Ctrl-r` | Undo / redo |
| `Shift-Up` / `Shift-Down` | Move the current line without touching the clipboard; also works in Insert mode |
| `Option-Left` / `Option-Right` | Move by word in Insert mode |
| `Command-Left` / `Command-Right` | Move to the first non-whitespace character / end of line in Insert mode |
| `Left` / `Right` at a line boundary | Move to the previous line’s end / next line’s beginning in Insert mode |
| `za` | Toggle the fold under the cursor |
| `zM` / `zR` | Close / open all Tree-sitter folds |
| `/text`, `n` | Search / next match |

For C# completion, `Option-i` converts compatible `new` expressions to an initializer, `Option-u` converts compatible collection declarations to collection expressions, and `Option-Enter` finishes the current expression by moving past a closing delimiter and adding a missing semicolon when it is safe.

## Code navigation

| Key | Action |
| --- | --- |
| `gd` | Go to definition |
| `gi` | Go to implementation |
| `gr` | Find references |
| `K` | Show documentation / hover information |
| `Space s` | Show method parameters and signature help |
| `Option-s` / `Option-Shift-s` | Next / previous overload while signature help is open |
| `Space r n` | Rename symbol |
| `Space c a` | Code action |
| `Space c d` | Generate C# XML documentation |
| `Space c f` | Format the file or Visual selection |
| `Space e` | Show the diagnostic under the cursor |
| `Space y` | Copy the diagnostic under the cursor |
| `Space x` | Toggle the diagnostic list |
| `[d` / `]d` | Previous / next diagnostic |

Unused imports and similar fixes are available through `Space c a` and the relevant Roslyn action.

## SQL Server and sqldeps

For `.sql` buffers, `sqldeps lsp` provides ScriptDom parsing, diagnostics, completion, hover, and navigation over stdio. `gd`, `gr`, `K`, `Space d s`, and `Space w s` provide the standard LSP actions. Rename and formatting are intentionally not configured because sqldeps does not support them.

Tree-sitter’s MSSQL parser remains responsible for highlighting, folding, text objects, and clause motions. Index a SQL project with `sqldeps index .` for command-line queries and C# → SQL navigation.

The commands `:SqlDef`, `:SqlRefs`, and `:SqlColumns` query the SQLite index and open their results in the quickfix list. From a C# buffer, `Space c s` opens the matching stored procedure definition.

The default index is searched under `~/.local/share/sqldeps/<workspace>.sqlite`. Override it in Neovim with:

```lua
vim.g.sqldeps_database = "/absolute/path/deps.sqlite"
vim.g.sqldeps_root = "/absolute/path/sql-sources"
```

## Tree-sitter text objects and motions

These mappings work in Visual and operator-pending mode for C#, T-SQL, and JSON:

| Key | Action |
| --- | --- |
| `vab` / `vib` | Select a block including / excluding delimiters |
| `vaf` / `vif` | Select a method or function including / excluding its body delimiters |
| `val` / `vil` | Select a loop including / excluding its body delimiters |
| `vaC` / `viC` | Select an `if` or `switch` conditional |
| `vac` / `vic` | Select a class, struct, record, interface, or enum |
| `vaa` / `via` | Select an argument or parameter |
| `vaq` / `vaS` | Select a T-SQL query / statement |
| `]f` / `[f` | Next / previous method, function, procedure, or trigger |
| `]F` / `[F` | Next / previous method, function, procedure, or trigger end |
| `]a` / `[a` | Next / previous argument or parameter |
| `]c` / `[c` | Next / previous conditional |
| `]r` / `[r` | Next / previous query or parent query |
| `]k` / `[k` | Next / previous clause or C# structural item |
| `]s` / `[s` | Next / previous T-SQL statement |
| `]S` / `[S` | Next / previous spelling error |
| `]K` / `[K` | Next / previous C# `case` or `default` arm |

## Search

| Key | Action |
| --- | --- |
| `Space f f` | Find files; frequently and recently used files come first |
| `Space f g` | Search project text case-insensitively |
| `Space f G` | Fuzzy-search source and project files |
| `Space f b` | Search open buffers |
| `Space f s` | Search symbols in the current file |
| `Space f S` | Search project symbols |
| `Space f h` | Search Neovim help |

## Surround and file tree

| Key | Action |
| --- | --- |
| `sa` + delimiter | Add a surrounding pair; e.g. `saiw)` |
| `ds` + delimiter | Delete a surrounding pair |
| `sr` + old/new delimiter | Replace a surrounding pair |
| `Space n` | Toggle the icon-enabled file tree |
| `Right` in the tree | Open a file or expand a directory |
| `Left` in the tree | Collapse a directory or go to its parent |
| `Tab` in the tree | Preview the selected file while keeping focus in the tree |
| `W` in the tree | Collapse all directories |

The tree hides `bin/`, `obj/`, `.DS_Store`, and other generated noise. Opening it focuses the directory of the current file.

## Debugger

Run `dotnet build`, then press `F5`. The configuration discovers an executable, web, or worker project and launches its Debug DLL with `netcoredbg`. `Properties/launchSettings.json` values such as `commandLineArgs`, `workingDirectory`, environment variables, and web URLs are applied when available.

| Key | Action |
| --- | --- |
| `Space b` | Toggle a breakpoint on the current line |
| `F5` | Start / continue |
| `F10` | Step over |
| `F11` | Step into |
| `F12` | Step out |
| `Space d u` | Toggle the debug UI |
| `Space d c` | Clear all breakpoints |
| `Space d r` | Open the debug REPL |

Legacy .NET Framework projects can be debugged with Mono when installed through `./bootstrap-macos.sh --with-mono`.

## Terminal and tests

`Space t t` toggles the built-in terminal. While the terminal has focus, `Ctrl-\\` hides it and returns to the previous editor window.

| Key | Action |
| --- | --- |
| `Space r b` | Build the current solution or project asynchronously |
| `Space r r` | Run the test suite once |
| `Space r t` | Run the test or class under the cursor |
| `Space t w` | Start `dotnet test --watch` |

Build errors and warnings are sent to the quickfix list. Use `:cnext` and `:cprev` to navigate them, including errors in other files.

## Resource monitor

Bootstrap installs the macOS LaunchAgent `com.neovim.resource-watch`. Every 15 seconds it checks all processes and system memory pressure. A single macOS notification is sent when a process exceeds 80% CPU for three samples or free memory falls below 10%. The monitor never stops processes and sends no data anywhere.

Configure it with `NEO_RESOURCE_INTERVAL`, `NEO_RESOURCE_CPU_THRESHOLD`, `NEO_RESOURCE_MEMORY_FREE_THRESHOLD`, and `NEO_RESOURCE_SAMPLES_REQUIRED`. Disable it with:

```sh
launchctl bootout gui/$UID/com.neovim.resource-watch
```

## Command-line tools

The bootstrap installs or configures tools such as `z`, `fd`, `bat`, `fzf`, `lazygit`, `direnv`, `fossil`, and `gh`. Fossil commands including `status`, `changes`, `addremove`, `extras`, `timeline`, `branch list`, `tag list`, `info`, and `annotate` use readable, subdued colors.

| Key | Action |
| --- | --- |
| `Ctrl-r` | Open interactive history search |
| `Enter` | Run the command currently typed at the prompt |
| `Ctrl-g` | Accept the faded history suggestion without executing it |
| `Option-Delete` | Delete the word to the right of the cursor |

## Configuration layout

- `init.lua`: entry point; loads the `lua/neo` modules
- `lua/neo/plugins.lua`: bootstraps lazy.nvim and imports plugin modules
- `lua/neo/plugins/`: plugin definitions grouped by topic
- `lua/neo/textobjects.lua`: Tree-sitter text objects and structural motions
- `lua/neo/dotnet_debug.lua`: .NET project discovery and launch settings
- `lua/neo/call_parens.lua`: C# completion post-processing and Insert-mode expression helpers
- `lua/neo/lsp.lua`: Roslyn, Elm, and sqldeps LSP setup
- `lua/neo/snippets.lua`: C# snippets and documentation templates
- `lua/neo/dotnet_build.lua`: asynchronous build and quickfix integration
- `lua/neo/dotnet_test.lua`: test discovery and execution

Press and briefly hold `Space` in Normal mode to see available mappings with which-key. Use `:Lazy sync` to update plugins and `:restart` after changing `init.lua` or plugin configuration. Run `bash tests/run.sh` after plugin updates to validate the configuration in headless mode.

## New Mac setup

Clone this repository to `~/.config/nvim`, then run:

```sh
cd ~/.config/nvim
./bootstrap-macos.sh
```

Useful options:

```sh
./bootstrap-macos.sh --with-mono
./bootstrap-macos.sh --no-elm
```

If `~/Projects/sqldeps` already exists, bootstrap uses it. To clone sqldeps automatically, provide a repository URL (and optionally a different destination):

```sh
SQLDEPS_REPOSITORY=https://github.com/<owner>/sqldeps.git ./bootstrap-macos.sh
SQLDEPS_REPOSITORY=https://github.com/<owner>/sqldeps.git \
SQLDEPS_DIR="$HOME/Projects/sqldeps" \
./bootstrap-macos.sh
```

The script installs the required package-manager tools, Neovim, Ghostty configuration, language servers, formatters, debugger support, and shell helpers. Review the script before running it on another machine if you want a narrower installation.
