#!/bin/sh

#----------------------------------------
# A shell script for updating the minecraft server jar file on Linux Servers
# Written by: Andrew Haskell
# Updated by: Zukaro Travon
# Last updated on: 2019.Sep.23
# Distributed under The MIT License (MIT)
#
# Dependencies
# 	cURL	For downloading of the manifest and jar files
#	jq	For parsing the manifests
#
#
#			---- IMPORTANT ----
# 	This script merely updates the minecraft server jar.
# 	Wrap this script in a wrapper script to take care of stopping and
#	starting your server based on your setup.
# 	If you need to change permissions on the final server jar do it from
#	within that warpper script as well.
#
# Example Wrapper Script:
# 	systemctl stop minecraft
#	./updatemcjar.sh -y --jar-path "/srv/minecraft/server.jar"
#	sudo chown minecraft:minecraft "/srv/minecraft/server.jar"
#	sudo chmod 750 "/srv/minecraft/server.jar"
#	sudo chmod +x "/srv/minecraft/server.jar"
#	systemctl start minecraft
#----------------------------------------

# Error out script on errors
set -e

# Default Settings (Can be changed through parameters)
TEMP_DIR='/tmp/updatemc/'
JAR_PATH='/home/minecraftuser/minecraftdir/server.jar'
VERSION_MANIFEST='https://piston-meta.mojang.com/mc/game/version_manifest.json'

# Output paths
NORMAL_OUT=/dev/stdout
ERROR_OUT=/dev/stderr

# Parameter Flags
FLAG_FORCE=
FLAG_VERSION=
FLAG_CONFIRM=
FLAG_TEST=

# Help Page
usage()
{
	echo
	echo "----------------------------------------"
	echo "$0 - A tool for updating the minecraft server jar easily"
	echo "Written by: Andrew Haskell - Distributed under The MIT License (MIT)"
	echo
	echo "Dependencies:"
	echo "    cURL                 Included in most major distributions package repositories"
	echo "    jq                   Check your distribution repositories or build from source"
	echo
	echo "Usage: $0 [options]"
	echo
	echo "    -f, --force          If the Target Version SHA1 matches the current file's SHA1, force the update anyway, implies --yes"
	echo "    -y, --yes            Skip update confirmation"
	echo "    -v, --version        Specify a different target version. Without this parameter, the latest release version is used"
	echo "    -t, --test           Test the Target Version SHA1 against the current file's SHA1 without changing any files"
	echo "    -s, --silent         Suppress script output, implies --yes"
	echo "    --no-err             Suppress error messages (Dangerous!)"
	echo "    --temp-dir           Specify a different temporary directory, default is $TEMP_DIR"
	echo "    --jar-path           Specify a different final JAR path, default is $JAR_PATH"
	echo "    --manifest           Specify a different version manifest URL, default is $VERSION_MANIFEST"
	echo "    -h, --help           Print this help message"
	echo
	echo "Examle Usage:"
	echo "    $0                   Run the script normally"
	echo "    $0 -f                Force update the existing JAR"
	echo "    $0 -v 1.8.1 -y       Update to 1.8.1 without asking for confirmation"
	echo
	echo "----------------------------------------"
	echo 
}


# Check Script Parameters
while [ "$1" != "" ]; do
	case $1 in
		-f | --force )		FLAG_FORCE=1
					FLAG_CONFIRM=1
					;;
		-v | --version )	shift
					FLAG_VERSION=$1
					;;
		-y | --yes )		FLAG_CONFIRM=1
					;;
		-s | --silent )		NORMAL_OUT=/dev/null
					FLAG_CONFIRM=1
					;;
		--no-err )		ERROR_OUT=/dev/null
					;;
		--temp-dir )		shift
					TEMP_DIR=$1
					;;
		--jar-path )		shift
					JAR_PATH=$1
					;;
		--manifest )		shift
					VERSION_MANIFEST=$1
					;;
		-t | --test )		FLAG_TEST=1
					;;
		-h | --help )		usage
					exit
					;;
		* )			echo "Bad option specified"
					usage
					exit 1
					;;
	esac
	shift
done

echo "Clearing temp directory: $TEMP_DIR" > $NORMAL_OUT
mkdir -p $TEMP_DIR
DOWNLOADED_JAR="${TEMP_DIR}server.jar"
if [ -e $DOWNLOADED_JAR ]
then
	rm -f $DOWNLOADED_JAR
fi

echo "Downloading Version Manifest from: $VERSION_MANIFEST" > $NORMAL_OUT
VERSION_MANIFEST_DATA=$(curl -s "$VERSION_MANIFEST")
echo "Done" > $NORMAL_OUT


echo "Parsing Version Manifest" > $NORMAL_OUT
VERSION_LATEST=$(echo "$VERSION_MANIFEST_DATA" | jq -r '.latest.release' )

VERSION_TARGET=$VERSION_LATEST
echo "Latest released version: $VERSION_LATEST" > $NORMAL_OUT
if [ -n "$FLAG_VERSION" ]
then
	VERSION_TARGET=$FLAG_VERSION
	echo "Target version to download: $VERSION_TARGET" > $NORMAL_OUT
