# NixOS Gaming PC Configuration

A flake-based NixOS configuration for a high-performance AMD gaming PC.

## Hardware

| Component   | Spec                          |
|-------------|-------------------------------|
| CPU         | AMD Ryzen 5 5600G             |
| GPU         | AMD Radeon RX 7900 XTX        |
| Motherboard | ASRock B550M-ITX/ac           |
| RAM         | 32 GB                         |
| Display     | 3440x1440 @ 100Hz (ultrawide) |

## Structure

```
nixos-config/
├── flake.nix                   # Flake entrypoint — inputs & outputs
├── hardware-configuration.nix  # Machine-specific hardware (you generate this)
├── README.md                   # This file
└── modules/
    ├── core.nix        # Bootloader, locale, users, Nix settings, base packages
    ├── desktop.nix     # KDE Plasma 6, SDDM, PipeWire, Bluetooth, desktop apps
    ├── gaming.nix      # Steam, GameMode, Proton, Discord, gaming tools, Apollo
    ├── gpu.nix         # AMDGPU driver, LACT, ROCm, Vulkan, VA-API
    ├── networking.nix  # NetworkManager, firewall, DNS, NTP
    ├── browsers.nix    # Firefox (with extensions) and Brave
    └── home.nix        # Home Manager: LazyVim, KDE top panel, Kitty, shell, Git
```

---

## Flake Inputs

| Input            | Purpose                                                     |
|------------------|-------------------------------------------------------------|
| `nixpkgs`        | `nixos-unstable` — latest packages                          |
| `nixos-hardware` | Hardware-specific NixOS modules (AMD CPU/GPU, SSD)          |
| `lact`           | LACT flake for up-to-date RDNA3 GPU control support         |
| `home-manager`   | User environment manager — dotfiles, services, shell config |
| `plasma-manager` | Declarative KDE Plasma configuration via Home Manager       |

---

## First-Time Setup

These steps assume you have already installed NixOS with KDE using the graphical
installer and have booted into your new desktop. You do not need a live ISO.

### 1. Enable flakes in your current session

The graphical installer produces a classic (non-flake) config. Before doing
anything else, enable flakes for the current shell session so you can use
`nix` commands:

```sh
export NIX_CONFIG="experimental-features = nix-command flakes"
```

### 2. Install git

Git is needed to clone this repo. If it isn't already available:

```sh
nix-shell -p git
```

### 3. Clone this repo

Pick a home for the config — `/etc/nixos/nixos-config` keeps everything in the
standard NixOS location:

```sh
sudo git clone https://github.com/youruser/nixos-config /etc/nixos/nixos-config
# or copy from wherever you already have the files:
sudo cp -r /path/to/nixos-config /etc/nixos/nixos-config
```

### 4. Replace the hardware configuration

Your running system already has a generated `hardware-configuration.nix` at
`/etc/nixos/hardware-configuration.nix`. Copy it over the stub in this repo:

```sh
sudo cp /etc/nixos/hardware-configuration.nix \
        /etc/nixos/nixos-config/hardware-configuration.nix
```

Open the file and confirm it looks correct — it should list your actual disk
UUIDs, NVMe modules, and CPU settings rather than the placeholder values in the
stub.

### 5. Personalise the config

There are a small number of values you need to set before building. Open each
file noted below in your editor of choice.

**`modules/core.nix`** — confirm the username matches the account created during
the graphical install:

```nix
users.users.jon = { ... };
```

**`modules/networking.nix`** — set the hostname to whatever you like:

```nix
networking.hostName = "tallgeese";
```

**`modules/core.nix`** — confirm the timezone:

```nix
time.timeZone = "America/Los_Angeles";
# find yours with: timedatectl list-timezones | grep <City>
```

**`modules/home.nix`** — confirm the username and home directory match:

```nix
home.username    = "jon";
home.homeDirectory = "/home/jon";
```

**`modules/home.nix`** — set your Git identity:

```nix
programs.git = {
  userName  = "Your Name";
  userEmail = "you@example.com";
};
```

**`flake.nix`** — confirm the Home Manager user key matches your username:

```nix
users.jon = import ./modules/home.nix;
```

### 6. Do a dry run

Before applying anything, do a dry build to make sure the config evaluates
without errors:

```sh
cd /etc/nixos/nixos-config
sudo nixos-rebuild dry-build --flake .#gaming-pc
```

