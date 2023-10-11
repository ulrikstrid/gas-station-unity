{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    tezos.url = "github:marigold-dev/tezos-nix";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
  };

  nixConfig = {
    extra-trusted-public-keys = [ "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=" "tezos-nix-cache.marigold.dev-1:4nS7FPPQPKJIaNQcbwzN6m7kylv16UCWWgjeZZr2wXA=" ];
    extra-substituters = [ "https://devenv.cachix.org" "https://tezos.nix-cache.workers.dev" ];
  };

  outputs = { self, nixpkgs, tezos, devenv, systems, ... } @ inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      devShells = forEachSystem
        (system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
            tezos_packages = tezos.packages.${system};
          in
          {
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                {
                  env.OCTEZ_CLIENT_UNSAFE_DISABLE_DISCLAIMER = "yes";
                  # https://devenv.sh/reference/options/
                  packages = [ pkgs.ligo tezos_packages.next-octez-client ];

                  scripts.build_contract.exec = ''
                    ${pkgs.ligo}/bin/ligo compile contract './main.jsligo' > 'FA2.tz'
                  '';

                  scripts.build_storage.exec = ''
                    ${pkgs.ligo}/bin/ligo compile storage './main.jsligo' '{                                                 
                        ledger: Big_map.empty as big_map<address,map<nat,nat>>,
                        token_metadata: Big_map.empty as big_map<nat, {token_id : nat, token_info : map<string, bytes>}>,
                        operators: Big_map.empty as big_map<[address, address], set<nat>>,
                        marketplace: Map.empty as map<[address, nat], [nat, nat]>,
                        token_counter:(1 as nat)
                    }'
                  '';


                  scripts.build_parameter.exec = ''
                    ${pkgs.ligo}/bin/ligo compile parameter './main.jsligo' 'SetMeta({token_id:0 as nat, token_info:Map.literal( list([
                      ["item", Bytes.pack( {itemType:0, damage:0,armor:0,attackSpeed:0,healthPoints:0,manaPoints:0} )],

                      ["name", Bytes.pack("Example Coin")],
                      ["symbol", Bytes.pack("UnityTezos")],
                      ["decimals", Bytes.pack(0)],

                      ["image", Bytes.pack("ipfs://bafybeian23odhsho6gufacrcpcr65ft6bpqavzk36pt22lhcjoxy45mqpa")],
                      ["artifactUri", Bytes.pack("ipfs://bafybeian23odhsho6gufacrcpcr65ft6bpqavzk36pt22lhcjoxy45mqpa")],
                      ["displayUri", Bytes.pack("ipfs://bafybeian23odhsho6gufacrcpcr65ft6bpqavzk36pt22lhcjoxy45mqpa")],
                      ["thumbnailUri", Bytes.pack("ipfs://bafybeian23odhsho6gufacrcpcr65ft6bpqavzk36pt22lhcjoxy45mqpa")],
                      ["description", Bytes.pack("Unity Tezos Example Project coins used as soft currency")],
                      ["minter", Bytes.pack(Tezos.get_sender())],
                      ["creators", Bytes.pack(["https://assetstore.unity.com/packages/essentials/tutorial-projects/ui-toolkit-sample-dragon-crashers-231178"])],
                      ["isBooleanAmount", Bytes.pack(false)],

                      ["date", Bytes.pack(Tezos.get_now())]

                      ]) )})'
                  '';

                  scripts.set_meta.exec = ''
                    octez-client transfer 0 from holder to KT1UMxkM324nuYnDssv3z7L3obk262xN9CRC --entrypoint "setMeta" --arg "$(build_parameter)"
                  '';

                  scripts.originate_contract.exec = ''
                    octez-client originate contract FA2 transferring 0 from holder running FA2.tz --init "$(build_storage)" --burn-cap 5.0 $1
                  '';

                  scripts.prepare_octez.exec = ''
                    octez-client --endpoint https://ghostnet.tezos.marigold.dev/ config update

                    octez-client import secret key holder unencrypted:edsk3oRzLs4nUp4TrqsSJxqX9yMN1Jd6h2dx1SJf9DDWgr4tXbkRqm --force
                    octez-client get balance for holder

                    octez-client gen keys holder
                    octez-client list known addresses
                    octez-client show address holder -S
                  '';

                  enterShell = ''
                    ligo version
                  '';
                }
              ];
            };
          });
    };
}

