defmodule Charon.AuthChallenge.TotpChallenge do
  @moduledoc """
  TOTP-challenge.
  The otp codes may be generated by the user's device,
  or can be sent in advance by SMS/email.

  ## Config

  Additional config is required for this module under `optional.charon_totp_challenge`:

      Charon.Config.from_enum(
        ...,
        optional_modules: %{
          charon_totp_challenge: %{
            ...
          }
        }
      )

  The following configuration options are supported:
    - `:totp_label` (required). Ends up as a TOTP label in apps like Google Authenticator, for example "Gmail".
    - `:totp_issuer` (required). Similar to `:totp_label`, for example "Google".
    - `:totp_seed_field` (optional, default `:totp_seed`). The binary field of the user struct that is used to store the underlying secret of the TOTP challenges.
    - `:param` (optional, default: "otp"). The name of the param that contains an OTP code.
    - `:period` (optional, default 30). The duration in seconds in which a single OTP code is valid.
  """
  @challenge_name "totp"
  use Charon.AuthChallenge

  if Code.ensure_loaded?(NimbleTOTP) do
    alias Charon.Internal
    @optional_config_field :charon_totp_challenge
    @defaults %{
      totp_seed_field: :totp_seed,
      param: "otp",
      period: 30
    }
    @required [:totp_label, :totp_issuer]

    @impl true
    def challenge_complete(conn, params, user, config) do
      with :ok <- AuthChallenge.verify_enabled(user, @challenge_name, config) do
        %{totp_seed_field: field, param: param, period: period} = process_config(config)
        seed = Map.fetch!(user, field)
        now = Internal.now()

        with <<otp::binary>> <- Map.get(params, param, {:error, "#{param} not found"}),
             true <-
               NimbleTOTP.valid?(seed, otp, time: now, period: period) or
                 NimbleTOTP.valid?(seed, otp, time: now - period, period: period) do
          {:ok, conn, nil}
        else
          false -> {:error, "#{param} invalid"}
          error -> error
        end
      end
    end

    @impl true
    def setup_init(conn, params, user, config) do
      with :ok <- AuthChallenge.check_current_password(user, params, config) do
        %{totp_label: label, totp_issuer: issuer} = process_config(config)
        seed = :crypto.strong_rand_bytes(32)
        secret = Base.encode32(seed, padding: false, case: :upper)
        uri = NimbleTOTP.otpauth_uri(label, seed, issuer: issuer)
        token = AuthChallenge.gen_setup_token(@challenge_name, config, %{"secret" => secret})
        {:ok, conn, %{config.auth_challenge_setup_token_param => token, secret: secret, uri: uri}}
      end
    end

    @impl true
    def setup_complete(conn, params, user, config) do
      %{totp_seed_field: field} = process_config(config)

      with {:ok, payload} <- AuthChallenge.validate_setup_token(@challenge_name, params, config),
           %{"secret" => secret} = payload,
           seed = Base.decode32!(secret, padding: false, case: :upper),
           user_overrides = %{
             field => seed,
             config.enabled_auth_challenges_field => [@challenge_name]
           },
           {:ok, _, _} <-
             challenge_complete(conn, params, Map.merge(user, user_overrides), config),
           enabled = AuthChallenge.put_enabled(user, @challenge_name, config),
           params = %{field => seed, config.enabled_auth_challenges_field => enabled},
           {:ok, _} <- AuthChallenge.update_user(user, params, config) do
        {:ok, conn, nil}
      end
    end

    @doc false
    def generate_code(user, config) do
      %{totp_seed_field: field, period: period} = process_config(config)
      seed = Map.fetch!(user, field)
      now = Internal.now()
      NimbleTOTP.verification_code(seed, time: now, period: period)
    end

    ###########
    # Private #
    ###########

    defp process_config(config) do
      Internal.process_optional_config(config, @optional_config_field, @defaults, @required)
    end
  else
    @impl true
    def challenge_init(_conn, _params, _user, _config), do: throw_error()
    @impl true
    def challenge_complete(_conn, _params, _user, _config), do: throw_error()
    @impl true
    def setup_init(_conn, _params, _user, _config), do: throw_error()
    @impl true
    def setup_complete(_conn, _params, _user, _config), do: throw_error()
    def generate_code(_user, _config), do: throw_error()

    defp throw_error(), do: raise("optional dependency NimbleTOTP not found")
  end
end