Fix any evaluation errors before continuing. Common causes are a missing package
name (nixpkgs unstable moves fast) or a hardware-configuration.nix value that
doesn't match reality.

### 7. Apply the configuration

```sh
sudo nixos-rebuild switch --flake /etc/nixos/nixos-config#gaming-pc
```

This will take a while on the first run — it needs to download and build a large
number of packages. Subsequent rebuilds are much faster because most outputs are
cached.

### 8. Log out and back in

Several things only take full effect after a fresh login:

- **plasma-manager** writes KDE config files at login time — the top panel,
  shortcuts, and colour scheme won't appear until you log out and back in
- **Home Manager** user packages and shell config become active in new shells
  after the rebuild, but a fresh login ensures everything is clean

---

## Rebuilding After Changes

Once you have the config applied, the day-to-day workflow is:

```sh
# Apply changes immediately (also applies home.nix changes)
sudo nixos-rebuild switch --flake /etc/nixos/nixos-config#gaming-pc

# Short alias — available once home.nix is active
rebuild

# Build but don't switch yet — activates on next reboot
sudo nixos-rebuild boot --flake /etc/nixos/nixos-config#gaming-pc

# Check what would change without building anything
sudo nixos-rebuild dry-build --flake /etc/nixos/nixos-config#gaming-pc
```

Because Home Manager is wired in as a NixOS module, **`nixos-rebuild switch`
also applies your `home.nix` changes** — there is no separate
`home-manager switch` step.

---

## Desktop — KDE Plasma 6

The desktop is KDE Plasma 6 on Wayland via SDDM. `services.xserver` is not
enabled — there is no X server. XWayland provides compatibility for apps that
haven't been ported to Wayland yet (including most games) without running a
separate X session.

### Taskbar at the top

The panel is configured via `plasma-manager` in `modules/home.nix` and placed at
the **top** of the screen. It contains (left → right):

- **Kickoff** application launcher
- **Window title** of the active application
- Spacer
- **Icon task manager** (pinned apps + open windows, centred)
- Spacer
- **System tray** (volume, network, Bluetooth)
- **Digital clock**

To change the layout, edit the `programs.plasma.panels` block in `home.nix`.
Changes take effect after logging out and back in.

### plasma-manager notes

- `plasma-manager` writes KDE config files at login time via Home Manager.
- Changes to `programs.plasma` in `home.nix` **require a log-out/log-in** cycle
  to take effect — they cannot update a live session.
- If you want Plasma to reset all unmanaged settings to defaults on every login,
  enable `programs.plasma.overrideConfig = true;` in `home.nix`. Be aware this
  will wipe any settings you made interactively that aren't in the Nix config.
- To capture your current KDE configuration as Nix code (useful for migrating
  existing tweaks), run:
  ```sh
  nix run github:nix-community/plasma-manager
  ```

---

## Browsers

### Firefox

Firefox is managed via the `programs.firefox` NixOS module in `modules/browsers.nix`.
The following extensions are **automatically installed** for every user on the system:

| Extension                    | Mode               | Purpose                                                       |
|------------------------------|--------------------|---------------------------------------------------------------|
| **uBlock Origin**            | `force_installed`  | Ad and tracker blocker (MV2, stays in Firefox)                |
| **Multi-Account Containers** | `force_installed`  | Isolate sites into colour-coded containers                    |
| **Facebook Container**       | `normal_installed` | Automatically quarantines Facebook into its own container     |
| **1Password**                | `normal_installed` | Browser extension — requires the desktop app running          |
| **KDE Plasma Integration**   | `force_installed`  | Media controls and notifications in the KDE taskbar           |
| **SponsorBlock**             | `normal_installed` | Skip YouTube sponsorship segments automatically               |

`force_installed` extensions cannot be disabled without editing this config.
`normal_installed` extensions can be removed by the user at any time.

Additional Firefox preferences are set via policy (see `browsers.nix`) including:

- DNS over HTTPS via Cloudflare
- Enhanced Tracking Protection with fingerprinting and cryptomining blocking
- WebRender GPU compositing forced on
- VA-API hardware video decoding enabled
- Pocket and telemetry disabled

### Brave

Brave is installed as a system package. Because Brave is Chromium-based it does
not support declarative extension management from NixOS. Install extensions
manually from the Chrome Web Store after first launch. Recommended extensions:

