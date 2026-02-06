{ lib, wlib }:
# TODO: Add doc comments for each function (and generate docs from it once it is in wlib.docs)
rec {
  # TODO: This might not be robust enough?
  # Maybe check for pairings with all the regular suboptions of _module
  # Also, should it automatically add relatedPackages to some options somehow?
  # Technically users can do that themselves with option merging within the modules,
  # but should we try here? Could be nice?
  defaultOptionTransform = x: if builtins.elem "_module" x.loc then [ ] else [ x ];

  normWrapperDocs = import ./normopts.nix {
    inherit
      wlib
      lib
      defaultOptionTransform
      ;
  };

  fixupDocValues =
    {
      processTypedText ? v: v,
    }@opts:
    v:
    if v ? _type && v ? text then
      if lib.isFunction processTypedText then
        processTypedText v
      else
        throw "wlib.docs.fixupDocValues: processTypedText passed to first argument must be a function"
    else if lib.isStringLike v && !builtins.isString v then
      "`<${if v ? name then "derivation ${v.name}" else v}>`"
    else if builtins.isString v then
      v
    else if builtins.isList v then
      map (fixupDocValues opts) v
    else if lib.isFunction v then
      "`<function with arguments ${
        lib.pipe v [
          lib.functionArgs
          (lib.mapAttrsToList (n: v: "${n}${lib.optionalString v "?"}"))
          (builtins.concatStringsSep ", ")
        ]
      }>`"
    else if builtins.isAttrs v then
      builtins.mapAttrs (_: fixupDocValues opts) v
    else
      v;

  wrapperModuleJSON =
    {
      options,
      transform ? null,
      includeCore ? true,
      prefix ? false,
      ...
    }:
    lib.pipe
      {
        inherit
          options
          includeCore
          transform
          prefix
          ;
      }
      [
        normWrapperDocs
        (fixupDocValues { })
        builtins.toJSON
        builtins.unsafeDiscardStringContext
      ];

  # TODO: should have a warning for missing descriptions
  # and also a warnings as errors setting
  wrapperModuleMD = import ./rendermd.nix {
    inherit
      wlib
      lib
      normWrapperDocs
      fixupDocValues
      ;
  };
}
