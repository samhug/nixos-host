{ config, pkgs, lib, ... }:

let
  bootUuid = builtins.readFile ./meta/boot-uuid;
  datastoreUuid = builtins.readFile ./meta/datastore-uuid;
in
{

   fileSystems."/" = {
     device = "none";
     fsType = "tmpfs";
     options = [ "size=6G" ];
   };

   fileSystems."/bcachefs/${datastoreUuid}" = {
     device = "UUID=${datastoreUuid}";
     fsType = "bcachefs";
     neededForBoot = true;
   };

   fileSystems."/nix" = {
     device = "/bcachefs/${datastoreUuid}/host/nix";
     fsType = "bind";
   };

   fileSystems."/persist" = {
     device = "/bcachefs/${datastoreUuid}/host/persist";
     fsType = "bind";
     neededForBoot = true;
   };

   # fileSystems."/home" = {
   #   device = "/mnt/datastore/host/home";
   #   fsType = "bind";
   # };

   fileSystems."/boot" = {
     device = "/dev/disk/by-uuid/${bootUuid}";
     fsType = "vfat";
     # options = [];
   };

}
