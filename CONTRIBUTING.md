# Adding Modules!

There are 2 kinds of modules in this repository. One kind which defines the `package` option, and one kind which does not.

### Wrapper Modules

If you are making a wrapper module, i.e. one which **does** define the `config.package` option, and thus wraps a package:

You must define a `wrapperModules/<first_letter>/<your_package_name>/module.nix` file.
The file must contain a single, unevaluated module. In other words, it must be importable without calling it like a function first.

All wrapper modules must have a `config.meta.maintainers = [ <your wlib.maintainers listing> ];` entry.

Wrapper modules set `config.package`. They are "for" a program. They import helper module(s) (usually `wlib.modules.default`), and then use those options to provide a module customized for that program.

### Helper Modules

If you are making a helper module, i.e. one which does **not** define the `config.package` option:

You must define a `modules/<your_module_name>/module.nix` file instead.

Just like for wrapper modules, the file must contain a single, unevaluated module. In other words, it must be importable without calling it like a function first.

All helper modules must have a `config.meta.maintainers = lib.mkDefault [ <your wlib.maintainers listing> ];` entry.

Helper modules are meant to either remove boilerplate and improve consistency for common actions, or be a base for making particular kinds of wrapper modules.

For example:

- If someone wanted to provide a common set of options people should implement for themes, they could provide a `wlib.modules.themes` module.
That module could take care of the boilerplate for defining theme options for the module writer, leaving importers of the `wlib.modules.themes` module free to just handle the values in `config`, while also giving people a generally consistent interface.
(If someone were to do that, adding a `wlib.types.palette` type would also be a great first step)

- If someone wanted to provide a `wlib.wrapperModules.nginx-docker`, to make a wrapper module for running `nginx` in a `docker` container.
They might first add a `wlib.modules.docker` that other people could use too, to give the same sort of support we currently offer for `makeWrapper`.
Then they could import the module and implement `nginx-docker` using their new helper module.

### For Both:

All options must have description fields, so that documentation can be generated and people can know how to use it!

You may optionally set the `meta.description` option to provide a short description to include alongside your generated option documentation.

`meta.description` accepts either a set of `{ pre ? "", post ? "" }`, or just a plain string, which will end up as `{ pre = "the string"; post = ""; }`.

`pre` will be added after the title and before the content. `post` will be added after the content.

Do not name an option `options` or `config` if there is a chance the module system will try to use them as if they were top level module declarations.

## Guidelines and Examples:

When you provide an option to `enable` or `disable` something, you should call it `enable` regardless of its default value.

This prevents people from needing to look it up to use it, and prevents contributors from having to think too hard about which to call it.

- Placeholders and `config.constructFiles.<name>`

When you generate a file, it is generally better to do so as a string, and create it using the `constructFiles` option.

This is because, this will make placeholders such as `${placeholder "out"}` work consistently across all your options,
allowing them to all point to the final wrapper derivation rather than several intermediate ones.

What this allows you to do, is manually build files via another option like `constructFiles`, and then refer to that created file within your settings!

Making placeholders work in your module makes your modules generally more easily extensible, and is preferred when it is possible to generate a usable string.

It works by using `drv.passAsFile` and making a derivation attribute with the file contents, which is copied into place.

- `wlib.types.file`

When you provide a `wlib.types.file` option, you should name it the actual filename or something suggestive of it, especially if there are multiple, but `configFile` is also OK, especially if it is unambiguous.

Keep in mind that even if you do not choose to use `wlib.types.file`, the user can usually still override the option that you set to provide the generated path if needed.

So using something like `wlib.types.file` is only truly important when the file you are making an option for is passed to a list-style option, but may still be nice more generally.

Example:

