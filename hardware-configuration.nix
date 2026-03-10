# ┌─────────────────────────────────────────────────────────────────────────┐
# │  hardware-configuration.nix — STUB                                      │
# │                                                                         │
# │  This file is intentionally left as a placeholder.                      │
# │                                                                         │
# │  To generate YOUR real hardware configuration, boot into a NixOS live   │
# │  ISO on your machine and run:                                            │
# │                                                                         │
# │      sudo nixos-generate-config --root /mnt                             │
# │                                                                         │
# │  Then copy the generated file from:                                     │
# │      /mnt/etc/nixos/hardware-configuration.nix                          │
# │                                                                         │
# │  …and replace this file with its contents.                              │
# │                                                                         │
# │  The stub below includes the options most likely needed for your        │
# │  hardware (ASRock B550M-ITX/ac, Ryzen 5 5600G, RX 7900 XTX) so you     │
# │  can reference them when reviewing the generated output.                │
# └─────────────────────────────────────────────────────────────────────────┘

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # ── Boot ──────────────────────────────────────────────────────────────────
  # nixos-generate-config will fill in the correct initrd modules,
  # kernelModules, and luks devices for your specific disk layout.
  boot.initrd.availableKernelModules = [
    "nvme"        # NVMe SSD support
    "xhci_pci"   # USB 3.x host controller
    "ahci"        # SATA host controller
    "usbhid"      # USB HID (keyboard at boot)
    "sd_mod"      # SCSI disk support
  ];

  boot.initrd.kernelModules = [ "amdgpu" ];

  boot.kernelModules = [
    "kvm-amd"  # AMD hardware virtualisation
    "amdgpu"
  ];

  boot.extraModulePackages = [ ];

  # ── File systems ──────────────────────────────────────────────────────────
  # Replace these UUIDs with the real ones from `blkid` on your system.
  # Run `lsblk -f` or `blkid` to find your partition UUIDs.

  fileSystems."/" = {
    device  = "/dev/disk/by-uuid/REPLACE-WITH-YOUR-ROOT-UUID";
    fsType  = "ext4";
    options = [ "noatime" "nodiratime" ]; # Minor SSD performance boost
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-YOUR-BOOT-UUID";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # Optional: separate /home partition (remove if not applicable)
  # fileSystems."/home" = {
  #   device = "/dev/disk/by-uuid/REPLACE-WITH-YOUR-HOME-UUID";
  #   fsType = "ext4";
  #   options = [ "noatime" "nodiratime" ];
  # };

  # ── Swap ──────────────────────────────────────────────────────────────────
  # With 32 GB RAM a swap partition is optional; a swapfile or zram is fine.
  # swapDevices = [
  #   { device = "/dev/disk/by-uuid/REPLACE-WITH-YOUR-SWAP-UUID"; }
  # ];

  # zram swap — compressed in-RAM swap, good for 32 GB systems
  zramSwap = {
    enable    = true;
    algorithm = "zstd";
    # Use up to 25% of RAM (8 GB) as compressed swap
    memoryPercent = 25;
  };

  # ── CPU ───────────────────────────────────────────────────────────────────
  # Ryzen 5 5600G — 6 cores / 12 threads, Zen 3
  nixpkgs.hostPlatform          = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;

  # ── Networking ────────────────────────────────────────────────────────────
  # The MAC-based hostname anchor; generated config will set the actual
  # interface names (e.g. enp5s0, wlan0) detected on your hardware.
  # networking.interfaces.enp5s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlan0.useDHCP  = lib.mkDefault true;
}
