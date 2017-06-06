defmodule Graph.Reducer do
  @moduledoc false
  alias Graph.Edge

  def walk(%Graph{edges: es, ids: ids} = g, acc, fun, opts) when is_function(fun, 4) do
    case Keyword.get(opts, :algorithm, :depth_first) do
      :depth_first ->
        visit_dfs(Map.keys(ids), g, MapSet.new, fun, acc)
      :breadth_first ->
        case Map.keys(ids) do
          [] -> acc
          [starting_id|rest] ->
            starting_out = Map.get(es, starting_id, MapSet.new)
            q = :queue.in(starting_id, :queue.new)
            q = Enum.reduce(starting_out, q, fn v_id, q -> :queue.in(v_id, q) end)
            visit_bfs(q, rest, g, MapSet.new, fun, acc)
        end
    end
  end

  defp visit_dfs([v_id|rest], %Graph{ids: ids, edges: es} = g, visited, fun, acc) do
    if MapSet.member?(visited, v_id) do
      visit_dfs(rest, g, visited, fun, acc)
    else
      v = Map.get(ids, v_id)
      out_neighbors = get_out_edges(g, v, v_id)
      in_neighbors = get_in_edges(g, v, v_id)
      case fun.(v, out_neighbors, in_neighbors, acc) do
        {:next, acc2} ->
          visited = MapSet.put(visited, v_id)
          out = es |> Map.get(v_id, MapSet.new) |> MapSet.to_list
          visit_dfs(out ++ rest, g, visited, fun, acc2)
        {:next, v_next, acc2} ->
          v_next_id = Map.get(ids, v_next)
          visited = visited |> MapSet.put(v_id) |> MapSet.delete(v_next_id)
          visit_dfs([v_next_id | rest], g, visited, fun, acc2)
        {:skip, acc2} ->
          # Skip this vertex and it's out-neighbors
          visited = MapSet.put(visited, v_id)
          visit_dfs(rest, g, visited, fun, acc2)
        {:halt, acc2} ->
          acc2
      end
    end
  end
  defp visit_dfs([], _g, _visited, _fun, acc) do
    acc
  end

  def visit_bfs(q, vs, %Graph{ids: ids, edges: es} = g, visited, fun, acc) do
    case {:queue.out(q), vs} do
      {{{:value, v_id}, q1}, _vs} ->
        if MapSet.member?(visited, v_id) do
          visit_bfs(q1, vs, g, visited, fun, acc)
        else
          v = Map.get(ids, v_id)
          v_out = Map.get(es, v_id, MapSet.new)
          out_neighbors = get_out_edges(g, v, v_id)
          in_neighbors = get_in_edges(g, v, v_id)
          case fun.(v, out_neighbors, in_neighbors, acc) do
            {:next, acc2} ->
              visited = MapSet.put(visited, v_id)
              q2 = v_out |> MapSet.to_list |> List.foldl(q1, fn vid, q -> :queue.in(vid, q) end)
              visit_bfs(q2, vs, g, visited, fun, acc2)
            {:next, v_next, acc2} ->
              v_next_id = Map.get(ids, v_next)
              visited = visited |> MapSet.put(v_id) |> MapSet.delete(v_next_id)
              q2 = :queue.in_r(v_next_id, q1)
              visit_bfs(q2, vs, g, visited, fun, acc2)
            {:skip, acc2} ->
              visited = MapSet.put(visited, v_id)
              visit_bfs(q1, vs, g, visited, fun, acc2)
            {:halt, acc2} ->
              acc2
          end
        end
      {{:empty, _}, []} ->
        acc
      {{:empty, q1}, [v_id|vs]} ->
        q2 = :queue.in(v_id, q1)
        visit_bfs(q2, vs, g, visited, fun, acc)
    end
  end

  defp get_out_edges(%Graph{edges: es, edges_meta: es_meta, ids: ids}, v, v_id) do
    es
    |> Map.get(v_id, [])
    |> Enum.map(fn v2_id ->
      v2 = Map.get(ids, v2_id)
      meta = Map.get(es_meta, {v_id, v2_id}, [])
      Edge.new(v, v2, meta)
    end)
  end

  def get_in_edges(%Graph{edges: es, edges_meta: es_meta, ids: ids}, v, v_id) do
    es
    |> Stream.filter(fn {_, v_out} -> MapSet.member?(v_out, v_id) end)
    |> Enum.map(fn {v2_id, _} ->
      v2 = Map.get(ids, v2_id)
      meta = Map.get(es_meta, {v2_id, v_id}, [])
      Edge.new(v2, v, meta)
    end)
  end
end
