{
  pkgs ? import <nixpkgs> { },
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  docs = pkgs.writeShellApplication {
    name = "docs";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      usage() {
        echo "Usage: docs [OPTION]"
        echo ""
        echo "Builds and serves the documentation."
        echo ""
        echo "Options:"
        echo "  -p, --port PORT  Port to serve on (default: 1337)"
        echo "  -h, --help       Show this help"
      }

      port=1337

      while [ $# -gt 0 ]; do
        case "$1" in
          -h|--help)
            usage
            exit 0
            ;;
          -p|--port)
            port="$2"
            shift 2
            ;;
          *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        esac
      done

      nix run ./ci#docs -- ./_site && cd _site && python3 -m http.server "$port"
    '';
  };

  test = pkgs.writeShellScriptBin "check" ''
    usage() {
      echo "Usage: check [OPTION] [NAME]"
      echo ""
      echo "With no arguments, runs all checks."
      echo ""
      echo "Options:"
      echo "  -w, --wrapperModule NAME  Run check wrapperModule-NAME"
      echo "  -l, --wlib NAME           Run check wlib-NAME"
      echo "  -m, --module NAME         Run check module-NAME"
      echo "  NAME                      Run check NAME"
      echo "  -h, --help                Show this help"
    }

    if [ $# -eq 0 ]; then
      nix flake check -Lv ./ci
      exit 0
    fi

    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      -w|--wrapperModule)
        nix build "./ci#checks.${system}.wrapperModule-$2"
        ;;
      -l|--wlib)
        nix build "./ci#checks.${system}.wlib-$2"
        ;;
      -m|--module)
        nix build "./ci#checks.${system}.module-$2"
        ;;
      *)
        nix build "./ci#checks.${system}.$1"
        ;;
    esac && echo "Test passed!"
  '';
in
pkgs.mkShell {
  packages = [
    docs
    test
  ];
}
