{
  outputs = { self }: {
    nixosModules = (this: this // { default = this.flake-programdb; }) {
      flake-programdb = ./module.nix;
    };
  };
}
