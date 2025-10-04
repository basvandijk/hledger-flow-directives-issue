{
  description = "Van Dijk Colijn Family Finances";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    all-cabal-hashes = {
      url = "github:commercialhaskell/all-cabal-hashes/hackage";
      flake = false;
    };
    hledger-src = {
      url = "github:simonmichael/hledger";
      flake = false;
    };
    hledger-flow-src = {
      url = "github:apauley/hledger-flow/67f1776b69e312576e761e6a292688939462612f";

      # The issue doesn't occur when using the parent of ^
      # url = "github:apauley/hledger-flow/c9217e2a1ae44f8258e884d3e56782826363bae0";

      flake = false;
    };
  };
  outputs = { self, nixpkgs, flake-utils, all-cabal-hashes, hledger-src, hledger-flow-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (_self: _super: { inherit all-cabal-hashes; }) ];
        };

        haskellPackages = pkgs.haskellPackages.override {
          overrides = hself: hsuper:
            let
              hledger-pkg = name: hsuper.callCabal2nix name "${hledger-src}/${name}" { };
              # This is to copy the symlinks in hledger/embeddedfiles/
              hledger-src-fix = pkgs.runCommand "hledger-src" { }
                "cp -rL ${hledger-src}/hledger/ $out";
            in
            {
              hledger = hsuper.callCabal2nix "hledger" hledger-src-fix { };
              hledger-lib = hledger-pkg "hledger-lib";
              hledger-ui = hledger-pkg "hledger-ui";
              hledger-web = pkgs.haskell.lib.dontCheck (hledger-pkg "hledger-web");
              hledger-flow = hsuper.callCabal2nix "hledger-flow" hledger-flow-src { };

              base-compat = hsuper.base-compat_0_14_1;
              base-compat-batteries = hsuper.base-compat-batteries_0_14_1;
              time-compat = pkgs.haskell.lib.dontCheck hsuper.time-compat_1_9_8;
              tls = pkgs.haskell.lib.dontCheck hsuper.tls;
              encoding = hsuper.encoding_0_10_2;
              system-fileio = pkgs.haskell.lib.dontCheck hsuper.system-fileio;
              haddock-library = pkgs.haskell.lib.doJailbreak hsuper.haddock-library;
              typst = pkgs.haskell.lib.dontCheck hsuper.typst;
              hashtables = hsuper.hashtables_1_4_2;
            };
        };

        packages = {
          hledger = pkgs.haskell.lib.justStaticExecutables haskellPackages.hledger;
          hledger-ui = pkgs.haskell.lib.justStaticExecutables haskellPackages.hledger-ui;
          hledger-web = pkgs.haskell.lib.compose.overrideCabal
            (_drv: { disallowGhcReference = false; })
            (pkgs.haskell.lib.justStaticExecutables haskellPackages.hledger-web);
          hledger-flow = pkgs.haskell.lib.justStaticExecutables haskellPackages.hledger-flow;
        };
      in
      {
        inherit packages;

        devShells.default = pkgs.mkShell {
          LEDGER_FILE = "./all-years.journal";
          packages = pkgs.lib.attrValues packages ++ [
            # Use GNU tools such that we get reproducible preprocess scripts
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.gnused
          ];
        };
        formatter = pkgs.writeShellScriptBin "formatter" ''
          if [[ $# = 0 ]]; then set -- .; fi
          exec "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt" "$@"
        '';
      }
    );
}
