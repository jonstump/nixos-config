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
    ├── gaming.nix      # Steam, GameMode, Proton, Discord, gaming tools
    ├── gpu.nix         # AMDGPU driver, LACT, ROCm, Vulkan, VA-API
    ├── networking.nix  # NetworkManager, firewall, DNS, NTP
    ├── browsers.nix    # Firefox (with extensions) and Brave
    └── home.nix        # Home Manager: LazyVim, KDE top panel, Kitty, shell, Git
```

---

## Flake Inputs

| Input            | Purpose                                                         |
|------------------|-----------------------------------------------------------------|
| `nixpkgs`        | `nixos-unstable` — latest packages                              |
| `nixos-hardware` | Hardware-specific NixOS modules (AMD CPU/GPU, SSD)              |
| `lact`           | LACT flake for up-to-date RDNA3 GPU control support             |
| `home-manager`   | User environment manager — dotfiles, services, shell config     |
| `plasma-manager` | Declarative KDE Plasma configuration via Home Manager           |

---

## First-Time Setup

### 1. Boot a NixOS live ISO

Download the latest NixOS ISO from https://nixos.org/download and boot into it.

### 2. Partition and mount your disks

```sh
# Example: single NVMe drive with EFI + root (adjust to taste)
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 512MB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary ext4 512MB 100%

mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mkfs.ext4 -L nixos  /dev/nvme0n1p2

mount /dev/disk/by-label/nixos  /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot   /mnt/boot
```

### 3. Generate hardware configuration

```sh
sudo nixos-generate-config --root /mnt
```

This writes `/mnt/etc/nixos/hardware-configuration.nix`. Copy its contents into
`hardware-configuration.nix` in this repo, replacing the stub file.

### 4. Personalise the config

**Your username** — in `modules/core.nix` and `modules/home.nix`, replace every
occurrence of `user` with your actual username:

```nix
# core.nix
users.users.yourname = { ... };

# home.nix
home.username    = "yourname";
home.homeDirectory = "/home/yourname";
```

Also update `flake.nix` where the Home Manager user is referenced:

```nix
users.user = import ./modules/home.nix;
# change to:
users.yourname = import ./modules/home.nix;
```

**Your timezone** — in `modules/core.nix`:

```nix
time.timeZone = "America/Chicago"; # timedatectl list-timezones | grep <City>
```

**Git identity** — in `modules/home.nix`:

```nix
programs.git = {
  userName  = "Your Name";
  userEmail = "you@example.com";
};
```

**Hostname** — already set to `tallgeese` in `modules/networking.nix`. Change it
to whatever you like.

### 5. Copy this repo to the target machine

```sh
cp -r /path/to/nixos-config /mnt/etc/nixos/
```

Or clone it directly:

```sh
nix-shell -p git
git clone https://github.com/youruser/nixos-config /mnt/etc/nixos/nixos-config
```

### 6. Install

```sh
sudo nixos-install --flake /mnt/etc/nixos/nixos-config#gaming-pc
```

### 7. Set a root password when prompted, then reboot

```sh
reboot
```

---

## Rebuilding After Changes

Once booted into your installed system:

```sh
# Apply changes and switch immediately (also runs home-manager)
sudo nixos-rebuild switch --flake /etc/nixos/nixos-config#gaming-pc

# Short alias — defined in your shell config via home.nix
rebuild

# Build without switching (dry run)
sudo nixos-rebuild dry-build --flake /etc/nixos/nixos-config#gaming-pc

# Build and activate on next reboot only
sudo nixos-rebuild boot --flake /etc/nixos/nixos-config#gaming-pc
```

Because Home Manager is wired in as a NixOS module, **`nixos-rebuild switch`
also applies your `home.nix` changes** — you do not need a separate
`home-manager switch` command.

---

## Desktop — KDE Plasma 6

The desktop is KDE Plasma 6 running on Wayland via SDDM. A few things to know:

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
  existing settings), run the `rc2nix` tool:
  ```sh
  nix run github:nix-community/plasma-manager
  ```

---

## Browsers

### Firefox

Firefox is managed via the `programs.firefox` NixOS module in `modules/browsers.nix`.
The following extensions are **automatically installed** for every user on the system:

| Extension                       | Purpose                                                  |
|---------------------------------|----------------------------------------------------------|
| **uBlock Origin**               | Ad and tracker blocker (MV2, stays in Firefox)           |
| **Multi-Account Containers**    | Isolate sites into colour-coded containers               |
| **Facebook Container**          | Automatically quarantines Facebook into its own container|
| **KDE Plasma Integration**      | Media controls and notifications in the KDE taskbar      |
| **SponsorBlock**                | Skip YouTube sponsorship segments automatically          |
| **1Password**                   | 1Password browser extension — requires the desktop app running for autofill |

Extensions marked `force_installed` cannot be disabled without editing this config.
Extensions marked `normal_installed` can be removed by the user at any time.

Additional Firefox preferences are set via policy (see `browsers.nix`) including:

- DNS over HTTPS via Cloudflare
- Enhanced Tracking Protection with fingerprinting and cryptomining blocking
- WebRender GPU compositing forced on
- VA-API hardware video decoding enabled
- Pocket and telemetry disabled

### Brave

Brave is installed as a system package. Because Brave is Chromium-based, it does
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
# Then restart nvim once to let everything initialise cleanly
```

