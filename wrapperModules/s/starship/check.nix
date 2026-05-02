{
  pkgs,
  self,
  tlib,
  ...
}:

let
  inherit (tlib)
    fileContains
    isFile
    test
    ;
  wm = self.wrappers.starship;
in
test { wrapper = "starship"; } {

  "wrapper should output correct version" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
      };
    in
    ''
      "${wrapper}/bin/starship" --version |
      grep -q "${wrapper.version}"
    '';

  "starship.toml is properly configured" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
      };
      configFile = "${wrapper}/starship.toml";
    in
    [
      (isFile configFile)
      (fileContains "${wrapper}/bin/starship" "STARSHIP_CONFIG.*${configFile}")
    ];

  "default settings order is respected" =
    let
      # See here for preset values: https://github.com/starship/starship/blob/main/docs/public/presets/toml/tokyo-night.toml#L22
      wrapper = wm.wrap {
        inherit pkgs;
        preset = "tokyo-night";
        settings.directory.style = "foo";
      };
      configFile = "${wrapper}/starship.toml";
    in
    [
      (isFile configFile)
      (fileContains configFile ''truncation_symbol = "…/"'')
      (fileContains configFile ''style = "foo"'')
    ];

  "custom settings order is respected" =
    let
      # See here for preset values: https://github.com/starship/starship/blob/main/docs/public/presets/toml/tokyo-night.toml#L22
      wrapper = wm.wrap {
        inherit pkgs;
        order = [
          "settings"
          "preset"
        ];
        preset = "tokyo-night";
        settings.directory.style = "foo";
      };
      configFile = "${wrapper}/starship.toml";
    in
    [
      (isFile configFile)
      (fileContains configFile ''truncation_symbol = "…/"'')
      (fileContains configFile ''style = "fg:.* bg:.*"'')
    ];

  "preset list is merged in order" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
        preset = [
          "jetpack"
          "pastel-powerline"
        ];
      };
      configFile = "${wrapper}/starship.toml";
    in
    [
      (isFile configFile)
      # value exclusive to jetpack
      (fileContains configFile ''repo_root_style = "bold blue"'')
      # jetpack sets it to 2, pastel-powerline overrides it to 3
      (fileContains configFile "truncation_length = 3")
    ];
}
