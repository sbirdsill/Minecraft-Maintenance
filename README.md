# Minecraft-Maintenance
Minecraft maintenance script, will gracefully stop a minecraft server, back it up, rotate the backup, check for and install Minecraft updates, and then restart the Minecraft server. It acts as a wrapper for the updatemcjar.sh script (handles the update portion). 

# Instructions
1. Place the updatemcjar.sh file in your Minecraft server directory.
2. Place the MinecraftMaint.sh file in your home directory (or wherever you prefer).
3. Edit the MinecraftMaint.sh file and change the Minecraft server and backup location accordingly, or leave it as is if you prefer to keep them in your home directory.
4. Create a cron job to run the script on a schedule (I run it monthly and on reboot).
5. Ensure executable permissions are set on the script by running "chmod +x MinecraftMaint.sh". 

Thanks to https://minecraft.fandom.com/wiki/Tutorials/Linux_server_update_script for the updatemcjar.sh script.
