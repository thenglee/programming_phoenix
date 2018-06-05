defmodule Rumbl.InfoSys do
  @backends [Rumbl.InfoSys.Wolfram]

  defmodule Result do
    defstruct score: 0, text: nil, url: nil, backend: nil
  end

  # start_link is our proxy
  # calls start_link of the specified backend
  def start_link(backend, query, query_ref, owner, limit) do
    backend.start_link(query, query_ref, owner, limit)
  end

  def compute(query, opts \\ []) do
    limit = opts[:limit] || 10
    backends = opts[:backends] || @backends

    # backends
    # |> Enum.map(&spawn_query(&1, query, limit))

    backends
    |> Enum.map(&spawn_query(&1, query, limit))
    |> await_results(opts)
    |> Enum.sort(&(&1.score >= &2.score))
    |> Enum.take(limit)
  end

  # spawn_query starts a child, giving it some opts,
  # including a unique ref (representing a single response)
  # this fn returns the child pid & the unique reference,
  # which we'll await later on
  defp spawn_query(backend, query, limit) do
    query_ref = make_ref()
    opts = [backend, query, query_ref, self(), limit]

    # whenever our supervisor calls Supervisor.start_child
    # for InfoSys, it invokes InfoSys.start_link
    {:ok, pid} = Supervisor.start_child(Rumbl.InfoSys.Supervisor, opts)
    # {pid, query_ref}

    monitor_ref = Process.monitor(pid)
    {pid, monitor_ref, query_ref}
  end

  defp await_results(children, opts) do
    # await_result(children, [], :infinity)

    timeout = opts[:timeout] || 5000
    timer = Process.send_after(self(), :timedout, timeout)
    results = await_result(children, [], :infinity)
    cleanup(timer)
    results
  end

  defp await_result([head|tail], acc, timeout) do
    {pid, monitor_ref, query_ref} = head

    receive do
      {:results, ^query_ref, results} ->
        # The [:flush] option guarantees that the :DOWN
        # message is removed from our inbox in case it’s
        # delivered before we drop the monitor.
        Process.demonitor(monitor_ref, [:flush])
        await_result(tail, results ++ acc, timeout)
      # match on monitor_ref because
      # :DOWN messages come from the monitor,
      # not our GenServer
      {:DOWN, ^monitor_ref, :process, ^pid, _reason} ->
        await_result(tail, acc, timeout)
      :timedout ->
        kill(pid, monitor_ref)
        await_result(tail, acc, 0)
    after
      timeout ->
        kill(pid, monitor_ref)
        await_result(tail, acc, 0)
    end
  end

  defp await_result([], acc, _) do
    acc
  end

  defp kill(pid, ref) do
    Process.demonitor(ref, [:flush])
    Process.exit(pid, :kill)
  end

  defp cleanup(timer) do
    :erlang.cancel_timer(timer)
    receive do
      :timedout -> :ok
    after
      0 -> :ok
    end
  end
end
