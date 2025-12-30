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
    removeAttrs
    concatStringsSep
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
    entryAfter
    entriesBetween
    dagWith
    dalWith
    topoSort
    gmap
    dagToDal
    ;
  dagEntryOf =
    settings: isDal: elemType:
    let
      isStrict = if isBool (settings.strict or true) then settings.strict or true else true;
      dontConvertFunctions =
        if isBool (settings.dontConvertFunctions or null) then settings.dontConvertFunctions else false;
      dataTypeFn = if isFunction (settings.dataTypeFn or null) then settings.dataTypeFn else x: _: x;
      defaultNameFn =
        if isFunction (settings.defaultNameFn or null) then
          settings.defaultNameFn
        else
          { name, isDal, ... }: if isDal then null else name;
      extraOptions =
        if settings ? extraOptions then
          lib.warn
            "Deprecated dagWith/dalWith setting: `extraOptions` set. Use `modules` list instead to provide extra options"
            (if isAttrs (settings.extraOptions or null) then settings.extraOptions else { })
        else
          { };
      submoduleType = types.submoduleWith (
        {
          specialArgs = (if isAttrs (settings.specialArgs or null) then settings.specialArgs else { }) // {
            inherit isDal;
          };
          shorthandOnlyDefinesConfig =
            if isBool (settings.shorthandOnlyDefinesConfig or null) then
              settings.shorthandOnlyDefinesConfig
            else
              true;
          modules = [
            (
              # NOTE: if name is not declared, it doesnt get added for defaultNameFn or dataTypeFn
              { config, name, ... }@args:
              (if isStrict then { } else { freeformType = wlib.types.attrsRecursive; })
              // {
                options = (filterAttrs (_: v: !isBool v) extraOptions) // {
                  name = mkOption {
                    type = types.nullOr types.str;
                    default = defaultNameFn args;
                  };
                  data = mkOption { type = dataTypeFn elemType args; };
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
        // removeAttrs settings [
          "strict"
          "modules"
          "extraOptions"
          "specialArgs"
          "dontConvertFunctions"
          "shorthandOnlyDefinesConfig"
          "defaultNameFn"
          "dataTypeFn"
        ]
      );
      subopts = removeAttrs (submoduleType.getSubOptions [ ]) [ "_module" ];
      extraFieldsMsg =
        let
          extra-fields = attrNames (
            filterAttrs (
              n: v:
              if
                {
                  name = false;
                  data = false;
                  before = false;
                  after = false;
                }
                .${n} or true
              then
                if v.internal or false == true then false else true
              else
                false
            ) subopts
          );
          numfields = length extra-fields;
        in
        if numfields > 1 then
          "(with extra fields: `" + (concatStringsSep "`, `" extra-fields) + "`) "
        else if numfields > 0 then
          "(with extra field: `" + (concatStringsSep "`, `" extra-fields) + "`) "
        else
          "";
      extrasWithoutDefaults = attrNames (filterAttrs (n: v: !(v.isDefined or true)) subopts);
      # returns true if already the submodule type and false if not
      checkMergeDef =
        def:
        if dontConvertFunctions && isFunction def.value then
          true
        else if !isStrict then
          isEntry def.value && all (k: def.value ? ${k}) extrasWithoutDefaults
        else
          isEntry def.value
          && all (k: elem k (attrNames subopts)) (attrNames def.value)
          && all (k: def.value ? ${k}) extrasWithoutDefaults;
      # converts if not already the submodule type
      maybeConvert =
        def:
        if checkMergeDef def then
          def.value
        else
          { data = if def ? priority then mkOrder def.priority def.value else def.value; };
    in
    {
      inherit extraFieldsMsg;
      type = mkOptionType {
        name = "dagEntryOf";
        description = "DAG entry ${extraFieldsMsg}of ${elemType.description}";
        check = {
          # leave the checking to the submodule type merge
          __functor = _self: _x: true;
          isV2MergeCoherent = true;
        };
        merge = {
          __functor =
            self: loc: defs:
            (self.v2 { inherit loc defs; }).value;
          v2 =
            { loc, defs }:
            submoduleType.merge.v2 {
              inherit loc;
              defs = map (def: {
                inherit (def) file;
                value = maybeConvert def;
              }) defs;
            };
        };
      };
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

    Can be used in conjunction with `wlib.dag.topoSort` and `wlib.dag.sortAndUnwrap`

    Note, if the element type is a submodule then the `name` argument
    will always be set to the string "data" since it picks up the
    internal structure of the DAG values. To give access to the
    "actual" attribute name a new submodule argument is provided with
    the name `dagName`.

    The `config.optionname` value from the associated option
    will be normalized such that all items are DAG entries

    If you wish to alter the type, you may provide different options
    to `wlib.dag.dagWith` by updating this type `wlib.dag.dagOf // { strict = false; }`
  */
  dagOf = {
    __functor = self: dagWith (removeAttrs self [ "__functor" ]);
  };

  /**
    Arguments:
    - `settings`:
        - `strict ? true`:
          `false` adds `freeformType = wlib.types.attrsRecursive`
        - `defaultNameFn ? ({ config, name, isDal, ... }@moduleArgs: if isDal then null else name)`:
          Function to compute the default `name` for entries. Recieves the submodule arguments.
        - `dataTypeFn` ? `(elemType: { config, name, isDal, ... }@moduleArgs: elemType)`:
          Can be used if the type of the `data` field needs to depend upon the submodule arguments.
        - `dontConvertFunctions ? false`:
          `true` allows passing function-type submodules as dag entries.
          If your `data` field's type may contain a function, or is a submodule type itself, this should be left as `false`.
        - ...other arguments for `lib.types.submoduleWith` (`modules`, `specialArgs`, etc...)
          Passed through to configure submodules in the DAG entries.

    - `elemType`: `type`
      The type of the DAG entries’ `data` field. You can provide the type, OR an entry for each item.
      In the resulting `config.optionname` value, all items are normalized into entries.

    Notes:
    - `dagWith` accepts an attrset as its first parameter (the `settings`) **before** `elemType`.
    - Setting `strict = false` allows entries to have **unchecked** extra attributes beyond `data`, `name`, `before`, and `after`.
      If your item is a set, and might have a `data` field, you will want to keep `strict = true` to avoid false positives.
    - To add extra type-checked fields, use the `modules` attribute, which is passed through to `submoduleWith`.
      The allowed dag fields will be automatically generated from the base set of modules passed.
    - The `config.optionname` value from the associated option will be normalized so that all items become valid DAG entries.
    - If `elemType` is a submodule, and `dataTypeFn` is not provided, a `dagName` argument will automatically be injected to access the actual attribute name.
  */
  dagWith =
    settings: elemType:
    let
      entry = dagEntryOf settings false elemType;
      attrEquivalent = types.attrsOf entry.type;
    in
    mkOptionType rec {
      name = "dagOf";
      description = "DAG ${entry.extraFieldsMsg}of ${elemType.description}";
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

    Can be used in conjunction with `wlib.dag.topoSort` and `wlib.dag.sortAndUnwrap`

    Note, if the element type is a submodule then the `name` argument
    will always be set to the string "data" since it picks up the
    internal structure of the DAG values. To give access to the
    "actual" attribute name a new submodule argument is provided with
    the name `dagName`.

    The `config.optionname` value from the associated option
    will be normalized such that all items are DAG entries

    If you wish to alter the type, you may provide different options
    to `wlib.dag.dalWith` by updating this type `wlib.dag.dalOf // { strict = false; }`
  */
  dalOf = {
    __functor = self: dalWith (removeAttrs self [ "__functor" ]);
  };

  /**
    Arguments:
    - `settings`:
        - `strict ? true`:
          `false` adds `freeformType = wlib.types.attrsRecursive`
        - `defaultNameFn ? ({ config, name, isDal, ... }@moduleArgs: if isDal then null else name)`:
          Function to compute the default `name` for entries. Recieves the submodule arguments.
        - `dataTypeFn` ? `(elemType: { config, name, isDal, ... }@moduleArgs: elemType)`:
          Can be used if the type of the `data` field needs to depend upon the submodule arguments.
        - `dontConvertFunctions ? false`:
          `true` allows passing function-type submodules as dag entries.
          If your `data` field's type may contain a function, or is a submodule type itself, this should be left as `false`.
        - ...other arguments for `lib.types.submoduleWith` (`modules`, `specialArgs`, etc...)
          Passed through to configure submodules in the DAG entries.

    - `elemType`: `type`
      The type of the DAL entries’ `data` field. You can provide the type, OR an entry for each item.
      In the resulting `config.optionname` value, all items are normalized into entries.

    Notes:
    - `dalWith` accepts an attrset as its first parameter (the `settings`) **before** `elemType`.
    - Setting `strict = false` allows entries to have UNCHECKED extra attributes beyond `data`, `name`, `before`, and `after`.
      If your item is a set, and might have a `data` field, you will want to keep `strict = true` to avoid false positives.
    - To add extra type-checked fields, use the `modules` attribute, which is passed through to `submoduleWith`.
      The allowed dag fields will be automatically generated from the base set of modules passed.
    - The `config.optionname` value from the associated option will be normalized so that all items become valid DAG entries.
    - If `elemType` is a submodule, and `dataTypeFn` is not provided, a `dagName` argument will automatically be injected to access the actual attribute name.
  */
  dalWith =
    settings: elemType:
    let
      entry = dagEntryOf settings true elemType;
      listEquivalent = types.listOf entry.type;
    in
    mkOptionType rec {
      name = "dalOf";
      description = "DAG LIST ${entry.extraFieldsMsg}of ${elemType.description}";
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
    && (if e ? after then isList e.after && all isString e.after else true)
    && (if e ? before then isList e.before && all isString e.before else true)
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
          if isFunction mapIfOk then map mapIfOk sortedDag.result else sortedDag.result
        else
          abort ("Dependency cycle in ${name}: " + toJSON sortedDag);
    in
    result;
}
