{
  description = "Reusable NixOS module that turns a host into a VM host via virt-manager / libvirt / SPICE (nixpkgs-unstable)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    {
      # PRIMARY OUTPUT: import this into your own host's module list.
      #   modules = [ inputs.nixos-vm.nixosModules.default ];
      # Normal users are added to `libvirtd` automatically; override with
      # `vmSetup.users = [ ... ];` (or `[ ]` to opt out).
      nixosModules.default = import ./vm.nix;

      # Optional, self-contained example that CONSUMES the module above.
      # It is only a usage demo and is NOT required to use the module.
      # The hardware-configuration.nix it imports is a placeholder stub.
      nixosConfigurations.example = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.default
          ./example/configuration.nix
          ./example/hardware-configuration.nix
        ];
      };

      # Force the example system's toplevel derivation so that `nix flake check`
      # actually instantiates environment.systemPackages. The bare
      # nixosConfigurations check only forces the toplevel value to a
      # derivation (its `type`), not its `drvPath`, so a throwing package alias
      # (e.g. a renamed pkg) would otherwise slip through unnoticed.
      checks.x86_64-linux.example =
        self.nixosConfigurations.example.config.system.build.toplevel;
    };
}
