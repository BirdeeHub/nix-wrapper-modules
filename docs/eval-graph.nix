{
  pkgs,
  wlib,
  rootPath,
}:
module:
let
  grapherpath = ./eval-graph.nix;
  evaled = wlib.evalModules {
    modules = [
      {
        _file = grapherpath;
        _module.check = false;
      }
      {
        _file = grapherpath;
        imports = [ module ];
        key = "NEWDOCS";
      }
      {
        _file = grapherpath;
        inherit pkgs;
      }
    ];
  };

  stripStore = path: (pkgs.lib.removePrefix "/" (pkgs.lib.removePrefix "${rootPath}" path));

  cleanNodes =
    node:
    let
      cleaned = builtins.removeAttrs (
        node
        // {
          key = stripStore node.key;
        }
      ) [ "disabled" ];
    in
    cleaned
    // {
      imports = map cleanNodes cleaned.imports;
    };

  flattenGraph =
    let
      flatten = node: [ node ] ++ builtins.concatLists (map flatten node.imports);
    in
    graph: builtins.concatLists (map flatten (map cleanNodes graph));

  filtered = builtins.filter (v: v.key == "NEWDOCS") evaled.graph;
  docimport =
    let
      res = (builtins.head filtered).imports;
    in
    if (builtins.match ".*:anon-[0-9]+" (builtins.head res).key) != null then
      (builtins.head res).imports
    else
      res;

  flattened = flattenGraph docimport;

  stripAnon =
    node:
    node
    // {
      key =
        let
          matchres = builtins.match "(.*):anon-[0-9]+" node.key;
        in
        if matchres != null then builtins.head matchres else node.key;
    };
in
[ (stripAnon (builtins.head flattened)) ]
++ (
  if flattened != [ ] then builtins.tail flattened else throw ("BLEH2" + (builtins.toJSON filtered))
)
