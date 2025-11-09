# nix-wrapper-modules

A Nix library to create wrapped executables via the module system.

Are you annoyed by rewriting modules for every platform? nixos, home-manager, nix-darwin, devenv?

Then this library is for you!

## Long-term Goals

Upstream this schema into nixpkgs with an optional module.nix for every package. NixOS modules could then reuse these wrapper modules for consistent configuration across platforms.

## Why use this?

Watch this excellent Video by Vimjoyer for an explanation:

[![Homeless Dotfiles with Nix Wrappers](https://img.youtube.com/vi/Zzvn9uYjQJY/0.jpg)](https://www.youtube.com/watch?v=Zzvn9uYjQJY)

This repository is very much like the one mentioned at the end, but better!

It has modules that are capable of more, and a more consistent design.

## Why fork [lassulus/wrappers](https://github.com/Lassulus/wrappers)?

[I rewrote it with almost complete compatibility, without changing a test, and offered the changes.](https://github.com/Lassulus/wrappers/pull/39)

I know asking someone to accept a rewrite of basically their entire project is a tall order, but the result is a lot better.

The changes were not accepted unfortunately.

Free of compatibility issues, I was able to start out with a consistent design from the start! (and name a few values differently)

For a start, it actually uses `pkgs.makeWrapper`, and you can change that if you want via module option!

Everything you see in that video talking about [lassulus/wrappers](https://github.com/Lassulus/wrappers) will work here.

Except, instead of grabbing the package via `.wrapper` the final package is under `.wrapped` instead.

Yes, I know about this comic: [xkcd 927](https://xkcd.com/927/)

I did try to upstream first. When I did so, many fewer names, and things in general, had been changed.

## Overview

This library provides two main components:

- `lib.evalModule`: Function to create reusable wrapper modules with type-safe configuration options
  - And related, `lib.wrapPackage`: an alias for `(evalModule ...).config.wrapper` with the `wlib.modules.default` module import pre-included for convenience
- `wrapperModules`: Pre-built wrapper modules for common packages (mpv, notmuch, etc.)

## Usage

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

  imports = [ wlib.modules.default ]; # <-- includes wlib.modules.basic and wlib.modules.makeWrapper
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
    "--silent" = {};
    "--connect-timeout" = "30";
  };
  # Or use args for more control:
  # args = [ "--silent" "--connect-timeout" "30" ];
  flagSeparator = "=";  # Use --flag=value instead of --flag value (default is " ")
  wrapper.args."--run" = ''
    echo "Making request..." >&2
  '';
})
```

## Technical Details

### evalModule

Creates a reusable wrapper module with type-safe configuration options via the module system

Takes a module as its argument. To submit a module, this function must be able to evaluate it.

### wrapModule Function

Creates a reusable wrapper module.

Imports `wlib.modules.default` then evaluates the module. It then returns `.config` so that `.wrap` is easily accessible!

Use this when you want to quickly create a wrapper but without providing it a `pkgs` yet.

Equivalent to:

```nix
wrapModule = (wlib.evalModule wlib.modules.default).config.apply;
```

### wrapProgram Function

Imports `wlib.modules.default` then evaluates the module. It then returns the wrapped package.

Use this when you want to quickly create a wrapped package directly. Requires a `pkgs` to be set.

Equivalent to:

```nix
wrapModule = (wlib.evalModule wlib.modules.default).config.wrap;
```


### mkWrapperFlagType and mkWrapperFlag

These functions define typed module options representing wrapper flags.

`mkWrapperFlagType n` creates a Nix type that validates flags expecting `n` arguments per instance.

`mkWrapperFlag n` builds a matching option definition with reasonable defaults (`false` for 0-arity, empty list otherwise).

They help ensure that wrapper argument modules are statically type-checked and compatible with `argOpts2list`.

They are used when defining the module passed to `wrapper.opts`, which controls the options available to `wrapper.args`.

### argOpts2list

Converts a flat attribute set of wrapper argument options into a sequential list of command-line arguments.

Accepts a structure like `{ "--flag" = true; "--set" = [ [ "VAR" "VALUE" ] ]; }` and produces a linearized list suitable for `makeWrapper`.

Supports boolean flags (included or omitted), single-argument flags (lists of strings), and multi-argument flags (lists of fixed-length lists).

This is useful when redefining the `wrapper.func` module option to override the default `pkgs.makeWrapper` based wrapper function.

### generateArgsFromFlags

Generates a list of arguments from a flags attribute set and a configurable flag separator.
Each key is treated as a flag name, and values determine how the flag appears:

* `true` → flag alone
* `false` or `null` → omitted
* list → repeated flags
* string → flag with value
  The separator determines spacing (`"--flag value"`) or joining (`"--flag=value"`).

It is the function that maps the `config.flags` module option to something that would work in the `config.args` option.

### Module System Integration

The wrapper module system integrates with NixOS module evaluation:
- Uses `lib.evalModules` for configuration evaluation
- Supports all standard module features (imports, conditionals, mkIf, etc.)
- Provides `config` for accessing evaluated configuration
- Provides `options` for introspection and documentation

### Extending Configurations

The `eval` function allows you to extend an already-applied configuration with additional modules, similar to `extendModules` in NixOS.

The `.apply` function works the same way, but automatically grabs `.config` from the result of `.eval` for you.

The `.wrap` function works the same way, but automatically grabs `.config.wrapper` (the final package) from the result of `.eval` for you.

```nix
# Apply initial configuration
initialConfig = wrappers.wrapperModules.tmux.eval ({
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
package = actualPackage.wrap {
  vimVisualKeys = true;
  modeKeys = "vi";
  statusKeys = "vi";
};
```

## alternatives

- [wrapper-manager](https://github.com/viperML/wrapper-manager) by viperML. This project focuses more on a single module system, configuring wrappers and exporting them. This was an inspiration when building this library, but I wanted to have a more granular approach with a single module per package and a collection of community made modules.

# Core Options

## package

The base package to wrap\.
This means we inherit all other files from this package
(like man page, /share, …)

*Type:*
package

## apply

Function to extend the current configuration with additional modules\.
Re-evaluates the configuration with the original settings plus the new module\.

*Type:*
function that evaluates to a(n) raw value *(read only)*

*Default:*
` <function> `

## binName

The name of the binary output by ` wrapperFunction `\.
If not specified, the name of the package will be used\.
If set as an empty string, aliases will not be made,
and wrapperFunction may behave unpredictably, depending on its implementation\.

*Type:*
null or string

*Default:*
` null `

## eval

Function to extend the current configuration with additional modules\.
Re-evaluates the configuration with the original settings plus the new module\.
Returns the raw evaluated module\.

*Type:*
function that evaluates to a(n) raw value *(read only)*

## extraDrvAttrs

Extra attributes to add to the resulting derivation\.

*Type:*
attribute set of raw value

*Default:*
` { } `

## meta\.maintainers

Maintainers of this wrapper module\.

*Type:*
list of (submodule)

*Default:*
` [ ] `

## meta\.maintainers\.\*\.email

email

*Type:*
null or string

*Default:*
` null `

## meta\.maintainers\.\*\.github

GitHub username

*Type:*
string

## meta\.maintainers\.\*\.githubId

GitHub id

*Type:*
signed integer

## meta\.maintainers\.\*\.matrix

Matrix ID

*Type:*
null or string

*Default:*
` null `

## meta\.maintainers\.\*\.name

name

*Type:*
string

*Default:*
` "‹name›" `

## meta\.platforms

Supported platforms

*Type:*
list of (one of `lib.platforms.all`)



*Default:*
`lib.platforms.all`



## outputs

Override the list of nix outputs that get symlinked into the final package\.

*Type:*
null or (list of string)

*Default:*
` null `

## passthru

Additional attributes to add to the resulting derivation’s passthru\.
This can be used to add additional metadata or functionality to the wrapped package\.
This will always contain options, config and settings, so these are reserved names and cannot be used here\.

*Type:*
attribute set

*Default:*
` { } `

## pkgs

The nixpkgs pkgs instance to use\.
We want to have this, so wrapper modules can be system agnostic\.

*Type:*
unspecified value

## symlinkScript

This is usually an option you will never have to redefine\.

This option takes a function receiving the following arguments:

```
{
  wlib,
  config,
  wrapper,
  ... # <- anything you can get from pkgs.callPackage
}:
```

The function is to return a string which will be added to the buildCommand of the wrapper\.
It is in charge of taking those options, and linking the files into place as requested\.

*Type:*
function that evaluates to a(n) string

*Default:*
` <function, args: {config, lndir, wlib, wrapper}> `

## wrap

Function to extend the current configuration with additional modules\.
Re-evaluates the configuration with the original settings plus the new module\.
Returns the updated package\.

*Type:*
function that evaluates to a(n) raw value *(read only)*

*Default:*
` <function> `

## wrapper

The wrapped package created by wrapPackage\. This wraps the configured package
with the specified flags, environment variables, runtime dependencies, and other
options in a portable way\.

*Type:*
package *(read only)*

*Default:*
` <derivation hello> `

## wrapperFunction

A function which returns a package\.

Arguments:

` { config, wlib, /* other args from callPackage */ ... } `

That package MUST contain “$out/bin/${binName}”
as the executable to be wrapped\.
(unless you also override ` symlinkScript `)

A helper function is available:

wlib\.argOpts2list args -> \[ “string” ]

It can be used to process a flat attrset of config options
of the type returned by ` wlib.mkWrapperFlag `

It will return a list of arguments suitable
for passing to lib\.escapeShellArgs and then makeWrapper

*Type:*
null or (function that evaluates to a(n) package)

*Default:*
` null `

# wlib.modules.default options (abridged)

## wlib.modules.symlinkScript

## aliases

Aliases for the package to also be added to the PATH

*Type:*
list of string

*Default:*
` [ ] `

## filesToExclude

List of file paths (glob patterns) relative to package root to exclude from the wrapped package\.
This allows filtering out unwanted binaries or files\.
Example: \[ “bin/unwanted-tool” “share/applications/\*\.desktop” ]

*Type:*
list of string

*Default:*
` [ ] `

## filesToPatch

List of file paths (glob patterns) relative to package root to patch for self-references\.
Desktop files are patched by default to update Exec= and Icon= paths\.

*Type:*
list of string

*Default:*

```
[
  "share/applications/*.desktop"
]
```

## wlib.modules.basic

## args

Command-line arguments to pass to the wrapper (like argv in execve)\.
This is a list of strings representing individual arguments\.
If not specified, will be automatically generated from flags\.

*Type:*
list of string

*Default:*
` [ ] `

## env

Environment variables to set in the wrapper\.

*Type:*
attribute set of string

*Default:*
` { } `

## extraPackages

Additional packages to add to the wrapper’s runtime PATH\.
This is useful if the wrapped program needs additional libraries or tools to function correctly\.

*Type:*
list of package

*Default:*
` [ ] `

## flagSeparator

Separator between flag names and values when generating args from flags\.
" " for “–flag value” or “=” for “–flag=value”

*Type:*
string

*Default:*
` " " `

## flags

Flags to pass to the wrapper\.
The key is the flag name, the value is the flag value\.
If the value is true, the flag will be passed without a value\.
If the value is false or null, the flag will not be passed\.
If the value is a list, the flag will be passed multiple times with each value\.

*Type:*
attribute set of unspecified value

*Default:*
` { } `

## runtimeLibraries

Additional libraries to add to the wrapper’s runtime LD_LIBRARY_PATH\.
This is useful if the wrapped program needs additional libraries or tools to function correctly\.

*Type:*
list of package

*Default:*
` [ ] `

## wlib.modules.makeWrapper

## wrapArgs\."--add-flag"

–add-flag ARG

Prepend the single argument ARG to the invocation of the executable,
before any command-line arguments\.

*Type:*
Wrapper flag (list of values)

*Default:*
` [ ] `

## wrapArgs\."--append-flag"

–append-flag ARG

Append the single argument ARG to the invocation of the executable,
after any command-line arguments\.

*Type:*
Wrapper flag (list of values)

*Default:*
` [ ] `

## wrapArgs\."--prefix"

–prefix ENV SEP VAL

Prefix or suffix ENV with VAL, separated by SEP\.

*Type:*
Wrapper flag (list of lists of length 3)

*Default:*
` [ ] `

## wrapArgs\."--prefix-contents"

–prefix-contents ENV SEP FILES

Like --suffix-each, but contents of FILES are read first and used as VALS\.

*Type:*
Wrapper flag (list of lists of length 3)

*Default:*
` [ ] `

## wrapArgs\."--set"

–set VAR VAL

Add VAR with value VAL to the executable’s environment\.

*Type:*
Wrapper flag (list of lists of length 2)

*Default:*
` [ ] `

## wrapArgs\."--set-default"

–set-default VAR VAL

Like --set, but only adds VAR if not already set in the environment\.

*Type:*
Wrapper flag (list of lists of length 2)

*Default:*
` [ ] `

## wrapArgs\."--unset"

–unset VAR

Remove VAR from the environment\.

*Type:*
Wrapper flag (list of values)

*Default:*
` [ ] `

## wrapArgs\."--suffix"

–suffix ENV SEP VAL

Suffix or prefix ENV with VAL, separated by SEP\.

*Type:*
Wrapper flag (list of lists of length 3)

*Default:*
` [ ] `

## wrapArgs\."--run"

–run COMMAND

Run COMMAND before executing the main program\.

*Type:*
Wrapper flag (list of values)

*Default:*
` [ ] `

## wrapArgs\."--argv0"

–argv0 NAME

Set the name of the executed process to NAME\.
If unset or empty, defaults to EXECUTABLE\.

*Type:*
Wrapper Flag (null or string)

*Default:*
` null `

## wrapArgs\.argv0

If “set” is provided, ` wrapArgs."--argv0" ` must be provided as well\.

The other options require no further configuration\.

Possible values are:

` "set" `:

–argv0 NAME

Set the name of the executed process to NAME\.
If unset or empty, defaults to EXECUTABLE\.
If “set” is provided, ` wrapArgs."--argv0" ` must be provided as well\.

` "inherit" `:
` --inherit-argv0 `

The executable inherits argv0 from the wrapper\.
Use instead of --argv0 ‘$0’\.

` "resolve" `:

` --resolve-argv0 `

If argv0 does not include a “/” character, resolve it against PATH\.

*Type:*
one of “set”, “resolve”, “inherit”

*Default:*
` "inherit" `
