# Teste: PHP-FPM — pool habbo, socket e extensão pdo_mysql.
{ ... }:
{
  name = "habbo-php";

  nodes.habbo = { config, pkgs, lib, ... }: {
    imports = [ (import ../modules/habbo.nix) ];
    # php CLI para inspecionar as extensões do pool (o fpm usa pkgs.php85)
    environment.systemPackages = [ pkgs.php85 ];
  };

  testScript = ''
    start_all()

    with subtest("phpfpm sobe"):
        habbo.wait_for_unit("phpfpm-habbo.service")
        habbo.wait_for_open_port(80) # aguarda nginx também (dependência do teste)

    with subtest("pool habbo escuta no socket"):
        out = habbo.succeed("ls -la /run/phpfpm/habbo.sock")
        assert "srw" in out, f"socket phpfpm-habbo ausente: {out}"

    with subtest("extensão pdo_mysql carregada"):
        habbo.succeed("php -m | grep pdo_mysql")
        habbo.succeed("php -m | grep pdo")

    print("php OK")
  '';
}