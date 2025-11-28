## Overview

This library provides two main components:

- `lib.evalModule`: Function to create reusable wrapper modules with type-safe configuration options
  - And related, `lib.wrapPackage`: an alias for `evalModule` which returns the package directly and pre-imports the `wlib.modules.default` module for convenience
- `wrapperModules`: Pre-built wrapper modules for common packages (`tmux`, `wezterm`, etc.)

## Usage

Note: there are also template(s) you can access via `nix flake init -t github:Birdeehub/nix-wrapper-modules`

They will get you started with a module file and the default one also gives you a flake which imports it, for quickly testing it out!

### Using Pre-built Wrapper Modules

```nix
{
  inputs.wrappers.url = "github:BirdeeHub/nix-wrapper-modules";
  outputs = { self, wrappers }: {
    packages.x86_64-linux.default =
      wrappers.wrapperModules.wezterm.wrap rec {
        pkgs = wrappers.inputs.nixpkgs.legacyPackages.x86_64-linux;
        luaInfo = {
          keys = [
            {
              key = "F12";
              mods = "SUPER|CTRL|ALT|SHIFT";
              action = pkgs.lib.generators.mkLuaInline "wezterm.action.Nop";
            }
          ];
        };
      };
  };
}
```

```nix
{
  inputs.wrappers.url = "github:BirdeeHub/nix-wrapper-modules";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs, wrappers }: let
    forAllSystems = with nixpkgs.lib; genAttrs platforms.all;
  in {
    packages = forAllSystems (system: {
      default = wrappers.wrapperModules.mpv.wrap (
        {config, wlib, lib, ...}: {
          pkgs = import nixpkgs { inherit system; };
          scripts = [ config.pkgs.mpvScripts.mpris ];
          "mpv.conf".content = ''
            vo=gpu
            hwdec=auto
          '';
          "mpv.input".content = ''
            WHEEL_UP seek 10
            WHEEL_DOWN seek -10
          '';
        }
      );
    });
  };
}
```

### Extending Configurations

The `.eval` function allows you to extend an already-applied configuration with additional modules, similar to `extendModules` in NixOS.

The `.apply` function works the same way, but automatically grabs `.config` from the result of `.eval` for you,
so you can have `.wrap` and `.apply` more easily available without evaluating.

The `.wrap` function works the same way, but automatically grabs `.config.wrapper` (the final package) from the result of `.eval` for you.

The package (via `passthru`) and the modules under `.config` both offer all 3 functions.

```nix
# Apply initial configuration
# you can use `.eval` `.apply` or `.wrap` for this.
initialConfig = (wrappers.wrapperModules.tmux.eval ({config, ...}{
  # but if you don't plan to provide pkgs yet, you can't use `.wrap` or `.wrapper` yet.
  # config.pkgs = pkgs;
  # but we can still use `config.pkgs` before that inside!
  config.plugins = [ config.pkgs.tmuxPlugins.onedark-theme ];
  config.clock24 = false;
})).config;

# Extend with additional configuration!
extendedConfig = initialConfig.apply {
  modeKeys = "vi";
  statusKeys = "vi";
  vimVisualKeys = true;
};

# Access the wrapper!
# apply is useful because we don't need to give it `pkgs` but it gives us
# top level access to `.wrapper`, `.wrap`, `.apply`, and `.eval`
# without having to grab `.config` ourselves
actualPackage = extendedConfig.wrap { inherit pkgs; };
# since we didn't supply `pkgs` yet, we must pass it `pkgs`
# before we are given the new value of `.wrapper` from `.wrap`

# Extend it again! You can call them on the package too!
apackage = (actualPackage.eval {
  prefix = "C-Space";
}).config.wrapper; # <-- `.wrapper` to access the package direcly

# and again! `.wrap` gives us back the package directly
# all 3 forms take modules as an argument
packageAgain = apackage.wrap ({config, ...}: {
  # list definitions append when declared across modules by default!
  plugins = [ config.pkgs.tmuxPlugins.fzf-tmux-url ];
});
```

### Creating Custom Wrapper Modules

```nix
{ wlib, lib }:

(wlib.evalModule ({ config, wlib, lib, ... }: {
  # You can only grab the final package if you supply pkgs!
  # But if you were making it for someone else, you would want them to do that!

  # config.pkgs = pkgs;

  imports = [ wlib.modules.default ]; # <-- includes wlib.modules.symlinkScript and wlib.modules.makeWrapper
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
})) # .config.wrapper to grab the final package! Only works if pkgs was supplied.
```

`wrapProgram` comes with `wlib.modules.default` already included, and outputs the package directly!

Use this for quickly creating a custom wrapped program within your configuration!

```nix
{ pkgs, wrappers, ... }:

wrappers.lib.wrapProgram ({ config, wlib, lib, ... }: {
  inherit pkgs; # you can only grab the final package if you supply pkgs!
  package = pkgs.curl;
  extraPackages = [ pkgs.jq ];
  env = {
    CURL_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  };
  flags = {
    "--silent" = true;
    "--connect-timeout" = "30";
  };
  flagSeparator = "=";  # Use --flag=value instead of --flag value (default is " ")
  runShell = [
  ''
    echo "Making request..." >&2
  ''
  ];
})
```

