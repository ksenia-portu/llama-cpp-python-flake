{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: rec {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [
            (final: prev: let
              llama-cpp = prev.callPackage ./pkgs/llama-cpp { };
            in {
              python311 = prev.python311.override {
                packageOverrides = pyfinal: pyprev: {
                  llama-cpp-python = pyfinal.callPackage ./pkgs/llama-cpp-python {
                    llama-cpp = final.llama-cpp;
                  };
                };
              };
              llama-cpp = (llama-cpp.overrideAttrs (oa: rec {
                version = "1662";
                src = prev.fetchFromGitHub {
                  owner = "ggerganov";
                  repo = "llama.cpp";
                  rev = "refs/tags/b${version}";
                  hash = "sha256-Nc9r5wU8OB6AUcb0By5fWMGyFZL5FUP7Oe/aVkiouWg=";
                };
                cmakeFlags = [
                  "-DAMDGPU_TARGETS=gfx1030"
                  "-DLLAMA_AVX2=off"
                  "-DLLAMA_FMA=off"
                  "-DLLAMA_F16C=off"
                ] ++ oa.cmakeFlags or [];
                enableParallelBuilding = true;
              })).override {
                cudaSupport = false;
                rocmSupport = true;
                openclSupport = false;
                openblasSupport = false;
              };
            })
          ];
        };
        packages = {
          llama-cpp = pkgs.llama-cpp;
          llama-cpp-python = pkgs.python3Packages.llama-cpp-python;
          default = packages.llama-cpp-python;
        };
        app = {
          llama-cpp-main = {
            type = "app";
            program = "${packages.llama-cpp}/bin/llama-cpp-main";
          };
          llama-cpp-server = {
            type = "app";
            program = "${packages.llama-cpp}/bin/llama-cpp-server";
          };
          default = app.llama-cpp-main;
        };
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.llama-cpp
            (pkgs.python3.withPackages(ps: with ps; [ llama-cpp-python ]))
          ];
        };
      };
    };
}