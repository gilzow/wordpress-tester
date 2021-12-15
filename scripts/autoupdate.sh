#!/usr/bin/env bash
#!/usr/bin/env bash
set -e
### COLORS! ###
# Contains a collection of color types we can quickly use in our scripts
# color used for general working notices (ie "installing foobar..."
CWORKING='\033[34;1m'
#The 'color' we use to reset the colors
CRESET='\033[0m'
#bold, duh
CBOLD='\033[1;96m'
#color we use for informational messages
CINFO='\033[1;33m'
#color we use for warnings
CWARN='\033[1;31m'
# not really sure if we'll need this or not since
#updateBranch="auto-updates"
updateBranch="add-source-ops"
printf "%bBeginning auto-update process... %b" "${CWORKING}" "${CRESET}"

#if we dont have the PLATFORMSH_CLI_TOKEN available, then there's not much we can do
if [[ -z ${PLATFORMSH_CLI_TOKEN+x} ]]; then
	printf "%bPlatform CLI Token environmental variable missing!%b\n" "${CWARN}" "${CRESET}"
	printf "%bIn order to perform an auto-update, a valid %bPLATFORMSH_CLI_TOKEN%b %btoken must be created" "${CINFO}" "${CBOLD}" "${CRESET}" "${CINFO}"
	printf " and accessible in this source \noperations environment. Please create the variable and try the source operation again. %b" "${CRESET}"
	exit 1
fi

printf "%bDo we have the psh cli tool installed?%b" "${CWORKING}" "${CRESET}"
which platform
pshCliInstalled=$?

if (( 0 != pshCliInstalled )); then
	printf "\n%bWe don't have the psh cli tool installed so I'll need to do that real quick...%b\n"
	curl -fsS https://platform.sh/cli/installer | php
else
	printf " %bYep!%b\n" "${CBOLD}" "${CRESET}"
fi

defaultBranch=$(platform p:info default_branch)
#ok, should we check on our integration yet, or just always pull from platform <default-branch>?
#make sure this branch is up-to-date with default
git pull platform "${defaultBranch}"
gitPull=$?
if (( 0 != gitPull )); then
	printf "%bMerge Conflict when trying to update from %s!!!%b\n" "${CWARN}" "${defaultBranch}" "${CRESET}"
	printf "%sThere was a merge conflict or other failure when trying to update this branch" "${CINFO}"
	printf " with %b%s%b%b. You will need to perform the update locally.%b"  "${CBOLD}" "${defaultBranch}" "${CRESET}" "${CINFO}" "${CRESET}"
	exit 1
else
	printf "%sUpdating this branch with %b%s%b%b complete. Continuing.%b\n" "${CINFO}" "${CBOLD}" "${defaultBranch}" "${CRESET}" "${CINFO}" "${CRESET}"
fi

printf "%bRunning composer update...%b" "${CWORKING}" "${CRESET}"
composer update
composerUpdated=$?

if (( 0 != composerUpdated )); then
	printf "\n%bComposer Update Failed!%b\n" "${CWARN}" "${CRESET}"
	printf "%sSomething caused composer to fail during the update. Please see the log above for more details.%s\n" "${CINFO}" "${CRESET}"
	exit 1
else
	printf " %sComplete.%b\n" "${CBOLD}" "${CRESET}"
fi

updates=$(git status --porcelain=1)

# If we had updates, add the updated composer.lock and commit it
if [[ -n "${updates}" ]]; then
	printf "%bComposer.lock updated. Adding and committing to the repository.%b" "${CINFO}" "${CRESET}"
	git add composer.lock
	git commit -m "Source Ops Auto-updates"
else
	printf "%bNothing to commit. Exiting.%b" "${CINFO}" "${CRESET}"
	exit 0
fi

#NOW we need to see if they have an integration...
integrations=$(platform integrations --columns=ID,type --no-header --format=csv)
# @todo this is nowhere near complete. We need to be able to support multiple types of integrations.
# @todo what do we do if there is more than one git integration?
while IFS=, read -r id type; do
	if [[ "github" == "${type }" ]]; then
		integrationID="${id}"
		#yes, this looks weird, but eventually we'll be looking for any of X types
		integrationType="${type}"
	fi
done < <(echo "${integrations}")

if [[ -z ${integrationID+x} ]]; then
	# we didnt find a valid integration so we'll have to assume they don't have one. So... that's it.
	printf "\n%bDone.%b\n" "${CBOLD}" "${CRESET}"
	exit 0
fi

#now we need to get the base_url
baseURL=$(platform integration:get "${integrationID}" --property=base_url)

if [[ -z "${baseURL}" && "github" == "${integrationType}" ]]; then
	#interestingly, I've seen a handful of github integrations where the base_url was left blank
	baseURL="https://github.com/"
fi

# now the project location
# should we add some checks to make sure this isn't empty?
projectLocation=$(platform integration:get "${integrationID}" --property=project)

#in case we need it. We'll need another map for each service --> location
manualPRLocation="${baseURL}${projectLocation}/compare/${defaultBranch}...${updateBranch}"

# now that we know we have a github integration, we need to see if we have a github token.
# @todo this will need to be expanded to check for a _generic_ git api token that we can then map to the specific integration
# @todo there is an env var COMPOSER_AUTH that has a prop `password` that contains the token used for the integration.
# I guess we could fail to using it?
if [[ -z ${GITHUB_TOKEN+x} ]]; then
	printf "%bGithub token missing!%b\n" "${CWARN}" "${CRESET}"
	printf "%bIn order to create a pull/merge request for this update, a valid %bGITHUB_TOKEN%b %btoken must be created" "${CINFO}" "${CBOLD}" "${CRESET}" "${CINFO}"
  printf " and accessible in this source operations environment. You will need to create the pull/merge manually at\n"
  printf " %b%s%b%b. Exiting.%b" "${CBOLD}" "${manualPRLocation}" "${CRESET}" "${CINFO}" "${CRESET}"
  # @todo do we exit 0 since the update completed? or exit 1 because the PR creation failed?
  exit 0
fi

# @todo this section will need to map types to api locations
gitAPILocation="https://api.github.com/"

gitRepoAPILocation="${gitAPILocation}${projectLocation}"

#now the moment of truth!
authHead="Authorization: token ${GITHUB_TOKEN}"
authAccept="Accept: application/vnd.github.v3+json"
title="Auto-update from Project source operations"
data="'{\"head\":\"${updateBranch}\",\"base\":\"${defaultBranch}\",\"title\":\"${title}\"}'"
prCreated=$(curl -s -D headers.txt -X POST -H "${authHead}" -H "${authAccept}" "${gitRepoAPILocation}/pulls" -d "${data}")

#parse the headers.txt file and make sure we received a 201 Created response
printf "Contents of the headers file:"
cat headers.txt
#ok, prCreated should be a json object where we can extract `number` and `url` to give back to the user
prURL=$(echo "${prCreated}" | jq -r '.url')
prNumber=$(echo "${prCreated}" | jq -r '.number')

printf "\n%bPR %d was created and is viewable at %b%s%b.\n" "${CINFO}" "${prNumber}" "${CBOLD}" "${prURL}" "${CRESET}"

printf "%bDone.%b" "${CBOLD}" "${CRESET}"
# Steps for creating an auto-merge PR
# 1. get the default branch for the repository. We can get that with either the
