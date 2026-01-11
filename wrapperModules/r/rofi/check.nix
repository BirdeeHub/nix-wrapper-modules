{
  pkgs,
  self,
}:

let
  rofiWrapped =
    (self.wrappedModules.rofi.apply {
      inherit pkgs;

      theme.foo = "bar";
    }).wrapper;

in
if builtins.elem pkgs.stdenv.hostPlatform.system self.wrappedModules.rofi.meta.platforms then
  pkgs.runCommand "rofi-test" { } ''
    # Rofi attempts to create some directories when first ran which doesn't work in a nix build
    export XDG_CACHE_HOME=/tmp
    export XDG_RUNTIME_DIR=/tmp

    res=$("${rofiWrapped}/bin/rofi" --help)

    if ! echo "$res" | grep -q '/nix/store/.*-config.rasi'; then
      echo "Rofi doesn't see config"
      touch $out
      exit 1
    fi

    if ! echo "$res" | grep -q '/nix/store/.*-rofi-theme'; then
      echo "Rofi doesn't see theme"
      touch $out
      exit 1
    fi

    touch $out
  ''
else
  null
