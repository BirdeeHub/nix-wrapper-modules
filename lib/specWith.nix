# source: https://github.com/NixOS/nixpkgs/blob/d93db1271e961c481d3283a0831f426822303322/lib/types.nix#L1214
# Modified submoduleWith type

# This type is for making options which are either an item, or a set with the item in it.
# It will auto-normalize the values into the set form on merge.
lib:
let
  name = "spec";
  specWith =
    {
      modules,
      specialArgs ? { },
      class ? null,
      description ? null,
      mainField ? null,
      dontConvertFunctions ? false,
    }@attrs:
    let
      inherit (builtins)
        intersectAttrs
        isAttrs
        isString
        attrNames
        length
        concatStringsSep
        all
        elem
        head
        ;
      inherit (lib)
        mkOrder
        mkOptionType
        isFunction
        types
        optionalString
        mkOptionDefault
        last
        optionalAttrs
        filterAttrs
        ;
      inherit (lib.modules) evalModules;
      inherit (types)
        noCheckForDocsModule
        optionDescriptionPhrase
        defaultFunctor
        ;
      allModules =
        defs:
        map (
          { value, file }:
          if isAttrs value then
            {
              _file = file;
              config = value;
            }
          else
            {
              _file = file;
              imports = [ value ];
            }
        ) defs;

      base = evalModules {
        inherit class specialArgs;
        modules = [ { _module.args.name = mkOptionDefault "‹name›"; } ] ++ modules;
      };
      baseNoCheck = base.extendModules { modules = [ noCheckForDocsModule ]; };

      freeformType = base._module.freeformType;

      main_field =
        if isString mainField then
          mainField
        else
          let
            withoutDefaults = attrNames (filterAttrs (n: v: !(v.isDefined or true)) baseNoCheck.options);
          in
          assert
            length withoutDefaults == 1
            || throw ''
              If mainField is not set, you must have exactly 1 option without a default value.
              If it had more than 1, conversion would not be possible.

              Consider using a submodule type instead.

              You have the following fields without default values:
              `${concatStringsSep "`, `" withoutDefaults}`
            '';
          head withoutDefaults;
      # returns true if already the submodule type and false if not
      checkMergeDef =
        def:
        if dontConvertFunctions && isFunction def.value then
          true
        else if baseNoCheck._module.freeformType or null != null then
          isAttrs def.value && def.value ? "${main_field}"
        else
          isAttrs def.value
          && all (k: elem k (attrNames baseNoCheck.options)) (attrNames def.value)
          && def.value ? "${main_field}";
      # converts if not already the submodule type
      maybeConvert =
        def:
        if checkMergeDef def then
          def.value
        else
          { ${main_field} = if def ? priority then mkOrder def.priority def.value else def.value; };

      typeMergeMatching =
        lhs: rhs: attr: err:
        if lhs.${attr} == null then
          rhs.${attr}
        else if rhs.${attr} == null then
          lhs.${attr}
        else if lhs.${attr} == rhs.${attr} then
          lhs.${attr}
        else
          throw "A specWith option is declared multiple times with conflicting ${attr} values${
            optionalString (err != null) " "
          }${toString err}";

    in
    mkOptionType {
      inherit name;
      descriptionClass = "composite";
      description =
        if description != null then
          description
        else if baseNoCheck._module.freeformType ? description then
          "open ${name} of ${
            optionDescriptionPhrase (
              class: class == "noun" || class == "composite"
            ) baseNoCheck._module.freeformType
          } with main field: `${main_field}` of ${
            optionDescriptionPhrase (class: class == "noun" || class == "composite") (
              baseNoCheck.${main_field}.type or "<unknown>"
            )
          }"
        else
          "${name} with main field: `${main_field}` of ${
            optionDescriptionPhrase (class: class == "noun" || class == "composite") (
              baseNoCheck.${main_field}.type or "<unknown>"
            )
          }";
      check = {
        __functor = _self: _: true;
        isV2MergeCoherent = true;
      };
      merge = {
        __functor =
          self: loc: defs:
          (self.v2 { inherit loc defs; }).value;
        v2 =
          { loc, defs }:
          let
            definitions = map (def: {
              inherit (def) file;
              value = maybeConvert def;
            }) defs;
            configuration = base.extendModules {
              modules = [ { _module.args.name = last loc; } ] ++ allModules definitions;
              prefix = loc;
            };
          in
          {
            headError = null;
            value = configuration.config;
            valueMeta = { inherit configuration; };
          };
      };
      emptyValue = {
        value = { };
      };
      getSubOptions =
        prefix:
        let
          docsEval = baseNoCheck.extendModules { inherit prefix; };
          # Intentionally shadow the freeformType from the possibly *checked*
          # configuration. See `noCheckForDocsModule` comment.
          inherit (docsEval._module) freeformType;
        in
        docsEval.options
        // optionalAttrs (freeformType != null) {
          # Expose the sub options of the freeform type. Note that the option
          # discovery doesn't care about the attribute name used here, so this
          # is just to avoid conflicts with potential options from the submodule
          _freeformOptions = freeformType.getSubOptions prefix;
        };
      getSubModules = modules;
      substSubModules =
        m:
        specWith (
          attrs
          // {
            modules = m;
          }
        );
      nestedTypes = optionalAttrs (freeformType != null) {
        elemType =
          baseNoCheck.options.${main_field}.type
            or (throw "Unable to find main field type for a specWith option!");
        freeformType = freeformType;
      };
      functor = defaultFunctor name // {
        type = specWith;
        payload = {
          inherit
            modules
            class
            specialArgs
            description
            dontConvertFunctions
            mainField
            ;
        };
        binOp = lhs: rhs: {
          class =
            typeMergeMatching lhs rhs "class"
              "\"${toString lhs.class}\" and \"${toString rhs.class}\".";
          mainField =
            typeMergeMatching lhs rhs "mainField"
              "\"${toString lhs.mainField}\" and \"${toString rhs.mainField}\".";
          description = typeMergeMatching lhs rhs "description" null;
          dontConvertFunctions = typeMergeMatching lhs rhs "dontConvertFunctions" null;
          modules = lhs.modules ++ rhs.modules;
          specialArgs =
            let
              intersecting = intersectAttrs lhs.specialArgs rhs.specialArgs;
            in
            if intersecting == { } then
              lhs.specialArgs // rhs.specialArgs
            else
              throw "A specWith option is declared multiple times with the same specialArgs \"${toString (attrNames intersecting)}\"";
        };
      };
    };
in
specWith
