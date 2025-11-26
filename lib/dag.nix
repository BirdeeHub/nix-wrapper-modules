# From home-manager: https://github.com/nix-community/home-manager/blob/master/modules/lib/dag.nix
# A generalization of Nixpkgs's `strings-with-deps.nix`.
#
# The main differences from the Nixpkgs version are
#
#  - not specific to strings, i.e., any payload is OK,
#
#  - the addition of the function `entryBefore` indicating a "wanted
#    by" relationship.
#
# The main differences from this version and the home-manager version are
#
# - It has a list form as well
#
# - It allows extra fields to be added to what an entry is,
#   in either a type-safe, or freeform way.
#
{ wlib, lib }:
let
  inherit (builtins)
    isAttrs
    attrValues
    attrNames
    elem
    all
    head
    tail
    length
    isString
    isBool
    mapAttrs
    isList
    toJSON
    ;
  inherit (lib)
    mkIf
    mkOrder
    mkOption
    mkOptionType
    isFunction
    types
    ;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.lists) toposort;
  inherit (wlib.dag)
    isEntry
    entryBetween
    entryAnywhere
    entryAfter
    entriesBetween
    dagWith
    dalWith
    topoSort
    gmap
    dagToDal
    ;
  mkExtraFieldsMsg =
    settings:
    if builtins.isAttrs (settings.extraOptions or null) then
      "(with extra field(s): `"
      + (builtins.concatStringsSep "`, `" (builtins.attrNames settings.extraOptions))
      + "`) "
    else
      "";
  dagEntryOf =
    settings: isDal: elemType:
    let
      isStrict = if isBool (settings.strict or true) then settings.strict or true else true;
      extraOptions =
        if isAttrs (settings.extraOptions or null) then
          settings.extraOptions
        else
          { };
      specialArgs = if isAttrs (settings.specialArgs or null) then settings.specialArgs else { };
      defaultNameFn =
        if isFunction (settings.defaultNameFn or null) then
          settings.defaultNameFn
        else
          { name, isDal, ... }: if isDal then null else name;
      submoduleType = types.submoduleWith (
        {
          specialArgs = specialArgs // {
            inherit isDal;
          };
          shorthandOnlyDefinesConfig =
            if isBool (settings.shorthandOnlyDefinesConfig or null) then
              settings.shorthandOnlyDefinesConfig
            else
              true;
          modules = [
            (
              # NOTE: if name is not declared, it doesnt get added.
              { config, name, ... }@args:
              (if isStrict then { } else { freeformType = wlib.types.attrsRecursive; })
              // {
                options = (extraOptions args) // {
                  name = mkOption {
                    type = types.nullOr types.str;
                    default = defaultNameFn args;
                  };
                  data = mkOption { type = elemType; };
                  after = mkOption {
                    type = with types; listOf str;
                    default = [ ];
                  };
                  before = mkOption {
                    type = with types; listOf str;
                    default = [ ];
                  };
                };
                config = mkIf (elemType.name == "submodule") {
                  data._module.args.dagName = config.name;
                };
              }
            )
          ]
          ++ (if isList (settings.modules or null) then settings.modules else [ ]);
        }
        // builtins.removeAttrs settings [
          "strict"
          "modules"
          "extraOptions"
          "specialArgs"
          "shorthandOnlyDefinesConfig"
          "defaultNameFn"
        ]
      );
      knownKeys = [
        "name"
        "data"
        "before"
        "after"
      ]
      ++ attrNames extraOptions;
      extrasWithoutDefaults = attrNames (filterAttrs (n: v: !v ? default) extraOptions);
      checkMergeDef =
        def:
        if !isStrict then
          isEntry def.value && all (k: def.value ? ${k}) extrasWithoutDefaults
        else
          isEntry def.value
          && all (k: elem k knownKeys && (extraOptions.${k}.type.check or (x: true)) def.value.${k}) (
            attrNames def.value
          )
          && all (k: def.value ? ${k}) extrasWithoutDefaults;
      maybeConvert =
        def:
        if checkMergeDef def then
          def.value
        else
          entryAnywhere (if def ? priority then mkOrder def.priority def.value else def.value);
    in
    mkOptionType {
      name = "dagEntryOf";
      description = "DAG entry ${mkExtraFieldsMsg settings}of ${elemType.description}";
      # leave the checking to the submodule type
      merge =
        loc: defs:
        submoduleType.merge loc (
          map (def: {
            inherit (def) file;
            value = maybeConvert def;
          }) defs
        );
    };
