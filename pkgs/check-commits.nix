# SPDX-FileCopyrightText: 2025 wucke13
#
# SPDX-License-Identifier: Apache-2.0

{
  writeShellApplication,
  git,
  util-linux,
}:

writeShellApplication rec {
  name = "check-commits";
  runtimeInputs = [
    git
    util-linux
  ];

  text = ''
    #
    ## Arguments, variables, clean-up & restore code
    #
    BASE_BRANCH="''${BASE_BRANCH:-origin/main}"
    CHECK_COMMAND=( "$@" )

    # command to restore the repo to the state before running this command
    restore(){
      echo -e "\nrestoring repo to state before running this command"

      # restore the head to before running this script
      if [ -n "''${GIT_CURRENT_HASH-}" ]
      then
        git switch --detach --quiet -- "$GIT_CURRENT_HASH"
      elif [ -n "''${GIT_CURRENT_BRANCH-}" ]
      then
        git switch --quiet -- "$GIT_CURRENT_BRANCH"
      fi

      # and restore all the uncommitted files
      if [ "''${RESTORE_STASH:-false}" = true ]
      then
        git stash pop --quiet
      fi
    }


    #
    ### Capture the current state
    #

    # get current branch
    if GIT_CURRENT_BRANCH=$(git symbolic-ref --quiet --short HEAD)
    then :
    # or if in detached mode, current hash
    elif GIT_CURRENT_HASH="$(git rev-parse HEAD)"
    then :
    # TODO handle orphan branches
    else
      echo "wouldn't know how to restore the current state"
      exit 1
    fi

    # register the restore handler
    trap restore EXIT


    #
    ### Stash away local, uncommitted changes
    #

    # stash away all uncommitted things, if any
    if [ -n "$(git ls-files --deleted --modified --others --unmerged --killed --exclude-standard \
      --directory --no-empty-directory)" ]
    then
      git stash push --all --message="${name}-$(date --iso-8601)-$(uuidgen)"
      RESTORE_STASH=true
    fi


    #
    ### Do the work, per each commit since $BASE_BRANCH
    #

    # do the actual per-commit checking
    FAILURES=0
    for commit in $(git rev-list "$BASE_BRANCH..HEAD")
    do
      # checkout the commit...
      git checkout --quiet "$commit"

      # ... and perform the check
      if "''${CHECK_COMMAND[@]}"
      then
        git --no-pager log -1 --pretty='format:%Cgreen✔%>(12)%h%Creset  %s%n%n%n' --color=always
      else
        git --no-pager log -1 --pretty='format:%Cred✘%>(12)%h%Creset  %s%n%n%n' --color=always
        (( FAILURES=FAILURES+1 ))
      fi

      # clean up any mess
      git checkout --quiet -- .
      git clean --force --quiet -- .
    done


    #
    ### Report findings
    #

    # finally, report on the number of failures
    if [[ "$FAILURES" -gt 0 ]]
    then
      echo "Encountered $FAILURES commits failing the check \`''${CHECK_COMMAND[*]}\`"
      exit 1
    fi
  '';
}
