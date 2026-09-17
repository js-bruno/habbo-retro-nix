# Teste: Nginx — vhost, client Nitro, sub_filter e PHP via fastcgi.
# O client e o CMS vivem no host real (habboRoot) — o VM test monta o diretório
# no mesmo caminho para exercitar o fluxo completo.
{ ... }:
let
  root = "/home/gipsydanger/projects/habbo-dev"; # deve casar com habboRoot do módulo
in {
  name = "habbo-nginx";

  nodes.habbo = { config, pkgs, lib, ... }: {
    imports = [ (import ../modules/habbo.nix) ];

    # A VM não tem /home/... — o testScript cria os arquivos reais no FS
    # antes de exercitar o nginx (alias serve direto do disco).
  };

  testScript = ''
    start_all()

    # Fixture: replica o client real do host dentro da VM
    with subtest("faz fixture do client no path do módulo"):
        habbo.succeed("mkdir -p /home/gipsydanger/projects/habbo-dev/cms/public/client")
        habbo.succeed("printf 'dummy client' > /home/gipsydanger/projects/habbo-dev/cms/public/client/index.html")
        habbo.succeed(
            "printf '%s' '{\"config\": {\"url\": \"http://localhost/client\"}, \"socket\": {\"url\": \"ws://localhost:2096\"}}'"
            " > /home/gipsydanger/projects/habbo-dev/cms/public/client/renderer-config.json"
        )

    with subtest("nginx sobe"):
        habbo.wait_for_unit("nginx.service")
        habbo.wait_for_open_port(80)

    with subtest("client é servido em /client/"):
        out = habbo.succeed("curl -s -o /dev/null -w '%{http_code}' http://localhost/client/")
        assert out == "200", f"/client/ retornou {out}"

    with subtest("renderer-config.json é servido"):
        out = habbo.succeed("curl -s http://localhost/client/renderer-config.json")
        assert '"socket"' in out, f"renderer-config.json sem socket.url: {out}"

    with subtest("sub_filter troca ws por Host do request"):
        out = habbo.succeed("curl -s -H 'Host: caravelho.com.br' http://localhost/client/renderer-config.json")
        assert "ws://caravelho.com.br:2096" in out, f"sub_filter não aplicou host: {out}"

    with subtest("sub_filter não vaza para localhost"):
        out = habbo.succeed("curl -s http://localhost/client/renderer-config.json")
        assert "ws://localhost:2096" in out, f"sub_filter aplicou indevidamente: {out}"

    print("nginx OK")
  '';
}