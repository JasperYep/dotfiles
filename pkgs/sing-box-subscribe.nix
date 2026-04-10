{ lib, stdenvNoCC, fetchFromGitHub, makeWrapper, python3 }:

let
  python = python3.withPackages (ps: with ps; [
    chardet
    flask
    paramiko
    pyyaml
    requests
    ruamel-yaml
    scp
  ]);
in
stdenvNoCC.mkDerivation {
  pname = "sing-box-subscribe";
  version = "2023-11-21";

  src = fetchFromGitHub {
    owner = "NiuStar";
    repo = "sing-box-subscribe";
    rev = "75e7d2fc9779c06942b9f2dd38b1154d79edbe98";
    hash = "sha256-mor1FApy9x0+HyCJLW6BUJuy/qpE5jE0QyTH1ZPxDMU=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec/sing-box-subscribe
    cp -r . $out/libexec/sing-box-subscribe

    substituteInPlace \
      $out/libexec/sing-box-subscribe/parsers/clash2base64.py \
      --replace-fail \
      "            vless_info[\"protocol\"] = share_link['smux']['protocol']" \
      "            vless_info[\"protocol\"] = share_link.get(\"smux\", {}).get(\"protocol\", \"\")"

    makeWrapper ${python}/bin/python $out/bin/sing-box-subscribe \
      --add-flags "$out/libexec/sing-box-subscribe/main.py" \
      --run "cd $out/libexec/sing-box-subscribe"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Subscription converter used to generate sing-box outbounds";
    homepage = "https://github.com/NiuStar/sing-box-subscribe";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "sing-box-subscribe";
  };
}
