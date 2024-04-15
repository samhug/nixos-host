{ config, pkgs, lib, ... }:

{

  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxKernel.packages.linux_bcachefs_master;

  boot.initrd.kernelModules = [ "bcachefs" ];
  boot.kernelModules = [ "bcachefs" ];

  boot.supportedFilesystems.zfs = lib.mkForce false;

  environment.systemPackages = with pkgs; [
    (enableDebugging bcachefs-tools)
    tmux
    htop
    strace
    config.boot.kernelPackages.perf

    keyutils

    # fsck-datastore
    # mount-datastore
    # run
    # dmesg-decoded
  ];

  # networking.hostId = "deadbeaf";

}
