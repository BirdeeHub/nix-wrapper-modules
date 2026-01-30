lib:
{
  options ? { },
  transform ? x: [ x ],
}:
let
  # Generate DocBook documentation for a list of packages. This is
  # what `relatedPackages` option of `mkOption` from
  # ../../../lib/options.nix influences.
  #
  # Each element of `relatedPackages` can be either
  # - a string:  that will be interpreted as an attribute name from `pkgs` and turned into a link
  #              to search.nixos.org,
  # - a list:    that will be interpreted as an attribute path from `pkgs` and turned into a link
  #              to search.nixos.org,
  # - an attrset: that can specify `name`, `path`, `comment`
  #   (either of `name`, `path` is required, the rest are optional).
  #
  # NOTE: No checks against `pkgs` are made to ensure that the referenced package actually exists.
  # Such checks are not compatible with option docs caching.
  genRelatedPackages =
    packages: optName:
    let
      unpack =
        p:
        if lib.isString p then
          { name = p; }
        else if lib.isList p then
          { path = p; }
        else
          p;
      describe =
        args:
        let
          title = args.title or null;
          name = args.name or (lib.concatStringsSep "." args.path);
        in
        ''
          - [${lib.optionalString (title != null) "${title} aka "}`pkgs.${name}`](
              https://search.nixos.org/packages?show=${name}&sort=relevance&query=${name}
            )${lib.optionalString (args ? comment) "\n\n  ${args.comment}"}
        '';
    in
    lib.concatMapStrings (p: describe (unpack p)) packages;
in
lib.pipe options [
  lib.optionAttrSetToDocList
  (builtins.concatMap transform)
  (map (
    opt:
    opt
    // lib.optionalAttrs (opt ? relatedPackages && opt.relatedPackages != [ ]) {
      relatedPackages = genRelatedPackages opt.relatedPackages opt.name;
    }
  ))
]
