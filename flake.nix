{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    hercules-ci-effects = {
      url = "github:hercules-ci/hercules-ci-effects";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bats-support = {
      url = "github:bats-core/bats-support";
      flake = false;
    };
    bats-assert = {
      url = "github:bats-core/bats-assert";
      flake = false;
    };
    terranix.url = "github:terranix/terranix";
  };

  outputs = inputs@{ bats-support, bats-assert, terranix, ... }:
    let
      system = "x86_64-linux";
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, config, ... }: {
      systems = [ "x86_64-linux" ];
      imports = [ inputs.hercules-ci-effects.flakeModule ];

      perSystem = { pkgs, config, ... }: {
        legacyPackages.generateSchema = pkgs.callPackage ./generator.nix { };

        packages = builtins.mapAttrs (provider: _: config.legacyPackages.generateSchema [ provider ]) pkgs.terraform-providers.actualProviders // {
          all-schemas = config.legacyPackages.generateSchema (builtins.attrNames pkgs.terraform-providers.actualProviders);
        };

        # nix run ".#test"
        apps.test =
          let
            bats-lib = import ./tests/nix-bats-lib.nix {
              inherit (pkgs) lib;
              terranix = terranix.${system}.terranix;
              terranixConfiguration = terranix.lib.terranixConfiguration;
            };
            tests = import ./tests {
              inherit pkgs;
              inherit (pkgs) lib;
              inherit (bats-lib) test testTerranixConfiguration;
            };
            testFile = pkgs.writeText "test" ''
              load '${bats-support}/load.bash'
              load '${bats-assert}/load.bash'
              ${pkgs.lib.concatStringsSep "\n" tests}
            '';
          in
          {
            type = "app";
            program = toString (pkgs.writeShellScript "test" ''
              set -e
              echo "running terranix schema tests" | ${pkgs.boxes}/bin/boxes -d ian_jones -a c
              ${pkgs.bats}/bin/bats ${testFile}
            '');
          };
      };

      hercules-ci.flake-update = {
        enable = true;
        autoMergeMethod = "rebase";
        # Update  everynight at midnight
        when = {
          hour = [ 0 ];
          minute = 0;
        };
      };

      herculesCI = herculesCI: {
        onPush.default.outputs.effects.dump-to-branch = withSystem config.defaultEffectSystem ({ pkgs, config, hci-effects, ... }:
          hci-effects.runIf (herculesCI.config.repo.branch == "master") (hci-effects.gitWriteBranch {
            git.checkout.remote.url = herculesCI.config.repo.remoteHttpUrl;
            git.checkout.forgeType = "github";
            git.checkout.user = "x-access-token";
            git.update.branch = "schemas";
            contents = pkgs.runCommand "all-schemas-no-link" { } ''
              mkdir "$out" 
              cp ${config.packages.all-schemas}/* "$out";
            '';
          }));
      };
    });
}
