{
  aspects.homeManager.daily =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.devenv ];
    };
}
