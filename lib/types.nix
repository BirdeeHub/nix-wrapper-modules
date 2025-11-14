{ wlib, lib }:
{
  /**
    Arguments:
    - `elemType`: `type`

    Accepts a LIST of elements

    The elements should be of type `elemType`
    or sets of the type `{ data, name ? null, before ? [], after ? [], ... }`
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
    or sets of the type `{ data, name ? null, before ? [], after ? [], ... }`
    where the `data` field is of type `elemType`

    `name` defaults to the key in the set.

    Can be used in conjunction with `wlib.dag.topoSort`
  */
  dagOf = wlib.dag.dagOf;

  /**
    Type for a value that can be converted to string `"${like_this}"`
  */
  stringable = lib.mkOptionType {
    name = "stringable";
    description = "str | path | v ? outPath";
    check = x: builtins.isString x || x ? outPath || builtins.isPath x;
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
    lib.mkOptionType {
      inherit (base) merge getSubOptions emptyValue;
      name = "fixedList";
      descriptionClass = "noun";
      description = "(List of length ${toString len})";
      check = x: base.check x && builtins.length x == len;
    };

  /**
    Arguments:
    - `length`: `int`,

    `len: wlib.types.dalOf (wlib.types.fixedList len wlib.types.stringable)`
  */
  wrapperFlags = len: wlib.types.dalOf (wlib.types.fixedList len wlib.types.stringable);

  /**
    DAL (list) of (stringable or list of stringable)

    More flexible than `wlib.types.wrapperFlags`, allows single items, or lists of items of varied length
  */
  wrapperFlag = wlib.types.dalOf (
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
}
