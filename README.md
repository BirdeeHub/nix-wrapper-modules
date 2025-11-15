# [nix-wrapper-modules](https://birdeehub.github.io/nix-wrapper-modules/)

A Nix library to create wrapped executables via the module system.

Are you annoyed by rewriting modules for every platform? nixos, home-manager, nix-darwin, devenv?

Then this library is for you!

## Why use this?

Watch this excellent Video by Vimjoyer for an explanation:

This repository is very much like the one mentioned at the end.

However it has modules that are capable of much more, with a more consistent, flexible, and capable design.

[![Homeless Dotfiles with Nix Wrappers](https://img.youtube.com/vi/Zzvn9uYjQJY/0.jpg)](https://www.youtube.com/watch?v=Zzvn9uYjQJY)

## Why rewrite [lassulus/wrappers](https://github.com/Lassulus/wrappers)?

Yes, I know about this comic: [xkcd 927](https://xkcd.com/927/)

This one was designed around giving you absolute control over the _derivation_ your wrapper is creating from **within** the module system, and defining modules for making the experience making wrapper modules great.

The other one was designed around a module system which can supply some but not all the arguments of some separate builder function designed to be called separately, which itself does not give full control over the derivation.

In short, this repo is more what it claims to be. A generalized and effective module system for creating wrapper derivations, and offers far more abilities to that effect to the module system itself.

In fact, the only attribute of the final derivation you cannot directly override is `buildCommand`.

And even for `buildCommand` you can still change its contents entirely if desired, although I think you will find `wlib.modules.default` provides very sensible defaults and that you will not need to do this yourself often.

This allows you to easily modify your module with extra files and scripts or whatever else you may need!

Maybe you want your `tmux` wrapper to also output a launcher script into a new session? You can do that in, for example, a `postBuild` hook, and you can supply it [from within the module system](https://birdeehub.github.io/nix-wrapper-modules/core.html#extradrvattrs)! And you can even use `"${placeholder "out"}"` in it!

In addition, the way it is implemented allows for the creation of helper modules that wrap derivations in all sorts of ways, which you could import instead of `wlib.modules.default` if you wanted. We could have similar modules for wrapping projects via bubblewrap or into docker containers with the same ease with which this library orchestrates regular wrapper scripts.

#### Exposition (you can skip the rest of this section):

I heard that I could wrap programs with the module system, and then reapply more changes after, like override. I was excited.

But the project was tiny, there were not many modules yet.

"No problem!" I thought to myself, and began to write a module...

Turns out there were actually several problems.

The first, was that a significant amount of the options were not even accessible to the module system,
and were instead only accessible to a secondary builder function.

There were many more things that were going to make it hard to use. So, I set about the task of fixing it.

However, when I began, the core was only about 700 lines of code.

Asking someone to accept someone else's rewrite of their _entire_ project is a tall order, even if it doesn't break anything existing.

I wanted this thing to be the best it could be, but it was looking like the full extent of my changes would be a difficult sell for the maintainer to handle reading and maintaining.

It looked like only small pieces would be accepted, and at some point I gained a very clear vision of what I wanted.

It turns out what I wanted was significantly different from what that project was.

I rewrote it several times, and finally found what I feel to be the right set of capabilities and options.

Most everything you see in that video will work here too, but this is not intended to be a 1 for 1 compatible library.

Free of compatibility issues, I was able to start out with a consistent design from the start!

This repo is as close to 100% module-based as it could be.

All in all, I added over 3.5k lines of code and removed over 1k from the project, which was quite small to begin with. So, it is definitely now its own thing!

## Long-term Goals

It is the ideal of this project to become a hub for everyone to contribute,
so that we can all enjoy our portable configurations with as little individual strife as possible.

In service of that ideal, the immediate goal would be to transfer this repo to nix-community the moment that becomes an option.

Eventually I hope to have wrapper modules in nixpkgs, but again, nix-community would be the first step.

## Short-term Goals

Help us add more modules! Contributors are what makes projects like these amazing!

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

  outputs = { self, nixpkgs, wrappers }: {
    packages.x86_64-linux.default =
      wrappers.wrapperModules.mpv.wrap {
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

### Creating Custom Wrapper Modules

```nix
{ wlib, lib }:

(wlib.evalModule ({ config, wlib, lib, ... }: {
  # You can only grab the final package if you supply pkgs!
  # But if you were making it for someone else, you would want them to do that!

  # inherit pkgs;

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

## Extending Configurations

The `.eval` function allows you to extend an already-applied configuration with additional modules, similar to `extendModules` in NixOS.

The `.apply` function works the same way, but automatically grabs `.config` from the result of `.eval` for you,
so you can have `.wrap` and `.apply` more easily available without evaluating.

The `.wrap` function works the same way, but automatically grabs `.config.wrapper` (the final package) from the result of `.eval` for you.

The package (via `passthru`) and the modules under `.config` both offer all 3 functions.

```nix
# Apply initial configuration
initialConfig = (wrappers.wrapperModules.tmux.eval {
  pkgs = pkgs;
  plugins = [ pkgs.tmuxPlugins.onedark-theme ];
}).config;

# Extend with additional configuration
extendedConfig = initialConfig.eval {
  clock24 = false;
};

# Access the wrapper
actualPackage = extendedConfig.config.wrapper;

# Extend it again!
apackage = (actualPackage.eval {
  vimVisualKeys = true;
  modeKeys = "vi";
  statusKeys = "vi";
}).config.wrapper;

# and again!
packageAgain = apackage.wrap {
  prefix = "C-Space";
};
```

## alternatives

- [wrapper-manager](https://github.com/viperML/wrapper-manager) by viperML. This project focuses more on a single module system, configuring wrappers and exporting them. This is something with a more granular approach with a single module per package and a collection of community made modules.

- [lassulus/wrappers](https://github.com/Lassulus/wrappers) the inspiration for the `.apply` interface for this library.