fi
PACKAGE_MANIFEST=$(echo "$VERSION_MANIFEST_DATA" | jq -r --arg VERSION_TARGET "$VERSION_TARGET" '.versions | .[] | select(.id==$VERSION_TARGET) | .url')
echo "Done" > $NORMAL_OUT

if [ -z "$PACKAGE_MANIFEST" ]
then
	echo "Could not find target version: $VERSION_TARGET within the manifest file. Was the target version incorrectly specified? If not then double check the Mojang version manifest by hand" > $ERROR_OUT
	exit 1
fi

echo "Downloading Package Manifest from: $PACKAGE_MANIFEST" > $NORMAL_OUT
PACKAGE_MANIFEST_DATA=$(curl -s "$PACKAGE_MANIFEST")
echo "Done" > $NORMAL_OUT

echo "Parsing Package Manifest" > $NORMAL_OUT
SERVER_NEWJAR_URL=$(jq -rn --argjson url "$PACKAGE_MANIFEST_DATA" '$url.downloads.server.url')
SERVER_NEWJAR_SHA1=$(jq -rn --argjson sha1 "$PACKAGE_MANIFEST_DATA" '$sha1.downloads.server.sha1')
echo "Done" > $NORMAL_OUT

echo "Calculating SHA1 of $JAR_PATH" > $NORMAL_OUT
SERVER_OLDJAR_SHA1=$(sha1sum "$JAR_PATH" | cut -d " " -f 1)

echo "Old JAR SHA1: $SERVER_OLDJAR_SHA1" > $NORMAL_OUT
echo "New JAR SHA1: $SERVER_NEWJAR_SHA1" > $NORMAL_OUT

if [ "$SERVER_OLDJAR_SHA1" = "$SERVER_NEWJAR_SHA1" ]
then
	echo "SHA1 sums match. $JAR_PATH is already target version" > $NORMAL_OUT
	if [ -z "$FLAG_TEST" ]
	then
		if [ -z "$FLAG_FORCE" ]
		then
			echo "Exiting" > $NORMAL_OUT
			exit
		else
			echo "Forcing JAR Update" > $NORMAL_OUT
		fi
	else
		exit
	fi
else
	echo "SHA1 sums mis-matched. $JAR_PATH differs from target version." > $NORMAL_OUT
	if [ -z "$FLAG_TEST" ]
	then
		if [ -z "$FLAG_CONFIRM" ]
		then
			while true; do
				read -p "Replace $JAR_PATH with latest? [y/n]: " yn
				case $yn in
					[Yy]* ) 	break
						;;
					[Nn]* ) 	echo "Exiting"
							exit
							;;
					* ) 		echo "Please answer Y(es) or N(o)"
							;;
				esac
			done
		fi
	else
		exit
	fi
fi

echo "Downloading new server JAR from: $SERVER_NEWJAR_URL to $DOWNLOADED_JAR" > $NORMAL_OUT
curl -s -L -f -o $DOWNLOADED_JAR $SERVER_NEWJAR_URL
echo "Done" > $NORMAL_OUT

echo "Calculating SHA1 of $DOWNLOADED_JAR" > $NORMAL_OUT
DOWNLOADED_SHA1=$(sha1sum $DOWNLOADED_JAR | cut -d " " -f 1)
echo "Dwn JAR SHA1: $DOWNLOADED_SHA1" > $NORMAL_OUT
echo "New JAR SHA1: $DOWNLOADED_SHA1" > $NORMAL_OUT


if [ "$DOWNLOADED_SHA1" = "$SERVER_NEWJAR_SHA1" ]
then
	echo "SHA1 sums match, proceeding" > $NORMAL_OUT
else
	echo "SHA1 sums mis-matched, check downloaded JAR at: $DOWNLOADED_JAR" > $ERROR_OUT
	exit 1
fi

JAR_PATH_BACKUP=${JAR_PATH}.bak
echo "Renaming $JAR_PATH to $JAR_PATH_BACKUP" > $NORMAL_OUT
mv $JAR_PATH $JAR_PATH_BACKUP

echo "Copying $DOWNLOADED_JAR to $JAR_PATH" > $NORMAL_OUT
cp $DOWNLOADED_JAR $JAR_PATH

echo "Re-Verifying $JAR_PATH" > $NORMAL_OUT
FINAL_SHA1=$(sha1sum $JAR_PATH | cut -d " " -f 1)
if [ "$FINAL_SHA1" = "$SERVER_NEWJAR_SHA1" ]
then
	echo "$JAR_PATH updated successfully to version: $VERSION_TARGET" > $NORMAL_OUT
	exit
else
	echo "SHA1 sums mis-matched, current JAR at: $JAR_PATH does NOT match the version attempting to be installed. Rolling Back" > $ERROR_OUT
	echo "Deleting $JAR_PATH" > $ERROR_OUT
	rm -f $JAR_PATH
	echo "Copying backup JAR from: $JAR_PATH_BACKUP to $JAR_PATH" > $ERROR_OUT
	cp $JAR_PATH_BACKUP $JAR_PATH
	echo "Original JAR file restored. Please check the files in $TEMP_DIR" > $ERROR_OUT
	exit
fi