in
{
  /**
    A directed acyclic graph of some inner type.

    Arguments:
    - `elemType`: `type`

    Accepts an attrset of elements

    The elements should be of type `elemType`
    or sets of the type `{ data, name ? null, before ? [], after ? [] }`
    where the `data` field is of type `elemType`

    `name` defaults to the key in the set.

    Can be used in conjunction with `wlib.dag.topoSort`

    Note, if the element type is a submodule then the `name` argument
    will always be set to the string "data" since it picks up the
    internal structure of the DAG values. To give access to the
    "actual" attribute name a new submodule argument is provided with
    the name `dagName`.

    The `config.optionname` value from the associated option
    will be normalized such that all items are DAG entries
  */
  dagOf = dagWith { };

  /**
    Arguments:
    - `settings`:
        - `strict ? true`
        - `extraOptions ? {}`
        - `defaultNameFn ? ({ config, name, isDal, ... }: if isDal then null else name)`
        - ... other arguments for `lib.types.submoduleWith`
    - `elemType`: `type`

    dagWith accepts an attrset as its first parameter BEFORE elemType.

    You may include `{ strict = false; }` to make it recognize sets
    with arbitrary extra values beyond just `data`, `name`, `before`, and `after`.

    You may include `{ extraOptions = { lib.mkOption ... }; }`
    to add extra fields to the dagEntryOf type to have extra type checked values,
    even if strict is true

    The `config.optionname` value from the associated option
    will be normalized such that all items are DAG entries
  */
  dagWith =
    settings: elemType:
    let
      attrEquivalent = types.attrsOf (dagEntryOf settings false elemType);
    in
    mkOptionType rec {
      name = "dagOf";
      description = "DAG ${mkExtraFieldsMsg settings}of ${elemType.description}";
      inherit (attrEquivalent) check merge emptyValue;
      inherit (elemType) getSubModules;
      getSubOptions = prefix: elemType.getSubOptions (prefix ++ [ "<name>" ]);
      substSubModules = m: dagWith settings (elemType.substSubModules m);
      functor = {
        name = name;
        type = dagWith settings;
        wrapped = elemType;
        payload = elemType;
        binOp = a: b: a;
      };
      nestedTypes.elemType = elemType;
    };

  /**
    A DAG LIST or (DAL) or `dependency list` of some inner type

    Arguments:
    - `elemType`: `type`

    Accepts a LIST of elements

    The elements should be of type `elemType`
    or sets of the type `{ data, name ? null, before ? [], after ? [] }`
    where the `data` field is of type `elemType`

    If a name is not given, it cannot be targeted by other values.

    Can be used in conjunction with `wlib.dag.topoSort`

    Note, if the element type is a submodule then the `name` argument
    will always be set to the string "data" since it picks up the
    internal structure of the DAG values. To give access to the
    "actual" attribute name a new submodule argument is provided with
    the name `dagName`.

    The `config.optionname` value from the associated option
    will be normalized such that all items are DAG entries
  */
  dalOf = dalWith { };

  /**
    Arguments:
    - `settings`:
      - `strict ? true`
      - `extraOptions ? {}`
      - `defaultNameFn ? ({ config, name, isDal, ... }: if isDal then null else name)`
      - ... other arguments for `lib.types.submoduleWith`
    - `elemType`: `type`

    dalWith accepts an attrset as its first parameter BEFORE elemType.

    You may include `{ strict = false; }` to make it recognize sets
    with arbitrary extra values beyond just `data`, `name`, `before`, and `after`.

    You may include `{ extraOptions = { lib.mkOption ... }; }`
    to add extra fields to the dagEntryOf type to have extra type checked values,
    even if strict is true

    The `config.optionname` value from the associated option
    will be normalized such that all items are DAG entries
  */
  dalWith =
    settings: elemType:
    let
      listEquivalent = types.listOf (dagEntryOf settings true elemType);
    in
    mkOptionType rec {
      name = "dalOf";
      description = "DAG LIST ${mkExtraFieldsMsg settings}of ${elemType.description}";
      inherit (listEquivalent) check merge emptyValue;
      inherit (elemType) getSubModules getSubOptions;
      substSubModules = m: dalWith settings (elemType.substSubModules m);
      functor = {
        name = name;
        type = dalWith settings;
        wrapped = elemType;
        payload = elemType;
        binOp = a: b: a;
      };
      nestedTypes.elemType = elemType;
    };

  /**
    Determines whether a value is a valid DAG entry (allows extra values)
  */
  isEntry =
    e:
    e ? data
    && (if e ? after then isList e.after else true)
    && (if e ? before then isList e.before else true)
    && (if e ? name then e.name == null || isString e.name else true);

  /**
    determines whether a value is of the attrset type and all values are dag entries

    Allows entries to have extra values
  */
  isDag = dag: isAttrs dag && all isEntry (attrValues dag);

  /**
    determines whether a value is of the list type and all values are dag entries

    Allows entries to have extra values
  */
  isDal = dal: isList dal && all isEntry dal;

  /*
    Takes an attribute set containing entries built by entryAnywhere,
    entryAfter, and entryBefore to a topologically sorted list of
    entries.

    Alternatively, it can take a `dal` (dependency list) instead.
    Which is a list of such entries.

    Requires values to all be DAG entries (in other words, have a `value.data` field)

    Internally this function uses the `topoSort` function in
    `<nixpkgs/lib/lists.nix>` and its value is accordingly.

    Specifically, the result on success is

    ```nix
       { result = [ { name = ?; data = ?; } … ] }
    ```

    For example

    ```nix
       nix-repl> topoSort {
                   a = entryAnywhere "1";
                   b = entryAfter [ "a" "c" ] "2";
                   c = entryBefore [ "d" ] "3";
                   d = entryBefore [ "e" ] "4";
                   e = entryAnywhere "5";
                 } == {
                   result = [
                     { data = "1"; name = "a"; }
                     { data = "3"; name = "c"; }
                     { data = "2"; name = "b"; }
                     { data = "4"; name = "d"; }
                     { data = "5"; name = "e"; }
                   ];
                 }
       true
    ```

    And the result on error is

    ```nix
       {
         cycle = [ { after = ?; name = ?; data = ? } … ];
         loops = [ { after = ?; name = ?; data = ? } … ];
       }
    ```

    For example

    ```nix
       nix-repl> topoSort {
                   a = entryAnywhere "1";
                   b = entryAfter [ "a" "c" ] "2";
                   c = entryAfter [ "d" ] "3";
                   d = entryAfter [ "b" ] "4";
                   e = entryAnywhere "5";
                 } == {
                   cycle = [
                     { after = [ "a" "c" ]; data = "2"; name = "b"; }
                     { after = [ "d" ]; data = "3"; name = "c"; }
                     { after = [ "b" ]; data = "4"; name = "d"; }
                   ];
                   loops = [
                     { after = [ "a" "c" ]; data = "2"; name = "b"; }
                   ];
                 }
       true
    ```
  */
  topoSort =
    dag:
    let
      before =
        a: b:
        let
          aName = a.name or null;
          bName = b.name or null;
        in
        (aName != null && elem aName (b.after or [ ])) || (bName != null && elem bName (a.before or [ ]));
    in
    toposort before (if isList dag then dag else dagToDal dag);

  /**
    Applies a function to each element of the given DAG.

    Requires values to all be DAG entries (in other words, have a `value.data` field)
  */
  gmap = f: mapAttrs (n: v: v // { data = f n v.data; });

  /**
    wlib.dag.gmap but returns the result as a DAL

    Requires values to all be DAG entries (in other words, have a `value.data` field)
  */
  mapDagToDal = f: dag: dagToDal (gmap f dag);

  /**
    converts a DAG to a DAL

    Requires values to all be DAG entries (in other words, have a `value.data` field)
  */
  dagToDal =
    dag:
    attrValues (
      mapAttrs (
        n: v:
        v
        // {
          name =
            if isString (v.name or null) then
              v.name
            else if isString n then
              n
            else
              null;
        }
      ) dag
    );

  /**
    Applies a function to each element of the given DAL.

    Requires values to all be DAG entries (in other words, have a `value.data` field)
  */
  lmap = f: map (v: v // { data = f v.data; });

  /**
    Creates a DAG entry with specified `before` and `after` dependencies.
  */
  entryBetween = before: after: data: { inherit data before after; };

  /**
    Create a DAG entry with no particular dependency information.
  */
  entryAnywhere = entryBetween [ ] [ ];

  /**
    Convenience function to create a DAG entry that should come after certain nodes.
  */
  entryAfter = entryBetween [ ];

  /**
    Convenience function to create a DAG entry that should come before certain nodes.
  */
  entryBefore = before: entryBetween before [ ];

  /**
    Given a list of entries, this function places them in order within the DAG.
    Each entry is labeled "${tag}-${entry index}" and other DAG entries can be
    added with 'before' or 'after' referring these indexed entries.

    The entries as a whole can be given a relation to other DAG nodes. All
    generated nodes are then placed before or after those dependencies.
  */
  entriesBetween =
    tag:
    let
      go =
        i: before: after: entries:
        let
          name = "${tag}-${toString i}";
        in
        if entries == [ ] then
          { }
        else if length entries == 1 then
          {
            "${name}" = entryBetween before after (head entries);
          }
        else
          {
            "${name}" = entryAfter after (head entries);
          }
          // go (i + 1) before [ name ] (tail entries);
    in
    go 0;

  /**
    Convenience function for creating multiple entries without specific dependencies.
  */
  entriesAnywhere = tag: entriesBetween tag [ ] [ ];

  /**
    Convenience function for creating multiple entries that must be after another entry
  */
  entriesAfter = tag: entriesBetween tag [ ];

  /**
    Convenience function for creating multiple entries that must be before another entry
  */
  entriesBefore = tag: before: entriesBetween tag before [ ];

  /**
    Convenience function for resolving a DAG or DAL and getting the result in a sorted list of DAG entries

    Unless you make use of mapIfOk, the result is still a DAL, but sorted.

    Arguments:
    ```nix
    {
      name ? "DAG", # for error message
      dag,
      mapIfOk ? null,
    }
    ```

    Requires values to all be DAG entries (in other words, have a `value.data` field)
  */
  sortAndUnwrap =
    {
      name ? "DAG",
      dag,
      mapIfOk ? null,
    }:
    let
      sortedDag = topoSort dag;
      result =
        if sortedDag ? result then
          if lib.isFunction mapIfOk then map mapIfOk sortedDag.result else sortedDag.result
        else
          abort ("Dependency cycle in ${name}: " + toJSON sortedDag);
    in
    result;
}
