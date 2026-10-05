# ============================================================================
# EXAMPLE base configuration.
#
# This is a minimal, usage-demo host config that consumes the VM-host module
# (see the repo root flake.nix `nixosConfigurations.example`). You do NOT need
# this file to use the module in your own flake -- it only exists to show how
# the module is wired up and to let `nix flake check` evaluate a full system.
#
# Everything marked CHANGE ME is a placeholder.
# ============================================================================
{ config, pkgs, ... }:

{
  # Bootloader (systemd-boot / UEFI).
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # CHANGE ME: hostname.
  networking.hostName = "nixos-vm";

  # Networking via NetworkManager.
  networking.networkmanager.enable = true;

  # CHANGE ME: your time zone.
  time.timeZone = "Etc/UTC";

  # CHANGE ME: your user account.
  # Because it is a normal user, the VM module auto-detects it and adds it to
  # the `libvirtd` group -- no `vmSetup.*` setting is needed. To restrict or
  # opt out, set e.g. `vmSetup.users = [ "alice" ];` or `vmSetup.users = [ ];`.
  users.users.alice = {
    isNormalUser = true;
    description = "Example user";
    extraGroups = [ "wheel" "networkmanager" ];
    # Set a password with `passwd` after first boot, or use hashedPassword here.
  };

  # The NixOS release this config was first written for. Keep it fixed; do not
  # bump it when you upgrade. 26.05 is the current latest release (Oct 2026).
  system.stateVersion = "26.05";
}
