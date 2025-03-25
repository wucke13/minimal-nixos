{
  lib,
  writeScriptBin,
  python3,
}:

# NOTE a `nix` interpreter is intentionally not provided but required by the script.
# We want the host environments nix interpreter to be used.
let
  python = python3.withPackages (ps: with ps; [ ruamel-yaml ]);

  shebang = "#!" + lib.meta.getExe python;
  script = builtins.readFile ./update-ci.py;
in
writeScriptBin "update-ci.py" (shebang + "\n" + script)
