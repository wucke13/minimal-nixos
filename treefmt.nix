# treefmt.nix
{ pkgs, ... }:
{
  # Used to find the project root
  projectRootFile = "flake.nix";
  programs.actionlint.enable = true;
  programs.black.enable = true;
  programs.nixfmt.enable = true;
  programs.prettier.enable = true;
}
