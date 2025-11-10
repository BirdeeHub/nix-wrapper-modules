{ lib }:
let
  all_mod_res = import ./modules.nix { inherit lib wlib; };
  wlib = {
    inherit (all_mod_res)
      wrapperModules
      modules
      checks
      ;

    misc = builtins.removeAttrs all_mod_res [
      "wrapperModules"
      "modules"
      "checks"
    ];

    dag = import ./dag.nix { inherit lib wlib; };

    /**
      calls nixpkgs.lib.evalModules with the core module imported and wlib added to specialArgs

      wlib.evalModules takes the same arguments as nixpkgs.lib.evalModules
    */
    evalModules = import ./core.nix { inherit lib wlib; };

    /**
      evalModule = module: wlib.evalModules { modules = [ module ]; };

      evalModule returns the direct result of calling evalModules

      It includes only the core options, it does not include anything which maps to wrapper.args

      This split is also necessary because documentation generators
      need access to .options, and it is feasible someone else may need something as well.
    */
    evalModule = module: wlib.evalModules { modules = [ module ]; };

    /**
      wrapModule = (evalModule wlib.modules.default).config.apply;

      A function to create a wrapper module.
      returns an attribute set with options and apply function.

      Example usage:
        helloWrapper = wrapModule ({ config, wlib, ... }: {
          options.greeting = lib.mkOption {
            type = lib.types.str;
            default = "hello";
          };
          config.package = config.pkgs.hello;
          config.flags = {
            "--greeting" = config.greeting;
          };
          # Or use args directly:
          # config.args = [ "--greeting" config.greeting ];
        };

        helloWrapper.wrap {
          pkgs = pkgs;
          greeting = "hi";
        };

        # This will return a derivation that wraps the hello package with the --greeting flag set to "hi".
    */
    wrapModule =
      module:
      (wlib.evalModules {
        modules = [
          wlib.modules.default
          module
        ];
      }).config;

    /**
      wrapPackage = (wlib.evalModule wlib.modules.default).config.wrap;

      Takes a module, returns a package.
    */
    wrapPackage =
      module:
      (wlib.evalModules {
        modules = [
          wlib.modules.default
          module
        ];
      }).config.wrapper;

    types = {
      inherit (wlib.dag) dalOf dagOf;

      fixedList =
        len: elemType:
        let
          base = lib.types.listOf elemType;
        in
        lib.mkOptionType {
          inherit (base) merge getSubOptions emptyValue;
          name = "fixedList";
          descriptionClass = "noun";
          description = "List of length ${toString len}";
          check = x: base.check x && builtins.length x == len;
        };

      wrapperFlags =
        len:
        wlib.types.dalOf (
          wlib.types.fixedList len (
            lib.types.oneOf [
              lib.types.str
              lib.types.package
            ]
          )
        );

      /**
        pkgs -> module { content, path }
      */
      file =
        # we need to pass pkgs here, because writeText is in pkgs
        pkgs:
        lib.types.submodule (
          { name, config, ... }:
          {
            options = {
              content = lib.mkOption {
                type = lib.types.lines;
                description = ''
                  content of file
                '';
              };
              path = lib.mkOption {
                type = lib.types.path;
                description = ''
                  the path to the file
                '';
                default = pkgs.writeText name config.content;
                defaultText = "pkgs.writeText name <content>";
              };
            };
          }
        );
    };

    /**
      getPackageOutputsSet ::
        Derivation -> AttrSet

      This function is probably not one you will use,
      but it is used by the default `symlinkScript` module option value.

      Given a package derivation, returns an attribute set mapping each of its
      output names (e.g. "out", "dev", "doc") to the corresponding output path.

      This is useful when a wrapper or module needs to reference multiple outputs
      of a single derivation. If the derivation does not define multiple outputs,
      an empty set is returned.

      Example:
        getPackageOutputsSet pkgs.git
        => {
          out = /nix/store/...-git;
          man = /nix/store/...-git-man;
        }
    */
    getPackageOutputsSet =
      package:
      if package ? outputs then
        lib.listToAttrs (
          map (output: {
            name = output;
            value = if package ? ${output} then package.${output} else null;
          }) package.outputs
        )
      else
        { };

  };
in
wlib
