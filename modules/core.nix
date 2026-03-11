{ config, pkgs, lib, ... }:

{
  # ── Bootloader ────────────────────────────────────────────────────────────
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
    };

    # Latest kernel for best AMD hardware support
    kernelPackages = pkgs.linuxPackages_latest;

    # AMD-specific kernel parameters
    kernelParams = [
      "amd_iommu=on"
      "iommu=pt"
      "amdgpu.ppfeaturemask=0xffffffff" # Unlock all amdgpu power/clock features for LACT
    ];

    # Ensure the kernel's own hwmon thermal zone is available for monitoring.
    kernelModules = [ "kvm-amd" "amdgpu" "k10temp" "nct6775"];

    initrd = {
      kernelModules = [ "amdgpu" ];
    };
  };

  # ── Time & Locale ─────────────────────────────────────────────────────────
  time.timeZone = "America/Los_Angeles"; # Adjust to your timezone
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS        = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT    = "en_US.UTF-8";
      LC_MONETARY       = "en_US.UTF-8";
      LC_NAME           = "en_US.UTF-8";
      LC_NUMERIC        = "en_US.UTF-8";
      LC_PAPER          = "en_US.UTF-8";
      LC_TELEPHONE      = "en_US.UTF-8";
      LC_TIME           = "en_US.UTF-8";
    };
  };

  # ── Console ───────────────────────────────────────────────────────────────
  console = {
    font   = "Lat2-Terminus16";
    keyMap = "us";
  };

  # ── Users ─────────────────────────────────────────────────────────────────
  users.users.jon = {
    isNormalUser = true;
    description  = "Jon";
    extraGroups  = [
      "wheel"        # sudo access
      "networkmanager"
      "audio"
      "video"
      "input"
      "render"       # GPU access (needed for LACT and Vulkan tools)
      "gamemode"     # GameMode daemon access
    ];
    shell = pkgs.bash;
  };

  # ── sudo ──────────────────────────────────────────────────────────────────
  security.sudo.wheelNeedsPassword = true;

  # ── Nix settings ──────────────────────────────────────────────────────────
  nix = {
    settings = {
      experimental-features  = [ "nix-command" "flakes" ];
      auto-optimise-store    = true;
      # "root" and "@wheel" are standard. "@wheel" already covers jon since
      # he is in the wheel group (see users.users.jon.extraGroups above), so
      # listing "jon" explicitly is redundant — but harmless. It's been kept
      # here only as a reminder that this is the account that will be running
      # nix commands day-to-day. Feel free to remove "jon" if you prefer.
      trusted-users          = [ "root" "@wheel" ];

      # Binary caches
      substituters = [
        "https://cache.nixos.org"
        "https://nix-gaming.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      ];
    };

    gc = {
      automatic = true;
      dates     = "weekly";
      options   = "--delete-older-than 14d";
    };
  };

  nixpkgs.config.allowUnfree = true;

  # ── Common system packages ────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    # System essentials
    neovim  # Switched from vim — pairs with the LazyVim setup in modules/home.nix
    wget
    curl
    git
    htop
    btop    # btop++ — the C++ rewrite of bashtop; "bashtop" is the old package name in nixpkgs
    tree
    unzip
    zip
    p7zip
    rsync
    pciutils      # lspci
    usbutils      # lsusb
    lshw
    nvme-cli
    smartmontools

    # Shell & terminal
    bash
    tmux
    fzf
    ripgrep
    fd
    bat
    eza           # modern ls replacement
    fastfetch

    # Networking utilities
    nmap
    dig
    whois
    traceroute

    # Monitoring
    lm_sensors
    nvtopPackages.amd  # AMD GPU monitoring in terminal
    radeontop
  ];

  # ── Fonts ─────────────────────────────────────────────────────────────────
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      liberation_ttf
      # fira-code and fira-code-symbols removed — Mononoki is now the primary
      # terminal font. JetBrainsMono is kept as a secondary option (e.g. for
      # Zed Editor). The non-Nerd standalone jetbrains-mono package is kept
      # for applications that prefer the plain upstream font over the patched one.
      (nerdfonts.override { fonts = [ "Mononoki" "JetBrainsMono" ]; })
      jetbrains-mono
    ];

    fontconfig = {
      defaultFonts = {
        serif      = [ "Noto Serif" ];
        sansSerif  = [ "Noto Sans" ];
        # System-wide default monospace font — used by terminals, code views,
        # and any app that requests a generic monospace font.
        monospace  = [ "Mononoki Nerd Font" ];
      };
    };
  };

  # ── Hardware ──────────────────────────────────────────────────────────────
  hardware = {
    enableAllFirmware      = true;
    enableRedistributableFirmware = true;

    # CPU microcode
    cpu.amd.updateMicrocode = true;
  };

  # ── System state version ──────────────────────────────────────────────────
  # Do not change after initial install — see `man configuration.nix`
  system.stateVersion = "24.11";
}
