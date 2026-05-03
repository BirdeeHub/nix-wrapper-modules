{
  self,
  tlib,
  pkgs,
  ...
}:

let
  inherit (tlib) test areEqual;

  evalWith =
    excluded:
    self.lib.evalModule [
      { inherit pkgs; }
      (
        { pkgs, wlib, ... }:
        {
          imports = [ (import wlib.modules.makeWrapper // { excluded_options = excluded; }) ];
          config.package = pkgs.hello;
          config.wrapperVariants.test.enable = true;
        }
      )
    ];

  # Access a variant's submodule options via the option's valueMeta
  varOpts = r: r.options.wrapperVariants.valueMeta.attrs.test.configuration.options;

in
test "excluded-options" {

  flat =
    let
      r = evalWith { argv0 = true; };
    in
    {
      argv0-absent-top = areEqual false (r.options ? argv0);
      argv0-absent-variant = areEqual false (varOpts r ? argv0);
      flagSeparator-present-top = areEqual true (r.options ? flagSeparator);
      flagSeparator-present-variant = areEqual true (varOpts r ? flagSeparator);
    };

  top-only =
    let
      r = evalWith { top.argv0 = true; };
    in
    {
      argv0-absent-top = areEqual false (r.options ? argv0);
      argv0-present-variant = areEqual true (varOpts r ? argv0);
    };

  variants-only =
    let
      r = evalWith { wrapperVariants.argv0 = true; };
    in
    {
      wrapperVariants-option-present = areEqual true (r.options ? wrapperVariants);
      argv0-present-top = areEqual true (r.options ? argv0);
      argv0-absent-variant = areEqual false (varOpts r ? argv0);
    };

  wrapperVariants-entire-attrset =
    let
      r = self.lib.evalModule [
        { inherit pkgs; }
        (
          { pkgs, wlib, ... }:
          {
            imports = [ (import wlib.modules.makeWrapper // { excluded_options.wrapperVariants = true; }) ];
            config.package = pkgs.hello;
          }
        )
      ];
    in
    {
      wrapperVariants-option-present = areEqual false (r.options ? wrapperVariants);
    };

}
