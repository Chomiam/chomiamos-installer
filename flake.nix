{
  description = "Générateur d'image ISO bootable pour ChomiamOS Gaming Edition avec installateur Yad";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";

      isoConfiguration = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-gnome.nix"
          "${nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
          ./iso/configuration.nix
        ];
      };
    in
    {
      nixosConfigurations.iso = isoConfiguration;

      packages.${system} = {
        default = isoConfiguration.config.system.build.isoImage;
        iso = isoConfiguration.config.system.build.isoImage;
      };
    };
}
