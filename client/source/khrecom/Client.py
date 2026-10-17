from __future__ import annotations
import os
import sys
import asyncio
import shutil
import logging
import time
import math
from calendar import timegm

import ModuleUpdate
ModuleUpdate.update()

import Utils

death_link = False

item_num = 1

logger = logging.getLogger("Client")

if __name__ == "__main__":
    Utils.init_logging("KHRECOMClient", exception_logger="Client")

from NetUtils import NetworkItem, ClientStatus
from CommonClient import gui_enabled, logger, get_base_parser, ClientCommandProcessor, \
    CommonContext, server_loop


def check_stdin() -> None:
    if Utils.is_windows and sys.stdin:
        print("WARNING: Console input is not routed reliably on Windows, use the GUI instead.")

class KHRECOMClientCommandProcessor(ClientCommandProcessor):
    def __init__(self, ctx):
        super().__init__(ctx)

    def _cmd_deathlink(self):
        """Toggles Deathlink"""
        global death_link
        if death_link:
            death_link = False
            self.output(f"Death Link turned off")
        else:
            death_link = True
            self.output(f"Death Link turned on")

    def _cmd_deathlinktest(self):
        """Simulate one incoming DeathLink locally; never broadcast to other players."""
        if not death_link:
            self.output("Enable DeathLink with /deathlink before running the local test.")
            return
        self.output("DeathLink: local incoming test; not sent to the server or other players.")
        self.ctx.on_deathlink({
            "time": time.time(),
            "source": "Local DeathLink test",
            "cause": "Local incoming DeathLink test."
        })


class KHRECOMContext(CommonContext):
    command_processor: int = KHRECOMClientCommandProcessor
    game = "Kingdom Hearts RE Chain of Memories"
    items_handling = 0b111  # full remote

    def __init__(self, server_address, password):
        super(KHRECOMContext, self).__init__(server_address, password)
        self.send_index: int = 0
        self.syncing = False
        self.awaiting_bridge = False
        # self.game_communication_path: files go in this path to pass data between us and the actual game
        if "localappdata" in os.environ:
            self.game_communication_path = os.path.expandvars(r"%localappdata%/KHRECOM")
        else:
            self.game_communication_path = os.path.expandvars(r"$HOME/KHRECOM")
        if not os.path.exists(self.game_communication_path):
            os.makedirs(self.game_communication_path)
        for root, dirs, files in os.walk(self.game_communication_path):
            for file in files:
                if file.find("obtain") <= -1:
                    os.remove(root+"/"+file)

    async def server_auth(self, password_requested: bool = False):
        for root, dirs, files in os.walk(self.game_communication_path):
            for file in files:
                if file.find("obtain") <= -1:
                    os.remove(root+"/"+file)
        if password_requested and not self.password:
            await super(KHRECOMContext, self).server_auth(password_requested)
        await self.get_username()
        await self.send_connect()

    async def connection_closed(self):
        await super(KHRECOMContext, self).connection_closed()
        for root, dirs, files in os.walk(self.game_communication_path):
            for file in files:
                if file.find("obtain") <= -1:
                    os.remove(root + "/" + file)
        global item_num
        item_num = 1

    @property
    def endpoints(self):
        if self.server:
            return [self.server]
        else:
            return []

    async def shutdown(self):
        await super(KHRECOMContext, self).shutdown()
        for root, dirs, files in os.walk(self.game_communication_path):
            for file in files:
                if file.find("obtain") <= -1:
                    os.remove(root+"/"+file)
        global item_num
        item_num = 1

    def on_package(self, cmd: str, args: dict):
        if cmd in {"Connected"}:
            if not os.path.exists(self.game_communication_path):
                os.makedirs(self.game_communication_path)
            for ss in self.checked_locations:
                filename = f"send{ss}"
                with open(os.path.join(self.game_communication_path, filename), 'w') as f:
                    f.close()
            for key in list(args['slot_data'].keys()):
                with open(os.path.join(self.game_communication_path, key + ".cfg"), 'w') as f:
                    f.write(str(args['slot_data'][key]))
                    f.close()
        if cmd in {"ReceivedItems"}:
            start_index = args["index"]
            if start_index != len(self.items_received):
                global item_num
                for item in args['items']:
                    found = False
                    item_filename = f"AP_{str(item_num)}.item"
                    for filename in os.listdir(self.game_communication_path):
                        if filename == item_filename:
                            found = True
                    if not found:
                        with open(os.path.join(self.game_communication_path, item_filename), 'w') as f:
                            f.write(str(NetworkItem(*item).item) + "\n" + str(NetworkItem(*item).location) + "\n" + str(NetworkItem(*item).player))
                            f.close()
                            item_num = item_num + 1

        if cmd in {"RoomUpdate"}:
            if "checked_locations" in args:
                for ss in self.checked_locations:
                    filename = f"send{ss}"
                    with open(os.path.join(self.game_communication_path, filename), 'w') as f:
                        f.close()
    
    def on_deathlink(self, data: dict[str, object]):
        self.last_death_link = max(data["time"], self.last_death_link)
        text = data.get("cause", "")
        if text:
            logger.info(f"DeathLink: {text}")
        else:
            logger.info(f"DeathLink: Received from {data['source']}")
        # Publish complete contents atomically so Lua cannot read a partial write.
        marker = os.path.join(self.game_communication_path, 'dlreceive')
        try:
            with open(marker + '.tmp', 'w') as f:
                f.write(str(data["time"]))
            os.replace(marker + '.tmp', marker)
        except OSError:
            logger.exception("DeathLink: could not write the game bridge marker")

    def run_gui(self):
        """Import kivy UI system and start running it as self.ui_task."""
        from kvui import GameManager

        class KHRECOMManager(GameManager):
            logging_pairs = [
                ("Client", "Archipelago")
            ]
            base_title = "Archipelago KHRECOM Client"

        self.ui = KHRECOMManager(self)
        self.ui_task = asyncio.create_task(self.ui.async_run(), name="UI")



