{ wlib, lib }:
let
  extradagopts = {
    extraOptions = {
      esc-fn = lib.mkOption {
        type = lib.types.nullOr (lib.types.functionTo lib.types.str);
        default = null;
      };
    };
  };
in
{
  /**
    Arguments:
    - `elemType`: `type`

    Accepts a LIST of elements

    The elements should be of type `elemType`
    or sets of the type `{ data, name ? null, before ? [], after ? [] }`
    where the `data` field is of type `elemType`

    If a name is not given, it cannot be targeted by other values.

    Can be used in conjunction with `wlib.dag.topoSort`
  */
  dalOf = wlib.dag.dalOf;

  /**
    Arguments:
    - `elemType`: `type`

    Accepts an attrset of elements

    The elements should be of type `elemType`
    or sets of the type `{ data, name ? null, before ? [], after ? [] }`
    where the `data` field is of type `elemType`

    `name` defaults to the key in the set.

    Can be used in conjunction with `wlib.dag.topoSort`
  */
  dagOf = wlib.dag.dagOf;

  /**
    same as `dalOf` except with an extra field `esc-fn`

    esc-fn is to be null, or a function that returns a string

    used by `wlib.modules.makeWrapper`
  */
  dalWithEsc = wlib.dag.dalWith extradagopts;

  /**
    same as `dagOf` except with an extra field `esc-fn`

    esc-fn is to be null, or a function that returns a string

    used by `wlib.modules.makeWrapper`
  */
  dagWithEsc = wlib.dag.dagWith extradagopts;

  /**
    Type for a value that can be converted to string `"${like_this}"`

    used by `wlib.modules.makeWrapper`
  */
  stringable = lib.mkOptionType {
    name = "stringable";
    description = "str|path|drv";
    check = lib.isStringLike;
    inherit (lib.types.str) merge;
  };

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
    - `path`: Derived path using pkgs.writeText
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
            defaultText = "pkgs.writeText name <content>";
          };
        };
      }
    );

  /**
    Like lib.types.anything, but allows contained lists to also be merged
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
