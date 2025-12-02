# Adding modules!

Please add some modules to the `modules/` directory to help everyone out!

That way, your module can be available for others to enjoy as well!

There are 2 kinds of modules. One kind which defines the `package` option, and one kind which does not.

If you are making a wrapper module, i.e. one which defines the `package` argument, and thus wraps a package,
then you must define a `wrapperModules/<first_letter>/<your_package_name>/wrapper.nix` file.

It must contain a single, unevaluated module. In other words, it must be importable without calling it first to return the module.

If you are making a helper module, i.e. one which does not define the `package` argument, then you must define a `modules/<your_module_name>/module.nix` file.

All options must have descriptions, so that documentation can be generated and people can know how to use it!

All modules must have a `meta.maintainers = [];` entry.

## Guidelines:

When making options for your module, if you are able, please provide both nix-generated, and `wlib.types.file` or `lib.types.lines` options

If you are not able to provide both, default to `wlib.types.file` unless it is `JSON` or something else which does not append nicely, but do try to provide both options.

When you provide a `wlib.types.file` option, you should name it the actual filename, especially if there are multiple, but `configFile` is also OK.

Example:

```nix
{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  gitIniFmt = pkgs.formats.gitIni { };
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      inherit (gitIniFmt) type;
      default = { };
      description = ''
        Git configuration settings.
        See {manpage}`git-config(1)` for available options.
      '';
    };

    configFile = lib.mkOption {
      type = wlib.types.file pkgs;
      default.path = gitIniFmt.generate "gitconfig" config.settings;
      description = "Generated git configuration file.";
    };
  };

  config.env.GIT_CONFIG_GLOBAL = config.configFile.path;
  config.package = lib.mkDefault pkgs.git;
  config.meta.maintainers = [ wlib.maintainers.birdee ];
}
```

# Formatting

`nix fmt`

# Tests

`nix flake check -Lv .`

# Writing tests

You may also include a `check.nix` file in your module's directory.

It will be provided with the flake `self` value and `pkgs`

Example:

```nix
{
  pkgs,
  self,
}:
let
  gitWrapped = self.wrapperModules.git.wrap {
    inherit pkgs;
    settings = {
      user = {
        name = "Test User";
        email = "test@example.com";
      };
    };
  };

in
pkgs.runCommand "git-test" { } ''
  "${gitWrapped}/bin/git" config user.name | grep -q "Test User"
  "${gitWrapped}/bin/git" config user.email | grep -q "test@example.com"
  touch $out
''
```

# Questions?

The github discussions board is open and a great place to find help!
