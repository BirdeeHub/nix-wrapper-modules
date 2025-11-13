{
  config,
  wlib,
  lib,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options.greeting = lib.mkOption {
    type = lib.types.str;
    default = "hello";
    description = "The greeting to use";
  };
  config.package = config.pkgs.hello;
  config.flags = {
    "--greeting" = config.greeting;
  };
}
