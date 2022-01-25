#!/usr/bin/env bash

printf "We are in the %s stage.\n" "${1}"

printf "So let's see what we have, shall we?\n"

if [[ -z ${PLATFORM_PROJECT+x} ]]; then
	printf "PLATFORM_PROJECT is NOT available\n"
else
	printf "PLATFORM_PROJECT is available\n"
fi

if [[ -z ${PLATFORM_DOCUMENT_ROOT+x} ]]; then
	printf "PLATFORM_DOCUMENT_ROOT is NOT available\n"
else
	printf "PLATFORM_DOCUMENT_ROOT is available\n"
fi

printf "Finally, all env vars for stage %s: \n" "${1}"
printenv


