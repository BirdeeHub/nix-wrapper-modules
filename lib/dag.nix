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
# It looks nothing like it anymore
{ wlib, lib }:
let
  inherit (builtins)
    isAttrs
    attrValues
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
    mkOption
    optionals
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
    topoSort
    gmap
    dagToDal
    mkDagEntry
    dagNameModule
    ;
  mkDagEntryModule =
    settings: elemType:
    let
      isStrict =
        if isBool (settings.strict or null) then
          lib.warn "dagWith `strict` setting deprecated, set freeformType from within a module passed to the modules argument instead" settings.strict
        else
          true;
      extraOptions =
        if settings ? extraOptions then
          lib.warn
            "Deprecated dagWith/dalWith setting: `extraOptions` set. Use `modules` list instead to provide extra options"
            (if isAttrs (settings.extraOptions or null) then settings.extraOptions else { })
        else
          null;
      dataOptFn =
        if isFunction (settings.dataTypeFn or null) then
          args: { type = settings.dataTypeFn elemType args; }
        else
          _: { type = elemType; };
    in
    wlib.types.specWith {
      specialArgs = settings.specialArgs or { };
      class = settings.class or null;
      description = settings.description or null;
      mainField = settings.mainField or null;
      dontConvertFunctions = settings.dontConvertFunctions or false;
      modules =
        optionals (!isStrict) [ { freeformType = wlib.types.attrsRecursive; } ]
        ++ [
          (mkDagEntry {
            dataOptFn = if isFunction (settings.dataOptFn or null) then settings.dataOptFn else dataOptFn;
            defaultNameFn =
              if isFunction (settings.defaultNameFn or null) then settings.defaultNameFn else null;
            isDal = if isBool (settings.isDal or null) then settings.isDal else false;
          })
        ]
        ++ optionals (elemType.name == "submodule" || elemType.name == "spec") [ dagNameModule ]
        ++ optionals (extraOptions != null) [ { options = filterAttrs (_: v: !isBool v) extraOptions; } ]
        ++ optionals (isList (settings.modules or null)) settings.modules;
    };
