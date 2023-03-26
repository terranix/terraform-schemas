{ pkgs, lib, test, testTerranixConfiguration, ... }:
with lib;
[

  (testTerranixConfiguration {
    label = "config test";
    config = { resource.aws.enable = true; };
    compareConfig = { resource.aws = { enable = true; }; };
  })

  (testTerranixConfiguration {
    label = "config test (should fail)";
    config = { resource.aws.enable = true; };
    compareConfig = { resource.aws = { enable = false; }; };
    skip = true;
  })

]
