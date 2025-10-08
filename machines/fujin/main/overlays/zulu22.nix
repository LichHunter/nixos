final: prev: {
  zulu22 = prev.callPackage ({ lib, stdenv, fetchurl, makeWrapper, setJavaClassPath }:
    let
      platform = if stdenv.isLinux then "linux"
                 else if stdenv.isDarwin then "macos"
                 else throw "Unsupported platform";

      arch = if stdenv.isx86_64 then "x64"
             else if stdenv.isAarch64 then "aarch64"
             else throw "Unsupported architecture";

      version = "22.32.21";

      hashes = {
        "linux-x64" = "sha256-8fvtwOc/aXHnufwjNTvv9iB9ZIFRWhFmdLix9NtthEE=";
        "linux-aarch64" = "sha256-3RLNNEbMk5wAZsQmbQj/jpx9iTL/yr9N3wL4t7m6c+s=";
        "macos-x64" = "sha256-Y6PSNQjHRXukwux2sVbvpTIqT+Cg+KeG1C0iSEwyKZw=";
        "macos-aarch64" = "sha256-o0VkWB4+PzBmNNWy+FZlyjTgukBTe6owfydb3YNfEE0=";
      };

    in stdenv.mkDerivation {
      pname = "zulu";
      inherit version;

      src = fetchurl {
        url = "https://cdn.azul.com/zulu/bin/zulu22.32.21-ca-crac-jdk22.0.2-linux_x64.tar.gz";
        hash = hashes."${platform}-${arch}";
      };

      nativeBuildInputs = [ makeWrapper ];

      installPhase = ''
        mkdir -p $out
        cp -r ./* $out/
      '';

      meta = with lib; {
        description = "Certified builds of OpenJDK";
        platforms = platforms.linux ++ platforms.darwin;
      };
    }
  ) {};
}
