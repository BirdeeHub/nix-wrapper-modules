{
  pkgs,
  self,
  ...
}:
let
  testfunctor = self.lib.makeCustomizable "test" { } (v: { value = v; }) { some = "args"; };

  testfunctor2 = testfunctor.test (lp: {
    more = lp.some;
  });
  testfunctor3 = testfunctor.test (lp: {
    more = "with overriding";
  });
  testfunctor4 = testfunctor3.test { again = "testing"; };
in
pkgs.runCommand "makeCustomizable-test" { } ''

  if [ "${testfunctor.value.some}" != "args" ]; then
    echo "FAILURE: makeCustomizable test failed (some = args)"
    exit 1
  fi

  if [ "${testfunctor2.value.some}" != "args" ] || [ "${testfunctor2.value.more}" != "args" ]; then
    echo "FAILURE: makeCustomizable test 2 failed (some = args, more = args)"
    exit 1
  fi

  if [ "${testfunctor3.value.some}" != "args" ] || [ "${testfunctor3.value.more}" != "with overriding" ]; then
    echo "FAILURE: makeCustomizable test 3 failed (some = args, more = with overriding)"
    exit 1
  fi

  if [ "${testfunctor4.value.some}" != "args" ] || [ "${testfunctor4.value.more}" != "with overriding" ] || [ "${testfunctor4.value.again}" != "testing" ]; then
    echo "FAILURE: makeCustomizable test 4 failed (some = args, more = with overriding, again = testing)"
    exit 1
  fi

  echo "SUCCESS: makeCustomizable test passed (including multi-level chaining)"
  touch $out
''
