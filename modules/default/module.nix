{ wlib, lib, ... }:
{
  imports = [
    wlib.modules.symlinkScript
    wlib.modules.makeWrapper
  ];
  config.meta.description = lib.mkDefault ''
    This module imports both `wlib.modules.makeWrapper` and `wlib.modules.symlinkScript` for convenience

    ## `wlib.modules.makeWrapper`

    An implementation of the `makeWrapper` interface via type safe module options.

    Allows you to choose one of several underlying implementations of the `makeWrapper` interface.

    Wherever the type includes `DAG` you can mentally substitute this with `attrsOf`

    Wherever the type includes `DAL` or `DAG list` you can mentally substitute this with `listOf`

    However they also take items of the form `{ data, name ? null, before ? [], after ? [] }`

    This allows you to specify that values are added to the wrapper before or after another value.

    The sorting occurs across ALL the options, thus you can target items in any `DAG` or `DAL` within this module from any other `DAG` or `DAL` option within this module.

    The `DAG`/`DAL` entries in this module also accept an extra field, `esc-fn ? null`

    If defined, it will be used instead of the value of `options.escapingFunction` to escape that value.

    ## `wlib.modules.symlinkScript`

    Adds extra options compared to the default `symlinkScript` option value.

    ---
  '';
  config.meta.maintainers = lib.mkDefault [ wlib.maintainers.birdee ];
}
