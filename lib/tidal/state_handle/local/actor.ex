defmodule Tidal.StateHandle.Local.Actor do
  @moduledoc false

  use GenServer, restart: :temporary
  use Arena.Process

  @impl Arena.Process
  def to_process_key(%{handle: handle}), do: {__MODULE__, handle}

  @impl GenServer
  def init(opts) do
    state = %{
      handle: Map.fetch!(opts, :handle),
      value: Map.fetch!(opts, :value),
      auth_context: Map.get(opts, :auth_context),
      idle_timeout: Map.fetch!(opts, :idle_timeout),
      expiry_token: nil
    }

    {:ok, refresh_expiry(state)}
  end

  @impl GenServer
  def handle_call({:fetch, auth_context}, _from, state) do
    with :ok <- authorize(state, auth_context) do
      {:reply, {:ok, state.value}, refresh_expiry(state)}
    else
      {:error, :unauthorized} = error -> {:reply, error, state}
    end
  end

  def handle_call({:transact, auth_context, function}, _from, state) do
    with :ok <- authorize(state, auth_context),
         {:ok, new_value, result} <- run_transaction(function, state.value) do
      {:reply, {:ok, result}, refresh_expiry(%{state | value: new_value})}
    else
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  def handle_call({:destroy, auth_context}, _from, state) do
    with :ok <- authorize(state, auth_context) do
      {:stop, :normal, :ok, state}
    else
      {:error, :unauthorized} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_info({:expire, token}, %{expiry_token: token} = state), do: {:stop, :normal, state}
  def handle_info({:expire, _stale_token}, state), do: {:noreply, state}

  defp authorize(%{auth_context: expected}, actual) when expected == actual, do: :ok
  defp authorize(_state, _actual), do: {:error, :unauthorized}

  defp run_transaction(function, value) do
    case function.(value) do
      {:ok, new_value, result} -> {:ok, new_value, result}
      {:error, _reason} = error -> error
      other -> {:error, {:invalid_transaction_result, other}}
    end
  rescue
    exception -> {:error, {:transaction_failed, exception}}
  catch
    kind, reason -> {:error, {:transaction_failed, kind, reason}}
  end

  defp refresh_expiry(%{idle_timeout: :infinity} = state), do: state

  defp refresh_expiry(%{idle_timeout: timeout} = state) do
    token = make_ref()
    Process.send_after(self(), {:expire, token}, timeout)
    %{state | expiry_token: token}
  end
end
