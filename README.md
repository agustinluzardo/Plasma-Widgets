# Plasma 6 widgets

Two panel widgets for KDE Plasma 6, written natively for it.

- **Network Indicator** — the address you actually have, in the panel, with the
  details a panel cannot fit behind one click: public IPv4/IPv6, ISP, country
  flag, LAN address, gateway, interface, latency, which device traffic really
  leaves through, and your NetworkManager VPN profiles with connect/disconnect.
- **Pac-Man Workspaces** — your virtual desktops as a strip of Pac-Man, ghosts
  and pellets. Click a slot to switch, scroll to step through them.

They began as plugins for [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
on Hyprland, and calling them either a port or a rewrite would overstate one
half. What draws and what computes came across close to line-for-line — Pac-Man's
sprite geometry is the original's, arc for arc. What talks to the host was
written from scratch, because none of it transfers: representations, `KConfigXT`
settings, the icon theme, `libtaskmanager`, `NetworkManager`. Measured against
the originals, about 40% of the code here is inherited and 60% is new, and the
settings pages share not a single line.

That split is also where every bug lived: the representation that drew nothing,
the clicks that did nothing, the probe script that was a syntax error. None of
them were in the inherited code.

## Requirements

Plasma 6 (tested on 6.7) and KDE Frameworks 6. Nothing to compile.

Network Indicator shells out to `nmcli`, `ip`, `curl` and `ping`; all four are
present on any normal desktop install. Pac-Man Workspaces reads virtual desktops
through `org.kde.taskmanager`, which ships with plasma-workspace.

## Install

```sh
./install.sh
```

Copies both widgets to `~/.local/share/plasma/plasmoids/` and restarts
plasmashell through its systemd unit. Then: right-click the panel → **Add
Widgets** → *Network Indicator* / *Pac-Man Workspaces*.

## Network Indicator

The pill shows one address — local IP, public IP, gateway, interface, Wi-Fi
network, or just an icon. Click it for the panel.

- **Public connection** — IPv4 and IPv6, ISP, location, and the flag of the
  country your public address geolocates to, so it follows a VPN.
- **Local network** — LAN address, gateway, interface, latency.
- **Tunnel** — the address and device traffic *actually* leaves through,
  measured from the routing table rather than taken from the VPN's own word for
  it. It can tell you a tunnel is connected but carrying nothing, which the VPN
  service itself cannot.
- **VPN** — every NetworkManager profile, whether it connects at boot, and
  connect/disconnect.
- **Privacy mode** — masks every address with one click, for screenshots.

Left-click opens the panel, middle-click refreshes (or swaps the local address
between router and tunnel, if you set it to), right-click is left to Plasma for
the widget's own menu.

The public lookup walks a chain of providers, so one being down or rate-limiting
your address is not the end of it, and reports the HTTP status when they all
refuse.

## Pac-Man Workspaces

Pac-Man sits on the focused desktop, ghosts on the others, pellets on the rest.
Everything is drawn with `QtQuick.Shapes` — vector geometry in the scene graph,
no raster backing store, so it survives suspend, DPMS and output hotplug.

- **Ghosts** on the desktops behind you, on the ones with windows open, or on
  every other one. Blinky, Pinky, Inky and Clyde in the cabinet's exact colours,
  or your Plasma colour scheme.
- **Frightened ghosts** — going back to a lower desktop counts as eating an
  energizer: they turn blue for a few seconds, then flash white.
- **Maze background** — an optional corridor or a pair of rails behind the
  strip, in the cabinet's blue or a colour you pick.
- **Arcade or smooth animation**, or none — and with animations off, an optional
  pellet in Pac-Man's frozen open mouth, which is what the arcade frame shows at
  that moment.

## Tests

```sh
tests/run.sh
```

138 checks. They **render the widgets and count pixels**, because the questions
that matter here are not the ones a construction test asks: this widget once
loaded, reported a size, raised no error, and drew nothing at all. The suite
also runs the applets through Plasma's own representation path, syntax-checks
every shell command the widgets generate, and drives the network layer with a
fake `nmcli`/`curl` in `tests/fakebin/`.

`DECISIONS.md` records what each of those checks is defending against, and why —
including several bugs that shipped precisely because nothing was measuring the
thing that broke.

## Troubleshooting

```sh
./diagnostico.sh
```

Prints versions, QML errors since the currently installed build (separating
Plasma's own noise from anything real), which widgets are in each panel, the
HTTP status of every public-IP provider, and how the distro logo resolves.

## License and trademarks

MIT — see [LICENSE](LICENSE).

PAC-MAN is a trademark of Bandai Namco Entertainment Inc. This project is not
affiliated with, endorsed by, or sponsored by Bandai Namco. The Pac-Man
Workspaces widget is an unofficial, non-commercial fan work: it contains no
code, art or assets from any Pac-Man game — the sprites are drawn from
geometry in QML — and it is distributed free of charge.
