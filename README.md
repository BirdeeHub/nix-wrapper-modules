# wrappers

A Nix library to create wrapped executables via the module system.

Are you annoyed by rewriting modules for every platform? nixos, home-manager, nix-darwin, devenv?

Then this library is for you!

[xkcd 927](https://xkcd.com/927/)

## Overview

This library provides two main components:

- `lib.wrapPackage`: Low-level function to wrap packages with additional flags, environment variables, and runtime dependencies
- `lib.wrapModule`: High-level function to create reusable wrapper modules with type-safe configuration options
- `wrapperModules`: Pre-built wrapper modules for common packages (mpv, notmuch, etc.)

## Usage

### Using Pre-built Wrapper Modules

```nix
{
  inputs.wrappers.url = "github:lassulus/wrappers";
  
  outputs = { self, nixpkgs, wrappers }: {
    packages.x86_64-linux.default = 
      wrappers.wrapperModules.mpv.apply {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        scripts = [ pkgs.mpvScripts.mpris ];
        "mpv.conf".content = ''
          vo=gpu
          hwdec=auto
        '';
        "mpv.input".content = ''
          WHEEL_UP seek 10
          WHEEL_DOWN seek -10
        '';
      };
  };
}
```

### Using wrapPackage Directly

```nix
{ pkgs, wrappers, ... }:

wrappers.lib.wrapPackage {
  inherit pkgs;
  package = pkgs.curl;
  runtimeInputs = [ pkgs.jq ];
  env = {
    CURL_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  };
  flags = {
    "--silent" = {};
    "--connect-timeout" = "30";
  };
  # Or use args directly for more control:
  # args = [ "--silent" "--connect-timeout" "30" ];
  flagSeparator = "=";  # Use --flag=value instead of --flag value (default is " ")
  preHook = ''
    echo "Making request..." >&2
  '';
}
```

### Creating Custom Wrapper Modules

```nix
{ wlib, lib }:

wlib.wrapModule (wlib: { config, ... }: {
  options = {
    profile = lib.mkOption {
      type = lib.types.enum [ "fast" "quality" ];
      default = "fast";
      description = "Encoding profile to use";
    };
    outputDir = lib.mkOption {
      type = lib.types.str;
      default = "./output";
      description = "Directory for output files";
    };
  };
  
  config.package = config.pkgs.ffmpeg;
  config.flags = {
    "-preset" = if config.profile == "fast" then "veryfast" else "slow";
  };
  config.env = {
    FFMPEG_OUTPUT_DIR = config.outputDir;
  };
})
```

## Technical Details

### wrapPackage Function

Arguments:
- `pkgs`: nixpkgs instance
- `package`: Base package to wrap
- `runtimeInputs`: List of packages added to PATH (default: `[]`)
- `env`: Attribute set of environment variables (default: `{}`)
- `flags`: Attribute set of command-line flags (default: `{}`)
  - Value `{}`: Flag without argument (e.g., `--verbose`)
  - Value `"string"`: Flag with argument (e.g., `--output "file.txt"`)
  - Value `false` or `null`: Flag omitted
- `flagSeparator`: Separator between flag name and value when generating args from flags (default: `" "`, can be `"="`)
- `args`: List of command-line arguments like argv in execve (default: auto-generated from `flags`)
  - Example: `[ "--silent" "--connect-timeout" "30" ]`
  - If provided, overrides automatic generation from `flags`
- `preHook`: Shell script executed before the command (default: `""`)
- `passthru`: Additional attributes for the derivation's passthru (default: `{}`)
- `aliases`: List of additional symlink names for the executable (default: `[]`)
- `filesToPatch`: List of file paths (glob patterns) relative to package root to patch for self-references (default: `["share/applications/*.desktop"]`)
  - Example: `["bin/*", "lib/*.sh"]` to replace original package paths with wrapped package paths
  - Desktop files are patched by default to update Exec= and Icon= paths
- `wrapper`: Custom wrapper function (optional, overrides default exec wrapper)

The function:
- Preserves all outputs from the original package (man pages, completions, etc.)
- Uses `lndir` for symlinking to maintain directory structure
- Generates a shell wrapper script with proper escaping
- Handles multi-output derivations correctly

### wrapModule Function

Creates a reusable wrapper module with:
- Type-safe configuration options via the module system
- `options`: Exposed options for documentation generation
- `apply`: Function to instantiate the wrapper with settings

Built-in options (always available):
- `pkgs`: nixpkgs instance (required)
- `package`: Base package to wrap
- `extraPackages`: Additional runtime dependencies
- `flags`: Command-line flags (attribute set)
- `flagSeparator`: Separator between flag name and value (default: `" "`)
- `args`: Command-line arguments list (auto-generated from `flags` if not provided)
- `env`: Environment variables
- `passthru`: Additional passthru attributes
- `filesToPatch`: List of file paths (glob patterns) to patch for self-references (default: `["share/applications/*.desktop"]`)

Custom types:
- `wlib.types.file`: File type with `content` and `path` options
  - `content`: File contents as string
  - `path`: Derived path using `pkgs.writeText`

### Module System Integration

The wrapper module system integrates with NixOS module evaluation:
- Uses `lib.evalModules` for configuration evaluation
- Supports all standard module features (imports, conditionals, mkIf, etc.)
- Provides `config` for accessing evaluated configuration
- Provides `options` for introspection and documentation

## Example Modules

### mpv Module

Wraps mpv with configuration file support and script management:

```nix
wrappers.wrapperModules.mpv.apply {
  pkgs = pkgs;
  scripts = [ pkgs.mpvScripts.mpris pkgs.mpvScripts.thumbnail ];
  "mpv.conf".content = ''
    vo=gpu
    profile=gpu-hq
  '';
  "mpv.input".content = ''
    RIGHT seek 5
    LEFT seek -5
  '';
  extraFlags = {
    "--save-position-on-quit" = {};
  };
}
```

### notmuch Module

Wraps notmuch with INI-based configuration:

```nix
wrappers.wrapperModules.notmuch.apply {
  pkgs = pkgs;
  config = {
    database = {
      path = "/home/user/Mail";
      mail_root = "/home/user/Mail";
    };
    user = {
      name = "John Doe";
      primary_email = "john@example.com";
    };
  };
}
```

## Long-term Goals

Upstream this schema into nixpkgs with an optional module.nix for every package. NixOS modules could then reuse these wrapper modules for consistent configuration across platforms.
