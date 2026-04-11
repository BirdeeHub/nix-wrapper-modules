{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options.will-cite = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Accept GNU Parallels citation policy: <https://www.gnu.org/software/parallel/parallel_design.html#citation-notice>
    '';
  };
  config.flags."--will-cite" = config.will-cite;
  config.package = lib.mkDefault pkgs.parallel-full;
  config.meta.maintainers = [ wlib.maintainers.xavwe ];
}
