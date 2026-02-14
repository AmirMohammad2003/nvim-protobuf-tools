# nvim-protobuf-tools

Protocol Buffers development tools for Neovim.

> **Note:** This plugin was built with [Claude Code](https://claude.ai/code).

## Features

- **Compile on save** - Auto-run protoc when .proto files are saved
- **VSCode workspace support** - Reads and respects `.vscode/settings.json` configurations
- **Language-agnostic** - Works with any protoc output language (Go, Python, Java, etc.)
- **Linting** - Integration with buf, protolint, and api-linter
- **Formatting** - Built-in formatter or use clang-format/buf format
- **Breaking change detection** - Compare schemas against git refs
- **Field renumbering** - Automatically renumber message fields and enum values
- **Schema visualization** - Display dependency graphs for proto files
- **Async execution** - Non-blocking compilation and linting

## Requirements

- Neovim 0.10+
- protoc (Protocol Buffers compiler) - **required**
- buf, protolint, or api-linter (optional, for linting)
- clang-format (optional, for formatting)
- git (optional, for breaking change detection)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "amirmohammad2003/nvim-protobuf",
  dev = true, -- If developing locally
  config = function()
    require("nvim-protobuf").setup({
      -- Your configuration here
    })
  end,
}
```

## Configuration

### Neovim Configuration

Example configuration in your `init.lua`:

```lua
require('nvim-protobuf').setup({
  protoc = {
    path = 'protoc',
    options = {
      '--go_out=./gen',
      '--go-grpc_out=./gen',
      '--proto_path=.',
    },
    compileOnSave = true,
  },
  includes = {
    '${workspaceFolder}/proto',
    '${workspaceFolder}/third_party',
  },
  formatOnSave = false,
  formatter = {
    enabled = true,
    type = 'builtin', -- 'builtin', 'clang-format', or 'buf'
  },
  externalLinter = {
    linter = 'buf', -- 'none', 'buf', 'protolint', or 'api-linter'
    runOnSave = false,
  },
  breaking = {
    enabled = false,
    againstGitRef = 'main',
  },
})
```

### VSCode Workspace Compatibility

The plugin automatically reads `.vscode/settings.json` from your workspace root. VSCode settings take precedence over Neovim configuration.

Example `.vscode/settings.json`:

```json
{
  "protobuf.protoc.path": "protoc",
  "protobuf.protoc.options": [
    "--go_out=./gen",
    "--go-grpc_out=./gen",
    "--proto_path=."
  ],
  "protobuf.protoc.compileOnSave": true,
  "protobuf.includes": [
    "${workspaceFolder}/proto"
  ],
  "protobuf.formatOnSave": false,
  "protobuf.externalLinter.linter": "buf",
  "protobuf.externalLinter.runOnSave": false
}
```

### Configuration Precedence

1. VSCode settings (`.vscode/settings.json`) - **highest priority**
2. User Neovim config (`setup()` call)
3. Plugin defaults - **lowest priority**

### Variable Substitution

The plugin supports VSCode-style variable substitution:

- `${workspaceFolder}` - Workspace root directory
- `${file}` - Current file path
- `${fileDirname}` - Current file's directory
- `${fileBasename}` - Current file name
- `${fileBasenameNoExtension}` - File name without extension
- `${env:VAR_NAME}` - Environment variables

Example:

```json
{
  "protobuf.protoc.options": [
    "--go_out=${workspaceFolder}/gen",
    "--proto_path=${workspaceFolder}/proto"
  ]
}
```

## Usage

### Commands

- `:ProtobufCompile [file]` - Compile current or specified proto file
- `:ProtobufCompileAll` - Compile all proto files in workspace
- `:ProtobufLint` - Run configured linter on current file
- `:ProtobufFormat` - Format current proto file
- `:ProtobufBreaking [ref]` - Check breaking changes against git ref
- `:ProtobufRenumber` - Renumber fields and enums
- `:ProtobufGraph` - Show schema dependency graph
- `:ProtobufReloadConfig` - Reload configuration

### Compile on Save

Enable compile-on-save in your configuration:

```lua
require('nvim-protobuf').setup({
  protoc = {
    compileOnSave = true,
  },
})
```

Or in `.vscode/settings.json`:

```json
{
  "protobuf.protoc.compileOnSave": true
}
```

### Linting

Configure a linter:

```lua
require('nvim-protobuf').setup({
  externalLinter = {
    linter = 'buf',
    runOnSave = true,
  },
})
```

Supported linters:
- **buf** - Modern Protobuf tooling
- **protolint** - Protobuf linter
- **api-linter** - Google API linter

### Formatting

The plugin supports three formatting backends:

1. **Built-in** - Simple indentation-based formatter (no dependencies)
2. **clang-format** - Uses clang-format for formatting
3. **buf** - Uses buf format

Configure formatter:

```lua
require('nvim-protobuf').setup({
  formatOnSave = true,
  formatter = {
    enabled = true,
    type = 'clang-format', -- or 'buf' or 'builtin'
  },
})
```

### Breaking Change Detection

Check for breaking changes against a git reference:

```vim
:ProtobufBreaking main
:ProtobufBreaking HEAD~1
```

Or enable automatic detection:

```lua
require('nvim-protobuf').setup({
  breaking = {
    enabled = true,
    againstGitRef = 'main',
  },
})
```

### Schema Visualization

View dependency graph:

```vim
:ProtobufGraph
```

Press `q` or `Esc` to close the graph window.

## Diagnostics

The plugin integrates with Neovim's native diagnostic system. Errors and warnings from protoc, linters, and breaking change detection are displayed as diagnostics with virtual text, signs, and in the quickfix list.

Diagnostic sources:
- `protoc` - Compilation errors
- `buf`/`protolint`/`api-linter` - Linter warnings
- `breaking-changes` - Breaking change violations

## Examples

### Minimal Setup (Use VSCode Settings Only)

```lua
require('nvim-protobuf').setup({})
```

Then create `.vscode/settings.json` in your project.

### Go Project

```lua
require('nvim-protobuf').setup({
  protoc = {
    path = 'protoc',
    options = {
      '--go_out=./gen',
      '--go_opt=paths=source_relative',
      '--go-grpc_out=./gen',
      '--go-grpc_opt=paths=source_relative',
      '--proto_path=.',
    },
    compileOnSave = true,
  },
  includes = { '${workspaceFolder}/proto' },
  externalLinter = {
    linter = 'buf',
    runOnSave = true,
  },
})
```

### Python Project

```lua
require('nvim-protobuf').setup({
  protoc = {
    options = {
      '--python_out=./gen',
      '--pyi_out=./gen',
      '--proto_path=.',
    },
    compileOnSave = true,
  },
})
```

## Troubleshooting

### Protoc not found

Make sure protoc is installed and in your PATH:

```bash
protoc --version
```

Install from: https://protobuf.dev/downloads/

### VSCode settings not being read

Check that:
1. `.vscode/settings.json` exists in your workspace root
2. The file contains valid JSON (JSONC with comments is supported)
3. Run `:ProtobufReloadConfig` to reload settings

Debug workspace root detection:

```lua
:lua print(require('nvim-protobuf.utils').find_workspace_root())
```

### Compilation errors not showing

Check that diagnostics are enabled:

```lua
require('nvim-protobuf').setup({
  diagnostics = {
    enabled = true,
    virtual_text = true,
  },
})
```

### Format-on-save not working

Ensure the formatter is installed and enabled:

```lua
require('nvim-protobuf').setup({
  formatOnSave = true,
  formatter = {
    enabled = true,
  },
})
```


## Acknowledgments

[protobuf-vsc-extension](https://github.com/DrBlury/protobuf-vsc-extension) 
