{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    xc = {
      url = "github:joerdav/xc";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, xc, ... }:
    let
      pkgsForSystem = system: import nixpkgs {
        inherit system;
        overlays = [
          (final: prev: { xc = xc.packages.${system}.xc; })
        ];
      };
      flakeClosureRefForSystem = { system, pkgs }: (import ./flakeClosureRef.nix {
        pkgs = pkgs;
        lib = nixpkgs.lib;
      });
      listFlakeInputsForSystem = { system, pkgs }: pkgs.writeShellScriptBin "list-flake-inputs" ''
        cat ${((flakeClosureRefForSystem { inherit system pkgs; }) self)}
      '';
      allSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
        system = system;
        pkgs = pkgsForSystem system;
      });
    in
    {
      # Add the flake input reference to the output set so that we can see it in the repl.
      #
      # Load the repl with:
      #   nix repl
      # Inside the repl, load the flake:
      #   :lf .
      # View the derivation:
      #   outputs.flakeInputReference.x86_64-linux
      # Then build it.
      #   :b outputs.flakeInputReference.x86_64-linux
      #
      # The store path will be printed.
      #
      # cat the store path to see the contents. If you inspect the directories, you'll see
      # that the directories contain the source code of all flake inputs.
      flakeInputReference = forAllSystems ({ system, pkgs }: {
        default = ((flakeClosureRefForSystem { inherit system pkgs; }) self);
      });

      # `nix develop` provides a shell containing development tools.
      devShells = forAllSystems ({ system, pkgs }: {
        default = pkgs.mkShell {
          buildInputs = [
            # Bring in xc as an overlay applied within pkgsForSystem.
            # So instead of xc.packages.${system}.xc, we can use pkgs.xc.
            pkgs.xc

            # Ensure that the recursive tree of flake inputs are added to the Nix store.
            # You can list the flake inputs with the `list-flake-inputs` command.
            (listFlakeInputsForSystem { inherit system pkgs; })
          ];
        };
      });
    };
}

