# [nix-wrapper-modules](https://birdeehub.github.io/nix-wrapper-modules/)

A Nix library to create wrapped executables via the module system.

Are you annoyed by rewriting modules for every platform? nixos, home-manager, nix-darwin, devenv?

Then this library is for you!

## What is this for?

When configuring programs using nix, one of the highlights for most is the module system.

The main "configuration.nix" file of NixOS and "home.nix" for home-manager contain all sorts of shortlist options. For a while, it's great!

But then you need to use your configuration somewhere else. Pulling in your home-manager configuration on some other machine is usually overkill, takes too long, and is often a destructive action, as it will link files into the home directory and move the old files.

You don't want to pull in your entire home environment, you just needed to do some pair programming and wanted to use some of your tools, not destroy your co-workers dotfiles. Can't you make like, a shell, or a derivation or something and use that directly?

In addition, you often have some modules that might be duplicated because NixOS or home-manager options can be different. And you can't use any of that in a shell. It is starting to wear on you a bit.

So you hear about this thing called "wrapping" a package. This means, writing a script that launches the program with specific arguments or variables set, and installing that instead.

Then, you could have your configured tools as derivations you can just install via any means nix has of installing something.

Nix makes this concept very powerful, as you can create files and pull in other programs without installing them globally.

Your first attempt, you might write something that looks like this:

```nix
pkgs.writeShellScriptBin "alacritty" (let
  tomlcfg = pkgs.writeText "alacritty.toml" ''
    [terminal.shell]
    program = "${pkgs.zsh}/bin/zsh"
    args = [ "-l" ]
  '';
in ''
  exec ${pkgs.alacritty}/bin/alacritty --config-file ${tomlcfg} "$@"
'')
```

This is good! Kinda. If you install it, it will install the wrapper script instead of the program, and the script tells it where the config is! And it doesn't need home-manager or NixOS!

But on closer inspection, its missing a lot. What if this were a package with a few more things you could launch? Where is the desktop file? Man pages?

So, your next attempt might look more like this:

```nix
pkgs.symlinkJoin (let
  tomlcfg = pkgs.writeText "alacritty.toml" ''
    [terminal.shell]
    program = "${pkgs.zsh}/bin/zsh"
    args = [ "-l" ]
  '';
in {
  name = "alacritty";
  paths = [ pkgs.alacritty ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/alacritty --add-flag --config-file --add-flag ${tomlcfg}
  '';
})
```

Ok. So maybe that isn't your second try. But you get there eventually.

This is a little closer to how stuff like nixvim works, if you have heard of it. It just has a lot more on top of that.

But even this has problems. If you want to have any sensible ability to override this later, for example, you will need to add that ability yourself.

You also now have a desktop file that might point to the wrong place. And if all you wanted to do was set a setting or 2 and move on, all of that will still be necessary to deal with.

You eventually are reduced to going to the source code of a bunch of modules in nixpkgs or home-manager and copy pasting what they did into your wrapper.

What if I told you, you can solve all those problems, and gain a really nice, consistent, and flexible way to do this, and make sure it can always be overridden later?

And it uses something you already know! The module system!

```nix
inputs.nix-wrapper-modules.wrapperModules.alacritty.wrap {
  inherit pkgs;
  settings.terminal.shell.program = "${pkgs.zsh}/bin/zsh";
  settings.terminal.shell.args = [ "-l" ];
}
```

The above snippet does everything the prior 2 examples did, and then some!

That's a full module (defined like [this](https://github.com/BirdeeHub/nix-wrapper-modules/blob/main/wrapperModules/a/alacritty/module.nix) and with docs [here](https://birdeehub.github.io/nix-wrapper-modules/alacritty.html)) but just for that package, and the result is a fully portable derivation, just like the wrapper scripts above!

And you can call `.wrap` on it as many times as you want! You can define your own options to easily toggle things for your different use cases and re-export it in a flake and change them on import, etc.

There are included modules for several programs already, but there are rich and easy to use options defined for creating your own modules as well!

If you make one, you are encouraged to submit it here for others to use if you wish!

For more information on how to do this, check out the [getting started](https://birdeehub.github.io/nix-wrapper-modules/getting-started.html) documentation, and the descriptions of the module options you have at your disposal!

## Long-term Goals

It is the ideal of this project to become a hub for everyone to contribute,
so that we can all enjoy our portable configurations with as little individual strife as possible.

In service of that ideal, the immediate goal would be to transfer this repo to nix-community the moment that becomes an option.

Eventually I hope to have wrapper modules in nixpkgs, but again, nix-community would be the first step.

### Short-term Goals

Help us add more modules! Contributors are what makes projects like these amazing!

---

### Why rewrite [lassulus/wrappers](https://github.com/Lassulus/wrappers)?

For those paying attention to the recent nix news, they may have heard of a similar project which was released recently.

This excellent video by Vimjoyer was made, which mentions the project this one is inspired by at the end.

The video got that repository a good amount of attention. And the idea of the `.apply` interface was quite good.

But that project also leaves a lot to be desired.

This one has modules that are capable of much more, with a more flexible, and capable design.

Most of the video is still applicable though! So, if you still find yourself confused as to what problem this repository is solving, please watch it!

[![Homeless Dotfiles with Nix Wrappers](https://img.youtube.com/vi/Zzvn9uYjQJY/0.jpg)](https://www.youtube.com/watch?v=Zzvn9uYjQJY)

Yes, I know about this comic: [xkcd 927](https://xkcd.com/927/)

This repository was designed around giving you absolute control over the _derivation_ your wrapper is creating from **within** the module system, and defining modules for making the experience making wrapper modules great.

The other repository was designed around a module system which can supply some but not all the arguments of some separate builder function designed to be called separately, which itself does not give full control over the derivation.

In short, this repo is more what it claims to be. A generalized and effective module system for creating wrapper derivations, and offers far more abilities to that effect to the module system itself.

In fact, the only attribute of the final derivation you cannot directly override is `buildCommand`.

And even for `buildCommand` you can still change its contents entirely if desired, although I think you will find `wlib.modules.default` provides very sensible defaults and that you will not need to do this yourself often.

This allows you to easily modify your module with extra files and scripts or whatever else you may need!

Maybe you want your `tmux` wrapper to also output a launcher script that rejoins a session, or creates one? You can do that using this project with, for example, a `postBuild` hook just like in a derivation, and you can even use `"${placeholder "out"}"` in it!

But you can supply it [from within the module system](https://birdeehub.github.io/nix-wrapper-modules/core.html#drv)! You could define an option to customize its behavior later!

In addition, the way it is implemented allows for the creation of helper modules that wrap derivations in all sorts of ways, which you could import instead of `wlib.modules.default` if you wanted. We could have similar modules for wrapping projects via bubblewrap or into docker containers with the same ease with which this library orchestrates regular wrapper scripts.

In short, while both projects have surface level similarities, you would be leaving a lot on the table to not use this one instead!

I did originally try to contribute my changes, but for numerous reasons, this did not work out.

The original changes suggested were not as sweeping as the changes made when rewriting it for this repository.

That being said, contributing to a project by entirely rewriting it and then trying to get that accepted is not a good way to get changes to happen. But nothing short of that would have made sense, because the architecture was the problem, and the core of the project, which I was altering, was under 700 lines at the time.
