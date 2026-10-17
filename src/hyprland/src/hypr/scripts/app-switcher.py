#!/usr/bin/env python3
"""⌘Tab app switcher for Hyprland that behaves like the one on a Mac.

Runs as a small daemon (`scripts/app-switcher daemon`, started at login) and takes commands
from key bindings (`scripts/app-switcher next` ...) on $XDG_RUNTIME_DIR/hyprlain-switcher.sock,
so it never needs keyboard focus:

  next, prev   step through apps, most recently used first. The first ⌘Tab already selects
               the previous app, so a quick tap flips between the last two.
  grave        ⌘`: steps backwards while the switcher is open, otherwise moves between the
               windows of the focused app.
  commit       switch to the selected app (bound to releasing ⌘). Minimized or hidden
               windows come back to the current desktop.
  cancel       close without switching (⌘Esc).
  quit         ⌘Q while the switcher is open quits the selected app; replies 1 when it did.
  overview     ⌃↑ Mission Control: the windows of the current desktop and a bar of
               desktops; click or Return to go there, Esc or ⌃↑ to leave.

The strip only appears when ⌘ is held for a moment, as on a Mac.
"""
import json
import os
import socket
import subprocess

import gi

gi.require_version("Gdk", "4.0")
gi.require_version("Graphene", "1.0")
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gdk, Gio, GLib, Graphene, Gtk, Gtk4LayerShell as LayerShell  # noqa: E402

try:  # GLib 2.86 moved DesktopAppInfo to GioUnix
    gi.require_version("GioUnix", "2.0")
    from gi.repository import GioUnix  # noqa: E402
    DesktopAppInfo = GioUnix.DesktopAppInfo
except (ImportError, ValueError):
    DesktopAppInfo = Gio.DesktopAppInfo

SOCKET = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "hyprlain-switcher.sock")
SHOW_DELAY_MS = 160
ICON_SIZE = 72

CSS = b"""
window.switcher { background: transparent; }
.strip {
    background-color: rgba(0, 0, 0, 0.90);
    border: 2px solid #CE7688;
    padding: 14px;
}
.app { padding: 10px 12px; border-bottom: 2px solid transparent; }
.app.selected { background-color: #381E24; border-bottom: 2px solid #CE7688; }
.app label {
    color: #965363;
    font-family: "AdwaitaMono Nerd Font";
    font-size: 12px;
    margin-top: 6px;
}
.app.selected label { color: #C1B48E; }

window.mission-control { background-color: rgba(0, 0, 0, 0.78); }
.spaces { margin: 18px 0px 10px 0px; }
.spaces button {
    background: rgba(26, 26, 26, 0.95);
    border: 2px solid #5D333C;
    border-radius: 0px;
    color: #965363;
    padding: 6px 18px;
    margin: 0px 4px;
    font-family: "AdwaitaMono Nerd Font";
}
.spaces button.current { border-color: #CE7688; color: #C1B48E; }
.spaces button:hover { background: #381E24; }
flowbox { padding: 20px 40px; }
flowboxchild { padding: 0px; border-radius: 0px; background: transparent; }
.card { border: 2px solid #5D333C; background: #000000; padding: 0px; }
flowboxchild:selected .card, flowboxchild:hover .card { border-color: #CE7688; }
.card label {
    color: #C1B48E;
    font-family: "AdwaitaMono Nerd Font";
    font-size: 12px;
    padding: 4px 8px;
}
.empty { color: #965363; font-family: "AdwaitaMono Nerd Font"; font-size: 16px; }
"""


def hyprctl(*args):
    result = subprocess.run(["hyprctl", *args], capture_output=True, text=True)
    return result.stdout


def hyprctl_json(*args):
    try:
        return json.loads(hyprctl("-j", *args) or "null")
    except json.JSONDecodeError:
        return None


def desktop_entries():
    """Map lowercase window class names to desktop entries."""
    entries = {}
    for info in Gio.AppInfo.get_all():
        if not isinstance(info, DesktopAppInfo):
            continue
        keys = {(info.get_id() or "").removesuffix(".desktop").lower()}
        wm_class = info.get_startup_wm_class()
        if wm_class:
            keys.add(wm_class.lower())
        for key in keys:
            if key:
                entries.setdefault(key, info)
    return entries