in
{
  /**
    Arguments:
    - `settings`:
        - `defaultNameFn ? ({ config, name, isDal, ... }@moduleArgs: if isDal then null else name)`:
          Function to compute the default `name` for entries. Recieves the submodule arguments.
        - `dataTypeFn` ? `(elemType: { config, name, isDal, ... }@moduleArgs: elemType)`:
          Can be used if the type of the `data` field needs to depend upon the submodule arguments.
        - ...other arguments for `wlib.types.specWith` (`modules`, `specialArgs`, etc...)
          Passed through to configure submodules in the DAG entries.

    - `elemType`: `type`
      The type of the DAG entries’ `data` field. You can provide the type, OR an entry for each item.
      In the resulting `config.optionname` value, all items are normalized into entries.

    Notes:
    - `dagWith` accepts an attrset as its first parameter (the `settings`) **before** `elemType`.
    - To add extra type-checked fields, use the `modules` attribute, which is passed through to `wlib.types.specWith`.
      The allowed dag fields will be automatically generated from the base set of modules passed.
    - The `config.optionname` value from the associated option will be normalized so that all items become valid DAG entries.
    - If `elemType` is a `submodule` or `spec`, a `parentName` argument will automatically be injected to access the actual attribute name.
  */
  dagWith =
    settings: elemType: types.attrsOf (mkDagEntryModule (settings // { isDal = true; }) elemType);

  /**
    Arguments:
    - `settings`:
        - `defaultNameFn ? ({ config, name, isDal, ... }@moduleArgs: if isDal then null else name)`:
          Function to compute the default `name` for entries. Recieves the submodule arguments.
        - `dataTypeFn` ? `(elemType: { config, name, isDal, ... }@moduleArgs: elemType)`:
          Can be used if the type of the `data` field needs to depend upon the submodule arguments.
        - ...other arguments for `wlib.types.specWith` (`modules`, `specialArgs`, etc...)
          Passed through to configure submodules in the DAG entries.

    - `elemType`: `type`
      The type of the DAL entries’ `data` field. You can provide the type, OR an entry for each item.
      In the resulting `config.optionname` value, all items are normalized into entries.

    Notes:
    - `dalWith` accepts an attrset as its first parameter (the `settings`) **before** `elemType`.
    - To add extra type-checked fields, use the `modules` attribute, which is passed through to `wlib.types.specWith`.
      The allowed dag fields will be automatically generated from the base set of modules passed.
    - The `config.optionname` value from the associated option will be normalized so that all items become valid DAG entries.
    - If `elemType` is a `submodule` or `spec`, a `parentName` argument will automatically be injected to access the actual attribute name.
  */
  dalWith =
    settings: elemType: types.listOf (mkDagEntryModule (settings // { isDal = false; }) elemType);

  /**
    Arguments:

    ```nix
    {
      dataOptFn, # <- receives the submodule arguments. Returns a set for `lib.mkOption` (`internal = true` will be added unless you set it otherwise)
      defaultNameFn ? { name, isDal, ... }@moduleArgs: if isDal then null else name,
      isDal ? false, # <- added to `config._module.args`
    }:
    ```

    `dataOptFn` receives `config`, `options`, `name`, and `isDal`. Returns a set for `lib.mkOption`

    Creates a module with a `name`, `data`, `before`, and `after` field,
    which can be passed to `wlib.types.specWith` or `wlib.types.spec`,
    to create a spec type which can be used with all the `wlib.dag` functions.
  */
  mkDagEntry =
    {
      dataOptFn,
      defaultNameFn ? { name, isDal, ... }@moduleArgs: if isDal then null else name,
      isDal ? false,
    }@settings:
    { name, isDal, ... }@args:
    {
      config._module.args.isDal = if isBool (settings.isDal or null) then settings.isDal else false;
      options = {
        data = mkOption ({ internal = true; } // dataOptFn args);
        name = mkOption {
          internal = true;
          type = types.nullOr types.str;
          default =
            if isFunction defaultNameFn then
              defaultNameFn args
            else if isDal then
              null
            else
              name;
        };
        before = mkOption {
          internal = true;
          type = with types; listOf str;
          default = [ ];
        };
        after = mkOption {
          internal = true;
          type = with types; listOf str;
          default = [ ];
        };
      };
    };

  /**
    If, when constructing your own DAG type with `mkDagEntry`, your `data` field accepts submodules, you should also supply this module to `specWith`
    in order to set `config.data._module.args.dagName`.

    You would do this because the name argument of that submodule will receive the field it was in,
    not the one from the parent `attrsOf` type.

    If you use `dagWith` or `dalWith`, this is done for you for `submodule` and `spec`.
  */
  dagNameModule =
    { config, name, ... }:
    {
      config.data._module.args.dagName = config.name or name;
    };

  /*
    Takes an attribute set or list containing attrsets with (optional)
    `name`, `before` and `after` fields.

    It then sorts them into a topologically sorted list of
    entries.

    It does not perform any normalization of the entries themselves.

    Internally this function uses the `toposort` function in
    `<nixpkgs/lib/lists.nix>` and it returns the same thing.

    It returns an object which is like a "result"

    Specifically, the result on success is

    ```nix
       { result = [ { name = ?; data = ?; … } … ] }
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
                    { data = "1"; name = "a"; after = [ ]; before = [ ]; }
                    { data = "3"; name = "c"; after = [ ]; before = [ "d" ]; }
                    { data = "2"; name = "b"; after = [ "a" "c" ]; before = [ ]; }
                    { data = "4"; name = "d"; after = [ ]; before = [ "e" ]; }
                    { data = "5"; name = "e"; after = [ ]; before = [ ]; }
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
                    { data = "2"; name = "b"; after = [ "a" "c" ]; before = [ ]; }
                    { data = "3"; name = "c"; after = [ "d" ]; before = [ ]; }
                    { data = "4"; name = "d"; after = [ "b" ]; before = [ ]; }
                  ];
                  loops = [
                    { data = "2"; name = "b"; after = [ "a" "c" ]; before = [ ]; }
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
    Convenience function for resolving a DAG or DAL and getting the result in a sorted list of DAG entries

    Unless you make use of mapIfOk, the result is still a DAL, but sorted.

    Arguments:
    ```nix
    {
      dag,
      name ? "DAG", # for error message
      mapIfOk ? null,
    }
    ```

    Accepts the same types in its dag argument as `wlib.dag.topoSort`.

    But it returns the resulting list directly, and generates an error message if there is a cycle
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
          throw ("Dependency cycle in ${name}: " + toJSON sortedDag);
    in
    result;

  /**
    converts a DAG to a DAL

    Accepts the same types as `wlib.dag.topoSort`.

    It is the normalization function used by `topoSort`
    when the argument is not a list prior to sorting the list.
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
    Determines whether a value is a valid DAG entry (allows extra values)

    Will return true if the item meets the following criteria:

    Has a data field.
    If it has a name field that field is a string.
    If it has a before or after field that field is a list of strings.

    It allows entries to have extra values not mentioned above.
  */
  isEntry =
    e:
    e ? data
    && (if e ? after then isList e.after && all isString e.after else true)
    && (if e ? before then isList e.before && all isString e.before else true)
    && (if e ? name then e.name == null || isString e.name else true);

  /**
    determines whether a value is of the attrset type and all values meet the criteria of `wlib.dag.isEntry`

    Allows entries to have extra values
  */
  isDag = dag: isAttrs dag && all isEntry (attrValues dag);

  /**
    determines whether a value is of the list type and all values meet the criteria of `wlib.dag.isEntry`
  */
  isDal = dal: isList dal && all isEntry dal;

  /**
    Applies a function to each element of the given DAL.

    Requires values to meet the criteria of `wlib.dag.isEntry`
  */
  lmap = f: map (v: v // { data = f v.data; });

  /**
    Applies a function to each element of the given DAG.

    Requires values to meet the criteria of `wlib.dag.isEntry`
  */
  gmap = f: mapAttrs (n: v: v // { data = f n v.data; });

  /**
    wlib.dag.gmap but returns the result as a DAL

    Requires values to meet the criteria of `wlib.dag.isEntry`
  */
  mapDagToDal = f: dag: dagToDal (gmap f dag);

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

  dagOf = lib.warn "wlib.dag.dagOf deprecated. Use wlib.types.dagOf instead." wlib.types.dagOf;
  dalOf = lib.warn "wlib.dag.dalOf deprecated. Use wlib.types.dalOf instead." wlib.types.dalOf;
}
