# nix-wrapper-modules

A Nix library to create wrapped executables via the module system.

Are you annoyed by rewriting modules for every platform? nixos, home-manager, nix-darwin, devenv?

Then this library is for you!

## Long-term Goals

It is the goal of this project to become a hub for everyone to contribute,
so that we can all enjoy our portable configurations with as little individual strife as possible.

In service of that goal, the moment we have some contributors to speak of,
the immediate goal would be first to transfer this repo to nix-community.

That way, everyone can feel some shared ownership of the project.

The goal would be eventually to have wrapper modules in nixpkgs, but again, nix-community would be the first step.

## Why use this?

Watch this excellent Video by Vimjoyer for an explanation:

This repository is very much like the one mentioned at the end, but better!

It has modules that are capable of much more, with a more consistent design.

[![Homeless Dotfiles with Nix Wrappers](https://img.youtube.com/vi/Zzvn9uYjQJY/0.jpg)](https://www.youtube.com/watch?v=Zzvn9uYjQJY)

## Why fork [lassulus/wrappers](https://github.com/Lassulus/wrappers)?

Yes, I know about this comic: [xkcd 927](https://xkcd.com/927/)

I heard that I could wrap programs with the module system, and then reapply more changes after, like override. I was excited.

But the project was tiny, the core was about 600 lines, and there were not many modules yet.

"No problem!" I thought to myself, and began to write a module...

Turns out, most of the options were not even accessible to the module system,
and were instead only accessible to a secondary builder function.

Whats worse, the whole evaluated result was not accessible, so docgen wasn't going to be a thing without a lot of work.

So, I then rewrote the whole project with almost complete compatibility, without changing a test, and offered the changes.

However, asking someone to accept someone else's rewrite of actually their entire project is a tall order, even if it doesn't break anything existing.

It looked like only small pieces would be accepted, and it would be a shadow of itself.

I wanted this thing to be the best it could be, but it was looking like the full extent of my changes would be a difficult sell for the maintainer to handle reading and maintaining.

Most everything you see in that video will work here too, but this is not intended to be a 1 for 1 compatible library.

Free of compatibility issues, I was able to start out with a consistent design from the start!

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

## alternatives

- [wrapper-manager](https://github.com/viperML/wrapper-manager) by viperML. This project focuses more on a single module system, configuring wrappers and exporting them. This was an inspiration when building this library, but I wanted to have a more granular approach with a single module per package and a collection of community made modules.

- [lassulus/wrappers](https://github.com/Lassulus/wrappers) the inspiration for the `.apply` interface for this library.

## Technical Details

### evalModule

Creates a reusable wrapper module with type-safe configuration options via the module system

Takes a module as its argument. To submit a module to this repo, this function must be able to evaluate it.

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

## Types:

Custom types:

`wlib.types.file`: File type with content and path options

Arguments:
- `pkgs`: nixpkgs instance

Fields:
- `content`: File contents as string
- `path`: Derived path using pkgs.writeText

`wlib.types.dagOf`: 

Arguments:
- `elemType`: `type`

Accepts an attrset of elements of type elemType
OR sets of the type `{ data, name ? null, before ? [], after ? [] }`

Can be used in conjunction with `wlib.dag.topoSort`

`wlib.types.dalOf`: 

Arguments:
- `elemType`: `type`

Accepts a LIST of elements of type elemType
OR sets of the type `{ data, name ? null, before ? [], after ? [] }`

Can be used in conjunction with `wlib.dag.topoSort`

`wlib.types.fixedList`:

Arguments:
- `length`: `int`,
- `elemType`: `type`

It's a list, but it rejects lists of the wrong length.

Still has regular list merge across multiple definitions, best used inside another list

# Core Options (except meta info)

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
` <function, args: {config, wlib, outputs, binName, wrapper}> `

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

` { config, wlib, outputs, binName, /* other args from callPackage */ ... } `

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

# wlib.modules.default options

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

## wlib.modules.makeWrapper

> [!NOTE]
>
> a `DAG LIST` or `DAL` is a `list` which accepts either the values directly,
> or sets containing `{ data, name ? null, before ? [], after ? [] }`
>
> Put the name of another entry in before or after, to be inserted before or after it
>
> It is very much like a `DAG`, which is also a type offered by this library,
> like the one offered by home manager, however some of its fields are optional.
>
> If a value does not have a name, it can't be targeted by other entries.

## add-flag

–add-flag ARG

Prepend the single argument ARG to the invocation of the executable,
before any command-line arguments\.

*Type:*
DAG LIST of string or package

*Default:*
` [ ] `

## append-flag

–append-flag ARG

Append the single argument ARG to the invocation of the executable,
after any command-line arguments\.

*Type:*
DAG LIST of string or package

*Default:*
` [ ] `

## argv0

–argv0 NAME

Set the name of the executed process to NAME\.
If unset or empty, defaults to EXECUTABLE\.

*Type:*
null or string

*Default:*
` null `

## argv0type

` argv0 ` overrides this option if not null or unset

` "inherit" `:
` --inherit-argv0 `

The executable inherits argv0 from the wrapper\.
Use instead of --argv0 ‘$0’\.

` "resolve" `:

` --resolve-argv0 `

If argv0 does not include a “/” character, resolve it against PATH\.

*Type:*
one of “resolve”, “inherit”

*Default:*
` "inherit" `

## chdir

–chdir DIR

Change working directory before running the executable\.
Use instead of --run “cd DIR”\.

*Type:*
DAG LIST of string or package

*Default:*
` [ ] `

## env

Environment variables to set in the wrapper\.

*Type:*
DAG of string or package

*Default:*
` { } `

## env-default

Environment variables to set in the wrapper\.

Like env, but only adds the variable if not already set in the environment\.

*Type:*
DAG of string or package

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
DAG of null or boolean or string or package or list of (string or package)

*Default:*
` { } `

## makeWrapper

makeWrapper implementation to use (default pkgs\.makeWrapper)

*Type:*
null or package

*Default:*
` null `

## prefix

–prefix ENV SEP VAL

Prefix or suffix ENV with VAL, separated by SEP\.

*Type:*
DAG LIST of List of length 3

*Default:*
` [ ] `

## prefix-contents

–prefix-contents ENV SEP FILES

Like --suffix-each, but contents of FILES are read first and used as VALS\.

*Type:*
DAG LIST of List of length 3

*Default:*
` [ ] `

## rawWrapperArgs

list of wrapper arguments, escaped with lib\.escapeShellArgs

*Type:*
DAG LIST of list of (string or package)

*Default:*
` [ ] `

## run

–run COMMAND

Run COMMAND before executing the main program\.

*Type:*
DAG LIST of string or package

*Default:*
` [ ] `

## runtimeLibraries

Additional libraries to add to the wrapper’s runtime LD_LIBRARY_PATH\.
This is useful if the wrapped program needs additional libraries or tools to function correctly\.

*Type:*
list of package

*Default:*
` [ ] `

## suffix

–suffix ENV SEP VAL

Suffix or prefix ENV with VAL, separated by SEP\.

*Type:*
DAG LIST of List of length 3

*Default:*
` [ ] `

## suffix-contents

–suffix-contents ENV SEP FILES

Like --prefix-each, but contents of FILES are read first and used as VALS\.

*Type:*
DAG LIST of List of length 3

*Default:*
` [ ] `

## unsafeWrapperArgs

list of wrapper arguments, concatenated with spaces, which are always after rawWrapperArgs

*Type:*
DAG LIST of list of (package or string)

*Default:*
` [ ] `

## unset

–unset VAR

Remove VAR from the environment\.

*Type:*
DAG LIST of string or package

*Default:*
` [ ] `

## useBinaryWrapper

changes the makeWrapper implementation from pkgs\.makeWrapper to pkgs\.makeBinaryWrapper

also disables --run, --prefix-contents, and --suffix-contents,
as they are not supported by pkgs\.makeBinaryWrapper

*Type:*
boolean

*Default:*
` false `
