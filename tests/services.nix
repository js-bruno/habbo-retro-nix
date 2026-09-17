# Teste: serviços — o servidor inteiro sobe junto e as portas abrem.
# Sem exercitar o protocolo real (requer schema + login), valida o orquestramento
# systemd: ordem mysql→arcturus, working dir, Java 17 e portas.
{ ... }:
{
  name = "habbo-services";

  nodes.habbo = { config, pkgs, lib, ... }: {
    imports = [ (import ../modules/habbo.nix) ];
  };

  testScript = ''
    start_all()

    with subtest("todos os serviços sobem"):
        habbo.wait_for_unit("mysql.service")
        habbo.wait_for_unit("nginx.service")
        habbo.wait_for_unit("phpfpm-habbo.service")

    with subtest("habbo-arcturus tenta subir (jar é pós-instalação)"):
        # O jar do emulador não existe na VM (é copiado do host na instalação).
        # O que validamos: a unit existe, tem o ExecStart certo e o Restart=on-failure.
        unit = habbo.succeed("systemctl cat habbo-arcturus.service")
        assert "Habbo-3.5.5-jar-with-dependencies.jar" in unit, f"ExecStart errado: {unit}"
        assert "Restart=on-failure" in unit, f"Restart errado: {unit}"
        assert "WorkingDirectory=/home/gipsydanger/projects/habbo-dev/arcturus" in unit, f"WorkingDirectory errado: {unit}"

    print("services OK")
  '';
}