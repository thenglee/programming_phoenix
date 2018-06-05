defmodule Rumbl.Counter do
  use GenServer

  def inc(pid), do: GenServer.cast(pid, :inc)

  def dec(pid), do: GenServer.cast(pid, :dec)

  def val(pid) do
    GenServer.call(pid, :val)
  end

  def start_link(initial_val) do
    GenServer.start_link(__MODULE__, initial_val)
  end

  def init(initial_val) do
    # send_after(dest, msg, time, opts \\ [])
    # send msg to dest after time (ms)
    Process.send_after(self(), :tick, 1000)
    {:ok, initial_val}
  end

  def handle_info(:tick, val) when val <= 0, do: raise "boom!"
  def handle_info(:tick, val) do
    IO.puts "tick #{val}"
    Process.send_after(self(), :tick, 1000)
    {:noreply, val - 1}
  end

  def handle_cast(:inc, val) do
    {:noreply, val + 1}
  end

  def handle_cast(:dec, val) do
    {:noreply, val - 1}
  end

  def handle_call(:val, _from, val) do
    {:reply, val, val}
  end


  # original: before using OTP
    # # client api interface
    # # exists only to send messages to the process
    # # that does the work

    # # pid of the server process
    # # sends async message to counter process
    # def inc(pid), do: send(pid, :inc)

    # # sends async message to counter process
    # def dec(pid), do: send(pid, :dec)

    # # sends message to count and then blocks
    # # the caller process while waiting for
    # # a response
    # def val(pid, timeout \\ 5000) do

    #   # make_ref() -> Reference - a unique value in the runtime system
    #   # because we need to associate this response
    #   # with a particular (unique) request
    #   ref = make_ref()

    #   # self() returns the PID of the calling process
    #   # sender pid
    #   # send(dest, message)
    #   send(pid, {:val, self(), ref})
    #   receive do
    #     {^ref, val} -> val
    #   after timeout -> exit(:timeout)
    #   end
    # end

    # # spawn a process (pid) and return {:ok, pid}
    # def start_link(initial_val) do
    #   # spawn_link(fn) -> Spawns the given function,
    #   # links it to the current process, and returns its PID.
    #   {:ok, spawn_link(fn -> listen(initial_val) end)}
    # end

    # # server (implementation)
    # # the server is a process that recursively loops,
    # # processing a message and sending
    # # updated state to itself

    # # use pattern matching and recursion
    # # to manage state

    # # The last thing any receive clause does
    # # is call listen again with the updated state.

    # # tail recursive function
    # # the last thing you do in the function
    # # is to call the function itself
    # # aka it optimizes to a loop instead
    # # of a function call
    # defp listen(val) do
    #   # blocks to wait for a message
    #   receive do
    #     :inc -> listen(val + 1)
    #     :dec -> listen(val - 1)
    #     {:val, sender, ref} ->
    #       send sender, {ref, val}
    #       listen(val)
    #   end
    # end
end
