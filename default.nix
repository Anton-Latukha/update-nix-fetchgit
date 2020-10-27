{ pkgs ? import <nixpkgs> { }, compiler ? null, hoogle ? true }:

let
  src = pkgs.nix-gitignore.gitignoreSource [ ] ./.;

  compiler' = if compiler != null then
    compiler
  else
    "ghc" + pkgs.lib.concatStrings
    (pkgs.lib.splitVersion pkgs.haskellPackages.ghc.version);

  # Any overrides we require to the specified haskell package set
  haskellPackages = with pkgs.haskell.lib;
    pkgs.haskell.packages.${compiler'}.override {
      overrides = self: super:
        {
          prettyprinter = self.prettyprinter_1_7_0; # at least 1.7
          hnix = overrideSrc super.hnix {
            src = pkgs.fetchFromGitHub {
              owner = "expipiplus1";
              repo = "hnix";
              rev =
                "9bbb9f8d4a22f88dce5004996c57b9a48eacbf4f"; # update-nix-fetchgit
              sha256 = "1xwcf3mih7zrc5dfc75g2wssl270aifsz4i00maqrw4w6bwaff0k";
            };
          };
          data-fix = self.data-fix_0_3_0;
          optparse-generic = self.optparse-generic_1_4_4;
          optparse-applicative = self.optparse-applicative_0_16_0_0;
        } // pkgs.lib.optionalAttrs hoogle {
          ghc = super.ghc // { withPackages = super.ghc.withHoogle; };
          ghcWithPackages = self.ghc.withPackages;
        };
    };

  # Any packages to appear in the environment provisioned by nix-shell
  extraEnvPackages = with haskellPackages; [ pkgs.nix-prefetch-git ];

  # Generate a haskell derivation using the cabal2nix tool on `update-nix-fetchgit.cabal`
  drv = haskellPackages.callCabal2nix "update-nix-fetchgit" src { };

  # Insert the extra environment packages into the environment generated by
  # cabal2nix
  envWithExtras = pkgs.lib.overrideDerivation drv.env (attrs:
    {
      buildInputs = attrs.buildInputs ++ extraEnvPackages;
    } // pkgs.lib.optionalAttrs hoogle {
      shellHook = attrs.shellHook + ''
        export HIE_HOOGLE_DATABASE="$(cat $(${pkgs.which}/bin/which hoogle) | sed -n -e 's|.*--database \(.*\.hoo\).*|\1|p')"
      '';
    });

in drv // { env = envWithExtras; }