- **uBlock Origin** — `cjpalhdlnbpafiamejdnhcphjbkeiagm`
- **KDE Plasma Integration** — `cimiefiiaegbelhefglklhhbackokmgm`
- **SponsorBlock** — `mnjggcdmjocbbbhaepdhchncahnbgone`
- **1Password** — `aeblfdkhhhdcdjpifhhbdiojplfjncoa`

---

## Neovim / LazyVim

Neovim is installed as a system package (`core.nix`). The LazyVim configuration
is managed by Home Manager in `modules/home.nix`.

### How it works

1. Home Manager writes the LazyVim bootstrap `init.lua` to `~/.config/nvim/`.
2. On the **first `nvim` launch**, `lazy.nvim` is cloned from GitHub and then
   downloads and compiles all LazyVim plugins into `~/.local/share/nvim/lazy/`.
   This requires an internet connection and takes about 30–60 seconds.
3. All **external tools** (LSP servers, formatters, linters) are installed via
   Nix in `home.packages` so they are always on `PATH` without needing Mason.

### First launch

```sh
nvim
# Wait for lazy.nvim to finish installing plugins (watch the bottom status bar)
# Restart nvim once after it finishes to let everything initialise cleanly
```

### Updating plugins

```sh
# Inside nvim:
:Lazy update

# Or from the terminal:
nvim --headless "+Lazy! update" +qa
```

### Customising

| What to change           | Where                                      |
|--------------------------|--------------------------------------------|
| Options (tab size, etc.) | `~/.config/nvim/lua/config/options.lua`    |
| Keymaps                  | `~/.config/nvim/lua/config/keymaps.lua`    |
| Add / override plugins   | `~/.config/nvim/lua/plugins/*.lua`         |
| Change LSP servers       | Edit `home.packages` in `modules/home.nix` |

The `options.lua` and `keymaps.lua` files are seeded by Home Manager on first
activation but **are not overwritten on subsequent rebuilds** — edit them freely.
Only `init.lua` is regenerated on every rebuild.

### Installed LSP servers (via Nix)

| Language      | Server                         |
|---------------|--------------------------------|
| Lua           | `lua-language-server`          |
| Nix           | `nil` + `nixd`                 |
| Bash / Shell  | `bash-language-server`         |
| TypeScript    | `typescript-language-server`   |
| HTML/CSS/JSON | `vscode-langservers-extracted` |
| Python        | `pyright`                      |
| Rust          | `rust-analyzer`                |

---

## Gaming Features

### Steam + GameMode (automatic)

GameMode is applied to **every game launched through Steam** automatically — no
per-game launch options needed. When a game starts, GameMode will:

- Raise the game process's CPU priority (`renice 10`)
- Switch the AMDGPU power level to `high`
- Pin CPU cores to the game process
- Suppress the screensaver
- Send a desktop notification when the session starts and ends

You can also invoke GameMode manually for any application:

```sh
gamemoderun ./my-game
gamemoderun wine game.exe
```

Check GameMode status:

```sh
gamemoded -s            # Is the daemon running?
gamemode-simulate-game  # Test that it activates correctly
```

### MangoHud (in-game overlay)

MangoHud shows FPS, frame times, GPU/CPU usage, and temperatures as an
in-game overlay.

**Enable for a specific game in Steam** — add to that game's launch options:

```
mangohud %command%
```

**Enable globally for all Vulkan games** — edit `modules/gaming.nix`:

```nix
programs.mangohud.enableSessionWide = true;
```

Configure MangoHud by editing `~/.config/MangoHud/MangoHud.conf`, or use
**GOverlay** (included) to tweak settings visually.

### Gamescope

Gamescope is a micro-compositor that can enforce resolution/refresh rate, enable
VRR/FreeSync, and provides an HDR path. Use it via Steam launch options:

```
# Native resolution, 100 Hz
gamescope -W 3440 -H 1440 -r 100 -- %command%

# FSR upscaling from 1080p to ultrawide
gamescope -W 3440 -H 1440 -w 2560 -h 1080 -r 100 -F fsr -- %command%
```

### Proton / GE-Proton

`proton-ge-bin` is pre-installed. To use it for a game:

1. Right-click the game in Steam → **Properties** → **Compatibility**
2. Check **Force the use of a specific Steam Play compatibility tool**
3. Select **GE-Proton** from the dropdown

**Proton Plus** (also installed) provides a GUI for downloading and managing
multiple Proton and Wine-GE builds without editing launch options.

