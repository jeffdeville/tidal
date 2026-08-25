defmodule Tidal.RequestState do
  @moduledoc """
  Signs and verifies self-contained state for multi-round-trip requests.

  Request state is integrity-protected, expires, and is bound to the current
  authorization context and original request fingerprint. The payload is JSON
  rather than an Erlang term so a verified client token is never deserialized
  into executable VM data.

  Configure the same `:request_state_secret` on every node that may receive a
  retry. Signing requires a secret of at least 32 bytes.
  """

  alias Plug.Crypto.MessageVerifier
  alias Tidal.RequestContext

  @default_expiry_ms :timer.minutes(5)

  @doc """
  Signs JSON-compatible continuation data for a later retry.

  Pass `:expires_in_ms` to replace the five-minute default. Return the token in
  a `Tidal.Protocol.InputRequiredResult`; on retry, pass the current context and
  `context.request_state` to `verify/2`.

      {:ok, token} =
        Tidal.RequestState.sign(context, %{"step" => "confirm"},
          expires_in_ms: 120_000
        )

  Returns `{:error, :request_state_secret_not_configured}` when the server has
  no suitable secret.
  """
  @spec sign(RequestContext.t(), term(), keyword()) ::
          {:ok, String.t()} | {:error, :request_state_secret_not_configured}
  def sign(%RequestContext{} = context, data, opts \\ []) do
    with {:ok, secret} <- fetch_secret(context) do
      envelope = %{
        "auth" => authorization_digest(context.auth_context),
        "data" => data,
        "request" => context.request_fingerprint,
        "expiresAt" => System.system_time(:millisecond) + Keyword.get(opts, :expires_in_ms, @default_expiry_ms)
      }

      {:ok, envelope |> Jason.encode!() |> MessageVerifier.sign(secret)}
    end
  end

  @doc """
  Verifies a continuation and returns the embedded application data.

  Verification checks the signature, expiry, current authorization context,
  and current request fingerprint. A token is therefore not transferable to a
  different principal or a materially different retry.

      with {:ok, %{"step" => "confirm"}} <-
             Tidal.RequestState.verify(context, context.request_state) do
        continue_with(context.input_responses)
      end

  The error atom identifies the failed check and is safe to handle without
  inspecting the token payload.
  """
  @spec verify(RequestContext.t(), term()) ::
          {:ok, term()}
          | {:error,
             :request_state_secret_not_configured
             | :invalid_request_state
             | :authorization_mismatch
             | :request_mismatch
             | :expired_request_state}
  def verify(%RequestContext{} = context, token) do
    with {:ok, secret} <- fetch_secret(context),
         {:ok, payload} <- verify_signature(token, secret),
         {:ok, envelope} <- decode_envelope(payload),
         :ok <- verify_authorization(envelope, context.auth_context),
         :ok <- verify_request(envelope, context.request_fingerprint),
         :ok <- verify_expiry(envelope) do
      {:ok, envelope["data"]}
    end
  end

  defp fetch_secret(%RequestContext{server: %{request_state_secret: secret}})
       when is_binary(secret) and byte_size(secret) >= 32,
       do: {:ok, secret}

  defp fetch_secret(_context), do: {:error, :request_state_secret_not_configured}

  defp verify_signature(token, secret) when is_binary(token) do
    case MessageVerifier.verify(token, secret) do
      {:ok, payload} -> {:ok, payload}
      :error -> {:error, :invalid_request_state}
    end
  end

  defp verify_signature(_token, _secret), do: {:error, :invalid_request_state}

  defp decode_envelope(payload) do
    case Jason.decode(payload) do
      {:ok,
       %{
         "auth" => auth,
         "data" => _data,
         "expiresAt" => expires_at,
         "request" => request
       } = envelope}
      when is_binary(auth) and is_integer(expires_at) ->
        if is_nil(request) or is_binary(request) do
          {:ok, envelope}
        else
          {:error, :invalid_request_state}
        end

      _ ->
        {:error, :invalid_request_state}
    end
  end

  defp verify_authorization(%{"auth" => expected}, auth_context) do
    actual = authorization_digest(auth_context)

    if byte_size(expected) == byte_size(actual) and Plug.Crypto.secure_compare(expected, actual) do
      :ok
    else
      {:error, :authorization_mismatch}
    end
  end

  defp verify_expiry(%{"expiresAt" => expires_at}) do
    if expires_at >= System.system_time(:millisecond) do
      :ok
    else
      {:error, :expired_request_state}
    end
  end

  defp verify_request(%{"request" => expected}, expected), do: :ok
  defp verify_request(_envelope, _actual), do: {:error, :request_mismatch}

  defp authorization_digest(auth_context) do
    auth_context
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.url_encode64(padding: false)
  end
end
