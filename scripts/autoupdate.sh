#!/usr/bin/env bash
#!/usr/bin/env bash
set -e
echo "beginning auto-update check"
updateBranch="auto-updates"
echo "how about just git status?"
git status
#echo "What about branches?"
#BRANCHES=$(git branch -r)
#echo "${BRANCHES}"
#echo "here are all the remotes:"
#git remote -v
#get the name of our remote. we may have more than one so grab the first
#echo "getting the name of the remote"
#remote=$(git remote | head -n 1)
#printf "The name of our remote is %s\n" "${remote}"
#make sure we're up-to-date
echo "Fetching all"
git fetch --all

#echo "what about just git ls-remote on our remote?"
#git ls-remote "${remote}"

#do we have the branch remotely?
#echo "checking to see if we have the branch remotely"
#branchExistsRemote=$(git ls-remote --exit-code "${remote}" "${updateBranch}")

# does our branch exist locally?
#echo "checking to see if we have the branch locally"
#branchExistsLocally=$(git show-ref --quiet refs/heads/auto-updates)

#if it doesn't exist locally, then we know we'll need a new local branch
#if (( 1 == branchExistsLocally )); then
#  doBranch='yes'
#fi

#if (( 0 != branchExistsRemote )); then
#  getBranchFromRemote='yes'
#fi

#echo "checking out the branch"
#git checkout "${doBranch:+ -b }${updateBranch}${getBranchFromRemote:+ ${remote}/${updateBranch}}"

#now that we're on the branch, if we already had it locally AND we have it remotely, let's make sure it is up-to-date
#if (( 0 == branchExistsLocally  && 0 == branchExistsRemote )); then
#  echo "the branch was available locally and remotely so making sure we are up-to-date"
#  git pull --no-rebase
#fi

#let's get our updates
echo "running composer update"
composer update
updates=$(git status --porcelain=1)

# If we had updates, add the updated composer.lock and commit it
if [[ -n "${updates}" ]]; then
	git add composer.lock
	git commit -m "Auto updates"

#  git push "${remote}" "${updateBranch}"
fi