### Lossless Scaling Frame Generation (`lsfg-vk`)

`lsfg-vk` is a Vulkan layer that adds software frame generation to any game.
Use `lsfg-vk-ui` to configure the multiplier and settings. It works by
intercepting the Vulkan present queue — no game-side support required.

### Ludusavi

`ludusavi` is a game save backup and restore tool. It knows the save locations
for thousands of games and can back them up to any local or network path.
Run it from the application menu or via `ludusavi` in the terminal.

### Apollo game streaming

Apollo is a Sunshine-compatible game streaming host. It allows clients such as
your Steam Deck running Moonlight to stream games from this PC over the network.

The Apollo service is enabled in `gaming.nix` with `openFirewall = true`. All
required ports are also declared explicitly in `networking.nix`:

| Ports         | Protocol | Purpose                        |
|---------------|----------|--------------------------------|
| 47984–47990   | TCP      | HTTPS/HTTP management web UI   |
| 48010         | TCP      | RTSP stream negotiation        |
| 47998–48000   | UDP      | Video, control, and audio data |

**Display switching for streaming:**

When streaming to a Steam Deck docked to a TV, you want the stream to originate
from a 1080p@60 output rather than your 3440x1440@100 ultrawide. DisplayPort-2
is reserved for this purpose. The Apollo systemd service drop-in in `gaming.nix`
runs `wlr-randr` hooks that enable DP-2 at 1080p@60 before a session starts and
disable it when the session ends.

Before relying on this, verify the connector name on your system:

```sh
kscreen-doctor --outputs
# or
wlr-randr
```

If the connector is named differently from `DP-2`, update the `ExecStartPre`
and `ExecStopPost` commands in the `systemd.services.apollo` block in
`modules/gaming.nix`.

The Apollo web UI is available at **https://localhost:47990** after the service
starts. Use it to configure display, encoding, and client access settings.

---

## LACT — GPU Control

LACT (Linux AMDGPU Control Application) lets you adjust:

- GPU clock speeds (overdrive / underclock)
- Memory clock speeds
- Core and memory voltage (undervolt)
- Power limit
- Custom fan curves
- Thermal throttling thresholds

The `lactd` daemon is enabled via the LACT flake's own NixOS module
(`services.lact.enable = true` in `gpu.nix`) and starts automatically at boot.

### Starting LACT

Open LACT from the application launcher or run:

```sh
lact gui
```

### Checking the daemon

```sh
systemctl status lact      # Is the daemon running?
journalctl -u lact -f      # Live daemon logs
```

### Important: ppfeaturemask

The kernel parameter `amdgpu.ppfeaturemask=0xffffffff` (set in `core.nix`) and
the matching `modprobe` option (in `gpu.nix`) unlock **all** amdgpu power
management features. Without this, LACT cannot change clocks or fan curves on
RDNA3 GPUs. Do not remove these options.

---

## Display Configuration

KDE Plasma on Wayland manages display configuration internally. Set your
resolution, refresh rate, and arrangement once in
**System Settings → Display and Monitor** and KDE will persist it across reboots
in `~/.local/share/kscreen/`.

To inspect outputs from the terminal:

```sh
kscreen-doctor --outputs   # KDE Wayland display info
wlr-randr                  # Low-level Wayland output info
```

If you add or change monitors, re-apply the display settings in System Settings
and log out and back in to ensure everything is applied cleanly.

---

## Syncthing

Syncthing and its tray applet are both managed in `home.nix`. The daemon runs as
a **user systemd service** that starts on login under jon's UID.

```sh
systemctl --user status syncthing    # Check service status
systemctl --user restart syncthing   # Restart the daemon
```

The web UI is available at **http://localhost:8384**. Add remote devices and
shared folders there on first run. The `syncthing-tray` applet in the system
tray gives quick access without opening the browser.

---

## Shell Aliases

These are defined in `modules/home.nix` and available in every Bash session:

| Alias        | Expands to                                              |
|--------------|---------------------------------------------------------|
| `rebuild`    | `sudo nixos-rebuild switch --flake ...#gaming-pc`       |
| `rebuild-b`  | `sudo nixos-rebuild boot --flake ...#gaming-pc`         |
| `nix-gc`     | `sudo nix-collect-garbage -d && nix-collect-garbage -d` |
| `flake-up`   | `cd /etc/nixos/nixos-config && nix flake update`        |
| `ls`         | `eza --icons --group-directories-first`                 |
| `ll`         | `eza -lah --icons --group-directories-first --git`      |
| `lt`         | `eza --tree --icons --level=2`                          |
| `cat`        | `bat --style=auto`                                      |
| `v` / `vim`  | `nvim`                                                  |
| `lg`         | `lazygit`                                               |

