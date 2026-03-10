{ config, pkgs, lib, ... }:

{
  # ── Display Server ────────────────────────────────────────────────────────
  services.xserver = {
    enable = true;

    # 3440x1440 @ 100Hz ultrawide
    displayManager.setupCommands = ''
      ${pkgs.xorg.xrandr}/bin/xrandr --output DisplayPort-0 --mode 3440x1440 --rate 100
    '';
  };

  # Use Wayland-native session via SDDM + KDE Plasma 6
  services.displayManager = {
    sddm = {
      enable      = true;
      wayland.enable = true;
      theme       = "breeze";
    };
    defaultSession = "plasma";
  };

  services.desktopManager.plasma6.enable = true;

  # ── Wayland / XWayland ────────────────────────────────────────────────────
  # XWayland allows legacy X11 apps (including many games) to run under Wayland
  programs.xwayland.enable = true;

  # ── Input ─────────────────────────────────────────────────────────────────
  services.libinput.enable = true;

  # ── Audio (PipeWire) ──────────────────────────────────────────────────────
  # Disable PulseAudio in favour of PipeWire
  hardware.pulseaudio.enable = false;

  security.rtkit.enable = true; # Required for real-time audio scheduling

  services.pipewire = {
    enable            = true;
    alsa.enable       = true;
    alsa.support32Bit = true; # Needed for 32-bit games via Steam
    pulse.enable      = true; # PulseAudio compatibility shim
    jack.enable       = true; # JACK compatibility (optional but useful)

    # Low-latency tuning
    extraConfig.pipewire = {
      "99-low-latency" = {
        context.properties = {
          default.clock.rate          = 48000;
          default.clock.quantum       = 512;
          default.clock.min-quantum   = 32;
          default.clock.max-quantum   = 8192;
        };
      };
    };
  };

  # ── KDE / Plasma packages ─────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    # KDE core extras
    kdePackages.plasma-browser-integration
    kdePackages.kde-gtk-config        # GTK theme integration
    kdePackages.kdialog
    kdePackages.ark                   # Archive manager
    kdePackages.dolphin               # File manager
    kdePackages.konsole               # Terminal emulator
    kdePackages.kate                  # Text editor
    kdePackages.spectacle             # Screenshot tool
    kdePackages.gwenview              # Image viewer
    kdePackages.okular                # Document viewer
    kdePackages.kcalc                 # Calculator
    kdePackages.filelight             # Disk usage visualiser
    kdePackages.kdeconnect            # Phone integration

    # GTK theming so non-Qt apps look native
    gtk3
    gtk4
    adwaita-icon-theme
    libsForQt5.qtstyleplugin-kvantum

    # Fonts rendering
    freetype
    fontconfig

    # Wayland utilities
    wl-clipboard
    xdg-utils
    xdg-user-dirs

    # Additional must haves
    signal-desktop   # Encrypted messaging client — Signal protocol
    ferdium          # All-in-one messaging hub; wraps Slack, WhatsApp, Telegram, etc. in one window
    kitty            # GPU-accelerated terminal emulator; used as the primary terminal alongside Konsole
    zed-editor       # Fast, collaborative code editor written in Rust
    syncthing        # Continuous peer-to-peer file synchronisation daemon (no cloud required)
    syncthing-tray   # System tray GUI for monitoring and controlling the Syncthing daemon
    _1password-gui   # 1Password desktop client — requires a 1Password subscription
    feishin          # Modern Navidrome / Subsonic / Jellyfin music player client
  ];

  # ── XDG portals (required for Flatpak, screen sharing, file pickers) ──────
  xdg.portal = {
    enable      = true;
    extraPortals = [ pkgs.xdg-desktop-portal-kde ];
  };

  # ── D-Bus ─────────────────────────────────────────────────────────────────
  services.dbus.enable = true;

  # ── Bluetooth ─────────────────────────────────────────────────────────────
  hardware.bluetooth = {
    enable      = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable          = "Source,Sink,Media,Socket";
        Experimental    = true; # Enables battery reporting for BT devices
      };
    };
  };
  services.blueman.enable = true;

  # ── Printing (optional — remove if not needed) ────────────────────────────
  services.printing.enable = true;
  services.avahi = {
    enable   = true;
    nssmdns4 = true;
    openFirewall = true; # Allows mDNS for network printer discovery
  };

  # ── Thumbnails & file indexing ────────────────────────────────────────────
  services.tumbler.enable  = true; # Thumbnail generator for Dolphin
}
