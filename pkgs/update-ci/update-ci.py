# SPDX-FileCopyrightText: 2024-2025 wucke13
#
# SPDX-License-Identifier: Apache-2.0

from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import ruamel.yaml
import subprocess
import sys

print_output = open(os.devnull, "w")

print_indentation = "      "


def log(str):
    print(f"{print_indentation}{str}", file=print_output)


def nix_eval(args):
    """Evaluate a Nix expression, returning the result as native Python datatype"""
    output = subprocess.run(
        ["nix", "eval", "--json"] + args,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    ).stdout
    return json.loads(output)


def sha256sum(filepath):
    """Derive the sha256 of a file pased via filepath"""
    with open(filepath, "rb", buffering=0) as f:
        return hashlib.file_digest(f, "sha256").hexdigest()


def camelCase_to_SHOUT_CASE(input_str):
    return re.sub(r"(?<!^)(?=[A-Z])", "_", input_str).upper()


def update_if_exists(obj, key_chain, new_value_lambda):
    """obj contains a nested element under the keys in key_chain, update its value to the result of new_value_lambda"""
    try:
        x = obj
        x_ = None
        for key in key_chain:
            x_ = x
            x = x[key]
        log(f"updating value of {key_chain}")
        x_[key] = new_value_lambda()
        return True
    except KeyError:
        return False


flake_outputs = ["packages", "nixosConfigurations", "homeConfigurations"]


def process_actions(ci_workflow):
    """Update/insert jobs into a Forgejo/GitHub actions CI workflow YAML file"""
    for flake_output in flake_outputs:
        job_suffix = flake_output.removesuffix("s")  # ditch plural 's'
        var_name = camelCase_to_SHOUT_CASE(job_suffix)

        # TODO remove hardcoded architecture
        if flake_output == "packages":
            flake_output += ".x86_64-linux"

        key_chain = ["jobs", f"build-{job_suffix}", "strategy", "matrix", var_name]

        if not update_if_exists(
            ci_workflow,
            key_chain,
            lambda: nix_eval(["--apply", "builtins.attrNames", f".#{flake_output}"]),
        ):
            log(f"key_chain {key_chain} is not present")


def process_gitlab(ci_workflow):
    """Update/insert jobs into a Gitlab CI YAML file"""

    for flake_output in flake_outputs:
        job_suffix = flake_output.removesuffix("s")  # ditch plural 's'
        var_name = camelCase_to_SHOUT_CASE(job_suffix)

        # TODO remove hardcoded architecture
        if flake_output == "packages":
            flake_output += ".x86_64-linux"

        key_chain = [f"nix:build:{job_suffix}", "parallel", "matrix"]

        if not update_if_exists(
            ci_workflow,
            key_chain,
            lambda: [
                {
                    var_name: nix_eval(
                        ["--apply", "builtins.attrNames", f".#{flake_output}"]
                    )
                }
            ],
        ):
            log(f"key_chain {key_chain} is not present")


parser = argparse.ArgumentParser(
    prog="update-ci.py",
    description="Updates YAML based CI file with output from nix flake",
)
parser.add_argument(
    "-c",
    "--check",
    action="store_true",
    help="Emit non-zero return code if workflow was changed",
)
parser.add_argument(
    "-v",
    "--verbose",
    action="store_true",
    help="Be verbose about what is touched in the YAML files",
)
args = parser.parse_args()

if vars(args)["verbose"]:
    print_output = sys.stderr

yaml = ruamel.yaml.YAML()


known_ci_files = {
    ".forgejo/workflows/nix.yaml": process_actions,
    ".github/workflows/nix.yaml": process_actions,
    ".gitlab-ci.yml": process_gitlab,
}


change_detected = False

for key in known_ci_files:
    file_path = Path(key)
    if not file_path.is_file():
        continue
    log(f"processing {file_path}")

    hash_before = sha256sum(file_path)
    ci_yaml = yaml.load(file_path)
    process_fn = known_ci_files[key]
    process_fn(ci_yaml)
    yaml.dump(ci_yaml, file_path)

    subprocess.run(
        ["nix", "fmt", file_path],
        check=True,
    )

    if vars(args)["check"] and hash_before != sha256sum(file_path):
        change_detected = True
        # If something changed, show the diff
        subprocess.run(
            [
                "git",
                "diff",
                "--no-pager",
                f"--line-prefix={print_indentation}",
                file_path,
            ],
            check=False,
        )

if change_detected:
    exit(1)
