#!/bin/bash

# This script will gracefully stop a minecraft server, back it up, rotate the backup, check for and install Minecraft updates, and then restart the Minecraft server.
# It acts as a wrapper for the updatemcjar.sh script (handles the update portion). Please place the updatemcjar.sh script in the Minecraft server folder.
# 10/13/2022

#Minecraft server files location (CHANGE THIS ACCORDINGLY!)
mc=$HOME/minecraft-server

#Minecraft server backup location (CHANGE THIS ACCORDINGLY!)
mcb=$HOME/minecraft-server-backups

#Date var
d=$(date +%Y-%m-%d)

#Gracefully stop minecraft session and wait 30 seconds to complete
screen -S minecraft -X stuff "`echo -ne \"stop\r\"`"
sleep 30

#Create tar file of minecraft server files
tar -czvf "$mcb/mcc2-$d.tar.gz" $mc

#Remove backups older than 3 years
find $mcb -mtime +1095 -print

#Check for minecraft jar updates and install them
bash "$mc/updatemcjar.sh" -y --jar-path "$mc/server.jar"

#Start minecraft server
cd $mc
screen -dmS minecraft java -Xmx1024M -Xms1024M -jar "$mc/server.jar" nogui
