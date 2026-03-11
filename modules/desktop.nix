{ config, pkgs, lib, ... }:

{
  # ── Display Manager ───────────────────────────────────────────────────────
  # Wayland-native session via SDDM + KDE Plasma 6.
  # services.xserver is intentionally absent — we do not enable the X server.
  # XWayland (below) provides X11 app compatibility without a full X server.
  services.displayManager = {
    sddm = {
      enable         = true;
      wayland.enable = true;
      theme          = "breeze";
    };
    defaultSession = "plasma";
  };

  services.desktopManager.plasma6.enable = true;

  # ── XWayland ──────────────────────────────────────────────────────────────
  # XWayland is a compatibility layer that lets X11 applications run inside a
  # Wayland compositor. It is not an X server — there is no separate X session.
  # Most games and legacy apps that haven't been ported to Wayland use this.
  programs.xwayland.enable = true;

  # ── Audio (PipeWire) ──────────────────────────────────────────────────────
  # PulseAudio is disabled in favour of PipeWire, which provides PulseAudio,
  # ALSA, and JACK compatibility shims from a single low-latency daemon.
  hardware.pulseaudio.enable = false;

  security.rtkit.enable = true; # Required for real-time audio scheduling

  services.pipewire = {
    enable            = true;
    alsa.enable       = true;
    alsa.support32Bit = true; # Needed for 32-bit games via Steam / Proton
    pulse.enable      = true; # PulseAudio compatibility shim
    jack.enable       = true; # JACK compatibility (optional but useful for audio work)

    # Low-latency tuning — good defaults for a gaming machine
    extraConfig.pipewire = {
      "99-low-latency" = {
        context.properties = {
          default.clock.rate        = 48000;
          default.clock.quantum     = 512;
          default.clock.min-quantum = 32;
          default.clock.max-quantum = 8192;
        };
      };
    };
  };

  # ── KDE / Plasma packages ─────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    # KDE core extras
    kdePackages.plasma-browser-integration # Browser media controls in KDE taskbar
    kdePackages.kde-gtk-config             # GTK theme integration (non-Qt apps look native)
    kdePackages.kdialog                    # Shell-scriptable KDE dialog boxes
    kdePackages.ark                        # Archive manager (zip, tar, 7z, etc.)
    kdePackages.dolphin                    # Default file manager
    kdePackages.konsole                    # KDE terminal emulator (fallback alongside Kitty)
    kdePackages.kate                       # Advanced text editor with LSP support
    kdePackages.spectacle                  # Screenshot and screen recording tool
    kdePackages.gwenview                   # Image viewer
    kdePackages.okular                     # Document viewer (PDF, ePub, etc.)
    kdePackages.kcalc                      # Calculator
    kdePackages.filelight                  # Disk usage visualiser
    kdePackages.kdeconnect                 # Phone/tablet integration (notifications, clipboard, files)

    # GTK theming — ensures GTK apps respect the KDE colour scheme
    gtk3
    gtk4
    adwaita-icon-theme
    libsForQt5.qtstyleplugin-kvantum       # Kvantum theme engine for Qt5 apps

    # Font rendering libraries
    freetype
    fontconfig

    # XDG utilities — used by many apps for opening files, URLs, and directories
    xdg-utils
    xdg-user-dirs

    # Messaging & productivity
    signal-desktop  # Encrypted messaging client — Signal protocol
    ferdium         # All-in-one messaging hub; wraps Slack, WhatsApp, Telegram, etc. in one window
    zed-editor      # Fast, collaborative code editor written in Rust
    _1password-gui  # 1Password desktop client — requires a 1Password subscription
    feishin         # Modern Navidrome / Subsonic / Jellyfin music player client
  ];

  # ── XDG portals ───────────────────────────────────────────────────────────
  # Required for screen sharing, file pickers, and Flatpak sandbox integration
  # under Wayland. The KDE portal handles all of these natively in Plasma.
  xdg.portal = {
    enable       = true;
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
        Enable       = "Source,Sink,Media,Socket";
        Experimental = true; # Enables battery level reporting for BT peripherals
      };
    };
  };
  services.blueman.enable = true; # Bluetooth manager GUI and tray applet

  # ── Printing ──────────────────────────────────────────────────────────────
  services.printing.enable = true;
  services.avahi = {
    enable       = true;
    nssmdns4     = true;
    openFirewall = true; # Opens UDP 5353 for mDNS — required for network printer discovery
  };

  # ── Thumbnails ────────────────────────────────────────────────────────────
  services.tumbler.enable = true; # Thumbnail generator service used by Dolphin
}
