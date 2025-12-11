{ wlib, lib, ... }:
{
  imports = [
    wlib.modules.symlinkScript
    wlib.modules.makeWrapper
  ];
  config.meta.description = lib.mkDefault ''
    This module imports both `wlib.modules.makeWrapper` and `wlib.modules.symlinkScript` for convenience

    ---
  '';
  config.meta.maintainers = lib.mkDefault [ wlib.maintainers.birdee ];
}
