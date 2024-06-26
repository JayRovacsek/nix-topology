f: {
  lib,
  config,
  options,
  ...
}: let
  inherit
    (lib)
    attrValues
    elem
    flatten
    flip
    literalExpression
    mkDefault
    mkIf
    mkMerge
    mkOption
    types
    ;
in
  f {
    options.nodes = mkOption {
      default = {};
      description = ''
        Defines nodes that are shown in the topology graph.
        Nodes usually correspond to nixos hosts or other devices in your network.
      '';
      type = types.attrsOf (types.submodule (nodeSubmod: {
        options = {
          id = mkOption {
            description = "The id of this node";
            default = nodeSubmod.config._module.args.name;
            readOnly = true;
            type = types.str;
          };

          name = mkOption {
            description = "The name of this node";
            type = types.str;
            default = nodeSubmod.config.id;
            defaultText = literalExpression ''"<name>"'';
          };

          hardware = {
            info = mkOption {
              description = "A single line of information about this node's hardware. Usually the model name or a description the most important components.";
              type = types.str;
              default = "";
            };

            image = mkOption {
              description = "An image representing this node, usually shown larger than an icon.";
              type = types.nullOr types.path;
              default = null;
            };
          };

          icon = mkOption {
            description = "The icon representing this node. Usually shown next to the name. Must be a path to an image or a valid icon name (<category>.<name>).";
            type = types.nullOr (types.either types.path types.str);
            default = null;
          };

          deviceType = mkOption {
            description = ''
              The device type of the node. This can be set to anything, but some special
              values exist that will automatically set some other defaults, most notably
              the deviceIcon and renderer.preferredType.
            '';
            type = types.either (types.enum ["nixos" "internet" "router" "switch" "device"]) types.str;
          };

          guestType = mkOption {
            description = "If the device is a guest of another device, this will tell the type of guest it is.";
            default = null;
            type = types.nullOr (types.either (types.enum ["microvm" "nixos-container"]) types.str);
          };

          deviceIcon = mkOption {
            description = "The icon representing this node's type. Must be a path to an image or a valid icon name (<category>.<name>). By default an icon will be selected based on the deviceType.";
            type = types.nullOr (types.either types.path types.str);
            default = null;
          };

          parent = mkOption {
            description = "The id of the parent node, if this node has a parent.";
            default = null;
            type = types.nullOr types.str;
          };

          # Rendering related hints and settings
          renderer = {
            preferredType = mkOption {
              description = ''
                An optional hint to the renderer to specify whether this node should preferrably
                rendered as a full card, or just as an image with name. If there is no hardware
                image, this will usually still render a small card.
              '';
              type = types.enum ["card" "image"];
              default = "card";
              defaultText = ''"card" # defaults to card but is also derived from the deviceType if possible.'';
            };
          };
        };

        config = let
          nodeCfg = nodeSubmod.config;
        in
          mkIf config.topology.isMainModule (mkMerge [
            {
              # Set the default icon, if an icon exists with a matching name
              deviceIcon = mkIf (config.icons.devices ? ${nodeCfg.deviceType}) (
                mkDefault ("devices." + nodeCfg.deviceType)
              );

              # Set the hardware info to the guest type if nothing else was set
              hardware.info = mkIf (nodeCfg.guestType != null) (mkDefault nodeCfg.guestType);
            }

            # If the device type is not a full nixos node, try to render it as an image with name.
            (mkIf (elem nodeCfg.deviceType ["internet" "router" "switch" "device"]) {
              renderer.preferredType = mkDefault "image";
            })
          ]);
      }));
    };

    config = {
      assertions = flatten (
        flip map (attrValues config.nodes) (
          node: [
            (config.lib.assertions.iconValid
              node.icon "nodes.${node.id}.icon")
            (config.lib.assertions.iconValid
              node.deviceIcon "nodes.${node.id}.deviceIcon")
          ]
        )
      );
    };
  }