```nix
{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      inherit (pkgs.formats.gitIni { }) type;
      default = { };
      description = ''
        Git configuration settings.
        See {manpage}`git-config(1)` for available options.
      '';
    };
    configFile = lib.mkOption {
      type = wlib.types.file {
        # we can refer to the placeholder of our constructed file!
        path = lib.mkOptionDefault config.constructFiles.gitconfig.path;
      };
      default = { };
      description = "Generated git configuration file.";
    };
  };
  config = {
    env.GIT_CONFIG_GLOBAL = config.configFile.path;
    package = lib.mkDefault pkgs.git;
    constructFiles.gitconfig = { # <- constructs the path directly in the final wrapper derivation, such that placeholders work correctly.
      relPath = "${config.binName}config";
      # A string, which is to become the file contents
      content =
        # nixpkgs has a lot of handy generation functions!
        lib.generators.toGitINI config.settings
        # and gitconfig format allows you to arbitrarily append contents!
        + "\n" + config.configFile.content;
    };
    meta.maintainers = [ wlib.maintainers.birdee ]; # <- don't forget to make yourself the maintainer of your module!
  };
}
```

# Formatting

`nix fmt`

# Tests

`nix flake check -Lv ./ci`

# Run Site Generator Locally

`nix run ./ci`

or

`nix run ./ci#docs`

# Writing tests

You may also include a `check.nix` file in your module's directory.

It will be called via `pkgs.callPackage`, provided with the flake `self` value.
(i.e. `pkgs.callPackage your_check.nix { inherit self; }`)

It should build a derivation which tests the wrapper derivation as best you can.

If a command fails, it fails the test. If it builds the derivation successfully, it passes the test.

If the program gives options for running the program to check the generated configuration is correct, you should do that.

Sometimes it is not easily possible to run the program within a derivation, in those cases, searching the wrapper derivation and other generated files and their contents is also acceptable.

Example:

```nix
{ pkgs, self, tlib, ... }:
let
  gitWrapped = self.wrappers.git.wrap {
    inherit pkgs;
    settings = {
      user = {
        name = "Test User";
        email = "test@example.com";
      };
    };
  };
  inherit (tlib) it fileContains test enableBySystem ;
in
# git uses meta.platforms = lib.platforms.all, so this will be enabled on all platforms
enableBySystem self.wrappers.git (
  # define a test derivation using the testing library!
  test "git-test" [
    # define tests for your test derivation using `it` and the other helpers
    (it "has test user" ''"${gitWrapped}/bin/git" config user.name | grep -q "Test User"'')
    (it "has test email" ''"${gitWrapped}/bin/git" config user.email | grep -q "test@example.com"'')
    (fileContains (gitWrapped.configuration.constructFiles.gitconfig.outPath) "test@example\.com")
  ]
)
```

If your module declares a list of valid platforms via its `meta.platforms` option, you should disable your test on the relevant platforms like so:

```nix
if builtins.elem pkgs.stdenv.hostPlatform.system self.wrappers.waybar.meta.platforms then
  pkgs.runCommand "waybar-test" { } ''
    "${waybarWrapped}/bin/waybar" --version | grep -q "${waybarWrapped.version}"
    touch $out
  ''
else
  null
```

If you are writing a helper module, or something very complex, you may wish to have multiple derivations. Simply return a set of them instead.

# Commit Messages

Changes to wrapper modules should be titled `<type>(wrapperModules.<name>): some description`.
For new additions, the description should be `init`, with any further explanation on subsequent lines

Changes to helper modules should be titled `<type>(modules.<name>): some description`.
For new additions, the description should be `init`, with any further explanation on subsequent lines

For `lib` additions and changes, the description should be `<type>(lib.<set>.<name>): some description` or `<type>(lib.<name>): some description`.

For template additions and changes, the description should be `<type>(templates.<name>): some description`.

Changes to the core options set defined in `lib/core.nix` should be titled `<type>(core.<option>): some description`.

`<type>` refers to a one word tag [like `feat`, `fix`, `docs`, or `test`](https://gist.github.com/Zekfad/f51cb06ac76e2457f11c80ed705c95a3#commit-types) as specified by [Conventional Commits](https://www.conventionalcommits.org)

For everything else, do the best you can to follow conventional commit message style.

Why specify this? I was having trouble figuring out what to title my commits. So now I know.

# Questions?

The [github discussions board](https://github.com/BirdeeHub/nix-wrapper-modules/discussions) is open and a great place to find help!
