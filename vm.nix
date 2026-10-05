# Reusable NixOS module: VM host via virt-manager / libvirt / SPICE.
#
# Import this module (see flake.nix `nixosModules.default`) and it will:
#   * install virt-manager / virt-viewer / SPICE tooling,
#   * enable libvirtd (with swtpm + UEFI/OVMF) and SPICE USB redirection,
#   * enable the SPICE guest agent daemon and dconf,
#   * add a user of your choice to the `libvirtd` group.
#
# Configure it from your own configuration with:
#   vmSetup.user = "alice";   # the account that should manage VMs
# (set `vmSetup.enable = false;` to turn everything off without un-importing).

{ config, lib, pkgs, ... }:

let
  cfg = config.vmSetup;
in
{
  options.vmSetup = {
    # Defaults to true so that merely importing the module sets things up,
    # which matches the intended "import and it just works" UX.
    enable = lib.mkEnableOption "the virt-manager / libvirt / SPICE VM host setup" // {
      default = true;
    };

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "alice";
      description = ''
        Username to add to the `libvirtd` group so it can manage VMs without
        root. Leave as `null` to skip group management (e.g. if you add the
        user to `libvirtd` yourself elsewhere).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable dconf (needed by virt-manager to store settings).
    programs.dconf.enable = true;

    # Add the chosen user to the libvirtd group (if one was specified).
    users.users = lib.mkIf (cfg.user != null) {
      ${cfg.user}.extraGroups = [ "libvirtd" ];
    };

    # Install necessary packages.
    environment.systemPackages = with pkgs; [
      virt-manager
      virt-viewer
      spice
      spice-gtk
      spice-protocol
      virtio-win
      win-spice
      adwaita-icon-theme
    ];

    # Manage the virtualisation services.
    virtualisation = {
      libvirtd = {
        enable = true;
        qemu = {
          # TPM emulation.
          swtpm.enable = true;
          # NOTE: the `qemu.ovmf` submodule was removed on nixpkgs-unstable
          # (NixOS 25.11+). OVMF/UEFI firmware images now ship by default and
          # are exposed under /run/libvirt/nix-ovmf, so no ovmf config is
          # needed here any more.
        };
      };
      spiceUSBRedirection.enable = true;
    };
    services.spice-vdagentd.enable = true;
  };
}
