#!/bin/bash
set -o errexit -o pipefail
shopt -s globstar ; shopt -s dotglob
IFS=
PATH=$HOME/.exec:$PATH

# Arguments
tags= ; repo="https://$GITHUB_TOKEN@github.com/KonaArctic/Valve-Proton-Binaries.git" ; temp=/tmp ; force=
for item in $* ; do
	if [[ $item =~ ^-?-?version ]] ; then
		echo "0.0"
		exit 0
	elif [[ $item =~ ^-?-?tags= ]] ; then
		tags=${item#*=}
	elif [[ $item =~ ^-?-?repo= ]] ; then
		repo=${item#*=}
	elif [[ $item =~ ^-?-?temp= ]] ; then
		temp=${item#*=}
	elif [[ $item =~ ^-?-?force$ ]] ; then
		force=true
	else
		echo "F I dont know what $item means" 1>&2
		exit 80
	fi
done

# Must be root
if [[ `whoami` != root ]] ; then
	sudo --preserve-env -- bash $HOME/.exec/build-proton $*
	exit $?
fi

# Get enviorment
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get --yes install --no-install-recommends \
	git ca-certificates wget docker.io fontforge rsync afdko make xz-utils patch autoconf gzip tar coreutils
temp=$temp/kona-$$
mkdir $temp
cd $temp
git clone $repo `pwd`
git clone --recurse-submodules https://github.com/ValveSoftware/Proton.git proton

# Find latest tags
if [[ ! $tags ]] ; then
	tags=`wget --output-document=- --quiet https://api.github.com/repos/ValveSoftware/Proton/releases/latest `
	while read -r item ; do
		[[ ! $item =~ \"tag_name\":\ \"([^\"]+) ]] ||
			tags=${BASH_REMATCH[1]}
	done <<< $tags
fi
if [[ -f $tags.tar.xz ]] ; then
	echo "N $tags already exists" 1>&2
	[[ $force ]] ||
		exit 0
fi
git -C proton checkout $tags

# Start container engine
dockerd &
dock=$!
read -t 20 <> <( true ) ||
	true
kill -0 $dock 2> devnull ||
	wait $dock

# Build!
sh proton/configure.sh --build-name=$tags --container-engine=docker #--no-proton-sdk
make redist

# Package
[[ ! -f redist/proton_dist.tar.gz ]] ||
	gzip --decompress redist/proton_dist.tar.gz
tar --create --file=$tags.tar --group=kona --owner=kona --portability --transform 's|^redist/*||' redist
xz --compress --force --best --extreme --verbose --check=none --memory=max --threads=0 $tags.tar
git -C repo add $tags.tar.xz
git -C repo commit --message="Built $tags" $tags.tar.xz
git -C repo push

# Cleanup
make clean
for item in ** ; do
	[[ ! -f $item ]] ||
		true 1> $item
done

# Done.
echo "N done built $tags" 1>&2
exit 0
