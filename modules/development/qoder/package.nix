{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  zstd,

  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  krb5,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libsecret,
  libuuid,
  libxkbcommon,
  nspr,
  nss,
  pango,
  systemd,
  zlib,

  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxkbfile,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxshmfence,
  libxtst,

  version,
  url,
  hash,
  passwordStore ? "gnome-libsecret",
  extraFlags ? [ ],
}:

let
  runtimeLibs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    krb5
    libdrm
    libgbm
    libglvnd
    libnotify
    libsecret
    libuuid
    libxkbcommon
    nspr
    nss
    pango
    zlib
    (lib.getLib systemd)

    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxkbfile
    libxrandr
    libxrender
    libxscrnsaver
    libxshmfence
    libxtst
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "qoder";
  inherit version;

  src = fetchurl {
    inherit url hash;
    name = "qoder-${version}_amd64.deb";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
    zstd
  ];

  buildInputs = runtimeLibs;

  # dlopen'ed at runtime, so autoPatchelf can't see them in the ELF headers
  runtimeDependencies = [
    (lib.getLib systemd)
    libglvnd
    libgbm
  ];

  dontConfigure = true;
  dontBuild = true;
  dontWrapGApps = true; # wrapped by hand in preFixup

  # `ar` comes from stdenv. --no-same-permissions keeps the setuid bit on
  # chrome-sandbox from blowing up the build inside the nix sandbox.
  unpackPhase = ''
    runHook preUnpack
    ar x $src
    tar -xf data.tar.* --no-same-permissions --no-same-owner
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/qoder $out/bin

    if [ -d usr/share/qoder ]; then
    cp -r usr/share/qoder/. $out/share/qoder/
    elif [ -d opt/Qoder ]; then
    cp -r opt/Qoder/. $out/share/qoder/
    elif [ -d opt/qoder ]; then
    cp -r opt/qoder/. $out/share/qoder/
    else
    echo "unexpected .deb layout:" >&2
    find . -maxdepth 3 -type d >&2
    exit 1
    fi

    for d in applications icons pixmaps; do
    if [ -d "usr/share/$d" ]; then
    mkdir -p "$out/share/$d"
    cp -r "usr/share/$d/." "$out/share/$d/"
    fi
    done

    # Store paths can never be setuid — drop the helper, use --no-sandbox.
    rm -f $out/share/qoder/chrome-sandbox

    if [ ! -x $out/share/qoder/qoder ]; then
    echo "main binary not where expected:" >&2
    ls $out/share/qoder >&2
    exit 1
    fi

    for f in $out/share/applications/*.desktop; do
    [ -e "$f" ] || continue
    substituteInPlace "$f" \
    --replace-quiet "/usr/share/qoder/qoder" "$out/bin/qoder" \
    --replace-quiet "/opt/Qoder/qoder" "$out/bin/qoder" \
    --replace-quiet "/opt/qoder/qoder" "$out/bin/qoder"
    done

    runHook postInstall
  '';

  # preFixup, not installPhase: gappsWrapperArgs is only populated by then.
  preFixup = ''
    makeWrapper $out/share/qoder/qoder $out/bin/qoder \
    "''${gappsWrapperArgs[@]}" \
    --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}" \
    --set-default NIXOS_OZONE_WL 1 \
    --add-flags "--no-sandbox" \
    --add-flags "--password-store=${passwordStore}" \
    ${lib.optionalString (extraFlags != [ ]) ''--add-flags "${lib.escapeShellArgs extraFlags}"''}
  '';

  meta = {
    description = "Qoder — agentic coding IDE, repackaged from the upstream .deb";
    homepage = "https://qoder.com";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "qoder";
  };
})
