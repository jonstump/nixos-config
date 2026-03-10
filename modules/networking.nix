{ config, pkgs, lib, ... }:

{
  # ── Hostname ───────────────────────────────────────────────────────────────
  # "tallgeese" — named after the mobile suit from Gundam Wing. Change to
  # whatever you like; it shows up in your shell prompt and on the local network.
  networking.hostName = "tallgeese";

  # ── NetworkManager ────────────────────────────────────────────────────────
  networking.networkmanager = {
    enable = true;
    wifi.powersave = false; # Disable WiFi power saving for lower latency
  };

  # ── Wireless (wpa_supplicant disabled in favour of NetworkManager) ─────────
  networking.wireless.enable = false;

  # ── DNS ───────────────────────────────────────────────────────────────────
  networking.nameservers = [
    "1.1.1.1"   # Cloudflare primary
    "1.0.0.1"   # Cloudflare secondary
    "8.8.8.8"   # Google fallback
  ];

  # ── Firewall ──────────────────────────────────────────────────────────────
  networking.firewall = {
    enable = true;

    # Steam In-Home Streaming / Remote Play
    allowedTCPPorts = [
      27036  # Steam Remote Play
      27015  # Steam game server SRCDS
    ];

    allowedUDPPorts = [
      27031  # Steam Remote Play
      27032  # Steam Remote Play
      27033  # Steam Remote Play
      27034  # Steam Remote Play
      27035  # Steam Remote Play
      27036  # Steam Remote Play
      4380   # Steam
    ];

    allowedTCPPortRanges = [
      { from = 27015; to = 27030; } # Steam matchmaking / HLTV
    ];

    allowedUDPPortRanges = [
      { from = 27000; to = 27100; } # Steam general UDP range
    ];

    # KDE Connect — phone integration
    allowedTCPPortRanges = lib.mkAfter [
      { from = 1714; to = 1764; }
    ];
    allowedUDPPortRanges = lib.mkAfter [
      { from = 1714; to = 1764; }
    ];
  };

  # ── Network optimisations ─────────────────────────────────────────────────
  boot.kernel.sysctl = {
    # TCP tuning for fast LAN / low-latency gaming
    "net.ipv4.tcp_fastopen"           = 3;
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc"          = "fq";

    # Increase socket buffer sizes for game traffic
    "net.core.rmem_default" = 1048576;
    "net.core.wmem_default" = 1048576;
    "net.core.rmem_max"     = 16777216;
    "net.core.wmem_max"     = 16777216;

    # Reduce TIME_WAIT sockets lingering after connections close
    "net.ipv4.tcp_fin_timeout"    = 10;
    "net.ipv4.tcp_tw_reuse"       = 1;
    "net.ipv4.tcp_max_tw_buckets" = 400000;
  };

  # ── mDNS / Avahi ──────────────────────────────────────────────────────────
  # Avahi is also enabled in desktop.nix for printer discovery;
  # this entry ensures it is active regardless of desktop config.
  services.avahi = {
    enable       = true;
    nssmdns4     = true;
    openFirewall = true;
  };

  # ── NTP time synchronisation ──────────────────────────────────────────────
  services.timesyncd = {
    enable  = true;
    servers = [
      "0.nixos.pool.ntp.org"
      "1.nixos.pool.ntp.org"
      "2.nixos.pool.ntp.org"
      "3.nixos.pool.ntp.org"
    ];
  };

  # ── NetworkManager packages ───────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    networkmanager          # nmcli / nmtui
    networkmanagerapplet    # nm-applet system tray icon
    wireguard-tools         # WireGuard VPN utilities
    openvpn                 # OpenVPN client
    networkmanager-openvpn  # NM plugin for OpenVPN
    protonvpn-gui   # ProtonVPN desktop client — GUI frontend for the ProtonVPN service
  ];
}