def death_marker_timestamp(filename: str) -> float:
    """Parse a legacy UTC marker or a precise Unix-time marker from Lua."""
    if filename.startswith("dlsend_"):
        timestamp = float(filename[len("dlsend_"):])
        if not math.isfinite(timestamp) or timestamp <= 0:
            raise ValueError("Invalid DeathLink timestamp")
        return timestamp
    suffix = filename[len("dlsend"):]
    if not filename.startswith("dlsend") or len(suffix) != 14 or not suffix.isdigit():
        raise ValueError("Invalid DeathLink filename")
    return float(timegm(time.strptime(suffix, '%Y%m%d%H%M%S')))


async def process_death_marker(ctx, root: str, filename: str):
    """Consume outgoing markers once; never interpret them as location checks."""
    marker = os.path.join(root, filename)
    try:
        timestamp = death_marker_timestamp(filename)
    except (ValueError, OverflowError):
        logger.warning("DeathLink: discarding malformed marker %s", filename)
    else:
        age = time.time() - timestamp
        # Integer UTC markers lose fractions of a second. Compare in the same
        # precision so a distinct later death in the same second is not lost.
        cutoff = ctx.last_death_link
        if not filename.startswith("dlsend_"):
            cutoff = int(cutoff)
        if 0 <= age < 10 and timestamp >= cutoff:
            if "DeathLink" in ctx.tags:
                if not ctx.server or not ctx.server.socket or ctx.slot is None:
                    return  # Keep it while a connection is being established.
                await ctx.send_death(death_text="Sora was defeated!")
        elif age < 0:
            logger.warning("DeathLink: discarding future marker %s (use UTC)", filename)
    try:
        os.remove(marker)
    except FileNotFoundError:
        pass



def publish_deathlink_state(ctx):
    """Give Lua a short-lived heartbeat reflecting connection and subscription."""
    active = bool("DeathLink" in ctx.tags and ctx.server and ctx.server.socket and ctx.slot is not None)
    target = os.path.join(ctx.game_communication_path, "dlstate.cfg")
    try:
        with open(target + ".tmp", "w") as state_file:
            state_file.write(f"{int(active)}\n{int(time.time())}\n")
        os.replace(target + ".tmp", target)
    except OSError:
        logger.exception("DeathLink: could not publish bridge state")


async def game_watcher(ctx: KHRECOMContext):
    from .Locations import lookup_id_to_name
    last_bridge_heartbeat = -1
    while not ctx.exit_event.is_set():
        global death_link
        if death_link and "DeathLink" not in ctx.tags:
            await ctx.update_death_link(death_link)
        if not death_link and "DeathLink" in ctx.tags:
            await ctx.update_death_link(death_link)
        heartbeat_second = int(time.time())
        if heartbeat_second != last_bridge_heartbeat:
            publish_deathlink_state(ctx)
            last_bridge_heartbeat = heartbeat_second
        if ctx.syncing == True:
            sync_msg = [{'cmd': 'Sync'}]
            if ctx.locations_checked:
                sync_msg.append({"cmd": "LocationChecks", "locations": list(ctx.locations_checked)})
            await ctx.send_msgs(sync_msg)
            ctx.syncing = False
        sending = []
        victory = False
        for root, dirs, files in os.walk(ctx.game_communication_path):
            for file in files:
                if file.startswith("dlsend"):
                    await process_death_marker(ctx, root, file)
                elif file.startswith("send") and file[4:].isdigit():
                    location_id = int(file[4:])
                    if location_id in lookup_id_to_name:
                        sending.append(location_id)
                elif file == "victory":
                    victory = True
        ctx.locations_checked = sending
        message = [{"cmd": 'LocationChecks', "locations": sending}]
        await ctx.send_msgs(message)
        if not ctx.finished_game and victory:
            await ctx.send_msgs([{"cmd": "StatusUpdate", "status": ClientStatus.CLIENT_GOAL}])
            ctx.finished_game = True
        await asyncio.sleep(0.1)


def launch():
    async def main(args):
        ctx = KHRECOMContext(args.connect, args.password)
        ctx.server_task = asyncio.create_task(server_loop(ctx), name="server loop")
        if gui_enabled:
            ctx.run_gui()
        ctx.run_cli()
        progression_watcher = asyncio.create_task(
            game_watcher(ctx), name="KHRECOMProgressionWatcher")

        await ctx.exit_event.wait()
        ctx.server_address = None

        await progression_watcher

        await ctx.shutdown()

    import colorama

    parser = get_base_parser(description="KHRECOM Client, for text interfacing.")

    args, rest = parser.parse_known_args()
    colorama.init()
    asyncio.run(main(args))
    colorama.deinit()
