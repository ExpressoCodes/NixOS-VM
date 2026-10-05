# ============================================================================
# PLACEHOLDER hardware-configuration.nix
#
# This is NOT a real hardware configuration. Before you build this system you
# MUST replace this file with the output generated on the target machine:
#
#     sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
#
# The stub below only exists so the flake evaluates and the intent is clear.
# The UUIDs, device paths and kernel modules here are fake.
# ============================================================================
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # --- PLACEHOLDER: replace with your real boot modules ---
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ]; # or "kvm-amd" on AMD CPUs
  boot.extraModulePackages = [ ];

  # --- PLACEHOLDER filesystems: replace with your real UUIDs ---
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0000-0000";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ ];

  # Enables DHCP on each ethernet and wireless interface by default.
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
