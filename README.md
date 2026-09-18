# habbo-nixos

<!-- baked with love on coco's pixel safari gifs: https://pixelsafari.neocities.org -->

![palmtrees](https://pixelsafari.neocities.org/favicon/palmtrees.gif)
**Habbo Retro, the NixOS way** — a self-contained NixOS flake that brings up a
complete **Habbo Retro hotel** (Arcturus Morningstar 3.5.5 emulator + Atom CMS +
Nitro HTML5 client) from a single `nixosModules.habbo` import.
![palmtrees](https://pixelsafari.neocities.org/favicon/palmtrees.gif)

![construction](https://slimysomething.neocities.org/extras/images/Under_Construction_Bar.gif)

> This flake is modeled after `habbo-dev`, the reference hotel running in
> production on this machine — the same stack, declared declaratively.

![divider](https://pixelsafari.neocities.org/dividers/archingheartbow.gif)

## ✨ What the flake declares

| Piece | What you get |
|---|---|
| 🗄️ **MySQL / MariaDB 10.11** | `services.mysql` with databases `habbo` + `orioncms` and app user `habbo` (grants on both) |
| 🎮 **Emulator** | `habbo-arcturus.service` — Arcturus Morningstar 3.5.5 on Java 17, ports **3000** game TCP / **2096** websocket / **3560** RCON, `Restart=on-failure` |
| 🐘 **PHP-FPM** | pool `habbo` on PHP **8.5** with `pdo_mysql` (required by Atom CMS) |
| 🌐 **Nginx** | vhost `caravelho.com.br` serving the CMS via fastcgi, plus `/client/` for the Nitro build |
| 🪄 **`sub_filter`** | `renderer-config.json` rewritten per request — `ws://<request-host>:2096` so the client connects no matter which host you use |
| 🔗 **tmpfiles** | `/var/www/habbo → <habboRoot>/cms` symlink created at boot |
| 🔓 **ProtectHome=false** | on nginx/php-fpm (the CMS lives under `/home/...`) |
| 🛡️ **Extras** | `fail2ban`, `br-abnt2` keymap, `America/Fortaleza` tz, firewall ports 80/443/3000/2096/3306 |

![divider](https://pixelsafari.neocities.org/dividers/alternatestars.gif)

## 🗺️ Repo layout

```
habbo-nixos/
├── flake.nix              # entry point: module, example config, 5 test checks
├── modules/
│   └── habbo.nix          # the whole stack as one NixOS module
├── tests/
│   ├── mysql.nix          # VM test: mariadb up, both DBs, user + grants
│   ├── nginx.nix          # VM test: vhost, /client/, sub_filter by Host
│   ├── php.nix            # VM test: fpm pool, socket, pdo_mysql loaded
│   ├── services.nix       # VM test: all units, ExecStart + Restart policy
│   └── (system-module)    # VM test: module imports cleanly
└── README.md
```

`habboRoot` (top of `flake.nix` / `modules/habbo.nix`) points at the project
with the real artifacts — emulator JAR, CMS, client build. On a fresh server,
clone your `habbo-dev` repo there and adjust the path.

![divider](https://pixelsafari.neocities.org/dividers/beehearts.gif)

## 🧩 Stack & credits

Every piece of this flake stands on the shoulders of the Habbo retro community:

| Component | Role in the stack | Project |
|---|---|---|
| **Arcturus Morningstar 3.5.5** | Game emulator (Java) — rooms, pathfinder, catalog, RCON | [git.krews.org/morningstar/Arcturus-Community](https://git.krews.org/morningstar/Arcturus-Community) · [GitHub mirror](https://github.com/krewsarchive/Arcturus-Community) — community fork of **Arcturus Emulator** by TheGeneral · GPL-3.0 |
| **Atom CMS** | Website + hotel management (Laravel 13, themes, housekeeping) | [github.com/ObjectRetros/atomcms](https://github.com/ObjectRetros/atomcms) |
| **Nitro React** | HTML5 game client (the "flash-less" Habbo player) | [github.com/billsonnn/nitro-react](https://github.com/billsonnn/nitro-react) |
| **Nitro Renderer** | Pixi-based rendering engine behind the client | [github.com/billsonnn/nitro-renderer](https://github.com/billsonnn/nitro-renderer) |
| **Nitro Converter** | Turns legacy SWF assets into `.nitro` bundles | [github.com/billsonnn/nitro-converter](https://github.com/billsonnn/nitro-converter) |
| **ms-websockets** | Nitro websocket plugin (SSO login over ws :2096) | [git.krews.org/nitro/ms-websockets](https://git.krews.org/nitro/ms-websockets) |
| **default-assets** | Gamedata / furniture / figure assets for Nitro | [git.krews.org/nitro/default-assets](https://git.krews.org/nitro/default-assets) |
| **NixOS + nixpkgs** | The reproducible base everything runs on | [nixos.org](https://nixos.org) · [github.com/NixOS/nixpkgs](https://github.com/NixOS/nixpkgs) |
| **MariaDB / PHP 8.5 / nginx** | Data + app + web layers, packaged by nixpkgs | [mariadb.org](https://mariadb.org) · [php.net](https://php.net) · [nginx.org](https://nginx.org) |
| 🎨 **Pixel Safari** | All the retro graphics on this page | [pixelsafari.neocities.org](https://pixelsafari.neocities.org) — Coco's graphics archive |

![mysql badge](https://pixelsafari.neocities.org/misc/badge/mysql.gif)
![php badge](https://pixelsafari.neocities.org/misc/badge/phprendered.gif)
![php addict](https://pixelsafari.neocities.org/misc/badge/phpaddict.gif)
![linux](https://pixelsafari.neocities.org/misc/badge/linux.png)
![unix](https://pixelsafari.neocities.org/misc/badge/unix.gif)
![html editor](https://pixelsafari.neocities.org/misc/badge/htmleditor.gif)

![divider](https://pixelsafari.neocities.org/dividers/4cookies.gif)

## 🧪 Testing it — without touching your system

![blinkie](https://pixelsafari.neocities.org/blinkies/80stoys.gif)
**VM tests** — every check builds the system and boots it inside an ephemeral
NixOS VM (QEMU), runs assertions, then discards it. Your host is untouched.

```sh
# all 5 checks (mysql, nginx, php, services, system-module)
nix flake check

# one check, faster iteration
nix build .#checks.x86_64-linux.mysql
nix build .#checks.x86_64-linux.nginx
nix build .#checks.x86_64-linux.php
nix build .#checks.x86_64-linux.services

# just compile the example system, no VM, no activation
nixos-rebuild build --flake .#habbo
```

![blinkie](https://pixelsafari.neocities.org/blinkies/2003.gif)
**What the VM tests actually assert**

| Check | Asserts |
|---|---|
| `mysql` | mariadb up on :3306, databases `habbo` + `orioncms` exist, user `habbo` has grants on both and connects by password |
| `nginx` | vhost serves `/client/` (200), `renderer-config.json` present, `sub_filter` rewrites `ws://` to the request Host (and does **not** leak to other hosts) |
| `php` | php-fpm pool up, `/run/phpfpm/habbo.sock` listening, `pdo_mysql` loaded |
| `services` | `mysql`/`nginx`/`phpfpm-habbo` all up; `habbo-arcturus` unit exists with correct `ExecStart`, `WorkingDirectory` and `Restart=on-failure` |
| `system-module` | the module imports cleanly into a bare NixOS |

![blinkie](https://pixelsafari.neocities.org/blinkies/animal/fireflies.gif)
> ⚠️ On this old 8GB box: run one check at a time with a generous timeout —
> the first build downloads the whole `nixos-26.05` branch into the store;
> afterwards everything is cached. Example:
> `timeout 3600 nix build .#checks.x86_64-linux.mysql`

![divider](https://pixelsafari.neocities.org/dividers/blackpinkhearts.gif)

## 🚀 Deploying on a fresh server

1. **Clone the reference project** (emulator JAR, CMS, client assets) and point
   `habboRoot` at it if the path differs:
   ```sh
   git clone <your-habbo-dev-repo> ~/projects/habbo-dev
   ```

2. **Import the module** in your config:
   ```nix
   # /etc/nixos/flake.nix
   {
     inputs.habbo-nixos.url = "path:/home/<user>/projects/habbo-nixos";
     # or: github:<you>/habbo-nixos
     outputs = { self, nixpkgs, habbo-nixos }: {
       nixosConfigurations.myhotel = nixpkgs.lib.nixosSystem {
         modules = [
           habbo-nixos.nixosModules.habbo
           ./hardware-configuration.nix
         ];
       };
     };
   }
   ```

3. **Bring it up:**
   ```sh
   sudo nixos-rebuild switch --flake .#myhotel
   ```

![divider](https://pixelsafari.neocities.org/dividers/biscuits.gif)

## 🔧 Post-install (one time only)

The flake creates the databases and the MySQL user, but **not** the data.
Import the schema and set up the CMS:

- Game schema: `mysql -u habbo -p habbo < arcturus/base_arcturus.sql`
  (MariaDB rejects MySQL-8 collation — `sed 's/utf8mb4_0900_ai_ci/utf8mb4_unicode_ci/g'` first)
- CMS (Atom): `composer install && php artisan atom:install` inside `cms/`
- Client assets (gamedata, c_images, dcr/hof_furni, SWFs): copy to `cms/public/client/`
- SSO trigger between databases (`orioncms.auth_ticket` → `habbo.users`)
- Tune `config.ini` (MySQL credentials, `game.tcp.port=3000`, websocket 2096)

![divider](https://pixelsafari.neocities.org/dividers/balloons.gif)

## 📚 Reference

All the hard-won troubleshooting (websocket handshake, whitelist persistence,
20%/80% loading, sub_filter, ports) lives in
`~/projects/habbo-dev/HABBO-DEV-GUIDE.md` — read it before touching the stack.

![divider](https://pixelsafari.neocities.org/dividers/alternatestars.gif)

## ❤️ Credits & thanks

- **TheGeneral** — original Arcturus Emulator
- **Krews.org team** — Arcturus Morningstar (Harmonic, Beny, Capheus, Claudio
  and every contributor of the community project)
- **ObjectRetros** — Atom CMS
- **billsonnn & the Nitro team** — Nitro React / Renderer / Converter / assets
- **NixOS & nixpkgs maintainers** — the OS that makes this reproducible
- **Coco's Pixel Safari** ([pixelsafari.neocities.org](https://pixelsafari.neocities.org)) —
  every gif on this page. A wonderful graphics archive site — visit it!

![blinkie](https://pixelsafari.neocities.org/blinkies/angel.gif)
![blinkie](https://pixelsafari.neocities.org/blinkies/animal/catsprites.gif)
![blinkie](https://pixelsafari.neocities.org/blinkies/animal/batmoon.gif)
![blinkie](https://pixelsafari.neocities.org/blinkies/animal/bunnyhug.gif)
![blinkie](https://pixelsafari.neocities.org/blinkies/angelicbabe.gif)
![blinkie](https://pixelsafari.neocities.org/blinkies/alamode.gif)

![divider](https://pixelsafari.neocities.org/dividers/3pumpkins.gif)

---

![end](https://pixelsafari.neocities.org/text/end1.gif)
*habbo-nixos — host your retro hotel the reproducible way.*
![heart](https://pixelsafari.neocities.org/text/love1.gif)