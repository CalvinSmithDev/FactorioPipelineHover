local Network = {}

-- Ghosts have no live pipeline; fluid wagons/turret buffers have no segment.
function Network.is_candidate(entity)
  return entity and entity.valid and entity.type ~= "entity-ghost"
    and entity.fluids_count > 0
end

local function anchor(entity, connections)
  if entity.type == "pipe" or entity.type == "pipe-to-ground" then
    return entity.position
  end

  -- Each machine fluid storage gets its own anchor. Never draw a line through
  -- a machine connecting its independent input/output fluids.
  local x, y = 0, 0
  for _, connection in ipairs(connections) do
    x = x + connection.position.x
    y = y + connection.position.y
  end
  if #connections == 0 then return entity.position end
  return {x = x / #connections, y = y / #connections}
end

function Network.collect(selected, limit)
  local result = {nodes = {}, edges = {}, segments = {}, truncated = false}
  if not Network.is_candidate(selected) then return result end

  local seen, segments = {}, {}
  local surface_index = selected.surface.index

  local function enqueue(entity, index, expected_segment)
    if not entity or not entity.valid or entity.surface.index ~= surface_index
      or index < 1 or index > entity.fluids_count
      or not entity.has_fluid_segment(index) then return end

    local segment_id = entity.get_fluid_segment_id(index)
    if expected_segment and segment_id ~= expected_segment then return end

    local key = entity.unit_number or entity
    local entity_nodes = seen[key]
    if entity_nodes and entity_nodes[index] then return end
    if #result.nodes >= limit then
      result.truncated = true
      return
    end

    if not segments[segment_id] then
      local segment = {id = segment_id, entity = entity, index = index}
      segments[segment_id] = segment
      result.segments[#result.segments + 1] = segment
    end

    local connections = entity.get_fluid_box_pipe_connections(index) or {}
    local node = {
      id = #result.nodes + 1,
      entity = entity,
      index = index,
      segment_id = segment_id,
      connections = connections,
      position = anchor(entity, connections),
    }
    entity_nodes = entity_nodes or {}
    seen[key] = entity_nodes
    entity_nodes[index] = node
    result.nodes[node.id] = node
  end

  for index = 1, selected.fluids_count do
    if selected.has_fluid_segment(index) then
      enqueue(selected, index)
    else
      -- In 2.1 pumps and crafting machines can expose standalone buffers
      -- rather than segment members. Seed each attached pipeline independently.
      for _, connection in ipairs(selected.get_fluid_box_pipe_connections(index) or {}) do
        if connection.target and connection.target_fluidbox_index then
          enqueue(connection.target, connection.target_fluidbox_index)
        end
      end
    end
  end

  -- Breadth first, bounded by fluid storages, not entities. This keeps pumps
  -- and multi-fluid machines from merging unrelated pipelines.
  local cursor = 1
  while cursor <= #result.nodes do
    local node = result.nodes[cursor]
    for _, connection in ipairs(node.connections) do
      if connection.target and connection.target_fluidbox_index then
        enqueue(connection.target, connection.target_fluidbox_index, node.segment_id)
      end
    end
    cursor = cursor + 1
  end

  for _, node in ipairs(result.nodes) do
    for _, connection in ipairs(node.connections) do
      local target_entity = connection.target
      local target_nodes = target_entity and seen[target_entity.unit_number or target_entity]
      local target = target_nodes and target_nodes[connection.target_fluidbox_index]
      if target and target.segment_id == node.segment_id and node.id < target.id then
        local target_connection = target.connections[connection.target_pipe_connection_index]
        result.edges[#result.edges + 1] = {
          source = node,
          target = target,
          from = connection.position,
          to = target_connection and target_connection.position or target.position,
          underground = connection.connection_type ~= "normal",
        }
      elseif target_entity and target_entity.valid
        and target_entity.surface.index == surface_index
        and connection.target_fluidbox_index
        and not target_entity.has_fluid_segment(connection.target_fluidbox_index) then
        -- Draw up to this machine/pump port, but never walk through its buffer
        -- to another port (which could be a different pipeline or fluid).
        local connections = target_entity.get_fluid_box_pipe_connections(connection.target_fluidbox_index) or {}
        local port = connections[connection.target_pipe_connection_index]
        local position = port and port.position or connection.target_position
        result.edges[#result.edges + 1] = {
          source = node, target = {position = position},
          from = connection.position, to = position,
          underground = connection.connection_type ~= "normal",
        }
      end
    end
  end

  return result
end

return Network
