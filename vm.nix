# Reusable NixOS module: VM host via virt-manager / libvirt / SPICE.
#
# Import this module (see flake.nix `nixosModules.default`) and it will:
#   * install virt-manager / virt-viewer / SPICE tooling,
#   * enable libvirtd (with swtpm + UEFI/OVMF) and SPICE USB redirection,
#   * enable the SPICE guest agent daemon and dconf,
#   * add the host's human users to the `libvirtd` group (auto-detected),
#   * preseed virt-manager with an auto-connecting `qemu:///system`
#     connection (so no manual File -> Add Connection is needed).
#
# By default every account with `isNormalUser = true` is added to `libvirtd`,
# so merely importing the module is enough. Override or opt out with:
#   vmSetup.users = [ "alice" ];   # only these accounts manage VMs
#   vmSetup.users = [ ];           # manage `libvirtd` membership yourself
# (the legacy `vmSetup.user = "alice";` still works and is added on top).
# Set `vmSetup.enable = false;` to turn everything off without un-importing.
#
# SECURITY: membership in `libvirtd` is effectively root-equivalent (members
# can define VMs with arbitrary host disks / devices attached).
# Group changes only apply to new login sessions: log out and back in (or
# reboot) after the rebuild.

{ config, lib, pkgs, ... }:

let
  cfg = config.vmSetup;

  # Every "human" account on the host. This only *reads* config.users.users;
  # the result is written to users.groups.libvirtd.members (never back into
  # users.users), which is what avoids infinite recursion.
  normalUsers = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);

  # Final libvirtd member list: `users` plus the legacy single `user`.
  libvirtdMembers = lib.unique (cfg.users ++ lib.optional (cfg.user != null) cfg.user);

  # Everyone who will actually be in libvirtd, however they got there (used
  # only for the warning below). NixOS already folds users whose
  # extraGroups contain "libvirtd" into this list.
  effectiveMembers = config.users.groups.libvirtd.members;
in
{
  options.vmSetup = {
    # Defaults to true so that merely importing the module sets things up,
    # which matches the intended "import and it just works" UX.
    enable = lib.mkEnableOption "the virt-manager / libvirt / SPICE VM host setup" // {
      default = true;
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = normalUsers;
      defaultText = lib.literalExpression
        "lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users)";
      example = [ "alice" ];
      description = ''
        Usernames to add to the `libvirtd` group so they can manage VMs
        without root. Defaults to every account with `isNormalUser = true`.
        Set to `[ ]` to opt out (e.g. if you manage `libvirtd` membership
        yourself elsewhere). Note that `libvirtd` membership is effectively
        root-equivalent.
      '';
    };

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "alice";
      description = ''
        Legacy single-user form, kept for backward compatibility. If set, this
        username is added to the `libvirtd` group in addition to
        `vmSetup.users`. Prefer `vmSetup.users`.
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

    # Add the selected users to the libvirtd group. This is set on the group
    # (not via users.users.<name>.extraGroups) because the default list is
    # computed from config.users.users -- writing back into users.users would
    # cause infinite recursion.
    users.groups.libvirtd.members = libvirtdMembers;

    # virt-manager auto-connects to qemu:///system, which hits a polkit denial
    # for anyone not in libvirtd. Warn if nobody would end up in the group
    # (checked on the final group membership, so opting out and adding users
    # via extraGroups yourself does not warn).
    warnings = lib.optional (cfg.autoConnect && effectiveMembers == [ ]) ''
      vmSetup: autoConnect is enabled but no users are added to the `libvirtd`
      group (vmSetup.users is empty and vmSetup.user is null). virt-manager
      will show a polkit prompt ("System policy prevents management of local
      virtualized systems") when connecting to qemu:///system. Set
      vmSetup.users, add users to `libvirtd` yourself, or set
      vmSetup.autoConnect = false.
    '';

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
