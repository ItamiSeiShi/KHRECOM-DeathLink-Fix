# KHRECOM Archipelago DeathLink Fix

An OpenKH companion mod and matching Archipelago client patch for **Kingdom
Hearts Re:Chain of Memories (Steam, Sora)**.

- A friend's DeathLink defeats Sora, including outside combat.
- Natural player deaths send a DeathLink when **Continue** is selected.
- Continuing after a received death does not echo it back to other players.
- Includes the original item/check connector and EXP multiplier.

Both directions were tested with real players. v1.0.2 passed 27 Lua bridge
checks and 18 client/local-command checks, including recorded Larxene and Vexen
sequences and actual Windows file-sharing locks.

## v1.0.2: boss retries and Vexen

Some boss retries unload Sora for longer than the old two-second timeout,
which could discard the outgoing death. The bridge now detects the game's
native **Continue** selection directly and distinguishes **Return to Title**.
The first Larxene fight was verified live with one outgoing client send.

Vexen's automatic revival sends no DeathLink. A later actual game over still
sends one when Continue is selected; that sequence was also verified live.

**Upgrading from v1.0.1:** close the game, update this mod in OpenKH (or import
the v1.0.2 release ZIP), rebuild and restart the game. Keep only one DeathLink
companion enabled and keep backed-up Lua outside active script directories.
The client archive is unchanged from v1.0.1; reinstalling that client is
unnecessary. Enable `/deathlink` after any fresh client launch.

**Upgrading from v1.0.0 or an older patch:** update and rebuild the OpenKH mod,
and also install the bundled client as described below. It includes v1.0.1's
Windows file-sharing fix, nonblocking bridge retries and pending incoming
DeathLink delivery.

## Install the mod

1. Close the game and KHRECOM client; keep your existing backups.
2. In OpenKH Mod Manager, install this repository using its `owner/repository`
   name, with Re:Chain of Memories selected.
3. Disable the original RECOM Archipelago Companion and earlier DeathLink-only
   mods. Enable **RECOM Archipelago Companion - DeathLink Fix** instead.
4. Build your mods. Your existing LuaBackend setup must load OpenKH's built
   Recom script directory.

If upgrading from the outgoing-only patch, remove any leftover
`recomAPDeathLinkOutgoing.lua` from the built script directory after backing it
up. Keep backups outside active script directories and load one DeathLink bridge.

## Install the matching client

The KHRECOM Archipelago client is inside **`khrecom.apworld`**. Both the patched
client and Lua bridge are required. OpenKH installs the Lua files; install the
bundled client separately:

1. Open this mod's installed folder.
2. With the KHRECOM client closed, right-click
   [Install-Fixed-Client.ps1](Install-Fixed-Client.ps1) and choose **Run with
   PowerShell**.
3. The installer verifies the bundled archive, backs up the old client, installs
   the fixed archive, and verifies the result. It asks for your Archipelago
   folder if the standard installation is unavailable.

Backups default to `%LOCALAPPDATA%\KHRECOM-DeathLink-Fix\backups\`.

Alternatively, back up your old archive outside `custom_worlds`, then copy
[client/khrecom.apworld](client/khrecom.apworld) into your Archipelago
installation's `custom_worlds` folder. Do not leave a second renamed copy of the
same world there.

## Enable and test

Restart the KHRECOM client, connect to your slot, load your save, and enter:

```text
/deathlink
```

Check that it says **Death Link turned on**. This command toggles the setting;
enable it after each fresh client launch.

For a local test:

```text
/deathlinktest
```

This intentionally defeats Sora through the normal incoming handler. It does
not send a death to the server or other players. Keep gameplay running for
about eight seconds, then Continue; the received death should not be sent back.

## Compatibility

Tested with Steam PC Re:Chain of Memories, Sora's story, Archipelago client
0.6.7, and server 0.6.8. An existing LuaBackend setup is required. Other builds,
platforms, and Riku's story have not been validated. The bridge checks the
supported build before enabling itself.

Incoming requests wait during unsupported actions or busy controller
transitions. Markers older than two minutes are ignored. Updates to the world
or upstream companion can overwrite this patch.

## More information

- [Detailed installation and rollback instructions](README.txt)
- [Changes and validation](CHANGELOG.txt)
- [File integrity hashes](SHA256SUMS.txt)
- [OpenKH installation guide](https://openkh.dev/tool/GUI.ModsManager/)

## Credits

Original companion credit: **Gicu**, retained in `mod.yml`. Based on
[gaithern/KH-RECOM-AP-LUA](https://github.com/gaithern/KH-RECOM-AP-LUA).
This is an unofficial DeathLink repair. The original item/check connector and
EXP multiplier are unchanged.
