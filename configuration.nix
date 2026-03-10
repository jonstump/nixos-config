# This file is intentionally unused.
#
# This NixOS configuration is managed as a flake.
# The entrypoint is flake.nix, which composes the following modules:
#
#   modules/core.nix        — bootloader, locale, users, base packages
#   modules/desktop.nix     — KDE Plasma 6, SDDM, PipeWire, Bluetooth
#   modules/gaming.nix      — Steam, GameMode, Proton, Discord, gaming tools
#   modules/gpu.nix         — AMDGPU driver, LACT, ROCm, Vulkan, VA-API
#   modules/networking.nix  — NetworkManager, firewall, DNS, NTP
#
# To apply the configuration, run:
#
#   sudo nixos-rebuild switch --flake /etc/nixos/nixos-config#gaming-pc
#
# See README.md for full setup instructions.
