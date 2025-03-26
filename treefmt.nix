# treefmt.nix
{  ... }:
{
  # Used to find the project root
  projectRootFile = "flake.nix";
  programs.black.enable = true;
  programs.nixfmt.enable = true;
  programs.prettier.enable = true;
}
