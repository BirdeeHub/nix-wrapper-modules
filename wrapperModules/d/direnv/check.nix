{
  lib,
  callPackage,
  tlib,
  self,
  ...
}@args:
let
  inherit (tlib) test enableBySystem areEqual;
in
builtins.mapAttrs (_: v: enableBySystem self.wrappers.direnv v) (
  lib.fix (self: {
    "1" = callPackage ./check1.nix args;
    "2" = callPackage ./check2.nix args;
    "3" = callPackage ./check3.nix args;
    "4" = self."1".extend {
      moretests = {
        "another test" = "echo hello";
        "another test2" = "echo world";
      };
      outer = {
        inner = test "should have echoed 'hi'" "echo hi";
        inner2 = test "should have echoed 'hi again'" { something = "echo 'hi again'"; };
        inner3 = test "should have echoed 'woot'" (test "should have echoed 'woot'" "echo 'woot woot'");
      };
      zzz = [
        (test "another test" {
          like.this.too = "echo wtf1";
        })
      ];
    };
    "5" = self."4".extend [
      (test "well... so... it" {
        can.be.nested.like.this.too = [
          (areEqual 2 2)
          (areEqual
            {
              a = 1;
              b = 2;
              c = 3;
              inherit enableBySystem;
            }
            {
              a = 1;
              b = 2;
              c = 3;
              inherit enableBySystem;
            }
          )
        ];
      })
      (test "is" {
        a.bit.strange = "echo 'but it completed the loop nicely'";
      })
    ];
  })
)
