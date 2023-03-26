# nix repl -f aws.nix
with builtins;
with (import <nixpkgs> { }).pkgs.lib;
let
  inputJSON = fromJSON (readFile ./aws.json);
  providerName = head (attrNames inputJSON.provider_schemas);
  schema = inputJSON.provider_schemas.${providerName};
  resourcesOrginal = mapAttrs' (name: value: { name = substring 4 ((stringLength name) - 4) name; value = value; }) schema.resource_schemas;
  resources = mapAttrs'
    (name: value: {
      name = substring 4 ((stringLength name) - 4) name;
      value =
        mapAttrs (name: value: value) value.block.attributes;
    })
    schema.resource_schemas;
in
if inputJSON.format_version != "1.0" then
  throw "format_version is not 1.0" else
  {
    schema = schema;
    providerName = providerName;
    resources = resources;
  }