### Updating plugins

```sh
# Inside nvim:
:Lazy update

# Or from the terminal:
nvim --headless "+Lazy! update" +qa
```

### Customising

| What to change            | Where                                        |
|---------------------------|----------------------------------------------|
| Options (tab size, etc.)  | `~/.config/nvim/lua/config/options.lua`      |
| Keymaps                   | `~/.config/nvim/lua/config/keymaps.lua`      |
| Add/override plugins      | `~/.config/nvim/lua/plugins/*.lua`           |
| Change LSP servers        | Edit `home.packages` in `modules/home.nix`   |

The `options.lua` and `keymaps.lua` files are seeded by Home Manager but **are
not overwritten on rebuild** — edit them freely after the first activation.
Only `init.lua` is managed by Home Manager and will be regenerated on rebuild.

### Installed LSP servers (via Nix)

| Language     | Server                                  |
|--------------|-----------------------------------------|
| Lua          | `lua-language-server`                   |
| Nix          | `nil` + `nixd`                          |
| Bash/Shell   | `bash-language-server`                  |
| TypeScript   | `typescript-language-server`            |
| HTML/CSS/JSON| `vscode-langservers-extracted`          |
| Python       | `pyright`                               |
| Rust         | `rust-analyzer`                         |

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

You can also launch any application with GameMode manually:

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

**Enable for a specific game in Steam:**

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

# FSR upscaling from 1080p to 1440p ultrawide
gamescope -W 3440 -H 1440 -w 2560 -h 1080 -r 100 -F fsr -- %command%
```

### Proton / GE-Proton

`proton-ge-bin` is pre-installed. To use it for a game:

1. Right-click the game in Steam → **Properties** → **Compatibility**
2. Check **Force the use of a specific Steam Play compatibility tool**
3. Select **GE-Proton** from the dropdown

**Proton Plus** (also installed) provides a GUI for downloading and managing
multiple Proton/Wine-GE builds without editing launch options.

### Lossless Scaling Frame Generation (`lsfg-vk`)

`lsfg-vk` is a Vulkan layer that adds software frame generation to any game.
Use `lsfg-vk-ui` to configure multiplier and settings. It works by intercepting
the Vulkan present queue — no game-side support required.

### Ludusavi

`ludusavi` is a game save backup and restore tool. It knows the save locations
for thousands of games and can back them up to any local or network path.
Run it from the application menu or via `ludusavi` in the terminal.

---

## LACT — GPU Control

LACT (Linux AMDGPU Control Application) lets you adjust:

- GPU clock speeds (overdrive / underclock)
- Memory clock speeds
- Core and memory voltage (undervolt)
- Power limit
- Custom fan curves
- Thermal throttling thresholds

### Starting LACT

The `lactd` daemon starts automatically at boot. Open the GUI from your
application launcher or run:

```sh
lact gui
```

### Checking the daemon

```sh
systemctl status lactd     # Is the daemon running?
journalctl -u lactd -f     # Live daemon logs
```

### Important: ppfeaturemask

The kernel parameter `amdgpu.ppfeaturemask=0xffffffff` (set in `core.nix`) and
the matching `modprobe` option (in `gpu.nix`) unlock **all** amdgpu power
management features. Without this, LACT cannot change clocks or fan curves on
RDNA3 GPUs. Do not remove these options.

---

## Display Configuration

The config targets a single `3440x1440 @ 100Hz` display. If your DisplayPort
output is on a different connector, adjust the `xrandr` command in
`modules/desktop.nix`:

```nix
services.xserver.displayManager.setupCommands = ''
  ${pkgs.xorg.xrandr}/bin/xrandr --output DisplayPort-1 --mode 3440x1440 --rate 100
