{
  description = "A Neotest adapter for Haskell.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    plenary-nvim = {
      url = "github:nvim-lua/plenary.nvim";
      flake = false;
    };

    neotest = {
      url = "github:nvim-neotest/neotest";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-utils,
    neovim-nightly-overlay,
    pre-commit-hooks,
    plenary-nvim,
    neotest,
    ...
  }: let
    name = "neotest-haskell";

    supportedSystems = [
      "aarch64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
      "x86_64-linux"
    ];

    ci-overlay = import ./nix/ci-overlay.nix {inherit (inputs) self plenary-nvim neotest;};

    nvim-plugin-overlay = import ./nix/nvim-plugin-overlay.nix {
      inherit name;
      inherit self;
    };
  in
    flake-utils.lib.eachSystem supportedSystems (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          ci-overlay
          nvim-plugin-overlay
          neovim-nightly-overlay.overlay
        ];
      };

      pre-commit-check = pre-commit-hooks.lib.${system}.run {
        src = self;
        hooks = {
          alejandra.enable = true;
          stylua.enable = true;
          lua-ls.enable = true;
          editorconfig-checker.enable = true;
          markdownlint.enable = true;
        };
        settings = {
          lua-ls.config = {
            Lua = {
              diagnostics = {
                globals = [
                  "vim"
                  "describe"
                  "it"
                  "assert"
                ];
                libraryFiles = "Disable";
                disable = [
                  "duplicate-set-field"
                ];
              };
              workspace = {
                library = with pkgs; [
                  "${neovim-nightly}/share/nvim/runtime/lua"
                  "${plenary-plugin}/lua"
                  "${nvim-treesitter-plugin}/lua"
                  "${neotest-plugin}/lua"
                ];
                checkThirdParty = false;
                ignoreDir = [
                  ".git"
                  ".github"
                  ".direnv"
                  "result"
                  "nix"
                  "doc"
                  "tests" # neotest's types are not well-defined
                ];
              };
              runtime.version = "LuaJIT";
            };
          };
        };
      };

      devShell = pkgs.mkShell {
        name = "neotest-haskell devShell";
        inherit (pre-commit-check) shellHook;
        buildInputs =
          (with pkgs; [
            zlib
          ])
          ++ (with pre-commit-hooks.packages.${system}; [
            alejandra
            lua-language-server
            stylua
            editorconfig-checker
            markdownlint-cli
          ]);
      };

      docgen = pkgs.callPackage ./nix/docgen.nix {};
    in {
      devShells = {
        default = devShell;
        inherit devShell;
      };

      packages = rec {
        default = nvim-plugin;
        nvim-plugin = pkgs.neotest-haskell-dev;
        inherit docgen;
      };

      checks = {
        inherit pre-commit-check;
        inherit
          (pkgs)
          nvim-stable-test
          nvim-nightly-test
          ;
      };
    })
    // {
      overlays = {
        inherit nvim-plugin-overlay;
        default = nvim-plugin-overlay;
      };
    };
}
