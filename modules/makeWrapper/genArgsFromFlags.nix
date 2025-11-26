{ wlib, lib }:
{
  genArgs =
    f: default-sep: dag:
    wlib.dag.dagToDal (
      builtins.mapAttrs (
        n: v:
        let
          genArgs =
            sep: name: value:
            if lib.isList value then lib.concatMap (v: f true sep name v) value else f false sep name value;
        in
        v // { data = genArgs (if v.sep or null != null then v.sep else default-sep) n v.data; }
      ) dag
    );
  flagDag =
    with lib.types;
    wlib.dag.dagWith
      {
        extraOptions = {
          esc-fn = lib.mkOption {
            type = nullOr (functionTo str);
            default = null;
          };
          sep = lib.mkOption {
            type = nullOr str;
            default = null;
          };
        };
      }
      (
        nullOr (oneOf [
          bool
          wlib.types.stringable
          (listOf wlib.types.stringable)
        ])
      );
}
