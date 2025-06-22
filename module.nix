{ config, lib, pkgs, ... }:
let
  inherit (builtins) attrValues toFile;
  inherit (lib) escapeShellArg mkEnableOption mkOption mkIf;

  cfg = config.flake-programdb;

  # Parses aws listing xml
  hredParse = "contents key @.textContent";

  # Selects the release corresponding to a given rev, or fails with at least some kind of error message
  jqSrc = toFile "select-rev.jq" ''
    def prefixof(str): . as $prefix | str | startswith($prefix);
    map(select(split(".") | last | prefixof($rev))) |
    if length == 1 then
      .[0]
    else
      error("Git revision must have exactly one match among the channel releases. Matches for revision \($rev): \(.)")
    end
  '';

  # Downloads programs.sqlite from the release of the selected channel
  # with the same rev as our nixpkgs input, if not already downloaded.
  downloadDatabase = pkgs.resholve.writeScript "download-programs-database" {
    interpreter = "${pkgs.bash}/bin/bash";
    inputs = attrValues {
      inherit (pkgs) coreutils curl hred jq xz gnutar sqlite;
    };
    execer = [ "cannot:${pkgs.hred}/bin/hred" ];
  } ''
    set -e -o pipefail

    dbdir="$1"
    channel="$2"
    rev="$3"

    # Quit if we already have a database for the right rev
    [ -e "$dbdir/programs.sqlite" ] && [ -e "$dbdir/programs.rev" ] && [ "$(< "$dbdir/programs.rev")" == "$rev" ] && exit 0

    # Ensure we'll keep trying until we succeed
    rm -f "$dbdir/programs.rev"

    # Get the channel prefix used by the release infra
    redirect_url="$(curl -sSw '%{redirect_url}' "https://channels.nixos.org/$channel")"
    current_release="''${redirect_url#https://releases.nixos.org/}"
    channel_prefix="''${current_release%/*}"

    # Parse the list of channel releases for our channel and find the one with our nixpkgs rev
    aws_url="https://nix-releases.s3.amazonaws.com/?delimiter=/&prefix=$channel_prefix/"
    correct_release="$(curl -sSL "$aws_url" | hred ${escapeShellArg hredParse} | jq -rf ${jqSrc} --arg rev "$rev")"

    # Download nixexprs.tar.xz and extract programs.sqlite in stream
    nixexprs_url="https://releases.nixos.org/$correct_release/nixexprs.tar.xz"
    curl -sSL "$nixexprs_url" | xz -d | tar -xO --wildcards '*/programs.sqlite' > "$dbdir/programs.sqlite.part"

    # Check that what we downloaded at least looks like a valid sqlite3 database
    test_result="$(sqlite3 -readonly "$dbdir/programs.sqlite.part" 'PRAGMA integrity_check')"
    [ "$test_result" == "ok" ]

    # Overwrite previous download
    mv -Tf "$dbdir/programs.sqlite.part" "$dbdir/programs.sqlite"
    echo "$rev" > "$dbdir/programs.rev"
  '';
in
{
  options.flake-programdb = {
    enable = mkEnableOption "downloading the command-not-found database";
    dbDir = mkOption {
      type = lib.types.path;
      default = "/var/cache/programdb";
    };
    channel = mkOption {
      type = lib.types.str;
      default = "nixos-" + config.system.nixos.release;
      defaultText = ''"nixos-" + config.system.nixos.release'';
    };
    rev = mkOption {
      type = lib.types.nullOr lib.types.str;
      default = config.system.nixos.revision;
      defaultText = "config.system.nixos.revision";
    };
  };
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.rev != null;
        message = "flake-programdb.rev cannot be null. Autodetection of nixpkgs rev most likely failed. Set the option yourself to indicate your nixpkgs rev.";
      }
    ];
    programs.command-not-found.enable = true;
    programs.command-not-found.dbPath = "${cfg.dbDir}/programs.sqlite";

    systemd.tmpfiles.settings.flake-programdb.${cfg.dbDir} = {
      d = {
        user = "root";
        group = "root";
        mode = "0755";
      };
    };

    systemd.services.flake-programdb = {
      description = "program database download for command-not-found";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${downloadDatabase} ${cfg.dbDir} ${cfg.channel} ${cfg.rev}";
        RemainAfterExit = true;
      };
    };
  };
}
