{
  outputs = {}:{
    nixosModules = (x: x//{default=x.flake-command-not-found;}) {
      flake-command-not-found = ./module.nix;
    };
  };
}
