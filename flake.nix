{
  outputs = {}:{
    nixosModules = (x: x//{default=x.flake-programdb;}) {
      flake-programdb = ./module.nix;
    };
  };
}
