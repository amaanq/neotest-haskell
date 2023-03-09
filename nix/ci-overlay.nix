# Add flake.nix test inputs as arguments here
{
  self,
  plenary-nvim,
  nvim-treesitter,
  neotest,
}: final: prev:
with final.lib;
with final.stdenv; let
  nvim-nightly = final.neovim-nightly;

  plenary-plugin = final.pkgs.vimUtils.buildVimPluginFrom2Nix {
    name = "plenary.nvim";
    src = plenary-nvim;
  };

  treesitter-plugin = final.pkgs.vimUtils.buildVimPluginFrom2Nix {
    name = "treesitter-nvim";
    src = nvim-treesitter;
  };

  neotest-plugin = final.pkgs.vimUtils.buildVimPluginFrom2Nix {
    name = "neotest";
    src = neotest;
  };

  mkPlenaryTest = {
    nvim ? final.neovim-unwrapped,
    name,
  }: let
    nvim-wrapped = final.pkgs.wrapNeovim nvim {
      configure = {
        customRC = ''
          lua << EOF
          vim.cmd('runtime! plugin/plenary.vim')
          EOF
        '';
        packages.myVimPackage = {
          start = [
            final.neotest-haskell-dev
            plenary-plugin
            treesitter-plugin
            neotest-plugin
          ];
        };
      };
    };
  in
    mkDerivation {
      inherit name;

      phases = [
        "unpackPhase"
        "buildPhase"
        "checkPhase"
      ];

      src = self;

      doCheck = true;

      buildInputs = with final; [
        nvim-wrapped
        makeWrapper
      ];

      buildPhase = ''
        mkdir -p $out
        cp -r tests $out
      '';

      checkPhase = ''
        export HOME=$(realpath .)
        export TEST_CWD=$(realpath $out/tests)
        cd $out
        nvim --headless --noplugin -c "PlenaryBustedDirectory tests {nvim_cmd = 'nvim'}"
      '';
    };
in {
  ci = mkPlenaryTest {name = "ci";};
}
