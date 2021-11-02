[![Build Badge](https://github.com/KonaArctic/Valve-Proton-Binaries/actions/workflows/main.yml/badge.svg)](https://github.com/KonaArctic/Valve-Proton-Binaries/actions/workflows/main.yml)

# Valve Proton Binaries
What's This?
------------
In this repository are unofficial binary builds of Proton; made using Github Actions and Docker.

Proton is a compatibility layer lets Linux users play Windows games. If you use the Steam client then you already have Proton. I don't use the Steam client.

See [here](https://github.com/ValveSoftware/Proton) for details.

Usage
-----
1.  Download latest `proton-*.tar.xz[0-9]{4}` files
2.  Concatenate `cat proton-*.tar.xz[0-9]{4} 1> proton.tar.xz`
3.  Unpack `tar --extract --file=proton.tar.xz`
4.  Run `STEAM_COMPAT_DATA_PATH=~/proton-pfx ./proton run [YOUR GAME].exe`
