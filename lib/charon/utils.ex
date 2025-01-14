defmodule Charon.Utils do
  @moduledoc """
  Utility functions, mainly getters and setters for module internals.
  """
  use Charon.Internal.Constants
  alias Plug.Conn
  alias Charon.Models.{Session, Tokens}
  import Charon.Internal

  @doc """
  Get current session, if present.
  """
  @spec get_session(Conn.t()) :: Session.t() | nil
  def get_session(conn), do: get_private(conn, @session)

  @doc """
  Get tokens, if present.
  """
  @spec get_tokens(Conn.t()) :: Tokens.t() | nil
  def get_tokens(conn), do: get_private(conn, @tokens)

  @doc """
  Get auth errors, if present.
  """
  @spec get_auth_error(Conn.t()) :: binary() | nil
  def get_auth_error(conn), do: get_private(conn, @auth_error)

  @doc """
  Get the payload of the bearer token, if present.
  """
  @spec get_bearer_token_payload(Conn.t()) :: map() | nil
  def get_bearer_token_payload(conn), do: get_private(conn, @bearer_token_payload)

  @doc """
  Get token signature transport mechanism, if present.
  """
  @spec get_token_signature_transport(Conn.t()) :: atom() | nil
  def get_token_signature_transport(conn), do: get_private(conn, @token_signature_transport)

  @doc """
  Set token signature transport mechanism. Must be one of
  `"bearer"`, `"cookie"`, `:bearer` or `:cookie`.

  ## Examples / doctests

      iex> :bearer = %Conn{} |> set_token_signature_transport("bearer") |> get_token_signature_transport()
      iex> :bearer = %Conn{} |> set_token_signature_transport(:bearer) |> get_token_signature_transport()
      iex> :cookie = %Conn{} |> set_token_signature_transport("cookie") |> get_token_signature_transport()
      iex> :cookie = %Conn{} |> set_token_signature_transport(:cookie) |> get_token_signature_transport()

      iex> set_token_signature_transport(%Conn{}, "anything else")
      ** (FunctionClauseError) no function clause matching in Charon.Internal.parse_sig_transport/1
  """
  @spec set_token_signature_transport(Conn.t(), binary() | :bearer | :cookie) :: Conn.t()
  def set_token_signature_transport(conn, token_signature_transport) do
    transport = parse_sig_transport(token_signature_transport)
    put_private(conn, @token_signature_transport, transport)
  end

  @doc """
  Set user id for session creation
  """
  @spec set_user_id(Conn.t(), any) :: Conn.t()
  def set_user_id(conn, user_id), do: put_private(conn, @user_id, user_id)

  @doc "Put an auth error on the conn"
  @spec set_auth_error(Plug.Conn.t(), any) :: Plug.Conn.t()
  def set_auth_error(conn, error), do: put_private(conn, @auth_error, error)

  @doc "Put a token payload on the conn"
  @spec set_token_payload(Plug.Conn.t(), any) :: Plug.Conn.t()
  def set_token_payload(conn, payload), do: put_private(conn, @bearer_token_payload, payload)

  @doc "Put a token on the conn"
  @spec set_token(Plug.Conn.t(), any) :: Plug.Conn.t()
  def set_token(conn, token), do: put_private(conn, @bearer_token, token)

  @doc "Put a session on the conn"
  @spec set_session(Plug.Conn.t(), any) :: Plug.Conn.t()
  def set_session(conn, session), do: put_private(conn, @session, session)
end
