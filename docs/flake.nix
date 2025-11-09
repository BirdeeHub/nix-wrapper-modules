{
  description = ''
    Will eventually automatically generate
    wrapper modules documentation

    TODO: make this work in a way that is useful.
  '';
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      wlib = (import ./.. { inherit nixpkgs; }).lib;
      forAllSystems = f: lib.genAttrs lib.platforms.all (system: f system);

      corelist = builtins.attrNames (wlib.evalModule { }).options;
      to_remove = builtins.attrNames (wlib.evalModule { imports = [ wlib.modules.default ]; }).options;
      evaluate_helpers =
        pkgs: mp:
        (wlib.evalModules {
          modules = [
            { _module.check = false; }
            mp
            {
              inherit pkgs;
              package = pkgs.hello;
            }
          ];
        }).options;
      evaluate =
        pkgs: mp:
        (wlib.evalModules {
          modules = [
            { _module.check = false; }
            mp
            { inherit pkgs; }
          ];
        }).options;
      all_docs =
        {
          pkgs,
          nixosOptionsDoc,
          runCommand,
          ...
        }:
        let
          eval = evaluate pkgs;
          coredocs = runCommand "core-wrapper-docs" { } (
            let
              coreopts = nixosOptionsDoc {
                inherit
                  (wlib.evalModule {
                    inherit pkgs;
                    package = pkgs.hello;
                  })
                  options
                  ;
              };
            in
            ''
              cat ${coreopts.optionsCommonMark} > $out
            ''
          );
          eval_helpers = evaluate_helpers pkgs;
        in
        {
          core = coredocs;
        }
        // builtins.mapAttrs (
          name: mod:
          let
            optionsDoc = nixosOptionsDoc {
              options = builtins.removeAttrs (eval mod) to_remove;
            };
          in
          runCommand "${name}-wrapper-docs" { } ''
            cat ${optionsDoc.optionsCommonMark} > $out
          ''
        ) wlib.wrapperModules
        // builtins.mapAttrs (
          name: mod:
          let
            optionsDoc = nixosOptionsDoc {
              options = builtins.removeAttrs (eval_helpers mod) corelist;
            };
          in
          runCommand "${name}-wrapper-docs" { } ''
            cat ${optionsDoc.optionsCommonMark} > $out
          ''
        ) wlib.modules;

    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.callPackage all_docs { }
      );
    };
}
