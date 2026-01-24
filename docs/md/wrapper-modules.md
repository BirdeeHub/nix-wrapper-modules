# wlib.wrapperModules

`wrapper modules` are modules which set `config.package` and define convenience options for wrapping that package with a configuration.

They are specific to that program, and make configuring programs in an ad-hoc way stress-free!

They include shortlist options for common configuration settings, and/or for providing a config file to use.

`wlib.wrapperModules` contains paths to these wrapper modules.

The flake also exports wrapper modules that have been partially evaluated for convenience.

This allows you to do something like `inputs.nix-wrapper-modules.wrappers.tmux.wrap { inherit pkgs; prefix = "C-Space"; }`, to build a package with a particular configuration quickly!

You can then export that package, and somebody else could call `.wrap` on it as well to change it again!
