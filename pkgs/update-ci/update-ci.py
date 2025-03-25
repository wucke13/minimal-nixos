from pathlib import Path
import subprocess
import json
import ruamel.yaml
import argparse
import hashlib


def nix_eval(args):
    output = subprocess.run(
        ["nix", "eval", "--json"] + args,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    ).stdout
    return json.loads(output)


def sha256sum(filename):
    with open(filename, "rb", buffering=0) as f:
        return hashlib.file_digest(f, "sha256").hexdigest()


parser = argparse.ArgumentParser(
    prog="update-ci.py",
    description="Updates nix.yaml workflow file with output from nix flake",
)
parser.add_argument(
    "-c",
    "--check",
    action="store_true",
    help="Emit non-zero return code if workflow was changed",
)
args = parser.parse_args()

yaml = ruamel.yaml.YAML()


file_path = Path(".forgejo/workflows/nix.yaml")
hash_before = sha256sum(file_path)
ci_workflow = yaml.load(file_path)


all_pkgs = nix_eval(["--apply", "builtins.attrNames", ".#packages.x86_64-linux"])
ci_workflow["jobs"]["build-pkg"]["strategy"]["matrix"]["pkg"] = all_pkgs


all_nixos_configs = nix_eval(["--apply", "builtins.attrNames", ".#nixosConfigurations"])
ci_workflow["jobs"]["build-nixos-config"]["strategy"]["matrix"][
    "config"
] = all_nixos_configs


yaml.dump(ci_workflow, file_path)
subprocess.run(
    ["nix", "fmt"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
)

if vars(args)["check"] and hash_before != sha256sum(file_path):
    exit(1)
