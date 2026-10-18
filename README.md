# KHRECOM Archipelago DeathLink Fix

An OpenKH companion mod and matching Archipelago client patch for **Kingdom
Hearts Re:Chain of Memories (Steam, Sora)**.

- A friend's DeathLink defeats Sora, including outside combat.
- Natural player deaths send a DeathLink when **Continue** is selected.
- Continuing after a received death does not echo it back to other players.
- Includes the original item/check connector and EXP multiplier.

Both directions were tested with real players. The Lua bridge, client, and local
test command passed 34 automated checks for v1.0.1, including real Windows
file-sharing locks.

## v1.0.1 client update

Fixes `PermissionError: [WinError 5]` when Lua reads `dlstate.cfg` while the
client replaces it. Bridge writes retry without blocking, and incoming deaths
remain pending until written successfully.

If v1.0.0 is installed, close the KHRECOM client and run the updated client
installer below. Restart the client and enable `/deathlink`. The existing Lua
bridge is compatible with this update. For persistent warnings, close duplicate
clients and check the bridge folder's write permissions.

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
