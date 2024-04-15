{

  # inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.nixpkgs.url = "github:samhug/nixpkgs/bcachefs-upstream-kernel";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  # inputs.home-manager = {
  #   url = "github:nix-community/home-manager";
  #   inputs.nixpkgs.follows = "nixpkgs";
  # };
  # inputs.impermanence.url = "github:nix-community/impermanence";

  # inputs.nixos-hardware.url = "github:NixOS/nixos-hardware/master";

  outputs = inputs@{ self, ... }:
    {
      nixosConfigurations = {
        nixos-host = inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./configuration.nix
          ];
        };
      };
    }
    // (inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system}; # importNixpkgs { inherit system; };
        projectPackages = pkgs.callPackage ./pkgs { };
      in
      {
        legacyPackages.nixpkgs = pkgs;

        packages.format-system = pkgs.writeShellScriptBin "format-system" ''
          set -exu

          DEV_NVME1=/dev/disk/by-id/nvme-INTEL_MEMPEK1W016GA_PHBT723304FH016D
          DEV_NVME2=/dev/disk/by-id/nvme-INTEL_MEMPEK1W016GA_PHBT723304FH016D

          DEV_SSD1=/dev/disk/by-id/wwn-0x5002538e40a30507
          DEV_SSD2=/dev/disk/by-id/wwn-0x5002538e40a30f02
          DEV_SSD3=/dev/disk/by-id/wwn-0x5002538e40a6adde
          DEV_SSD4=/dev/disk/by-id/wwn-0x5002538e40ab5334
          DEV_SSD5=/dev/disk/by-id/wwn-0x5002538e40ab5336
          DEV_SSD6=/dev/disk/by-id/wwn-0x5002538e40ab59c1
          DEV_SSD7=/dev/disk/by-id/wwn-0x5002538e40ab5aa1
          DEV_SSD8=/dev/disk/by-id/wwn-0x5002538e40ad57ba

          DEV_EFI='/dev/disk/by-id/usb-SanDisk_Ultra_4C530001171229100085-0:0'

          ALT_ROOT=/mnt

          # Ref: https://github.com/NixOS/nixpkgs/issues/32279#issuecomment-1093682970
          ${pkgs.keyutils}/bin/keyctl link @u @s

          #	--encrypted \
          ${pkgs.bcachefs-tools}/bin/bcachefs format \
          	--force \
          	--replicas=2 \
          	--discard \
          	--compression=zstd \
          	--label nvme.nvme1 $DEV_NVME1 \
          	--label nvme.nvme2 $DEV_NVME2 \
          	--label ssd.ssd1 $DEV_SSD1 \
          	--label ssd.ssd2 $DEV_SSD2 \
          	--label ssd.ssd3 $DEV_SSD3 \
          	--label ssd.ssd4 $DEV_SSD4 \
          	--label ssd.ssd5 $DEV_SSD5 \
          	--label ssd.ssd6 $DEV_SSD6 \
          	--label ssd.ssd7 $DEV_SSD7 \
          	--label ssd.ssd8 $DEV_SSD8 \
          	--foreground_target=nvme \
          	--background_target=ssd \
          	;


          sgdisk --zip-all $DEV_EFI
          sgdisk -o -n 1:1M:+4G -t 1:ef00 $DEV_EFI


          sync
          partprobe \
          	$DEV_SSD1 \
          	$DEV_SSD2 \
          	$DEV_SSD3 \
          	$DEV_SSD4 \
          	$DEV_SSD5 \
          	$DEV_SSD6 \
          	$DEV_SSD7 \
          	$DEV_SSD8 \
          	$DEV_NVME1 \
          	$DEV_NVME2 \
          	$DEV_EFI \
          	;

          ls -l /dev/disk/by-id/

          sleep 5

          partprobe "$DEV_EFI-part1"


          mkdir -p $ALT_ROOT
          mount -t tmpfs -o size=4G none $ALT_ROOT

          mkdir -p $ALT_ROOT/boot
          mkfs.vfat -n BOOT "$DEV_EFI-part1"
          mount -t vfat "$DEV_EFI-part1" $ALT_ROOT/boot

          DATASTORE_PATH=$ALT_ROOT/mnt/datastore
          mkdir -p $DATASTORE_PATH
          mount -t bcachefs "$DEV_NVME1:$DEV_NVME2:$DEV_SSD1:$DEV_SSD2:$DEV_SSD3:$DEV_SSD4:$DEV_SSD5:$DEV_SSD6:$DEV_SSD7:$DEV_SSD8" $DATASTORE_PATH

          bcachefs subvolume create $DATASTORE_PATH/host

          bcachefs subvolume create $DATASTORE_PATH/host/nix
          bcachefs subvolume create $DATASTORE_PATH/host/nix/store
          mkdir -p $ALT_ROOT/nix
          mount --bind $DATASTORE_PATH/host/nix $ALT_ROOT/nix

          bcachefs subvolume create $DATASTORE_PATH/host/persist
          mkdir -p $ALT_ROOT/persist
          mount --bind $DATASTORE_PATH/host/persist $ALT_ROOT/persist

          nixos-generate-config --root $ALT_ROOT
        '';

        packages.install-system = pkgs.writeShellScriptBin "install-system" ''
          set -exu

          ALT_ROOT=/mnt
          nixos-install \
              --root $ALT_ROOT \
              --flake 'https://github.com/samhug/nixos-host#nixos-host' \
              ;
        '';

        #packages = inputs.flake-utils.lib.flattenTree projectPackages;

        # devShells.default =
        #   let
        #     devshell = import inputs.devshell { nixpkgs = pkgs; };
        #   in
        #   devshell.mkShell {
        #     name = "samhug-infra";
        #     #env = [
        #     #  {
        #     #    name = "NIX_PATH";
        #     #    value = "nixpkgs=${toString pkgs.path}";
        #     #  }
        #     #];
        #     packages = with pkgs; [
        #       niv
        #       nix
        #       nix-output-monitor
        #       nixpkgs-fmt
        #       update-host
        #       jq
        #     ];
        #     #commands = [
        #     #  {
        #     #    package = pkgs.writeShellScriptBin "update-host" ''
        #     #      ${./install.sh} $@
        #     #    '';
        #     #    name = "update-host";
        #     #    help = "Update the host system";
        #     #  }
        #     #];
        #   };
      }
    ))
    ;

}
