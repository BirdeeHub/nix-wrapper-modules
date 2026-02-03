{ lib, wlib }:
# TODO: Add doc comments for each function (and generate docs from it once it is in wlib.docs)
rec {
  collectOptions = import ./collectOptions.nix lib;

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
      collectOptions
      defaultOptionTransform
      ;
  };

  # TODO: Can people even pass in other types through lib.optionAttrSetToDocList?
  # If not this should take a set with 2 render functions instead of processTypedText,
  # 1 for literalExpression and 1 for literalMD (and if there are other ones I am forgetting?)
  fixupDocValues =
    processTypedText: v:
    if v ? _type && v ? text then
      if lib.isFunction processTypedText then
        processTypedText v
      else if v._type == "literalExpression" then
        "```nix\n${toString v.text}\n```"
      else
        toString v.text
    else if lib.isStringLike v && !builtins.isString v then
      "`<${if v ? name then "derivation ${v.name}" else v}>`"
    else if builtins.isString v then
      v
    else if builtins.isList v then
      map (fixupDocValues processTypedText) v
    else if lib.isFunction v then
      "`<function with arguments ${
        lib.pipe v [
          lib.functionArgs
          (lib.mapAttrsToList (n: v: "${n}${lib.optionalString v "?"}"))
          (builtins.concatStringsSep ", ")
        ]
      }>`"
    else if builtins.isAttrs v then
      builtins.mapAttrs (n: fixupDocValues processTypedText) v
    else
      v;

  wrapperModuleJSON =
    {
      options,
      graph,
      transform ? null,
      includeCore ? true,
      ...
    }:
    lib.pipe
      {
        inherit
          options
          graph
          includeCore
          transform
          ;
      }
      [
        normWrapperDocs
        (fixupDocValues null)
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
