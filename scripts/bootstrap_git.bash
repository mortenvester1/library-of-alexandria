#!/bin/bash

usage() {
	echo "Usage: $0 [-e email] [-s signingkey]" 1>&2;
	exit 1;
}

while getopts ":e:s:" o; do
    case "${o}" in
        e)
            EMAIL=${OPTARG}
            ;;
        s)
            SIGNINGKEY=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${EMAIL}" ] && [ -z "${SIGNINGKEY}" ]; then
    usage
fi

touch ~/.gitlocal
git config --file ~/.gitlocal user.email ${EMAIL}

if [ -n "${SIGNINGKEY}" ]; then
    git config --file ~/.gitlocal user.signingkey ${SIGNINGKEY}
    git config --file ~/.gitlocal commit.gpgsign true
fi
