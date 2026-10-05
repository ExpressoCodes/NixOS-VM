# Reusable NixOS module: VM host via virt-manager / libvirt / SPICE.
#
# Import this module (see flake.nix `nixosModules.default`) and it will:
#   * install virt-manager / virt-viewer / SPICE tooling,
#   * enable libvirtd (with swtpm + UEFI/OVMF) and SPICE USB redirection,
#   * enable the SPICE guest agent daemon and dconf,
#   * add a user of your choice to the `libvirtd` group,
#   * preseed virt-manager with an auto-connecting `qemu:///system`
#     connection (so no manual File -> Add Connection is needed).
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

    autoConnect = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Preseed virt-manager with an auto-connecting `qemu:///system`
        connection via a system-wide dconf default, so users do not have to
        add it manually (File -> Add Connection). This is installed as a
        non-destructive default (the per-user dconf database still takes
        priority), so users can still remove or change the connection.
        Set to `false` to leave virt-manager's connection list untouched.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable dconf (needed by virt-manager to store settings).
    programs.dconf.enable = true;

    # Preseed virt-manager's connection list with qemu:///system and mark it
    # autoconnect, system-wide. virt-manager stores connections under this
    # dconf path; `uris`/`autoconnect` are arrays of strings (GVariant `as`).
    #
    # This goes into the default "user" dconf profile. Because that profile has
    # `enableUserDb = true` by default, `user-db:user` is searched first and
    # this file-db only provides a fallback default -- it does not clobber a
    # user's own virt-manager settings, and the user can still override it.
    programs.dconf.profiles.user.databases = lib.mkIf cfg.autoConnect [
      {
        settings."org/virt-manager/virt-manager/connections" = {
          uris = [ "qemu:///system" ];
          autoconnect = [ "qemu:///system" ];
        };
      }
    ];

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
