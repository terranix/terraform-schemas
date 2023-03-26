{ lib, terranix, terranixConfiguration, ... }:
with lib;
let
  test = { label, run, success ? true, output ? null, outputFile ? null, skip ? false }:
    let
      assertion = if success then "assert_success" else "assert_failure";
      out =
        if output != null then
          "assert_output ${escapeShellArg output}"
        else if outputFile != null then
          "cat ${outputFile} | assert_output"
        else null;
    in
    ''
      @test "${label}" {
      ${optionalString skip "skip"}
      run ${run}
      ${assertion}
      ${optionalString (out != null) out }
      }
    '';

  #(testTerranixConfig {
  #  label = "config test";
  #  config = { resource.aws.enable = true; };
  #  compareConfig = { resource.aws = { enable = true; }; };
  #})
  testTerranixConfiguration = { label, config, compareConfig, skip ? false }:
    test {
      inherit label skip;
      run = "diff -u ${
        terranixConfiguration { system = "x86_64-linux"; modules = [config]; }
      } ${
        terranixConfiguration { system = "x86_64-linux"; modules = [ compareConfig ]; }
      }";
    };
in
{
  test = test;
  testTerranixConfiguration = testTerranixConfiguration;
}
