lib:

let
  # imports
  inherit (builtins) readDir;
  inherit (lib.attrsets) filterAttrs mapAttrs';
  inherit (lib.strings) removeSuffix;

  # generates an attribute set where each name is the filename of a file in pkgs, while the
  # coresponding value is the path to that file

  isNixFile = n: t: lib.strings.hasSuffix ".nix" n && t == "regular";
in
{
  zornlib = {

    # Get a map from file name (with the .nix extension removed) to full path of the .nix file
    # Only considers top-level files
    nixFilesToAttrset =
      dir:
      mapAttrs' (n: _: {
        name = removeSuffix ".nix" n;
        value = dir + "/${n}";
      }) ((filterAttrs isNixFile) (readDir dir));

    # Get a list of all Nix files withing a folder, recursively traversing all its subdirs
    nixFilesToListRecursive =
      dir: lib.lists.filter (lib.strings.hasSuffix ".nix") (lib.filesystem.listFilesRecursive dir);
  };
}
// lib
