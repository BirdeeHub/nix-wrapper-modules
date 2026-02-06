{
  wlib,
  lib,
}:
{

  /**
    Like `lib.types.submoduleWith` but for wrapper modules!

    Use this when you want any module (nixos and home manager included) to be able to accept other programs along with custom configurations.

    The resulting `config.optionname` value will contain `.config` from the evaluated wrapper module, just like `lib.types.submoduleWith`

    In other words, it will contain the same thing calling `.apply` returns.

    This means you may grab the wrapped package from `config.optionname.wrapper`

    It takes all the same arguments as `lib.types.submoduleWith`

    ```nix
    wlib.types.subWrapperModuleWith = {
      modules ? [],
      specialArgs ? {},
      shorthandOnlyDefinesConfig ? false,
      description ? null,
      class ? null
    }:
    ```

    In fact, it IS a submodule.

    This function simply adds `wlib.core` to the list of modules you pass,
    and both `wlib` and `modulesPath` (from wlib.modulesPath) to the specialArgs argument you pass.

    To perform type-merging with this type, use `lib.types.submodule` or `lib.types.submoduleWith`
  */
  subWrapperModuleWith =
    {
      modules ? [ ],
      specialArgs ? { },
      shorthandOnlyDefinesConfig ? false,
      description ? null,
      class ? null,
      ...
    }@args:
    lib.types.submoduleWith (
      args
      // {
        modules = [ wlib.core ] ++ modules;
        specialArgs = specialArgs // {
          inherit (wlib) modulesPath;
          inherit wlib;
        };
      }
    );

  /**
    ```nix
    wlib.types.subWrapperModule = module: wlib.types.subWrapperModuleWith { modules = lib.toList module; };
    ```

    i.e.

    ```nix
      options.myopts.xplr = lib.mkOption {
        type = wlib.types.subWrapperModule wlib.wrapperModules.xplr;
      };
      # and access config.myopts.xplr.wrapped and set settings and options within it.
    ```
  */
  subWrapperModule = module: wlib.types.subWrapperModuleWith { modules = lib.toList module; };

  /**
    Modified submoduleWith type for making options which are either an item, or a set with the item in it.

    It will auto-normalize the values into the set form on merge,
    so you can avoid custom normalization logic when using the `config` value associated with the option.

    The dag and dal types are made using this type.

    ```nix
    wlib.types.specWith =
      {
        modules,
        specialArgs ? { },
        class ? null,
        description ? null,
        mainField ? null,
        dontConvertFunctions ? false,
      }:
    ```

    - `modules`, `specialArgs`, `class`, `description` are the same as for `submoduleWith`.
    - `mainField ? null` You may specify your main field with this option.
      - If you don't, it will detect this value based on the option you do not give a default value to in your base modules.
      - You may only have 1 option without a default.
        - Any nested options will be assumed to have defaults.
        - If you have more than 1, and do not set `mainField`, it will error, and if you do set it, conversion will fail.
          In that case a submodule type would be a better match.
    - `dontConvertFunctions ? false`:
      `true` allows passing function-type submodules as specs.
      If your `data` field's type may contain a function, or is a submodule type itself, this should be left as `false`.
    - Setting `freeformType` allows entries to have **unchecked** extra attributes.
      If your item is a set, and might contain your main field,
      you will want to avoid this to avoid false positives.
  */
  specWith = import ./specWith.nix lib;

  /**
    ```nix
    wlib.types.spec = module: wlib.types.specWith { modules = lib.toList module; };
    ```
  */
  spec = module: wlib.types.specWith { modules = lib.toList module; };

  /**
    A DAG LIST or (DAL) or `dependency list` of some inner type

    Arguments:
    - `elemType`: `type`

    Accepts a LIST of elements

    The elements should be of type `elemType`
    or sets of the type `{ data, name ? null, before ? [], after ? [] }`
    where the `data` field is of type `elemType`

    If a name is not given, it cannot be targeted by other values.

    Can be used in conjunction with `wlib.dag.topoSort`, `wlib.dag.sortAndUnwrap`, and `wlib.dag.unwrapSort`

    Note, if the element type is a submodule then the `name` argument
    will always be set to the string "data" since it picks up the
    internal structure of the DAG values. To give access to the
    "actual" attribute name a new submodule argument is provided with
    the name `dagName`.

    The `config.optionname` value from the associated option
    will be normalized such that all items are DAG entries

    If you wish to alter the type, you may provide different options
    to `wlib.dag.dalWith` by updating this type `wlib.types.dalOf // { strict = false; }`

    You can further modify the type with type merging!
    Redefine the option with the type `lib.types.listOf (wlib.types.spec ({ your module here }))`
  */
  dalOf = {
    __functor = self: wlib.dag.dalWith (removeAttrs self [ "__functor" ]);
  };

  /**
    A directed acyclic graph (attrset) of some inner type.

    Arguments:
    - `elemType`: `type`

    Accepts an attrset of elements

    The elements should be of type `elemType`
    or sets of the type `{ data, name ? null, before ? [], after ? [] }`
    where the `data` field is of type `elemType`

    `name` defaults to the key in the set.

    Can be used in conjunction with `wlib.dag.topoSort`, `wlib.dag.sortAndUnwrap`, and `wlib.dag.unwrapSort`

    Note, if the element type is a submodule then the `name` argument
    will always be set to the string "data" since it picks up the
    internal structure of the DAG values. To give access to the
    "actual" attribute name a new submodule argument is provided with
    the name `dagName`.

    The `config.optionname` value from the associated option
    will be normalized such that all items are DAG entries

    If you wish to alter the type, you may provide different options
    to `wlib.dag.dagWith` by updating this type `wlib.types.dagOf // { strict = false; }`

    You can further modify the type with type merging!
    Redefine the option with the type `lib.types.attrsOf (wlib.types.spec ({ your module here }))`
  */
  dagOf = {
    __functor = self: wlib.dag.dagWith (removeAttrs self [ "__functor" ]);
  };

  /**
    This type functions like the `lib.types.listOf` type, but has reversed order across imports.
    The individual lists assigned are unaffected.

    This means, when you import a module, and it sets `config.optionwiththistype`,
    it will _append_ to the _importing_ module's definitions rather than prepending to them.

    This type is sometimes very useful when you want multiple `.wrap`, `.apply`, `.eval`, and `.extendModules`
    calls in series to apply to this option in a particular way.

    This is because in that case with `lib.types.listOf`,
    each successive call will place its new items BEFORE the last call.

    In some cases, where the first item will win, e.g. `lndir` this makes sense, or is inconsequential.

    In others, (for example, with the `config.overrides` field from the core module) you really want them to run in series. So you can use `seriesOf`!
  */
  seriesOf =
    elemType:
    let
      base = lib.types.listOf elemType;
      name = "seriesOf";
    in
    lib.mkOptionType rec {
      inherit name;
      inherit (base)
        getSubOptions
        getSubModules
        check
        emptyValue
        nestedTypes
        descriptionClass
        ;
      description = "series of ${
        lib.types.optionDescriptionPhrase (class: class == "noun" || class == "composite") elemType
      }";
      merge = {
        __functor =
          self: loc: defs:
          (self.v2 { inherit loc defs; }).value;
        v2 =
          { loc, defs }:
          base.merge.v2 {
            defs = lib.reverseList defs;
            inherit loc;
          };
      };
      substSubModules = m: wlib.types.seriesOf (elemType.substSubModules m);
      functor = base.functor // {
        inherit name;
        type = payload: wlib.types.seriesOf payload.elemType;
      };
    };

  /**
    same as `dalOf` except with an extra field `esc-fn`

    esc-fn is to be null, or a function that returns a string

    used by `wlib.modules.makeWrapper`
  */
  dalWithEsc = wlib.types.dalOf // {
    modules = [
      {
        options.esc-fn = lib.mkOption {
          type = lib.types.nullOr (lib.types.functionTo lib.types.str);
          default = null;
          description = ''
            A per-item override of the default string escape function
          '';
        };
      }
    ];
  };

  /**
    same as `dagOf` except with an extra field `esc-fn`

    esc-fn is to be null, or a function that returns a string

    used by `wlib.modules.makeWrapper`
  */
  dagWithEsc = wlib.types.dagOf // {
    inherit (wlib.types.dalWithEsc) modules;
  };

  /**
    The kind of type you would provide to `pkgs.lua.withPackages` or `pkgs.python3.withPackages`

    This type is a function from a set of packages to a list of packages.

    If you set it in multiple files, it will merge the resulting lists according to normal module rules for a `listOf package`.
  */
  withPackagesType =
    let
      inherit (lib.types) package listOf functionTo;
    in
    (functionTo (listOf package))
    // {
      merge =
        loc: defs: arg:
        (listOf package).merge (loc ++ [ "<function body>" ]) (
          map (
            def:
            def
            // {
              value = def.value arg;
            }
          ) defs
        );
    };

  /**
    Type for a value that can be converted to string `"${like_this}"`

    used by `wlib.modules.makeWrapper`
  */
  stringable = lib.mkOptionType {
    name = "stringable";
    descriptionClass = "noun";
    description = "str|path|drv";
    check = lib.isStringLike;
    merge =
      loc: defs:
      let
        res = lib.mergeEqualOption loc defs;
      in
      if builtins.isPath res then builtins.path { path = res; } else res;
  };

  /**
    A single-line, non-empty string
  */
  nonEmptyLine = lib.mkOptionType {
    name = "nonEmptyLine";
    description = "non-empty line";
    descriptionClass = "noun";
    check =
      x:
      lib.types.str.check x && builtins.match "[ \t\n]*" x == null && builtins.match "[^\n\r]*" != null;
    inherit (lib.types.str) merge;
  };
  nonEmptyline = lib.warn "`wlib.types.nonEmptyline` is deprecated due to having a mistake in its name, use `wlib.types.nonEmptyLine`" wlib.types.nonEmptyLine;

  /**
    Arguments:
    - `length`: `int`,
    - `elemType`: `type`

    It's a list, but it rejects lists of the wrong length.

    Still has regular list merge across multiple definitions, best used inside another list
  */
  fixedList =
    len: elemType:
    let
      base = lib.types.listOf elemType;
    in
    lib.types.addCheck base (x: base.check x && builtins.length x == len)
    // {
      name = "fixedList";
      descriptionClass = "noun";
      description = "(List of length ${toString len})";
    };

  /**
    Arguments:
    - `length`: `int`,

    `len: wlib.types.dalOf (wlib.types.fixedList len wlib.types.stringable)`
  */
  wrapperFlags = len: wlib.types.dalWithEsc (wlib.types.fixedList len wlib.types.stringable);

  /**
    DAL (list) of (stringable or list of stringable)

    More flexible than `wlib.types.wrapperFlags`, allows single items, or lists of items of varied length
  */
  wrapperFlag = wlib.types.dalWithEsc (
    lib.types.oneOf [
      wlib.types.stringable
      (lib.types.listOf wlib.types.stringable)
    ]
  );

  /**
    File type with content and path options

    Arguments:
    - `pkgs`: nixpkgs instance

    Fields:
    - `content`: File contents as string
    - `path`: Derived path using `pkgs.writeText`
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
              Content of the file. This can be a multi-line string that will be
              written to the Nix store and made available via the path option.
            '';
          };
          path = lib.mkOption {
            type = wlib.types.stringable;
            description = ''
              The path to the file. By default, this is automatically
              generated using pkgs.writeText with the attribute name and content.
            '';
            default = pkgs.writeText name config.content;
            defaultText = lib.literalExpression "pkgs.writeText name <content>";
          };
        };
      }
    );

  /**
    Like `lib.types.anything`, but allows contained lists to also be merged
  */
  attrsRecursive = lib.mkOptionType {
    name = "attrsRecursive";
    description = "attrsRecursive";
    descriptionClass = "noun";
    check = value: true;
    merge =
      loc: defs:
      let
        getType =
          value:
          if lib.isAttrs value && lib.isStringLike value then "stringCoercibleSet" else builtins.typeOf value;

        # Returns the common type of all definitions, throws an error if they
        # don't have the same type
        commonType = lib.foldl' (
          type: def:
          if getType def.value == type then
            type
          else
            throw "The option `${lib.showOption loc}' has conflicting option types in ${lib.showFiles (lib.getFiles defs)}"
        ) (getType (lib.head defs).value) defs;

        mergeFunction =
          {
            # Recursively merge attribute sets
            set = (lib.types.attrsOf wlib.types.attrsRecursive).merge;
            # merge lists
            list = (lib.types.listOf wlib.types.attrsRecursive).merge;
            # This is the type of packages, only accept a single definition
            stringCoercibleSet = lib.mergeOneOption;
            lambda =
              loc: defs: arg:
              wlib.types.attrsRecursive.merge (loc ++ [ "<function body>" ]) (
                map (def: {
                  file = def.file;
                  value = def.value arg;
                }) defs
              );
            # Otherwise fall back to only allowing all equal definitions
          }
          .${commonType} or lib.mergeEqualOption;
      in
      mergeFunction loc defs;
  };
}
