local Overlay = {}
local EMPTY_COLOR = {r = 0.65, g = 0.7, b = 0.75, a = 0.9}

local function rounded(value)
  return string.format("%.0f", value)
end

function Overlay.clear(state)
  if not state then return end
  for _, object in ipairs(state.objects) do
    if object.valid then object.destroy() end
  end
end

function Overlay.draw(player, selected, network, options)
  local state = {objects = {}}
  local colors, fluids = {}, {}

  local function draw(kind, parameters)
    parameters.surface = selected.surface
    parameters.players = {player.index}
    parameters.only_in_alt_mode = true
    -- Survives save/load via storage. TTL also bounds stray objects if an
    -- entity/surface disappears between the hover event and the next refresh.
    parameters.time_to_live = 35
    local object = rendering[kind](parameters)
    state.objects[#state.objects + 1] = object
  end

  for _, segment in ipairs(network.segments) do
    local fluid = segment.entity.get_fluid_segment_fluid(segment.index)
    fluids[segment.id] = fluid
    local prototype = fluid and prototypes.fluid[fluid.name]
    local color = prototype and prototype.visualization_color or EMPTY_COLOR
    -- Keep very dark fluids visible without changing the fluid's hue.
    local peak = math.max(color.r, color.g, color.b)
    local gain = peak > 0 and math.max(1, 0.65 / peak) or 1
    colors[segment.id] = {
      r = math.min(1, color.r * gain), g = math.min(1, color.g * gain),
      b = math.min(1, color.b * gain), a = 0.9,
    }
  end

  local function line(from, to, color, underground)
    local dx, dy = from.x - to.x, from.y - to.y
    if dx * dx + dy * dy < 0.0001 then return end
    draw("draw_line", {
      from = from, to = to, color = {r = 0.04, g = 0.04, b = 0.04, a = 0.8},
      width = 8, gap_length = underground and 0.22 or 0,
      dash_length = underground and 0.35 or 0,
    })
    draw("draw_line", {
      from = from, to = to, color = color, width = 4,
      gap_length = underground and 0.22 or 0, dash_length = underground and 0.35 or 0,
    })
  end

  for _, edge in ipairs(network.edges) do
    local color = colors[edge.source.segment_id]
    line(edge.source.position, edge.from, color, false)
    line(edge.from, edge.to, color, edge.underground)
    line(edge.to, edge.target.position, color, false)
  end

  local icon_cells = {}
  for _, node in ipairs(network.nodes) do
    draw("draw_circle", {
      target = node.position, color = colors[node.segment_id], radius = 0.16, filled = true,
    })
    local fluid = fluids[node.segment_id]
    -- A sparse grid keeps long pipelines readable without a sprite on every tile.
    local cell = node.segment_id .. ":" .. math.floor(node.position.x / 4)
      .. ":" .. math.floor(node.position.y / 4)
    if options.icons and fluid and not icon_cells[cell] then
      icon_cells[cell] = true
      draw("draw_sprite", {
        sprite = "fluid/" .. fluid.name, target = node.position,
        x_scale = 0.35, y_scale = 0.35,
      })
    end
  end

  local row = 0
  if options.contents then
    for _, segment in ipairs(network.segments) do
      local fluid = fluids[segment.id]
      local capacity = segment.entity.get_fluid_segment_capacity(segment.index)
      local label
      if fluid then
        label = {"pipeline-hover.contents", "[fluid=" .. fluid.name .. "]",
          prototypes.fluid[fluid.name].localised_name, rounded(fluid.amount), rounded(capacity),
          rounded(fluid.temperature)}
      else
        label = {"pipeline-hover.empty", rounded(capacity)}
      end
      draw("draw_text", {
        text = label, target = {entity = selected, offset = {0, -1.6 - row * 0.65}},
        color = {r = 1, g = 1, b = 1}, alignment = "center", scale = 0.85,
        use_rich_text = true,
      })
      row = row + 1
    end
  end
  if network.truncated then
    draw("draw_text", {
      text = {"pipeline-hover.truncated", options.limit},
      target = {entity = selected, offset = {0, -1.6 - row * 0.65}},
      color = {r = 1, g = 0.75, b = 0.25}, alignment = "center", scale = 0.8,
    })
  end

  return state
end

return Overlay
