{
  config,
  lib,
  ...
} @ args: let
  inherit
    (lib)
    any
    attrValues
    flatten
    flip
    optional
    optionalAttrs
    ;

  inherit
    (import ./lib.nix args)
    idForInterface
    interfaceLabels
    mkDiagram
    mkEdge
    mkLabel
    mkPort
    mkRender
    pathStyleFromNetworkStyle
    ;

  nodeInterfaceToElk = node: interface:
    [
      {
        children."node:${node.id}".ports."interface:${interface.id}" = mkPort {
          properties = optionalAttrs (node.renderer.preferredType == "card") {
            "port.side" = "WEST";
          };
          labels = interfaceLabels interface;
        };
      }
    ]
    ++ flatten (flip map interface.physicalConnections (
      conn: let
        otherInterface = config.nodes.${conn.node}.interfaces.${conn.interface};
      in
        optionalAttrs (
          (!any (y: y.node == node.id && y.interface == interface.id) otherInterface.physicalConnections)
          || (node.id < conn.node)
        ) (
          optional (!interface.renderer.hidePhysicalConnections && !otherInterface.renderer.hidePhysicalConnections) (
            mkEdge
            (idForInterface node interface.id)
            (idForInterface config.nodes.${conn.node} conn.interface)
            conn.renderer.reverse
            {
              style = optionalAttrs (interface.network != null) (
                pathStyleFromNetworkStyle config.networks.${interface.network}.style
              );
            }
          )
        )
    ));

  nodeToElk = node:
    [
      # Add node to main view
      {
        children."node:${node.id}" = {
          svg = {
            file = config.lib.renderers.svg.node.mkPreferredRender node;
            scale = 0.8;
          };
          properties =
            {
              "portLabels.placement" = "OUTSIDE";
            }
            // optionalAttrs (node.renderer.preferredType == "card") {
              # "portConstraints" = "FIXED_SIDE";
            };
        };
      }
    ]
    ++ optional (node.parent != null) (
      {
        children."node:${node.parent}".ports.guests = mkPort {
          properties."port.side" = "EAST";
          style.stroke = "#49d18d";
          style.fill = "#78dba9";
          labels."00-name" = mkLabel "guests" 1 {};
        };
      }
      // mkEdge "children.node:${node.parent}.ports.guests" "children.node:${node.id}" false {
        style.stroke-dasharray = "10,8";
        style.stroke-linecap = "round";
      }
    )
    ++ map (nodeInterfaceToElk node) (attrValues node.interfaces);
in rec {
  diagram = mkDiagram (
    [
      # Add service overview
      {
        children.services-overview = {
          svg = {
            file = config.lib.renderers.svg.services.mkOverview;
            scale = 0.8;
          };
        };
      }

      # Add network overview
      {
        children.network-overview = {
          svg = {
            file = config.lib.renderers.svg.net.mkOverview;
            scale = 0.8;
          };
        };
      }
    ]
    ++ flatten (map nodeToElk (attrValues config.nodes))
  );
  render = mkRender "main" diagram;
}
