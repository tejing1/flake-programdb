This nixos module restores `command-not-found` behavior on flake-based nixos systems.

It works by using the name of the channel you are following and your nixpkgs rev to find and download the programdb from the channel infrastructure. This download happens at runtime via a systemd service. So long as you follow a branch of nixpkgs which is also a channel, this approach should always work.

# Installation

Import `nixosModules.flake-programdb` from this flake into your nixos configuration through `imports` or the `nixosSystem` function's `modules` argument, and set:

```nix
flake-programdb.enable = true;
flake-programdb.channel = "nixos-unstable"; # Only necessary on unstable. The default will work if following nixos-XX.YY.
```

Full example:
```nix
{
  inputs.nixpkgs
  inputs.flake-programdb.url = "github:tejing1/flake-programdb";
  outputs = { nixpkgs, flake-programdb, ...}: {
    hostname = nixpkgs.lib.nixosSystem {
      system = "x86-64-linux";
      modules = [
        ./configuration.nix
        flake-programdb.nixosModules.flake-programdb
        {
          flake-programdb.enable = true;
          flake-programdb.channel = "nixos-unstable"; # Only necessary on unstable. The default will work if following nixos-XX.YY.
        }
      ];
    };
  }
}
```

# Options

## flake-programdb.enable
Enable the module. Without this set to `true`, it does nothing.
Defaults to `false`.

## flake-programdb.dbDir
Directory in which to store the downloaded programdb and a revision tag for comparison. The directory will be created through tmpfiles.d rules if necessary.
Defaults to `"/var/cache/programdb"`.

## flake-programdb.channel
Name of the channel whose history should be searched for the right revision of nixpkgs.
Defaults to `"nixos-" + config.system.nixos.release`.
Must be set when following `nixos-unstable`

## flake-programdb.rev
The git revision of nixpkgs to search for in the history of the channel.
Defaults to `config.system.nixos.revision`.
