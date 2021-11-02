#!/bin/bash
set -x -e
IFS=
PATH=$HOME/.exec:$PATH

# Must be root
if [[ `whoami` != root ]] ; then
	sudo --preserve-env -- bash $HOME/.exec/build-proton $*
	exit $?
fi

# Get dependecies
export DEBIAN_FRONTEND=noninteractive
apt --yes install --no-install-recommends \
	git ca-certificates wget docker.io fontforge rsync afdko make xz-utils patch autoconf
git clone https://$TOKEN@github.com/KonaArctic/Valve-Proton-Binaries.git `pwd`
git clone --recurse-submodules https://github.com/ValveSoftware/Proton.git proton

# Find latest tags
tags=$( wget --output-document=- --quiet https://api.github.com/repos/ValveSoftware/Proton/releases/latest )
while read -r item ; do
	if [[ $item =~ \"tag_name\":\ \"([^\"]+) ]] ; then
		tags=${BASH_REMATCH[1]}
		if [[ -f $tags.tar.xz ]] ; then
			echo "$tags already exists"
			exit 0
		else
			git -C proton checkout $tags
			break
		fi
	fi
done <<< $tags

# Start container engine
dockerd &
dock=$!
sleep 20
kill -0 $dock 2> devnull ||
	wait $dock

# Build!
proton/configure.sh --build-name=$tags --container-engine=docker #--no-proton-sdk
make redist

# Package
[[ ! -f redist/proton_dist.tar.gz ]] ||
	gzip --decompress redist/proton_dist.tar.gz
tar --create --file=$tags.tar --group=kona --owner=kona --portability --transform 's|^redist/*||' redist
xz --compress --best --extreme --verbose --check=none --memory=max --threads=0 $tags.tar
git -C repo add $tags.tar.xz
git -C repo commit --message="Built $tags" $tags.tar.xz
git -C repo push

# Done.
echo "Built $tags"
exit 0
