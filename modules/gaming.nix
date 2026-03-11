{ config, pkgs, lib, ... }:

{
  # ── Steam ─────────────────────────────────────────────────────────────────
  programs.steam = {
    enable = true;
    remotePlay.openFirewall      = true; # Steam Remote Play
    dedicatedServer.openFirewall = false;

    # Launch all games through GameMode automatically
    gamescopeSession.enable = false; # We use GameMode instead of Gamescope here

    extraCompatPackages = with pkgs; [
      proton-ge-bin # GE-Proton: community Proton build with extra patches
    ];

    # Pass GameMode wrapper as the default launch prefix for every Steam game.
    # This is equivalent to adding `gamemoderun %command%` to every game's
    # launch options, but applied globally via Steam's environment.
    package = pkgs.steam.override {
      extraEnv = {
        # Steam reads STEAM_EXTRA_COMPAT_TOOLS_PATHS for additional Proton builds
        STEAM_EXTRA_COMPAT_TOOLS_PATHS = "$HOME/.steam/root/compatibilitytools.d";
      };
      extraLibraries = p: with p; [
        # Wayland-native libraries only — X11 libs removed
        libpng
        libpulseaudio
        libvorbis
        stdenv.cc.cc.lib
        libkrb5
        keyutils
      ];
    };
  };

  # Wrap the Steam launch script so every game inherits `gamemoderun`.
  # Steam exposes a per-game "launch command" concept; the cleanest
  # system-wide equivalent is overriding the Steam run script.
  environment.sessionVariables = {
    # Tells the steam-run wrapper to prefix every game with gamemoderun
    STEAM_GAME_OVERLAYSCRIPT = "${pkgs.gamemode}/bin/gamemoderun";
  };

  # A shell alias so users can just type `steam` and get GameMode-aware
  # launches without touching per-game launch options.
  environment.shellAliases = {
    steam = "gamemoderun steam";
  };

  # ── GameMode ──────────────────────────────────────────────────────────────
  # programs.gamemode installs the package AND activates the daemon — no need
  # to list gamemode in systemPackages separately.
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice              = 10;    # Raise game process priority
        softrealtime        = "auto"; # Enable SCHED_RR when governors allow
        inhibit_screensaver = 1;
      };

      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device              = 0;
        amd_performance_level   = "high"; # Switch amdgpu power profile to high
      };

      cpu = {
        park_cores = "no";
        pin_cores  = "yes";
      };

      custom = {
        # Desktop notifications at the start and end of each game session
        start = "${pkgs.libnotify}/bin/notify-send 'GameMode' 'Game session started — performance profile active'";
        end   = "${pkgs.libnotify}/bin/notify-send 'GameMode' 'Game session ended — normal profile restored'";
      };
    };
  };

  # ── Gamescope (optional session compositor for HDR / VRR) ─────────────────
  programs.gamescope = {
    enable     = true;
    capSysNice = true; # Allow gamescope to renice itself without sudo
  };

  # ── MangoHud (in-game overlay: FPS, temps, frame times) ──────────────────
  # programs.mangohud installs the package — no need to list it in
  # systemPackages separately.
  programs.mangohud = {
    enable            = true;
    enableSessionWide = false; # Set to true to force MangoHud in ALL Vulkan apps
  };

  # ── Gaming packages ───────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    # Communication
    discord

    # Launchers & compatibility
    lutris       # Multi-platform game launcher (GOG, Epic, etc.)
    heroic       # Epic Games & GOG launcher (Electron-based)
    bottles      # Wine prefix manager

    # Proton / Wine tools
    wine         # Wine stable
    wine64       # Wine 64-bit
    winetricks   # Helper scripts for Wine
    protontricks # Winetricks wrapper for Proton prefixes
    protonplus   # GUI manager for installing/updating Proton and Wine GE builds

    # Post-processing
    vkbasalt     # Vulkan post-processing layer (sharpening, CAS, etc.)

    # Vulkan tools
    vulkan-tools             # vulkaninfo, vkcube
    vulkan-loader
    vulkan-validation-layers

    # Controller support
    antimicrox   # Map controller buttons to keyboard/mouse
    sc-controller # Steam Controller driver (works for other pads too)

    # Steam CLI tools
    steamcmd     # Steam command-line tools

    # Utilities
    gamepad-tool  # Gamepad testing and mapping
    jstest-gtk    # Joystick / gamepad tester
    goverlay      # GUI configurator for MangoHud and vkbasalt
    replay-sorcery # GPU-accelerated instant replay (shadow play)
    lsfg-vk       # Lossless Scaling Frame Generation for Vulkan — software frame gen for any game
    lsfg-vk-ui    # GUI companion for lsfg-vk — configure frame gen settings
    ludusavi      # Cross-platform game save backup and restore tool
  ];

  # ── udev rules for controllers ────────────────────────────────────────────
  services.udev.packages = with pkgs; [
    game-devices-udev-rules  # Adds udev rules for 100s of controllers/joysticks
  ];

  # ── Controller / input daemon ─────────────────────────────────────────────
  hardware.xpadneo.enable = true; # Xbox wireless gamepad driver (BT)

  # ── Apollo game streaming ─────────────────────────────────────────────────
  # Apollo is a Sunshine-compatible, open-source game streaming host that
  # allows clients (Steam Deck, Moonlight, etc.) to stream your desktop or
  # individual games over the local network.
  #
  # Display switching for streaming:
  #   When streaming to a Steam Deck docked to a TV, you typically want the
  #   stream to originate from a virtual or secondary display set to 1080p@60
  #   rather than your main 3440x1440@100 ultrawide. DisplayPort-2 is reserved
  #   for this purpose. The wlr-randr commands in the Apollo pre/post hooks
  #   below enable DP-2 at 1080p@60 before a session starts and disable it
  #   when the session ends.
  #
  #   NOTE: connector name (DP-2) and exact modeline may differ on your system.
  #   Verify with `kscreen-doctor --outputs` or `wlr-randr` while logged in.
  #   Update the ExecStartPre / ExecStopPost commands accordingly.
  services.apollo = {
    enable    = true;
    openFirewall = true; # Opens the ports Apollo needs (47984-47990, 48010)
  };

  environment.systemPackages = lib.mkAfter (with pkgs; [
    wlr-randr  # Wayland output management CLI — used by Apollo session hooks
  ]);

  # Apollo runs as a system service. We extend the upstream unit with
  # pre/post display-switching commands using a systemd drop-in override.
  # The override file is written to /etc/systemd/system/apollo.service.d/
  # and is applied automatically by systemd alongside the base unit.
  systemd.services.apollo = {
    # Drop-in overrides — merged on top of the unit provided by services.apollo
    serviceConfig = {
      # Before streaming starts: bring up DP-2 at 1080p@60 for the client.
      # WAYLAND_DISPLAY is set to the compositor socket for the logged-in user;
      # adjust if you use a non-default socket name.
      ExecStartPre = pkgs.writeShellScript "apollo-display-on" ''
        export WAYLAND_DISPLAY=wayland-1
        export XDG_RUNTIME_DIR=/run/user/$(id -u jon)
        ${pkgs.wlr-randr}/bin/wlr-randr \
          --output DP-2 \
          --on \
          --mode 1920x1080@60
      '';

      # After streaming ends: disable DP-2 so it doesn't stay active.
      ExecStopPost = pkgs.writeShellScript "apollo-display-off" ''
        export WAYLAND_DISPLAY=wayland-1
        export XDG_RUNTIME_DIR=/run/user/$(id -u jon)
        ${pkgs.wlr-randr}/bin/wlr-randr \
          --output DP-2 \
          --off
      '';
    };
  };

  # ── Kernel tweaks for gaming ──────────────────────────────────────────────
  boot.kernel.sysctl = {
    # Reduce latency for game workloads
    "vm.swappiness"                  = 10;
    "kernel.sched_autogroup_enabled" = 0;       # Prevents scheduler from grouping Steam processes together
    # Increase max inotify watches (needed by some game engines)
    "fs.inotify.max_user_watches"    = 524288;
    # Large receive buffers help with game download speeds
    # (also set in networking.nix; these are kept here as the gaming-specific rationale)
    "net.core.rmem_max"              = 16777216;
    "net.core.wmem_max"              = 16777216;
  };

  # ── Split lock mitigation — disable for better game perf ─────────────────
  boot.kernelParams = [ "split_lock_detect=off" ];
}
