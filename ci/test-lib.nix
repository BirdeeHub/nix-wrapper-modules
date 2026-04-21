{
  self,
  lib,
  runCommand,
  pkgs,
  ...
}:
let
  wlib = self.lib;
  inherit (lib) isList;
  toSanitizedJSON =
    value:
    if builtins.isAttrs value then
      builtins.toJSON (
        lib.mapAttrsRecursive (
          path: v:
          if builtins.isFunction v then
            let
              res = builtins.unsafeGetAttrPos (lib.last path) (
                lib.getAttrFromPath (lib.sublist 0 (builtins.length path - 1) path) value
              );
            in
            "<lambda${
              if builtins.isAttrs res then
                ":${res.file or ""}:${toString (res.line or "")}:${toString (res.column or "")}"
              else
                ""
            }>"
          else
            v
        ) value
      )
    else
      builtins.toJSON value;

  recursiveUpdateWithMerging = wlib.recursiveMergeUntil {
    until =
      path: lh: rh:
      !(wlib.isNonDrvAttrs lh) || !(wlib.isNonDrvAttrs rh);
    merge =
      path: left: right:
      if isList left && isList right then left ++ right else right;
  };

  enableForSystem =
    system: value: test:
    let
      platforms =
        if builtins.isList value then
          value
        else
          value.passthru.configuration.meta.platforms or value.config.meta.platforms or value.meta.platforms
            or (wlib.evalModule value).config.meta.platforms;
    in
    if builtins.elem system platforms then test else null;

  test = message: condition: { inherit message condition; };
in
{
  inherit enableForSystem toSanitizedJSON test;
  enableBySystem = enableForSystem pkgs.stdenv.hostPlatform.system;

  isDirectory = path: test "No such directory ${path}" ''[ -d "${path}" ]'';

  isFile = path: test "No such file ${path}" ''[ -f "${path}" ]'';

  notIsFile = path: test "File ${path} should not exist" ''[ ! -f "${path}" ]'';

  fileContains =
    file: pattern: test "Pattern '${pattern}' not found in ${file}" ''grep -q '${pattern}' "${file}"'';

  areEqual =
    expected: actual:
    test (
      if expected == actual then
        "areEqual"
      else
        lib.escapeShellArg "Expected:\n${toSanitizedJSON expected}\nbut got:\n${toSanitizedJSON actual}"
    ) (if expected == actual then "true" else "false");

  /**
    first argument is a string.
    It is the name of the test derivation,
    and default warning message name.

    Second argument is of type `cond` as specified below

    ```nix
    cond = let
      assertion = { condition :: cond, message :: str };
    in str | assertion | [ (str | assertion) ] | (attrsOf cond);
    ```

    TODO: show usage

    you can call .extend on the result to add more items
    It is the same, but without the first name argument
  */
  mkTestDrv =
    name:
    let
      idnt = len: "\n" + wlib.repeatStr "  " len;
      createAssertion =
        prefix:
        { condition, message }:
        let
          loc = prefix ++ [ message ];
          lvl = builtins.length loc;
          renderCond =
            first: c:
            if lib.isStringLike c then
              c
            else if builtins.isList c then
              let
                conds = builtins.filter (v: v.cond or "" != [ ] && v.cond or v != "") c;
              in
              if conds == [ ] then
                ""
              else
                "( " + lib.concatMapStringsSep " ) && ( " (renderCond false) conds + " )"
            else if !first && builtins.isAttrs c then
              createAssertion loc c
            else if first && builtins.isAttrs c then
              helper loc c
            else
              throw "Invalid condition type in assertion, received ${toSanitizedJSON c}";
        in
        if condition == [ ] then
          ""
        else
          "(${idnt (lvl + 1)}${renderCond true condition}${idnt lvl}) || (echo 'failing test at:' ${lib.escapeShellArg "${lib.options.showOption prefix}:"} ${message} >&2; return 1)";
      helper =
        prefix: assertions:
        let
          lvl = builtins.length prefix;
        in
        if
          builtins.isAttrs assertions
          && (
            lib.removeAttrs assertions [
              "condition"
              "message"
            ] != { }
          )
        then
          lib.concatMapAttrsStringSep "${idnt lvl}" (
            n: v:
            if v == [ ] then
              ""
            else
              let
                loc = prefix ++ [ n ];
                text = helper loc v;
              in
              "(${idnt (lvl + 1)}${text}${idnt lvl}) || (echo 'failing test at:' ${lib.escapeShellArg "${lib.options.showOption prefix}:"} ${n} >&2 && ${
                if builtins.length loc == 1 then "exit" else "return"
              } 1)"
          ) assertions
        else
          "(${idnt (lvl + 1)}"
          + lib.concatMapStringsSep "${idnt lvl}) && (${idnt (lvl + 1)}" (
            a: if lib.isStringLike a then "${a}" else createAssertion prefix a
          ) (lib.toList assertions)
          + "${idnt lvl})";
      normArgs =
        args:
        if builtins.isList args then
          { ${name} = args; }
        else if lib.isStringLike args then
          { ${name} = [ args ]; }
        else
          args;
    in
    wlib.makeCustomizable "extend"
      {
        mergeArgs =
          og: new:
          if lib.isFunction new then
            new (normArgs og)
          else
            recursiveUpdateWithMerging (normArgs og) (normArgs new);
      }
      (
        assertions:
        let
          finalText = helper [ ] (normArgs assertions);
        in
        runCommand name { passthru.test = finalText; } ''
          ${finalText}
          mkdir -p $out
        ''
      );
}
