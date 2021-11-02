#!/bin/bash
set -o errexit -o pipefail
shopt -s globstar ; shopt -s dotglob
IFS=
PATH=$HOME/.exec:$PATH

# Arguments
tags= ; repo="https://KonaArctic:$GITHUB_TOKEN@github.com/KonaArctic/Valve-Proton-Binaries.git" ; temp=/tmp ; force= ; apts= 
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
	elif [[ $item =~ ^-?-?apts$ ]] ; then
		apts=true
	else
		echo "F I dont know what $item means" 1>&2
		exit 80
	fi
done

# Testing
tags=proton
cd `mktemp -d`
git clone $repo `pwd`
git config user.email "arcticjieer@gmail.com"
git config user.name "Kona Arctic"
head --bytes=$(( 201 * 1024 ** 2 )) /dev/urandom 1> $tags.tar.xz
split --suffix-length=4 --bytes=$(( 100 * 1024 ** 2 )) --numeric-suffixes=0000 $tags.tar.xz $tags.tar.xz
git add $tags.tar.xz[0-9a-fA-F]*
git commit --message="Built $tags" $tags.tar.xz[0-9a-fA-F]*
git push
exit

# Must be root
if [[ `whoami` != root ]] ; then
	if command -v sudo | read ; then
		sudo --preserve-env -- bash $0 $*
		exit $?
	else
		echo "F must be root" 1>&2
		exit 60
	fi
fi

# Get dependencies
if [[ $apts ]] ; then
	sed --in-place=.bak --expression="s|focal|groovy|g" /etc/apt/sources.list # force newer repo for afdko
	export DEBIAN_FRONTEND=noninteractive
	apt-get update
	apt-get --yes dist-upgrade
	apt-get --yes install --no-install-recommends \
		git ca-certificates wget fontforge rsync afdko make xz-utils patch autoconf gzip tar coreutils #docker.io
fi

# Enviorment
temp=$temp/kona-$$
mkdir $temp
cd $temp
git clone $repo `pwd`
git config user.email "arcticjieer@gmail.com"
git config user.name "Kona Arctic"
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
#kill -0 $dock 2> devnull ||
#	wait $dock

# Build!
bash proton/configure.sh --build-name=$tags --container-engine=docker #--no-proton-sdk
make redist

# Package
[[ ! -f redist/proton_dist.tar.gz ]] ||
	gzip --decompress redist/proton_dist.tar.gz
tar --create --file=$tags.tar --group=kona --owner=kona --portability --transform 's|^redist/*||' redist
xz --compress --force --best --extreme --verbose --check=none --memory=max --threads=0 $tags.tar
split --suffix-length=4 --bytes=$(( 100 * 1024 ** 2 )) --numeric-suffixes=0000 $tags.tar.xz $tags.tar.xz
git add $tags.tar.xz[0-9a-fA-F]*
git commit --message="Built $tags" $tags.tar.xz[0-9a-fA-F]*
git push

# Cleanup
make clean
for item in ** ; do
	[[ ! -f $item ]] ||
		true 1> $item
done

# Done.
echo "N done built $tags" 1>&2
exit 0
