{
  description = "入門書コレクション - Typst development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Japanese fonts required by templates/book.typ
        fonts = [
          pkgs.noto-fonts-cjk-serif # Noto Serif CJK JP
          pkgs.noto-fonts-cjk-sans  # Noto Sans CJK JP
          pkgs.dejavu_fonts          # DejaVu Serif / Sans (fallback)
        ];

        fontPaths = builtins.concatStringsSep ":" (map (f: "${f}/share/fonts") fonts);
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.typst
            pkgs.gnumake
          ] ++ fonts;

          shellHook = ''
            export TYPST_FONT_PATHS="${fontPaths}"
            echo "Typst $(typst --version)"
            echo "Font paths: $TYPST_FONT_PATHS"
          '';
        };

        # Build all PDFs
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "introductory-guides";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [ pkgs.typst ] ++ fonts;

          buildPhase = ''
            export TYPST_FONT_PATHS="${fontPaths}"
            make all
          '';

          installPhase = ''
            mkdir -p $out
            cp -v *入門.pdf $out/
          '';
        };
      }
    );
}
