{ wlib, lib }:
let

  baseFunc =
    {
      variant,
      config,
      callPackage,
      wrapperImplementation ? null,
      ...
    }@args:
    let
      call =
        v:
        callPackage
          (
            if (wrapperImplementation != null) then
              wrapperImplementation
            else if config.wrapperImplementation or "nix" == "nix" then
              ./makeWrapperNix.nix
            else
              ./makeWrapper.nix
          )
          (
            v
            // {
              inherit wlib;
              config = v.config or config;
            }
          );
    in
    if variant == null || variant == true then
      lib.pipe (config.wrapperVariants or { }) [
        (lib.mapAttrsToList (n: v: if v.enable or false then call (args // { config = v; }) else null))
        (builtins.filter (v: v != null))
        (list: (if variant != true then [ (call args) ] else [ ]) ++ list)
        (builtins.concatStringsSep "\n")
      ]
    else if variant == false then
      call args
    else if builtins.isString variant then
      if config.wrapperVariants.${variant}.enable or false then
        call (args // { config = config.wrapperVariants.${variant}; })
      else
        ""
    else
      "";

  baseFunc_usage_err = name: ''
    ERROR: usage of ${name} is as follows:

    wlib.makeWrapper.${name} {
      inherit config;
      inherit (pkgs) callPackage; # or `inherit pkgs`;${
        if name != "wrapVariant" then "" else "\n  name = \"attribute\";\n"
      }
    }${
      if name != "wrapVariant" then
        ""
      else
        "\n\nWhere `attribute` is a valid attribute of the `config.wrapperVariants` set"
    }
  '';
in
{
  /**
    The default `config.wrapperFunction` value for the `wlib.modules.makeWrapper` module

    Generates build instructions for wrapping the main target and all enabled variants.

    Usage:

    ```nix
      wlib.makeWrapper.wrapAll {
        inherit config;
        inherit (pkgs) callPackage; # or `inherit pkgs`;
      };
    ```

    Arguments:
      - `pkgs` (set either this or `callPackage`): Package set providing `callPackage`.
      - `callPackage` (set either this or `pkgs`): calls the wrapper builder.
      - `config` (required): Configuration attribute set.
      - `wrapperImplementation` (optional): Path or function for the wrapper implementation.

    Requirements on `config`:
      - Must define `binName`, `package`, and `exePath`.
      - May include options from `wlib.modules.makeWrapper`.

    Behavior:
      - Wraps the main target and all enabled variants.
      - If `config.binName` or `config.package` are missing, returns an empty string.
      - If `config.exePath` is not a non-empty string, wraps the full `config.package` path.
        Otherwise wraps:
          `"${config.package}/${config.binName}"`
      - Variants with `enable = false` are excluded.
      - It will output the main wrapper to `${placeholder "out"}/${config.binDir or "bin"}/${config.binName}`
      - It will do the same for each enabled variant, but with values from that variant's option set.

    Returns:
      A string containing build instructions to append to a derivation.

    It also takes as an argument `wrapperImplementation`

    You may define a function that recieves `config`, `wlib`, and arguments from `callPackage`
    and returns a string of build instructions, that follows similar behavior.

    You may use the other functions in `wlib.makeWrapper` to help with this.
  */
  wrapAll =
    {
      pkgs ? null,
      callPackage ? pkgs.callPackage or (baseFunc_usage_err "wrapAll"),
      config,
      wrapperImplementation ? null,
      ...
    }:
    baseFunc {
      inherit config callPackage wrapperImplementation;
      variant = null;
    };

  /*
    Generates build instructions for wrapping only the main target.

    Usage:

    ```nix
      wlib.makeWrapper.wrapMain {
        inherit config;
        inherit (pkgs) callPackage; # or `inherit pkgs`;
      };
    ```

    Arguments:
      - `pkgs` (set either this or `callPackage`): Package set providing `callPackage`.
      - `callPackage` (set either this or `pkgs`): calls the wrapper builder.
      - `config` (required): Configuration attribute set.
      - `wrapperImplementation` (optional): Path or function for the wrapper implementation.

    Requirements on `config`:
      - Must define `binName`, `package`, and `exePath`.
      - May include options from `wlib.modules.makeWrapper`.

    Behavior:
      - Wraps only the main target (no variants).
      - If `config.binName` or `config.package` are missing, returns an empty string.
      - If `config.exePath` is not a non-empty string, wraps the full `config.package` path.
        Otherwise wraps:
          `"${config.package}/${config.binName}"`
      - It will output the wrapper to `${placeholder "out"}/${config.binDir or "bin"}/${config.binName}`

    Returns:
      A string containing build instructions to append to a derivation.

    It also takes as an argument `wrapperImplementation`

    You may define a function that recieves `config`, `wlib`, and arguments from `callPackage`
    and returns a string of build instructions, that follows similar behavior.

    You may use the other functions in `wlib.makeWrapper` to help with this.
  */
  wrapMain =
    {
      pkgs ? null,
      callPackage ? pkgs.callPackage or (baseFunc_usage_err "wrapMain"),
      config,
      wrapperImplementation ? null,
      ...
    }:
    baseFunc {
      inherit config callPackage wrapperImplementation;
      variant = false;
    };

  /*
    Generates build instructions for wrapping all enabled variants,
    excluding the main target.

    Usage:

    ```nix
      wlib.makeWrapper.wrapVariants {
        inherit config;
        inherit (pkgs) callPackage; # or `inherit pkgs`;
      };
    ```

    Arguments:
      - `pkgs` (set either this or `callPackage`): Package set providing `callPackage`.
      - `callPackage` (set either this or `pkgs`): calls the wrapper builder.
      - `config` (required): Configuration attribute set.
      - `wrapperImplementation` (optional): Path or function for the wrapper implementation.

    Requirements on `config`:
      - Must define `binName`, `package`, and `exePath`.
      - Must define `wrapperVariants` as an attribute set.
      - May include options from `wlib.modules.makeWrapper`.

    Behavior:
      - Wraps all variants in `config.wrapperVariants`.
      - Variants with `enable = false` are excluded.
      - If `config.binName` or `config.package` are missing, returns an empty string.
      - If `config.exePath` is not a non-empty string, wraps the full `config.package` path.
        Otherwise wraps:
          `"${config.package}/${config.binName}"`
      - It will output each variant to the `${placeholder "out"}/${config.binDir or "bin"}/${config.binName}`
        corresponding to that variants options

    Returns:
      A string containing build instructions to append to a derivation.

    It also takes as an argument `wrapperImplementation`

    You may define a function that recieves `config`, `wlib`, and arguments from `callPackage`
    and returns a string of build instructions, that follows similar behavior.

    You may use the other functions in `wlib.makeWrapper` to help with this.
  */
  wrapVariants =
    {
      pkgs ? null,
      callPackage ? pkgs.callPackage or (baseFunc_usage_err "wrapVariants"),
      config,
      wrapperImplementation ? null,
      ...
    }:
    baseFunc {
      inherit config callPackage wrapperImplementation;
      variant = true;
    };

  /*
    Generates build instructions for wrapping a single variant.

    Usage:

    ```nix
      wlib.makeWrapper.wrapVariant {
        inherit config;
        inherit (pkgs) callPackage; # or `inherit pkgs`;
        name = "attribute";
      };
    ```

    Arguments:
      - `pkgs` (set either this or `callPackage`): Package set providing `callPackage`.
      - `callPackage` (set either this or `pkgs`): calls the wrapper builder.
      - `config` (required): Configuration attribute set.
      - `wrapperImplementation` (optional): Path or function for the wrapper implementation.
      - `name` (required): String name of a variant attribute
        in `config.wrapperVariants`.

    Requirements on `config`:
      - Must define `binName`, `package`, and `exePath`.
      - Must define `wrapperVariants` containing `name`.
      - May include options from `wlib.modules.makeWrapper`.

    Behavior:
      - Wraps only the specified variant.
      - Asserts that `name` is a string.
      - If the selected variant has `enable = false`, it is excluded.
      - If `config.binName` or `config.package` are missing, returns an empty string.
      - If `config.exePath` is not a non-empty string, wraps the full `config.package` path.
        Otherwise wraps:
          `"${config.package}/${config.binName}"`
      - It will output the wrapper to:
        `"${placeholder "out"}/${config.wrapperVariants.${name}.binDir or "bin"}/${config.wrapperVariants.${name}.binName}"`

    Returns:
      A string containing build instructions to append to a derivation.

    It also takes as an argument `wrapperImplementation`

    You may define a function that recieves `config`, `wlib`, and arguments from `callPackage`
    and returns a string of build instructions, that follows similar behavior.

    You may use the other functions in `wlib.makeWrapper` to help with this.
  */
  wrapVariant =
    {
      pkgs ? null,
      callPackage ? pkgs.callPackage or (baseFunc_usage_err "wrapVariant"),
      config,
      wrapperImplementation ? null,
      name,
    }:
    assert builtins.isString name || baseFunc_usage_err "wrapVariant";
    baseFunc {
      inherit config callPackage wrapperImplementation;
      variant = name;
    };

  /**
    Aggregates a single wrapper option set (either the top-level `config`
    or one of the entries from `config.wrapperVariants`) into a unified
    DAG-like list (DAL).

    Usage:

    ```nix
      wlib.makeWrapper.aggregateSingleOptionSet {
        inherit config;
        sortResult = true; # optional
      };
    ```

    Arguments:
      - `config` (required): An attribute set containing wrapper options.
        This may be the top-level wrapper configuration or a single
        variant’s option set.
      - `sortResult` (optional, default: `true`): Whether to sort the
        resulting DAL using `wlib.dag.unwrapSort "makeWrapper"`.

    Behavior:
      - Collects the following wrapper option categories from `config`:
          * unsetVar
          * env
          * envDefault
          * prefixVar
          * suffixVar
          * prefixContent
          * suffixContent
          * chdir
          * runShell
          * flags
          * addFlag
          * appendFlag
      - Normalizes each entry into a consistent structure containing:
          * `type`        — the originating option category
          * `data`        — primary value
          * `before`/`after`/`name` — DAG sorting values
          * `esc-fn`      — not yet applied, may be null.
          * `value`       — original value
          * 3 more which are only present for some types:
            * `sep`/`ifs`     — `flags` option-specific metadata (only included for `type == flags`)
            * `attr-name`       — (on attribute-style options) original attribute name (can't be overriden from within the spec)
      - Attribute-based option sets (e.g. `env`, `flags`) are converted
        into lists with their attribute names preserved.
      - If `sortResult = true`, the combined list is then sorted according to
        DAG ordering rules via `wlib.dag.unwrapSort`.

    Returns:
      A list (DAL) of normalized option entries suitable for further
      processing (e.g., splitting with `splitDal` or transforming with
      `fixArgs`).
  */
  aggregateSingleOptionSet =
    {
      config,
      sortResult ? true,
      ...
    }:
    let
      liftDag = type: v: {
        inherit type;
        data = v.data or null;
        before = v.before or null;
        after = v.after or null;
        name = v.name or null;
        esc-fn = v.esc-fn or null;
        ${if type == "flags" then "sep" else null} = v.sep or null;
        ${if type == "flags" then "ifs" else null} = v.ifs or null;
        value = v;
      };
      mapAndLiftDal = from_option: map (liftDag from_option);
      mapAndLiftDag =
        from_option: dag:
        lib.mapAttrsToList (attr-name: v: liftDag from_option v // { inherit attr-name; }) (
          wlib.dag.pushDownDagNames dag
        );
      unsorted =
        mapAndLiftDal "unsetVar" (config.unsetVar or [ ])
        ++ mapAndLiftDag "env" (config.env or { })
        ++ mapAndLiftDag "envDefault" (config.envDefault or { })
        ++ mapAndLiftDal "prefixVar" (config.prefixVar or [ ])
        ++ mapAndLiftDal "suffixVar" (config.suffixVar or [ ])
        ++ mapAndLiftDal "prefixContent" (config.prefixContent or [ ])
        ++ mapAndLiftDal "suffixContent" (config.suffixContent or [ ])
        ++ mapAndLiftDal "chdir" (config.chdir or [ ])
        ++ mapAndLiftDal "runShell" (config.runShell or [ ])
        ++ mapAndLiftDag "flags" (config.flags or { })
        ++ mapAndLiftDal "addFlag" (config.addFlag or [ ])
        ++ mapAndLiftDal "appendFlag" (config.appendFlag or [ ]);
    in
    if sortResult then wlib.dag.unwrapSort "makeWrapper" unsorted else unsorted;

  /*
    splitDal receives the dal as returned by `aggregateSingleOptionSet` and splits it into 2 lists, `args` and `other`.

    It returns a set with `args` and `other` attributes, containing the same format of items as `aggregateSingleOptionSet` returns.

    It puts all `type ==` `"flags"`, `"addFlag"`, or `"appendFlag"` into `args`, and anything else into `other`.

    `args` are almost always necessarily separate from the way anything else gets set, so a helper exists to separate them.
  */
  splitDal =
    DAL:
    builtins.foldl'
      (
        acc: v:
        if v.type == "flags" || v.type == "addFlag" || v.type == "appendFlag" then
          acc // { args = acc.args ++ [ v ]; }
        else
          acc // { other = acc.other ++ [ v ]; }
      )
      {
        args = [ ];
        other = [ ];
      }
      DAL;

  /**
    Normalizes and resolves argument-related entries from a DAL into
    concrete `addFlag` and `appendFlag` lists.

    Usage:

    ```nix
    wlib.makeWrapper.fixArgs {
      sep = "=";  # optional default separator
      ifs = ",";  # optional default inner-field separator
    } argsDAL;
    ```

    Arguments:
      - 1st argument, a set with:
        - `sep` (optional, default: `null`):
          Default separator used when a `flags` entry does not define
          its own `sep`. If null, flags and values may be emitted as
          separate arguments depending on configuration.
        - `ifs` (optional, default: `null`):
          Default inner-field separator used when a `flags` entry does
          not define its own `ifs` and the value is a list.
        - `fixPreFlagSort` (optional, default: `true`):
          Sorts the flags and addFlag values again after concatenating them,
          thus ensuring that it all still works like 1 DAL.
      - 2nd argument (required):
        A list of DAL entries, typically the `args` attribute returned
        by `splitDal`, but may also be the full DAL.

    Behavior:
      - Identifies entries of type:
          * "flags"
          * "addFlag"
          * "appendFlag"
      - Converts all `"flags"` entries into `"addFlag"` entries.
      - For each `"flags"` entry:
          * Uses entry-specific `sep` and `ifs` if defined.
          * Otherwise falls back to the provided `sep` and `ifs`
            options.
      - Handles flag value forms:
          * Boolean flags (`true` → standalone flag,
            `false`/null → omitted)
          * Single scalar values
          * Lists of values
      - Applies separator logic:
          * If both `sep` and `ifs` are set and the value is a list,
            emits a single argument with joined values.
          * If `sep` is set but `ifs` is null, emits one argument
            per list element using the separator.
          * If `sep` is null and `ifs` is set, emits the flag name
            followed by a joined value string.
          * If both are null, emits flag and value(s) as separate
            arguments.
      - Preserves existing `"addFlag"` and `"appendFlag"` entries.

    Returns:
      An attribute set containing:

    ```nix
    {
      addFlag = [ ... ];    # fully expanded and converted flags
      appendFlag = [ ... ]; # append-style flag entries
    }
    ```

    Intended to be called after `splitDal` and before final wrapper
    command generation.
  */
  fixArgs =
    {
      sep ? null,
      ifs ? null,
      fixPreFlagSort ? true,
    }@opts:
    argsDAL:
    let
      flags = builtins.filter (v: v.type or null == "flags") argsDAL;
      convertEntry =
        v: data:
        v
        // {
          inherit data;
          type = "addFlag";
        };
      mappedFlags = map (
        v:
        convertEntry v (
          let
            sep = if v.sep or null != null then v.sep else opts.sep or null;
            ifs = if v.ifs or null != null then v.ifs else opts.ifs or null;
          in
          if builtins.isList (v.data or null) then
            if sep != null && ifs != null then
              "${v.attr-name}${sep}${builtins.concatStringsSep ifs v.data}"
            else if sep != null && ifs == null then
              (builtins.concatMap (d: [ "${v.attr-name}${sep}${d}" ]) v.data)
            else if sep == null && ifs != null then
              ([ v.attr-name ] ++ builtins.concatStringsSep ifs v.data)
            else
              (builtins.concatMap (d: [
                v.attr-name
                d
              ]) v.data)
          else if v.data or null == null || v.data or false == false then
            [ ]
          else if v.data == true then
            v.attr-name
          else if sep != null then
            "${v.attr-name}${sep}${v.data}"
          else
            [
              v.attr-name
              v.data
            ]
        )
      ) flags;
      finalPreDal = mappedFlags ++ builtins.filter (v: v.type or null == "addFlag") argsDAL;
    in
    {
      addFlag =
        if builtins.isBool fixPreFlagSort && !fixPreFlagSort then
          finalPreDal
        else
          wlib.dag.unwrapSort "addFlag" finalPreDal;
      appendFlag = builtins.filter (v: v.type or null == "appendFlag") argsDAL;
    };

}