'';
```

To list available outputs from a running session:

```sh
xrandr --query         # X11 / XWayland
kscreen-doctor --outputs  # Wayland (KDE)
```

Under native Wayland, KDE stores display configuration in
`~/.local/share/kscreen/`. Set your resolution once in
**System Settings → Display and Monitor** and it will persist.

---

## Syncthing

Syncthing runs as a **user systemd service** (started via Home Manager in
`home.nix`) — it launches on login and runs under your UID.

```sh
systemctl --user status syncthing   # Check service status
systemctl --user restart syncthing  # Restart the daemon
```

The web UI is available at **http://localhost:8384**. Add remote devices and
shared folders there on first run. The `syncthing-tray` system tray icon
(installed in `desktop.nix`) gives quick access without opening the browser.

---

## Shell Aliases

These are defined in `modules/home.nix` and available in every Bash session:

| Alias       | Expands to                                                          |
|-------------|---------------------------------------------------------------------|
| `rebuild`   | `sudo nixos-rebuild switch --flake ...#gaming-pc`                   |
| `rebuild-b` | `sudo nixos-rebuild boot --flake ...#gaming-pc`                     |
| `nix-gc`    | `sudo nix-collect-garbage -d && nix-collect-garbage -d`             |
| `flake-up`  | `cd /etc/nixos/nixos-config && nix flake update`                    |
| `ls`        | `eza --icons --group-directories-first`                             |
| `ll`        | `eza -lah --icons --group-directories-first --git`                  |
| `lt`        | `eza --tree --icons --level=2`                                      |
| `cat`       | `bat --style=auto`                                                  |
| `v` / `vim` | `nvim`                                                              |
| `lg`        | `lazygit`                                                           |

---

## Useful Commands

| Task                             | Command                                                      |
|----------------------------------|--------------------------------------------------------------|
| GPU info (Vulkan)                | `vulkaninfo --summary`                                       |
| GPU info (ROCm)                  | `rocminfo`                                                   |
| OpenCL devices                   | `clinfo`                                                     |
| GPU usage (terminal overlay)     | `nvtop`                                                      |
| AMD GPU stats                    | `radeontop`                                                  |
| GPU temp/clocks (ROCm)           | `rocm-smi`                                                   |
| Check VA-API (video decode)      | `vainfo`                                                     |
| GameMode status                  | `gamemoded -s`                                               |
| Syncthing web UI                 | `http://localhost:8384`                                      |
| Capture KDE config as Nix        | `nix run github:nix-community/plasma-manager`                |
| List Nix generations             | `sudo nix-env --list-generations --profile /nix/var/nix/profiles/system` |
| Roll back to previous generation | `sudo nixos-rebuild switch --rollback`                       |
| Garbage collect old generations  | `sudo nix-collect-garbage -d`                                |
| Update all flake inputs          | `nix flake update`                                           |
| Update a single flake input      | `nix flake lock --update-input lact`                         |

---

## Troubleshooting

**Steam won't launch**
- Check `~/.steam/steam/logs/` for errors
- Run `vulkaninfo --summary` and confirm RADV is listed as a Vulkan device
- Ensure 32-bit libraries are present: `ls /run/opengl-driver-32/lib/`

**LACT shows no device / can't change clocks**
- Verify the daemon is running: `systemctl status lactd`
- Check `dmesg | grep amdgpu` for driver errors
- Confirm ppfeaturemask is active: `cat /proc/cmdline | grep ppfeaturemask`

**No sound**
- Check PipeWire status: `systemctl --user status pipewire pipewire-pulse`
- Restart it: `systemctl --user restart pipewire pipewire-pulse`
- Verify device visibility: `wpctl status`

**Wrong display resolution at login**
- Under Wayland, KDE uses its own display config saved in `~/.local/share/kscreen/`
- Set your resolution once in **System Settings → Display and Monitor** and it persists
- The `xrandr` setup command in `desktop.nix` only affects the X11/XWayland fallback

**KDE panel not at the top after first login**
- `plasma-manager` applies config at login time — log out and back in if the panel
  is still at the bottom after the first `nixos-rebuild switch`
- If the panel is duplicated (old bottom + new top), right-click the old panel
  and select **Remove Panel**, then log out and back in

**KDE Connect not finding phone**
- Ensure both TCP and UDP ports 1714–1764 are open (configured in `networking.nix`)
- Confirm both devices are on the same LAN segment (not guest WiFi isolation)

**LazyVim plugins not installing**
- Ensure you have an internet connection on first launch
- Run `:checkhealth lazy` inside nvim to diagnose issues
- Check that `gcc` and `git` are on PATH: `which gcc git`

**Neovim LSP not working for a language**
- Run `:LspInfo` inside nvim to see which servers are attached
- Run `:Mason` to check server status (though servers are installed via Nix, not Mason)
- Ensure the language server binary is on PATH: e.g. `which lua-language-server`

**Firefox extensions not installing**
- Extensions installed via policy require an internet connection at first launch
- Check `about:policies` in Firefox to confirm policies are being applied
- If an extension shows as "blocked", check `about:support` for policy errors