{
  description = "Jasper NixOS and Home Manager config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      username = "jasper";
      hostname = "jasper";
      pkgs = import nixpkgs { inherit system; };
      singBoxSubscribe = pkgs.callPackage ./pkgs/sing-box-subscribe.nix { };
    in {
      packages.${system}.sing-box-subscribe = singBoxSubscribe;

      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit hostname username singBoxSubscribe;
        };
        modules = [
          ./hosts/jasper/default.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.extraSpecialArgs = {
              inherit username singBoxSubscribe;
            };
            home-manager.users.${username} = import ./home/jasper.nix;
          }
        ];
      };
    };
}
