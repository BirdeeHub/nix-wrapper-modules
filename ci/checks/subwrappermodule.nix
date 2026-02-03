{
  pkgs,
  self,
}:
let
  evaled = self.lib.evalModule [
    (
      {
        pkgs,
        lib,
        wlib,
        config,
        ...
      }:
      {
        imports = [ wlib.modules.default ];
        config.package = pkgs.bash;
        options.subwrapped = lib.mkOption {
          type = wlib.types.subWrapperModuleWith {
            modules = [
              {
                imports = [ wlib.modules.default ];
                config.pkgs = pkgs;
                config.package = pkgs.hello;
                config.drv.postBuild = "touch $out/testfile";
                config.flags."--greeting" = "test-phrase";
              }
            ];
          };
          default = { };
        };
        config.addFlag = [
          [
            "-c"
            "${config.subwrapped.wrapper}/bin/${config.subwrapped.binName}"
          ]
        ];
      }
    )
    { inherit pkgs; }
  ];
in
pkgs.runCommand "subwrappermodule-test" { } ''
  ${pkgs.lib.getExe evaled.config.wrapper} | grep -q "test-phrase"
  [ -e "${evaled.config.subwrapped.wrapper}/testfile" ]
  touch "$out"
''