---

## Useful Commands

| Task                             | Command                                                                   |
|----------------------------------|---------------------------------------------------------------------------|
| GPU info (Vulkan)                | `vulkaninfo --summary`                                                    |
| GPU info (ROCm)                  | `rocminfo`                                                                |
| OpenCL devices                   | `clinfo`                                                                  |
| GPU usage (terminal overlay)     | `nvtop`                                                                   |
| AMD GPU stats                    | `radeontop`                                                               |
| GPU temp/clocks (ROCm)           | `rocm-smi`                                                                |
| Check VA-API (video decode)      | `vainfo`                                                                  |
| List Wayland outputs             | `kscreen-doctor --outputs`                                                |
| GameMode status                  | `gamemoded -s`                                                            |
| Apollo web UI                    | `https://localhost:47990`                                                 |
| Syncthing web UI                 | `http://localhost:8384`                                                   |
| Capture KDE config as Nix        | `nix run github:nix-community/plasma-manager`                             |
| List Nix generations             | `sudo nix-env --list-generations --profile /nix/var/nix/profiles/system` |
| Roll back to previous generation | `sudo nixos-rebuild switch --rollback`                                    |
| Garbage collect old generations  | `sudo nix-collect-garbage -d`                                             |
| Update all flake inputs          | `nix flake update`                                                        |
| Update a single flake input      | `nix flake lock --update-input lact`                                      |

---

## Troubleshooting

**Build fails with "experimental features" error**
- Run `export NIX_CONFIG="experimental-features = nix-command flakes"` first,
  or add `experimental-features = nix-command flakes` to `/etc/nix/nix.conf`
  and restart the nix-daemon: `sudo systemctl restart nix-daemon`

**Steam won't launch**
- Check `~/.steam/steam/logs/` for errors
- Run `vulkaninfo --summary` and confirm RADV is listed as a Vulkan device
- Ensure 32-bit libraries are present: `ls /run/opengl-driver-32/lib/`

**LACT shows no device / can't change clocks**
- Verify the daemon is running: `systemctl status lact`
- Check `dmesg | grep amdgpu` for driver errors
- Confirm ppfeaturemask is active: `cat /proc/cmdline | grep ppfeaturemask`

**No sound**
- Check PipeWire status: `systemctl --user status pipewire pipewire-pulse`
- Restart it: `systemctl --user restart pipewire pipewire-pulse`
- Verify device visibility: `wpctl status`

**Wrong display resolution**
- Set your resolution in **System Settings → Display and Monitor**
- Log out and back in to apply cleanly
- Check what KDE sees: `kscreen-doctor --outputs`

**KDE panel not at the top after first login**
- `plasma-manager` applies config at login time — log out and back in after
  the first `nixos-rebuild switch` if the panel is still at the bottom
- If the panel is duplicated (old bottom + new top), right-click the old panel,
  select **Remove Panel**, then log out and back in

**KDE Connect not finding phone**
- Ensure TCP and UDP ports 1714–1764 are open (configured in `networking.nix`)
- Confirm both devices are on the same network segment (not guest WiFi)

**Apollo streaming not connecting**
- Check the service is running: `systemctl status apollo`
- Open the web UI at `https://localhost:47990` and verify client PIN pairing
- Confirm the firewall ports are open: `sudo nft list ruleset | grep 47`
- Verify the DP-2 connector name matches your hardware: `kscreen-doctor --outputs`

**LazyVim plugins not installing**
- Ensure you have an internet connection on first launch
- Run `:checkhealth lazy` inside nvim to diagnose issues
- Check that `gcc` and `git` are on PATH: `which gcc git`

**Neovim LSP not working for a language**
- Run `:LspInfo` inside nvim to see which servers are attached
- Ensure the language server binary is on PATH: e.g. `which lua-language-server`

**Firefox extensions not installing**
- Extensions installed via policy require an internet connection at first launch
- Check `about:policies` in Firefox to confirm policies are being applied
- If an extension shows as blocked, check `about:support` for policy errors