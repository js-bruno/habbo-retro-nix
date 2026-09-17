{
  description = "Habbo Retro (Arcturus 3.5.5 + Atom CMS + Nitro client) as a NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    # Raiz do projeto habbo-dev (JAR, CMS, client). Em produção é este caminho;
    # num server novo, clone o repo e aponte para cá.
    habboRoot = "/home/gipsydanger/projects/habbo-dev";
  in {
    # ---------------------------------------------------------------------------
    # Módulo NixOS reutilizável — o servidor inteiro em um import:
    #   nixosConfigurations.meuhotel = nixpkgs.lib.nixosSystem {
    #     modules = [
    #       self.nixosModules.habbo
    #       ./hardware-configuration.nix
    #     ];
    #   };
    # O código do módulo vive em modules/habbo.nix (importável também pelos tests).
    # ---------------------------------------------------------------------------
    nixosModules.habbo = import ./modules/habbo.nix;

    # ---------------------------------------------------------------------------
    # Configuração de exemplo — um server novo sobe com:
    #   sudo nixos-rebuild switch --flake .#habbo
    # (adicione o seu hardware-configuration.nix em modules)
    # ---------------------------------------------------------------------------
    nixosConfigurations.habbo = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        self.nixosModules.habbo
        {
          # fileSystems do seu host real entram aqui
          # (ex.: ./hardware-configuration.nix)
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "/dev/sda1";
            fsType = "ext4";
          };
        }
      ];
    };

    # ---------------------------------------------------------------------------
    # Testes (NixOS VM tests) — rode com:
    #   nix flake check            # todos
    #   nix build .#checks.x86_64-linux.<nome>  # um específico
    # ---------------------------------------------------------------------------
    checks.${system} = let
      runTest = pkgs.testers.runNixOSTest;
      mkTest = name: runTest (import ./tests/${name}.nix);
    in {
      mysql = mkTest "mysql";
      nginx = mkTest "nginx";
      php = mkTest "php";
      services = mkTest "services";
      system-module = runTest {
        name = "habbo-system-module";
        nodes.habbo = { ... }: {
          imports = [ self.nixosModules.habbo ];
        };
        testScript = "habbo.succeed('true')";
      };
    };
  };
}