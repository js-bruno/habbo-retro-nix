# Teste: MySQL/MariaDB — bancos, usuário e inicialização.
# Verifica que o módulo cria habbo+orioncms e o usuário com grants.
{ ... }:
{
  name = "habbo-mysql";

  nodes.habbo = { config, pkgs, lib, ... }: {
    imports = [ (import ../modules/habbo.nix) ];
  };

  testScript = ''
    start_all()

    with subtest("mariadb sobe"):
        habbo.wait_for_unit("mysql.service")
        habbo.wait_for_open_port(3306)

    with subtest("bancos existem"):
        out = habbo.succeed("mysql -u root -e 'SHOW DATABASES;'")
        assert "habbo" in out, f"banco habbo ausente: {out}"
        assert "orioncms" in out, f"banco orioncms ausente: {out}"

    with subtest("usuário habbo tem grants"):
        out = habbo.succeed("mysql -u root -e \"SHOW GRANTS FOR 'habbo'@'localhost';\"")
        assert "GRANT ALL PRIVILEGES ON `habbo`.*" in out, f"grant do banco habbo ausente: {out}"
        assert "GRANT ALL PRIVILEGES ON `orioncms`.*" in out, f"grant do banco orioncms ausente: {out}"

    with subtest("usuário habbo conecta pela senha"):
        habbo.succeed("mysql -u habbo -phabbo123 -e 'SELECT 1;'")

    # O schema real é importado manualmente pós-instalação; aqui só validamos
    # a infraestrutura que o flake declara.
    print("mysql OK")
  '';
}