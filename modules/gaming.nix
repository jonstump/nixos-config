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
        xorg.libXcursor
        xorg.libXi
        xorg.libXinerama
        xorg.libXScrnSaver
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

  # A systemd service + shell alias so users can just type `steam` and get
  # GameMode-aware launches without touching per-game launch options.
  environment.shellAliases = {
    steam = "gamemoderun steam";
  };

  # ── GameMode ──────────────────────────────────────────────────────────────
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice             = 10;       # Raise game process priority
        softrealtime       = "auto";   # Enable SCHED_RR when governors allow
        inhibit_screensaver = 1;
      };

      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device              = 0;
        amd_performance_level   = "high"; # Switch amdgpu power profile to high
      };

      cpu = {
        park_cores    = "no";
        pin_cores     = "yes";
      };

      custom = {
        # Run before/after a game session — useful for per-session tweaks
        start = "${pkgs.libnotify}/bin/notify-send 'GameMode' 'Game session started — performance profile active'";
        end   = "${pkgs.libnotify}/bin/notify-send 'GameMode' 'Game session ended — normal profile restored'";
      };
    };
  };

  # ── Gamescope (optional session compositor for HDR / VRR) ─────────────────
  programs.gamescope = {
    enable      = true;
    capSysNice  = true; # Allow gamescope to renice itself without sudo
  };

  # ── MangoHud (in-game overlay: FPS, temps, frame times) ──────────────────
  programs.mangohud = {
    enable             = true;
    enableSessionWide  = false; # Set to true to force MangoHud in ALL Vulkan apps
  };

  # ── Proton & Wine dependencies ────────────────────────────────────────────
  hardware.graphics = {
    enable         = true;
    enable32Bit    = true; # 32-bit Vulkan / OpenGL for older games
    extraPackages = with pkgs; [
      amdvlk                  # AMD's official open-source Vulkan driver
      rocmPackages.clr        # ROCm OpenCL runtime
      rocmPackages.clr.icd
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      amdvlk
    ];
  };

  # ── Gaming packages ───────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    # Communication
    discord

    # Launchers & compatibility
    lutris              # Multi-platform game launcher (GOG, Epic, etc.)
    heroic              # Epic Games & GOG launcher (Electron-based)
    bottles             # Wine prefix manager

    # Proton / Wine tools
    wine                # Wine stable
    wine64              # Wine 64-bit
    winetricks          # Helper scripts for Wine
    protontricks        # Winetricks wrapper for Proton prefixes
    protonplus          # GUI manager for installing/updating Proton and Wine GE builds

    # Performance & overlay
    gamemode            # GameMode daemon + gamemoderun binary
    mangohud            # In-game performance overlay
    vkbasalt            # Post-processing layer for Vulkan games (sharpening, etc.)

    # Vulkan tools
    vulkan-tools        # vulkaninfo, vkcube
    vulkan-loader
    vulkan-validation-layers

    # Controller support
    antimicrox          # Map controller buttons to keyboard/mouse
    sc-controller       # Steam Controller driver (works for other pads too)

    # Networking for games
    steamcmd            # Steam command-line tools

    # Utilities
    gamepad-tool        # Gamepad testing and mapping
    jstest-gtk          # Joystick / gamepad tester
    goverlay            # GUI configurator for MangoHud and vkbasalt
    replay-sorcery      # GPU-accelerated instant replay (shadow play)
    lsfg-vk             # Lossless Scaling Frame Generation for Vulkan — software frame gen for any game
    lsfg-vk-ui          # GUI companion for lsfg-vk — configure frame gen settings
    ludusavi            # Cross-platform game save backup and restore tool
  ];

  # ── udev rules for controllers ────────────────────────────────────────────
  services.udev.packages = with pkgs; [
    game-devices-udev-rules  # Adds udev rules for 100s of controllers/joysticks
  ];

  # ── Controller / input daemon ─────────────────────────────────────────────
  hardware.xpadneo.enable = true; # Xbox wireless gamepad driver (BT)

  # ── Kernel tweaks for gaming ──────────────────────────────────────────────
  boot.kernel.sysctl = {
    # Reduce latency for game workloads
    "vm.swappiness"              = 10;
    "kernel.sched_autogroup_enabled" = 0; # Prevents scheduler from grouping steam
    # Increase max inotify watches (needed by some game engines)
    "fs.inotify.max_user_watches" = 524288;
    # Large receive buffers help with game download speeds
    "net.core.rmem_max"          = 16777216;
    "net.core.wmem_max"          = 16777216;
  };

  # ── Split lock mitigation — disable for better game perf ─────────────────
  boot.kernelParams = [ "split_lock_detect=off" ];
}
