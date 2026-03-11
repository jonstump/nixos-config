{ config, pkgs, lib, lact, ... }:

{
  # ── AMDGPU kernel module settings ────────────────────────────────────────
  # The ppfeaturemask is also set in core.nix kernelParams; this provides
  # the modprobe-level override as a belt-and-suspenders measure so LACT
  # can access all power/clock/fan controls on the RX 7900 XTX.
  boot.extraModprobeConfig = ''
    options amdgpu ppfeaturemask=0xffffffff
    options amdgpu deep_color=1
    options amdgpu dc=1
  '';

  # ── Fan / thermal safety (belt-and-suspenders alongside LACT) ────────────
  # Ensure the kernel's own hwmon thermal zone is available for monitoring.
  boot.kernelModules = [ "amdgpu" "k10temp" "nct6775" ];

  # ── LACT + ROCm + Vulkan packages ─────────────────────────────────────────
  # LACT is pulled from its own flake input for up-to-date RDNA3 support.
  # ROCm provides OpenCL / HIP compute. Vulkan tools round out the stack.
  environment.systemPackages = with pkgs; [
    # LACT — Linux AMDGPU Control (GUI + daemon client)
    lact.packages.${pkgs.system}.default

    # ROCm compute
    rocmPackages.rocm-runtime       # HIP / ROCm runtime
    rocmPackages.rocm-smi           # GPU SMI CLI (temps, clocks, fans)
    rocmPackages.rocminfo           # Print ROCm device info
    rocmPackages.clr                # OpenCL runtime
    rocmPackages.clr.icd            # OpenCL ICD loader entry

    # OpenCL inspection
    clinfo

    # VA-API utilities
    libva-utils                     # vainfo — verify hardware video decode
  ];

  # ── LACT daemon ───────────────────────────────────────────────────────────
  # LACT requires a background daemon running as root so it can write to
  # sysfs power management knobs. We define the service manually here so
  # the daemon binary is taken from the same flake-pinned package.
  systemd.services.lactd = {
    description = "LACT AMDGPU Control Daemon";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart       = "${lact.packages.${pkgs.system}.default}/bin/lact daemon";
      Restart         = "on-failure";
      RestartSec      = "5s";
      # Must run as root — required for sysfs GPU controls
      User            = "root";
      Group           = "root";
    };
  };

  # ── ROCm environment ──────────────────────────────────────────────────────
  # Tell ROCm which GPU architecture to target.
  # gfx1100 = RDNA3, which covers the RX 7900 XTX.
  environment.variables = {
    ROC_ENABLE_PRE_VEGA      = "0";
    HSA_OVERRIDE_GFX_VERSION = "11.0.0"; # RDNA3 target for RX 7900 XTX
    GPU_MAX_ALLOC_PERCENT    = "100";
    GPU_SINGLE_ALLOC_PERCENT = "100";
  };

  # ── Vulkan driver selection ───────────────────────────────────────────────
  # RADV (Mesa) is the recommended Vulkan driver for gaming on RDNA3.
  # amdvlk is installed as a fallback/alternative via hardware.graphics below.
  environment.variables.AMD_VULKAN_ICD = lib.mkDefault "RADV";

  # ── OpenGL / Vulkan / VA-API (hardware video decode/encode) ───────────────
  hardware.graphics = {
    enable      = true;
    enable32Bit = true; # Required for 32-bit games / Steam Proton

    extraPackages = with pkgs; [
      # Vulkan drivers
      mesa                  # RADV (Mesa Vulkan) — primary gaming driver
      amdvlk                # AMD's official Vulkan driver (fallback)

      # Video acceleration
      libva                 # VA-API library
      libva-utils           # vainfo
      vaapiVdpau            # VA-API → VDPAU bridge
      mesa.drivers          # radeonsi (OpenGL) + RADV (Vulkan)

      # ROCm OpenCL
      rocmPackages.clr
      rocmPackages.clr.icd
    ];

    extraPackages32 = with pkgs.pkgsi686Linux; [
      # 32-bit Mesa for older / 32-bit games running through Steam / Proton
      mesa
      amdvlk
    ];
  };

  # ── GPU power profile ─────────────────────────────────────────────────────
  # Default to "auto" at boot. LACT or GameMode will raise it to "high"
  # during gaming sessions and restore it afterwards.
  systemd.services.amdgpu-power-profile = {
    description = "Set AMDGPU default power profile";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "multi-user.target" ];

    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      ExecStart       = pkgs.writeShellScript "set-amdgpu-power" ''
        for card in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
          [ -f "$card" ] && echo auto > "$card"
        done
        for card in /sys/class/drm/card*/device/pp_power_profile_mode; do
          [ -f "$card" ] && echo 0 > "$card"
        done
      '';
    };
  };

  # ── udev: grant render group access to DRM / hwmon nodes ─────────────────
  # Members of the "render" group (see core.nix) can open GPU render nodes
  # directly, and LACT can read temperature / fan data from hwmon.
  services.udev.extraRules = ''
    # DRM render nodes
    SUBSYSTEM=="drm",   KERNEL=="renderD*",        GROUP="render", MODE="0660"
    # amdgpu hwmon nodes (temps, fans, power) — read by LACT
    SUBSYSTEM=="hwmon", ATTRS{name}=="amdgpu",      GROUP="render", MODE="0660"
  '';
}
