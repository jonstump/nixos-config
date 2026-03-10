{
  description = "NixOS Gaming PC Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    lact = {
      url = "github:ilya-zlobintsev/LACT";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { self, nixpkgs, nixos-hardware, lact, home-manager, plasma-manager, ... }: {
    nixosConfigurations.gaming-pc = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      specialArgs = { inherit lact; };

      modules = [
        ./hardware-configuration.nix
        ./modules/core.nix
        ./modules/desktop.nix
        ./modules/gaming.nix
        ./modules/gpu.nix
        ./modules/networking.nix
        ./modules/browsers.nix

        nixos-hardware.nixosModules.common-cpu-amd
        nixos-hardware.nixosModules.common-gpu-amd
        nixos-hardware.nixosModules.common-pc
        nixos-hardware.nixosModules.common-pc-ssd

        # Home Manager as a NixOS module — runs on nixos-rebuild, no separate
        # home-manager switch needed. User config lives in modules/home.nix.
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs    = true;  # Share the system nixpkgs instance
            useUserPackages  = true;  # Install HM packages into /etc/profiles
            backupFileExtension = "hm-bak"; # Back up conflicting dotfiles

            sharedModules = [
              plasma-manager.homeManagerModules.plasma-manager
            ];

            users.jon = import ./modules/home.nix;
          };
        }
      ];
    };
  };
}
