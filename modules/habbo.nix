# Habbo Retro — módulo NixOS completo.
# Usado pelo flake (nixosModules.habbo) e pelos testes (import direto).
# Raiz do projeto habbo-dev (JAR, CMS, client). Em produção é este caminho;
# num server novo, clone o repo e ajuste aqui.
{ config, pkgs, lib, ... }:
let
  habboRoot = "/home/gipsydanger/projects/habbo-dev";
in {
  # -------------------------------------------------------------------------
  # Base
  # -------------------------------------------------------------------------
  # Nota: NÃO definir nixpkgs.config aqui — o test framework (runNixOSTest)
  # torna essa opção read-only. Quem usa o módulo define no seu config.
  # -------------------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  console.keyMap = "br-abnt2";
  systemd.defaultUnit = "multi-user.target";
  time.timeZone = "America/Fortaleza";
  i18n.defaultLocale = "pt_BR.UTF-8";

  users.users.habbo = {
    isNormalUser = true;
    homeMode = "755"; # nginx precisa atravessar o home via symlink
    extraGroups = [ "wheel" ];
  };

  networking = {
    hostName = "habbo";
    firewall.allowedTCPPorts = [ 80 443 3000 2096 3306 ];
    useDHCP = true; # ajuste para IP fixo se necessário
  };

  services.fail2ban.enable = true;

  # -------------------------------------------------------------------------
  # MySQL / MariaDB (banco do jogo + CMS)
  # -------------------------------------------------------------------------
  services.mysql = {
    enable = true;
    package = pkgs.mariadb_1011;
    initialDatabases = [
      { name = "habbo"; }
      { name = "orioncms"; }
    ];
    initialScript = pkgs.writeText "habbo-mysql-init.sql" ''
      CREATE USER IF NOT EXISTS 'habbo'@'localhost' IDENTIFIED BY 'habbo123';
      CREATE USER IF NOT EXISTS 'habbo'@'127.0.0.1' IDENTIFIED BY 'habbo123';
      GRANT ALL PRIVILEGES ON habbo.* TO 'habbo'@'localhost';
      GRANT ALL PRIVILEGES ON habbo.* TO 'habbo'@'127.0.0.1';
      GRANT ALL PRIVILEGES ON orioncms.* TO 'habbo'@'localhost';
      GRANT ALL PRIVILEGES ON orioncms.* TO 'habbo'@'127.0.0.1';
      FLUSH PRIVILEGES;
    '';
  };

  # -------------------------------------------------------------------------
  # Emulador Arcturus (systemd)
  #   game TCP 3000 · websocket Nitro 2096 (plugin) · RCON 3560 loopback
  # -------------------------------------------------------------------------
  systemd.services.habbo-arcturus = {
    description = "Habbo Retro - Arcturus Morningstar 3.5.5 Emulator";
    after = [ "mysql.service" "network.target" ];
    wants = [ "mysql.service" ];
    serviceConfig = {
      Type = "simple";
      User = "habbo";
      WorkingDirectory = "${habboRoot}/arcturus";
      ExecStart = "${pkgs.jdk17}/bin/java -jar ${habboRoot}/arcturus/Habbo-3.5.5-jar-with-dependencies.jar";
      Restart = "on-failure";
      RestartSec = 10;
      TimeoutStartSec = 60;
    };
    wantedBy = [ "multi-user.target" ];
  };

  # -------------------------------------------------------------------------
  # PHP-FPM (pool habbo, PHP 8.5) — serve o CMS
  # -------------------------------------------------------------------------
  services.phpfpm.pools.habbo = {
    user = "nginx";
    group = "nginx";
    phpPackage = pkgs.php85.withExtensions ({ enabled, all }: enabled ++ [ all.pdo_mysql ]);
    settings = {
      "pm" = "dynamic";
      "pm.max_children" = "5";
      "pm.start_servers" = "2";
      "pm.min_spare_servers" = "1";
      "pm.max_spare_servers" = "3";
      "listen.owner" = "nginx";
      "listen.group" = "nginx";
      "listen.mode" = "0660";
    };
  };
  # CMS vive em ${habboRoot}/cms → /var/www/habbo (symlink).
  # ProtectHome=true (default) bloqueia a leitura de /home.
  systemd.services.phpfpm-habbo.serviceConfig.ProtectHome = lib.mkForce false;

  # -------------------------------------------------------------------------
  # Nginx (vhost + client Nitro + sub_filter por host)
  # -------------------------------------------------------------------------
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;

    virtualHosts."caravelho.com.br" = {
      root = "/var/www/habbo/public";

      # Client Nitro buildado — servido como /client/
      locations."/client/" = {
        alias = "${habboRoot}/cms/public/client/";
        tryFiles = "$uri $uri/ /client/index.html";
      };

      # renderer-config.json com host dinâmico por request (sub_filter)
      locations."= /client/renderer-config.json" = {
        extraConfig = ''
          sub_filter_once on;
          sub_filter 'ws://localhost:2096' 'ws://''${host}:2096';
          sub_filter 'http://localhost/client/c_images/' 'http://''${host}/client/c_images/';
          sub_filter 'http://localhost/client/dcr/hof_furni' 'http://''${host}/client/dcr/hof_furni';
          sub_filter 'http://localhost/client' 'http://''${host}/client';
          sub_filter_types application/json;
        '';
      };

      locations."/" = {
        index = "index.php index.html";
        tryFiles = "$uri $uri/ /index.php?$query_string";
      };

      locations."~ \\.php$" = {
        extraConfig = ''
          fastcgi_pass unix:${config.services.phpfpm.pools.habbo.socket};
          fastcgi_index index.php;
          include ${pkgs.nginx}/conf/fastcgi_params;
          fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        '';
      };
    };
  };
  systemd.services.nginx.serviceConfig.ProtectHome = lib.mkForce false;

  # -------------------------------------------------------------------------
  # Symlink /var/www/habbo → projeto (criado no boot se ausente)
  # -------------------------------------------------------------------------
  systemd.tmpfiles.rules = [
    "L /var/www/habbo - - - - ${habboRoot}/cms"
  ];
}