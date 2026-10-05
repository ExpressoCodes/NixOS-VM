# NixOS-VM

A Nix **flake** that exposes a reusable NixOS **module** for turning any NixOS
host into a VM host, using [virt-manager](https://virt-manager.org/) +
[libvirt](https://libvirt.org/) + [SPICE](https://www.spice-space.org/).

Import the module into your own host configuration and it will:

- install `virt-manager`, `virt-viewer` and the SPICE tooling,
- enable `libvirtd` with `swtpm` (TPM) and UEFI/OVMF (`OVMFFull`),
- enable SPICE USB redirection and the SPICE guest-agent daemon,
- enable `dconf` (needed by virt-manager),
- add the host's human users (every `isNormalUser = true` account) to the
  `libvirtd` group so they can manage VMs without root,
- preseed virt-manager with an auto-connecting `qemu:///system` connection,
  so you never have to do *File -> Add Connection* by hand.

This flake targets **nixpkgs-unstable**.

## Usage (import the module into your flake)

Add this flake to your inputs and drop the module into your host's module list:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixos-vm.url = "github:ExpressoCodes/NixOS-VM";
    # Optional: keep a single nixpkgs across your flakes.
    nixos-vm.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixos-vm, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        ./hardware-configuration.nix

        # The VM-host module (normal users are added to libvirtd
        # automatically; see "Who can manage VMs" below):
        nixos-vm.nixosModules.default
      ];
    };
  };
}
```

Then rebuild:

```sh
sudo nixos-rebuild switch --flake .#myhost
```

That's the whole workflow: add the input, add the module, rebuild. Then **log
out and back in** (or reboot) so your session picks up the new `libvirtd` group
membership.

## Module options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `vmSetup.enable` | bool | `true` | Enables the whole VM-host setup. Set to `false` to turn it off without removing the import. |
| `vmSetup.users` | list of strings | all `isNormalUser` accounts | Users to add to the `libvirtd` group. Set `[ ]` to opt out. |
| `vmSetup.user` | string or `null` | `null` | Legacy single-user form, kept for backward compatibility. If set, it is added on top of `vmSetup.users`. Prefer `vmSetup.users`. |
| `vmSetup.autoConnect` | bool | `true` | Preseed virt-manager with an auto-connecting `qemu:///system` connection via a system-wide dconf default. Set `false` to leave virt-manager's connection list untouched. |

Because `vmSetup.enable` defaults to `true` and `vmSetup.users` auto-detects
your human accounts, simply importing the module turns everything on; you
normally don't need to set anything.

### Who can manage VMs (`libvirtd` group)

By default, every account with `isNormalUser = true` in `users.users` is added
to the `libvirtd` group (via `users.groups.libvirtd.members`). System accounts
are not included. To control this explicitly:

```nix
# Only these accounts may manage VMs:
vmSetup.users = [ "alice" ];

# Opt out entirely (e.g. you add users to libvirtd yourself elsewhere):
vmSetup.users = [ ];
```

Existing configs that set `vmSetup.user = "alice";` keep working; that user is
added in addition to `vmSetup.users`.

If `vmSetup.autoConnect` is on but nobody ends up in `libvirtd`, the module
emits an evaluation warning, because virt-manager would otherwise hit a polkit
prompt ("System policy prevents management of local virtualized systems").

> **Security note:** membership in `libvirtd` is effectively
> **root-equivalent**: a member can define VMs that attach arbitrary host
> disks or devices. Only put accounts you would trust with root in this group,
> and use `vmSetup.users` to narrow the list if the host has untrusted users.

Group membership is only picked up by **new login sessions**: after the
rebuild, log out and back in (or reboot) before using virt-manager.

### The preseeded virt-manager connection

With `vmSetup.autoConnect = true` (the default), the module installs a
system-wide dconf default (in the `user` profile, after `user-db:user`) that
adds `qemu:///system` to virt-manager's connection list and marks it
autoconnect. This is a **non-destructive** default: a user's own dconf database
still takes priority, so they can remove or change the connection and it won't
be forced back.

Because dconf system defaults are read when a session starts, the connection
appears for **new login sessions**. If you are already logged in when you first
rebuild, log out and back in (or reboot) for virt-manager to pick it up.

## Example configuration

The [`example/`](./example) directory contains a complete, self-contained host
that consumes the module (exposed as `nixosConfigurations.example`). It exists
only as a usage demo and to let `nix flake check` evaluate a full system. You do
**not** need it to use the module.

Note that `example/hardware-configuration.nix` is a **placeholder stub** with
fake UUIDs. A real host's hardware config is generated on the target machine:

```sh
sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
```

Then edit the placeholders in `example/configuration.nix` (hostname, user,
time zone) to taste.
