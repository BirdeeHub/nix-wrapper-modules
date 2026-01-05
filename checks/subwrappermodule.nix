{
  pkgs,
  self,
}:
let
  eval'd = self.lib.wrapPackage [
    { inherit pkgs; }
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
  ];
in
pkgs.runCommand "subwrappermodule-test" { } ''
  ${pkgs.lib.getExe eval'd} | grep -q "test-phrase"
  touch "$out"
''
