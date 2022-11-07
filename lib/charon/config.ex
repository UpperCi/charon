defmodule Charon.Config do
  @moduledoc """
  Config struct. Keys & defaults:

      [
        :token_issuer,
        access_cookie_name: "_access_token_signature",
        access_cookie_opts: [http_only: true, same_site: "Strict", secure: true],
        # 15 minutes
        access_token_ttl: 15 * 60,
        optional_modules: %{},
        refresh_cookie_name: "_refresh_token_signature",
        refresh_cookie_opts: [http_only: true, same_site: "Strict", secure: true],
        # 2 months
        refresh_token_ttl: 2 * 30 * 24 * 60 * 60,
        session_store_module: Charon.SessionStore.RedisStore,
        # 1 year
        session_ttl: 365 * 24 * 60 * 60,
        token_factory_module: Charon.TokenFactory.SymmetricJwt
      ]

  Note that all config is compile-time config.
  Runtime configuration properties should be provided in the form of getters,
  like the optional config of `Charon.TokenFactory.SymmetricJwt`.
  """
  @enforce_keys [:token_issuer]
  defstruct [
    :token_issuer,
    access_cookie_name: "_access_token_signature",
    access_cookie_opts: [http_only: true, same_site: "Strict", secure: true],
    # 15 minutes
    access_token_ttl: 15 * 60,
    optional_modules: %{},
    refresh_cookie_name: "_refresh_token_signature",
    refresh_cookie_opts: [http_only: true, same_site: "Strict", secure: true],
    # 2 months
    refresh_token_ttl: 2 * 30 * 24 * 60 * 60,
    session_store_module: Charon.SessionStore.RedisStore,
    # 1 year
    session_ttl: 365 * 24 * 60 * 60,
    token_factory_module: Charon.TokenFactory.SymmetricJwt
  ]

  @type t :: %__MODULE__{
          access_cookie_name: String.t(),
          access_cookie_opts: keyword(),
          access_token_ttl: pos_integer(),
          optional_modules: map(),
          refresh_cookie_name: String.t(),
          refresh_cookie_opts: keyword(),
          refresh_token_ttl: pos_integer(),
          session_store_module: module(),
          session_ttl: pos_integer(),
          token_factory_module: module(),
          token_issuer: String.t()
        }

  @doc """
  Build config struct from enumerable (useful for passing in application environment).
  Raises for missing mandatory keys and sets defaults for optional keys.
  Optional modules must implement an `init_config/1` function to process their own config at compile time.

  ## Examples / doctests

      iex> from_enum([])
      ** (ArgumentError) the following keys must also be given when building struct Charon.Config: [:token_issuer]

      iex> %Charon.Config{} = from_enum(token_issuer: "https://myapp")

      # optional modules may also check compile-time config
      iex> from_enum(token_issuer: "Santa", optional_modules: %{Charon.TokenFactory.SymmetricJwt => []})
      ** (ArgumentError) the following keys must also be given when building struct Charon.TokenFactory.SymmetricJwt.Config: [:get_secret]
  """
  @spec from_enum(Enum.t()) :: %__MODULE__{}
  def from_enum(enum) do
    __MODULE__ |> struct!(enum) |> process_optional_modules()
  end

  ###########
  # Private #
  ###########

  defp process_optional_modules(config = %{optional_modules: opt_mods}) do
    opt_mods
    |> Map.new(fn {module, config} -> {module, module.init_config(config)} end)
    |> then(fn initialized_opt_mods -> %{config | optional_modules: initialized_opt_mods} end)
  end
end
