RECOM Archipelago Companion - DeathLink Fix
OpenKH-installable mod archive, v1.0.2 - 2026-10-19

This replaces the original RECOM Archipelago Companion with the same item/check
connector, EXP multiplier and the working DeathLink bridge. Original companion
credit: Gicu. The DeathLink repair is an unofficial local patch.

UPGRADING FROM v1.0.1

The Lua bridge now detects the game's Continue selection directly. This fixes
missed outgoing DeathLinks when boss retries unload Sora for longer than two
seconds, as recorded in the first Larxene fight.

Close the game, update this mod in OpenKH (or import the v1.0.2 ZIP), enable
only one DeathLink companion, rebuild your mods and restart the game. Keep any
backed-up Lua outside active script folders. The client archive is identical
to v1.0.1, so its client does not need reinstalling. If the client stayed open,
DeathLink can remain enabled; after a fresh client launch enter /deathlink.

UPGRADING FROM v1.0.0 OR AN OLDER PATCH

Update and rebuild the OpenKH mod as above. Also close the KHRECOM client and
run the included Install-Fixed-Client.ps1, which verifies the archive and backs
up the previous client. Restart the client, reconnect and enable /deathlink.
This includes v1.0.1's fix for Windows file-sharing errors writing dlstate.cfg.

WHAT IS THE FIXED CLIENT?

The KHRECOM Archipelago client is stored inside khrecom.apworld. The Lua bridge
and this patched client work together: the client handles server messages and
bridge files; the Lua bridge makes the game process incoming deaths. Both parts
are included. OpenKH installs the game-side Lua; the separate client installer
replaces the Archipelago archive after preserving a backup.

INSTALL THE OPENKH MOD

1. Close the game and KHRECOM client. Keep copies of your existing files.
2. In OpenKH Mod Manager, select Re:Chain of Memories and add a mod using
   "Select and install Mod Archive or Lua Script". Choose this ZIP directly.
   The archive has mod.yml at its root and declares game: Recom.
3. Disable the old RECOM Archipelago Companion and any earlier DeathLink-only
   mod. Enable "RECOM Archipelago Companion - DeathLink Fix" instead.
4. Build your mods. LuaBackend must already be installed and configured to load
   OpenKH's built Recom scripts directory.

If you previously used the outgoing-only patch, back up and remove any leftover
recomAPDeathLinkOutgoing.lua from the built scripts directory. Load only one
DeathLink bridge. Store all backups outside active script directories.

INSTALL THE INCLUDED CLIENT

The fixed archive is client/khrecom.apworld inside this mod.

Option A - Installer with backup:
Extract this ZIP into a normal folder (or open the installed mod's folder).
Close the KHRECOM client. Right-click Install-Fixed-Client.ps1 and choose
"Run with PowerShell". The installer checks the bundled client hash, finds the
standard ProgramData Archipelago folder or asks for your installation folder,
backs up the old client, then installs and verifies the new one. Running it
again with the same version makes no additional changes.

Default installer backups are stored at:
    %LOCALAPPDATA%\KHRECOM-DeathLink-Fix\backups\

For a custom installation, it can also be run from PowerShell:
    .\Install-Fixed-Client.ps1 -ArchipelagoPath 'D:\Archipelago'

If your Windows policy prevents running the script, use Option B.

Option B - Manual copy:
Back up the old khrecom.apworld outside the custom_worlds directory, then copy
client/khrecom.apworld into your Archipelago installation's custom_worlds folder.
A common target is C:\ProgramData\Archipelago\custom_worlds\khrecom.apworld.
Do not keep a second renamed .apworld copy of the same world in custom_worlds.

START AND ENABLE

Start the game and restart the KHRECOM client. Connect to your normal slot,
load your save, and enter /deathlink in the client. Verify it says Death Link
turned on. This is a toggle and needs enabling after a fresh client launch.

Incoming DeathLinks defeat Sora. Your natural deaths are sent when you press
Continue. Vexen auto-revive does not send a death; a later game over followed
by Continue still sends one. Continuing after a received death does not echo
that death back.
/deathlinktest triggers one local incoming test and intentionally defeats Sora,
without sending a death to other players. Keep gameplay running for about
eight seconds so the game-over sequence can finish.

COMPATIBILITY AND VERIFICATION

Tested: Steam PC Re:Chain of Memories, Sora's story, Archipelago client 0.6.7,
server 0.6.8. Existing LuaBackend setup is required. Other builds/platforms and
Riku's story have not been validated. The Lua bridge checks the supported build.
The packaged Lua and client match the working, live-tested installation.
Both real friend-to-Sora and Sora-to-friend DeathLinks were confirmed, including
Continue echo suppression. Incoming requests can wait during unsupported
actions/busy controller transitions; old incoming markers expire after two minutes.

ROLLBACK

Close game/client. Disable this mod, re-enable your original companion, and
rebuild. Remove its added recomAPDeathLink.lua from output if your rebuild
leaves it behind. Restore the original khrecom.apworld from your backup.
The installer manifest records the original path and hashes. This package does
not change your saves, game executable or LuaBackend configuration.

SHA256SUMS.txt contains integrity hashes. No personal logs, connection details,
saves or memory snapshots are included. An upstream mod/world update may
overwrite the fix; retain this package and your backups.

OpenKH installation reference:
https://openkh.dev/tool/GUI.ModsManager/
