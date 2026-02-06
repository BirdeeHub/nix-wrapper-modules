{
  wlib,
  lib,
  normWrapperDocs,
  fixupDocValues,
}:
# TODO: figure out how to simplify these options quite a bit.
# Or maybe just a little bit but then have a helper module which wraps it?
{
  options,
  includeCore ? true,
  transform ? null,
  prefix ? false,
  nameFromModule ?
    { file, ... }:
    lib.removeSuffix "/module.nix" (lib.removePrefix "${wlib.modulesPath}/" (toString file)),
  moduleStartsOpen ? i: mod: i == 1,
  descriptionStartsOpen ?
    type: i: mod:
    i == 1,
  descriptionIncluded ?
    type: i: mod:
    if type == "pre" then true else i == 1,
  extraModuleNotes ?
    i:
    { maintainers, ... }:
    lib.optionalString (maintainers != [ ] && i == 1) (
      "This module is made possible by: "
      + builtins.concatStringsSep ", " (
        map (v: "[${v.name}](https://github.com/${v.github})") maintainers
      )
    ),
  declaredBy ?
    { declarations, ... }:
    let
      linkDest =
        v:
        if lib.hasPrefix wlib.modulesPath v then
          "https://github.com/BirdeeHub/nix-wrapper-modules/blob/main"
          + lib.removePrefix wlib.modulesPath (toString v)
        else
          toString v;
      linkName = v: lib.removeSuffix "/module.nix" (lib.removePrefix "${wlib.modulesPath}/" (toString v));
    in
    builtins.concatStringsSep "\n" (map (v: "- [${linkName v}](${linkDest v})") declarations),
  ...
}:
let
  normed =
    fixupDocValues
      {
        processTypedText =
          v: if v._type == "literalExpression" then "```nix\n${toString v.text}\n```" else toString v.text;
      }
      (normWrapperDocs {
        inherit
          options
          transform
          prefix
          includeCore
          ;
      });
  mkOptField =
    opt: n: desc:
    lib.optionalString (opt ? "${n}" && lib.isStringLike opt.${n}) (
      lib.optionalString (desc != "") "${desc}\n" + "${opt.${n}}\n\n"
    );
  renderOption = opt: ''
    ## `${lib.options.showOption (opt.loc or [ ])}`

    ${mkOptField opt "description" ""}${mkOptField opt "relatedPackages" "Related packages:\n"}${
      mkOptField opt "type" "Type:${lib.optionalString (opt.readOnly or false == true) " (read-only)"}"
    }${mkOptField opt "default" "Default:"}${mkOptField opt "example" "Example:"}${
      lib.optionalString (opt.declarations or [ ] != [ ]) ''
        Declared by:

        ${declaredBy opt}

      ''
    }
  '';
  renderModule =
    i: mod:
    let
      moduleNotes = extraModuleNotes i mod;
    in
    lib.optionalString (mod.visible or [ ] != [ ]) ''
      ## ${nameFromModule mod}
      ${lib.optionalString (builtins.isString moduleNotes && moduleNotes != "") "\n${moduleNotes}\n"}
      ${lib.optionalString (mod.description.pre or "" != "" && descriptionIncluded "pre" i mod) ''
        <details${if descriptionStartsOpen "pre" i mod then " open" else ""}>
          <summary></summary>

        ${mod.description.pre}

        </details>

      ''}
      ${lib.optionalString (mod.visible or [ ] != [ ]) ''
        <details${if moduleStartsOpen i mod then " open" else ""}>
          <summary></summary>

        ${lib.pipe mod.visible [
          (map renderOption)
          (builtins.concatStringsSep "\n\n")
        ]}

        </details>
      ''}
      ${lib.optionalString (mod.description.post or "" != "" && descriptionIncluded "post" i mod) ''

        <details${if descriptionStartsOpen "post" i mod then " open" else ""}>
          <summary></summary>

        ${mod.description.post}

        </details>
      ''}
    '';
in
builtins.unsafeDiscardStringContext (
  builtins.concatStringsSep "\n\n" (lib.imap1 renderModule normed)
)
