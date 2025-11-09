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
      mkWrapperFlag ::
        Int or AttrSet -> Option

      Defines a typed wrapper flag option with enforced arity and default value.

      Accepts either a numeric arity (e.g. 0, 1, 2+) or an attribute set with
      optional fields:
        - `len`: expected argument length
        - `default`: default value
        - any additional attributes to merge into the option definition

      For example:
        mkWrapperFlag 0
          => Boolean flag (true/false)

        mkWrapperFlag 1
          => List of strings, each passed as `--flag value`

        mkWrapperFlag 2+
          => List of fixed-length lists, passed as
             `--flag VAR VAL etc.. --flag VAR2 VAL2 etc...`

      Used to build declarative flag option sets that map cleanly to wrapper
      command-line arguments.
    */
    mkWrapperFlag =
      arglen:
      lib.mkOption {
        type = wlib.mkWrapperFlagType (arglen.len or arglen);
        default =
          arglen.default or (
            if !builtins.isInt (arglen.len or arglen) then
              (arglen.len or arglen).emptyValue.value or null
            else if arglen == 0 then
              false
            else
              [ ]
          );
      }
      // lib.optionalAttrs (builtins.isAttrs arglen) (
        builtins.removeAttrs arglen [
          "len"
          "default"
        ]
      );

    /**
      mkWrapperFlagType ::
        Int -> OptionType

      Constructs a custom `lib.mkOptionType` enforcing the structure of a
      wrapper flag with a given arity.

      Rules:
        - 0 → boolean (true includes flag, false omits)
        - 1 → list of values, each producing `[ flag value ]`
        - n≥2 → list of lists, each inner list of length n

      The resulting type is used by `mkWrapperFlag` to ensure consistent
      argument structure at evaluation time.

      Example:
        mkWrapperFlagType 0  → Bool
        mkWrapperFlagType 1  → [ "value1" "value2" ]
        mkWrapperFlagType 2  → [ [ "VAR" "VAL" ] [ "FOO" "BAR" ] ]
    */
    mkWrapperFlagType =
      arglen:
      lib.mkOptionType {
        name = "wrapperFlag";
        descriptionClass = "noun";
        description =
          if arglen == 0 then
            "Wrapper flag (boolean)"
          else if arglen == 1 then
            "Wrapper flag (list of values)"
          else if !builtins.isInt arglen then
            "Wrapper Flag (" + arglen.description + ")"
          else
            "Wrapper flag (list of lists of length ${builtins.toString arglen})";
        check =
          v:
          with builtins;
          if arglen == 0 then
            isBool v
          else if arglen == 1 then
            isList v
          else if !isInt arglen then
            arglen.check v
          else
            isList v && all (x: isList x && length x == arglen) v;
      };

    /**
      generateArgsFromFlags :: flagSeparator "" -> flags {} -> args [""]
      The key is the flag name, the value is the flag value.
      If the value is true, the flag will be passed without a value.
      If the value is false or null, the flag will not be passed.
      If the value is a list, the flag will be passed multiple times with each value.
    */
    generateArgsFromFlags =
      flagSeparator: flags:
      lib.flatten (
        lib.mapAttrsToList (
          name: value:
          if value == false || value == null then
            [ ]
          else if value == { } then
            [ name ]
          else if lib.isList value then
            lib.flatten (
              map (
                v:
                if lib.trim flagSeparator == "" then
                  [
                    name
                    (toString v)
                  ]
                else
                  [ "${name}${flagSeparator}${toString v}" ]
              ) value
            )
          else if lib.trim flagSeparator == "" then
            [
              name
              (toString value)
            ]
          else
            [ "${name}${flagSeparator}${toString value}" ]
        ) flags
      );

    /**
      Convert an attribute set of wrapper arguments into a flat list of command-line arguments.

      This is used to translate a `{ flagName = value; }` structure into the format
      expected by `makeWrapper`, while enforcing arity rules declared in `flags`.

      Type:
        argOpts2list :: { <flag> = bool or [ string ] or [ [ string ] ], ... } -> [ string ]

      Parameters:
        argOpt:
          The actual flag values provided by the user or module.
          - If arity = 0 → value must be `true` or `false` (true means include the flag).
          - If arity = 1 → value must be a list, each item produces: [ flag item ]
          - If arity ≥ 2 → value must be a list of lists, and each inner list's length must match arity.

      Returns:
        A flattened list of command-line arguments, suitable for passing to makeWrapper.

      Throws:
        - If a flag in `argOpt` is not defined in `flags`.
        - If value type doesn't match expected arity.
        - If list lengths don't match the declared arity.

      Example:
        argOpt = {
          "--inherit-argv0" = true;
          "--unset" = [ "GIT_DIR" ];
          "--set" = [
            [ "PATH" "/tmp/bin" ]
            [ "EDITOR" "vim" ]
          ];
        };

        argOpts2list argOpt
        => [
          "--inherit-argv0"
          "--unset" "GIT_DIR"
          "--set" "PATH" "/tmp/bin"
          "--set" "EDITOR" "vim"
        ]
    */
    argOpts2list =
      argOpt:
      with builtins;
      lib.flatten (
        lib.mapAttrsToList (
          n: v:
          if isBool v then
            if v then [ n ] else [ ]
          else if !isList v then
            if v != null then
              [
                n
                v
              ]
            else
              [ ]
          else if isList v then
            (map (val: [
              n
              val
            ]) v)
          else
            [ ]
        ) argOpt
      );

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
