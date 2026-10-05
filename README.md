# NixOS-VM

A Nix **flake** that exposes a reusable NixOS **module** for turning any NixOS
host into a VM host, using [virt-manager](https://virt-manager.org/) +
[libvirt](https://libvirt.org/) + [SPICE](https://www.spice-space.org/).

Import the module into your own host configuration and it will:

- install `virt-manager`, `virt-viewer` and the SPICE tooling,
- enable `libvirtd` with `swtpm` (TPM) and UEFI/OVMF (`OVMFFull`),
- enable SPICE USB redirection and the SPICE guest-agent daemon,
- enable `dconf` (needed by virt-manager),
- add a user you choose to the `libvirtd` group so it can manage VMs
  without root,
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

        # The VM-host module:
        nixos-vm.nixosModules.default

        # Tell it which user should be able to manage VMs:
        { vmSetup.user = "alice"; }
      ];
    };
  };
}
```

Then rebuild:

```sh
sudo nixos-rebuild switch --flake .#myhost
```

That's the whole workflow: add the input, add the module, set `vmSetup.user`,
rebuild.

## Module options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `vmSetup.enable` | bool | `true` | Enables the whole VM-host setup. Set to `false` to turn it off without removing the import. |
| `vmSetup.user` | string or `null` | `null` | User to add to the `libvirtd` group. Leave `null` if you manage that group membership yourself. |
| `vmSetup.autoConnect` | bool | `true` | Preseed virt-manager with an auto-connecting `qemu:///system` connection via a system-wide dconf default. Set `false` to leave virt-manager's connection list untouched. |

Because `vmSetup.enable` defaults to `true`, simply importing the module turns
everything on; you normally only need to set `vmSetup.user`.

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
