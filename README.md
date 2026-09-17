# habbo-nixos

Flake NixOS autocontido para subir um servidor **Habbo Retro** (Arcturus Morningstar 3.5.5 + Atom CMS + Nitro client), a partir do servidor de referência `habbo-dev` que roda em produção nesta máquina.

## O que o flake declara

- **`nixosModules.habbo`** — módulo NixOS completo:
  - `services.mysql` (MariaDB, bancos `habbo` + `orioncms`, usuário `habbo`)
  - `habbo-arcturus.service` (emulador Java 17, ports 3000 game / 2096 websocket / 3560 RCON)
  - `phpfpm-habbo` (PHP 8.5 + pdo_mysql, pool `habbo`)
  - `nginx` vhost `caravelho.com.br` com:
    - `/client/` servido do diretório do projeto
    - `sub_filter` no `renderer-config.json` (host dinâmico — ws/host por request)
    - PHP via fastcgi para o CMS (Laravel/Atom)
  - `systemd.tmpfiles` symlink `/var/www/habbo → <habboRoot>/cms`
  - `ProtectHome=false` no nginx/php-fpm (o CMS vive em `/home/...`)
- **`nixosConfigurations.habbo`** — configuração de exemplo (use o seu `hardware-configuration.nix`).

## Deploy num servidor novo

1. Clone o projeto habbo-dev (JAR do emulador, CMS, assets do client):
   ```sh
   git clone <seu-repo-habbo-dev> ~/projects/habbo-dev
   ```
   e ajuste `habboRoot` em `flake.nix` se o caminho diferir.

2. Importe o módulo na sua config:
   ```nix
   # /etc/nixos/flake.nix
   {
     inputs.habbo-nixos.url = "path:/home/<user>/projects/habbo-nixos";
     # ou: github:<voce>/habbo-nixos
     outputs = { self, nixpkgs, habbo-nixos }: {
       nixosConfigurations.meuhotel = nixpkgs.lib.nixosSystem {
         modules = [
           habbo-nixos.nixosModules.habbo
           ./hardware-configuration.nix
         ];
       };
     };
   }
   ```

3. Suba:
   ```sh
   sudo nixos-rebuild switch --flake .#meuhotel
   ```

## Pós-instalação (uma vez)

O flake cria os bancos e o usuário MySQL, mas **não** popula os dados — importe o schema e o CMS:

- Schema do jogo: `mysql -u habbo -p habbo < arcturus/base_arcturus.sql`
- CMS (Atom): `composer install && php artisan atom:install` dentro de `cms/`
- Assets do client (gamedata, c_images, dcr/hof_furni, SWFs): copiar para `cms/public/client/`
- Trigger SSO inter-bancos (`orioncms.auth_ticket` → `habbo.users`) — ver HABBO-DEV-GUIDE.md
- Ajustar `config.ini` (credenciais MySQL, `game.tcp.port=3000`, websocket 2096)

## Build de teste (sem tocar no sistema)

```sh
nix flake check                 # valida módulo e config
nixos-rebuild build --flake .#habbo   # compila o system sem ativar
```

## Referência

Todo o troubleshooting (handshake, whitelist, 20/80%, sub_filter, ports) está em
`~/projects/habbo-dev/HABBO-DEV-GUIDE.md` — leia antes de mexer.