class Switcher(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.hyprlain.switcher", flags=Gio.ApplicationFlags.NON_UNIQUE)
        self.apps = []        # [{"class", "name", "icon", "windows": [address, ...]}]
        self.index = 0
        self.active = False
        self.visible = False
        self.show_timer = 0
        self.entries = {}

    # --- setup -----------------------------------------------------------------------
    def do_activate(self):
        self.hold()
        self.entries = desktop_entries()
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        self.window = Gtk.Window(application=self)
        self.window.add_css_class("switcher")
        LayerShell.init_for_window(self.window)
        LayerShell.set_namespace(self.window, "hyprlain-switcher")
        LayerShell.set_layer(self.window, LayerShell.Layer.OVERLAY)
        LayerShell.set_keyboard_mode(self.window, LayerShell.KeyboardMode.NONE)
        self.strip = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.strip.add_css_class("strip")
        self.window.set_child(self.strip)
        self.mission_control = MissionControl(self)
        self.listen()

    def listen(self):
        if os.path.exists(SOCKET):
            probe = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            try:
                probe.connect(SOCKET)
                probe.close()
                self.quit()  # another switcher is already running
                return
            except OSError:
                os.unlink(SOCKET)
        self.server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.server.bind(SOCKET)
        self.server.listen(8)
        GLib.io_add_watch(self.server.fileno(), GLib.IO_IN, self.on_client)

    def on_client(self, *_):
        conn, _ = self.server.accept()
        with conn:
            command = conn.recv(64).decode(errors="ignore").strip()
            reply = self.handle(command)
            if reply is not None:
                conn.sendall(reply.encode())
        return True

    # --- commands --------------------------------------------------------------------
    def handle(self, command):
        if command in ("next", "prev"):
            self.step(1 if command == "next" else -1)
        elif command == "grave":
            if self.active:
                self.step(-1)
            else:
                self.cycle_app_windows()
        elif command == "commit":
            self.commit()
        elif command == "cancel":
            self.close()
        elif command == "quit":
            if not self.active:
                return "0"
            app = self.apps[self.index]
            for address in app["windows"]:
                hyprctl("dispatch", "closewindow", f"address:{address}")
            self.close()
            return "1"
        elif command == "overview":
            self.close()
            self.mission_control.toggle()
        elif command == "reload":
            self.entries = desktop_entries()
        return None

    def step(self, direction):
        if not self.active:
            self.apps = self.collect()
            if len(self.apps) < 2:
                self.apps = []
                return
            self.active = True
            self.index = 1 if direction > 0 else len(self.apps) - 1
            self.show_timer = GLib.timeout_add(SHOW_DELAY_MS, self.show)
        else:
            self.index = (self.index + direction) % len(self.apps)
        self.render()

    def commit(self):
        if not self.active:
            return
        app = self.apps[self.index]
        self.close()
        address = app["windows"][0]
        window = next((c for c in hyprctl_json("clients") or [] if c["address"] == address), None)
        if window and window["workspace"]["name"].startswith("special:"):
            workspace = (hyprctl_json("activeworkspace") or {}).get("id", 1)
            hyprctl("dispatch", "movetoworkspacesilent", f"{workspace},address:{address}")
        hyprctl("dispatch", "focuswindow", f"address:{address}")

    def close(self):
        if self.show_timer:
            GLib.source_remove(self.show_timer)
            self.show_timer = 0
        self.active = False
        self.visible = False
        self.window.set_visible(False)

    def cycle_app_windows(self):
        active = hyprctl_json("activewindow") or {}
        cls = active.get("class")
        if not cls:
            return
        windows = sorted((c for c in hyprctl_json("clients") or []
                          if c["class"] == cls and c["mapped"] and not c["workspace"]["name"].startswith("special:")),
                         key=lambda c: c["focusHistoryID"])
        if len(windows) > 1:
            hyprctl("dispatch", "focuswindow", f"address:{windows[-1]['address']}")

    # --- model and view --------------------------------------------------------------
    def collect(self):
        """Apps ordered by most recent use, each with its windows most recent first."""
        apps = {}
        for client in sorted(hyprctl_json("clients") or [], key=lambda c: c["focusHistoryID"]):
            cls = client.get("class") or ""
            if not cls or not client.get("mapped") or client["workspace"]["name"] == "special:magic":
                continue
            app = apps.get(cls)
            if app is None:
                entry = self.entries.get(cls.lower()) or self.entries.get(cls.lower().split(".")[-1])
                apps[cls] = app = {
                    "class": cls,
                    "name": entry.get_display_name() if entry else cls,
                    "icon": entry.get_icon() if entry else None,
                    "windows": [],
                }
            app["windows"].append(client["address"])
        return list(apps.values())

    def render(self):
        child = self.strip.get_first_child()
        while child:
            self.strip.remove(child)
            child = self.strip.get_first_child()
        for position, app in enumerate(self.apps):
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            box.add_css_class("app")
            if position == self.index:
                box.add_css_class("selected")
            if app["icon"]:
                image = Gtk.Image.new_from_gicon(app["icon"])
            else:
                image = Gtk.Image.new_from_icon_name(app["class"].lower())
            image.set_pixel_size(ICON_SIZE)
            label = Gtk.Label(label=app["name"])
            label.set_max_width_chars(12)
            label.set_ellipsize(3)  # Pango.EllipsizeMode.END
            box.append(image)
            box.append(label)
            click = Gtk.GestureClick()
            click.connect("released", self.on_click, position)
            box.add_controller(click)
            self.strip.append(box)

    def on_click(self, _gesture, _n, _x, _y, position):
        self.index = position
        self.commit()

    def show(self):
        self.show_timer = 0
        if self.active:
            self.visible = True
            self.window.set_visible(True)
        return False


class Thumbnail(Gtk.Widget):
    """Draws one window's part of the Mission Control screenshot, scaled to fit."""

    def __init__(self, texture, region, width):
        super().__init__()
        self.texture = texture
        self.region = region
        self.set_size_request(width, int(width * region[3] / region[2]))

    def do_snapshot(self, snapshot):
        x, y, w, h = self.region
        scale = min(self.get_width() / w, self.get_height() / h)
        left = (self.get_width() - w * scale) / 2
        top = (self.get_height() - h * scale) / 2
        snapshot.push_clip(Graphene.Rect().init(left, top, w * scale, h * scale))
        snapshot.append_texture(self.texture, Graphene.Rect().init(
            left - x * scale, top - y * scale, self.texture.get_width() * scale, self.texture.get_height() * scale))
        snapshot.pop()


class MissionControl:
    """⌃↑: snapshots of the current desktop's windows with a desktops bar above them."""

    def __init__(self, app):
        self.app = app
        self.window = Gtk.Window(application=app)
        self.window.add_css_class("mission-control")
        LayerShell.init_for_window(self.window)
        LayerShell.set_namespace(self.window, "hyprlain-mission-control")
        LayerShell.set_layer(self.window, LayerShell.Layer.OVERLAY)
        LayerShell.set_keyboard_mode(self.window, LayerShell.KeyboardMode.EXCLUSIVE)
        LayerShell.set_exclusive_zone(self.window, -1)
        for edge in (LayerShell.Edge.TOP, LayerShell.Edge.BOTTOM, LayerShell.Edge.LEFT, LayerShell.Edge.RIGHT):
            LayerShell.set_anchor(self.window, edge, True)
        keys = Gtk.EventControllerKey()
        keys.connect("key-pressed", self.on_key)
        self.window.add_controller(keys)
        click = Gtk.GestureClick()
        click.connect("released", self.on_background_click)
        self.window.add_controller(click)
        self.open = False

    def toggle(self):
        if self.open:
            self.close()
        else:
            self.show()

    def close(self):
        self.open = False
        self.window.set_visible(False)

    def show(self):
        monitor = next((m for m in hyprctl_json("monitors") or [] if m.get("focused")), None)
        if not monitor:
            return
        current = monitor["activeWorkspace"]["id"]
        clients = [c for c in hyprctl_json("clients") or []
                   if c.get("mapped") and c["workspace"]["id"] == current and c.get("class")]
        snapshot = self.capture(monitor["name"])

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        root.append(self.spaces_bar(current))
        if clients:
            flow = Gtk.FlowBox(homogeneous=False, selection_mode=Gtk.SelectionMode.SINGLE)
            flow.set_valign(Gtk.Align.CENTER)
            flow.set_halign(Gtk.Align.CENTER)
            flow.set_row_spacing(28)
            flow.set_column_spacing(28)
            flow.set_activate_on_single_click(True)
            flow.connect("child-activated", self.on_activate)
            width = monitor["width"] / monitor["scale"]
            columns = min(4, max(1, len(clients)))
            card_width = int(min(900, (width - 160) / columns - 40))
            flow.set_max_children_per_line(columns)
            for client in sorted(clients, key=lambda c: (c["at"][1], c["at"][0])):
                flow.append(self.card(client, monitor, snapshot, card_width))
            scroller = Gtk.ScrolledWindow(vexpand=True)
            scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            scroller.set_child(flow)
            root.append(scroller)
            GLib.idle_add(lambda: flow.get_child_at_index(0) and flow.select_child(flow.get_child_at_index(0)))
        else:
            empty = Gtk.Label(label="No windows on this desktop", vexpand=True)
            empty.add_css_class("empty")
            root.append(empty)
        self.window.set_child(root)
        self.open = True
        self.window.set_visible(True)

    def capture(self, output):
        """One uncompressed screenshot of the monitor, uploaded once as a texture."""
        try:
            ppm = subprocess.run(["grim", "-t", "ppm", "-o", output, "-"], capture_output=True, check=True).stdout
        except (OSError, subprocess.CalledProcessError):
            return None
        fields, offset = [], 0
        while len(fields) < 4:  # "P6", width, height, maxval, then one whitespace byte
            while ppm[offset:offset + 1].isspace():
                offset += 1
            end = offset
            while not ppm[end:end + 1].isspace():
                end += 1
            fields.append(ppm[offset:end])
            offset = end
        width, height = int(fields[1]), int(fields[2])
        data = GLib.Bytes.new(ppm[offset + 1:])
        return Gdk.MemoryTexture.new(width, height, Gdk.MemoryFormat.R8G8B8, data, width * 3)

    def spaces_bar(self, current):
        bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, halign=Gtk.Align.CENTER)
        bar.add_css_class("spaces")
        workspaces = sorted((w for w in hyprctl_json("workspaces") or [] if w["id"] > 0), key=lambda w: w["id"])
        for workspace in workspaces:
            button = Gtk.Button(label=f"Desktop {workspace['id']}")
            if workspace["id"] == current:
                button.add_css_class("current")
            button.connect("clicked", self.go_to_workspace, workspace["id"])
            bar.append(button)
        add = Gtk.Button(label="+")
        add.set_tooltip_text("New desktop")
        add.connect("clicked", self.go_to_workspace, max([w["id"] for w in workspaces] + [0]) + 1)
        bar.append(add)
        return bar

    def card(self, client, monitor, snapshot, width):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        box.add_css_class("card")
        picture = None
        if snapshot:
            scale = monitor["scale"]
            region = ((client["at"][0] - monitor["x"]) * scale, (client["at"][1] - monitor["y"]) * scale,
                      client["size"][0] * scale, client["size"][1] * scale)
            if region[2] > 0 and region[3] > 0:
                picture = Thumbnail(snapshot, region, width)
        if picture is None:
            picture = Gtk.Image.new_from_icon_name(client["class"].lower())
            picture.set_pixel_size(96)
            picture.set_size_request(width, int(width * 0.6))
        title = client.get("title") or client["class"]
        label = Gtk.Label(label=title, xalign=0)
        label.set_ellipsize(3)
        label.set_max_width_chars(48)
        box.append(picture)
        box.append(label)
        child = Gtk.FlowBoxChild()
        child.set_child(box)
        child.address = client["address"]
        return child

    def on_activate(self, _flow, child):
        self.close()
        hyprctl("dispatch", "focuswindow", f"address:{child.address}")

    def go_to_workspace(self, _button, workspace):
        self.close()
        hyprctl("dispatch", "workspace", str(workspace))

    def on_key(self, _controller, keyval, _keycode, _state):
        if keyval == Gdk.KEY_Escape:
            self.close()
            return True
        return False

    def on_background_click(self, gesture, _n, x, y):
        picked = self.window.pick(x, y, Gtk.PickFlags.DEFAULT)
        if picked is None or isinstance(picked, (Gtk.Window, Gtk.ScrolledWindow, Gtk.FlowBox)):
            self.close()


if __name__ == "__main__":
    Switcher().run([])
