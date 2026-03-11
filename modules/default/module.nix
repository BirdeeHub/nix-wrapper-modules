{ wlib, lib, ... }:
{
  imports = [
    wlib.modules.symlinkScript
    wlib.modules.constructFiles
    wlib.modules.makeWrapper
  ];
  config.meta.maintainers = [ wlib.maintainers.birdee ];
}
