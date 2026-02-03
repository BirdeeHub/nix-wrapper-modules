{ lib, ... }:
{
  books.nix-wrapper-modules.book.output.html.redirect =
    lib.pipe
      [
        "alacritty"
        "atool"
        "btop"
        "claude-code"
        "foot"
        "fuzzel"
        "git"
        "helix"
        "jujutsu"
        "mako"
        "mpv"
        "neovim"
        "niri"
        "notmuch"
        "nushell"
        "opencode"
        "ov"
        "rofi"
        "tealdeer"
        "tmux"
        "vim"
        "waybar"
        "wezterm"
        "xplr"
        "yazi"
      ]
      [
        (map (n: {
          name = "/${n}.html";
          value = "wrapperModules/${n}.html";
        }))
        builtins.listToAttrs
        (
          v:
          v
          // {
            "/home.html" = "/md/intro.html";
            "/getting-started.html" = "/md/getting-started.html";
            "/lib-intro.html" = "/md/lib-intro.html";
            "/wlib.html" = "/lib/wlib.html";
            "/types.html" = "/lib/types.html";
            "/dag.html" = "/lib/dag.html";
            "/core.html" = "/lib/core.html";
            "/helper-modules.html" = "/md/helper-modules.html";
            "/wrapper-modules.html" = "/md/wrapper-modules.html";
            "/default.html" = "/modules/default.html";
            "/makeWrapper.html" = "/modules/makeWrapper.html";
            "/symlinkScript.html" = "/modules/symlinkScript.html";
          }
        )
      ];

}
