if Code.ensure_loaded?(Redix) and Code.ensure_loaded?(:poolboy) do
  defmodule Charon.SessionStore.RedisStore.LuaFunctions do
    @moduledoc false
    require Logger

    @hashed_version Mix.Project.config()
                    |> Keyword.fetch!(:version)
                    |> :erlang.phash2(Integer.pow(2, 32))
                    |> to_string()
    @resolve_set_exps_function_name "resolve_set_exps_#{@hashed_version}"
    @upsert_function_name "opt_lock_upsert_#{@hashed_version}"
    @prune_expired_function_name "maybe_prune_expired_#{@hashed_version}"

    @doc """
    Returns the Redis command to call Redis function "charon_resolve_set_exps",
    which sets all set expiration timestamps to that of the max-exp session.

    Returns `[n1, n2, n3]` with `n` being the EXPIREAT result.
    """
    @spec resolve_set_exps_cmd(iodata, iodata, iodata) :: [integer]
    def resolve_set_exps_cmd(session_set_key, exp_oset_key, lock_set_key) do
      call_redis_function_cmd(
        @resolve_set_exps_function_name,
        [session_set_key, exp_oset_key, lock_set_key],
        []
      )
    end

    @doc """
    Returns the Redis command to call Redis function "charon_opt_lock_upsert",
    which upserts a session while optimistically locking on `lock_version`.
    On a locking failure, `"CONFLICT"` is returned and no state is changed.

    On a locking success:
     - the serialized `session` is stored under its `sid` in `session_set_key`
     - the session's `expires_at` value is stored under the session's `sid` in `exp_oset_key`
     - the session's `lock_version` is stored under the session's `sid` in `lock_set_key`
     - the expiration timestamp of all sets is increased to `expires_at`

    Returns: `[n1, n2, n3, m1, m2, m3]` with n being the number of elements added to a respective set,
    and m being the result of calling EXPIREAT (with GT modifier) on that set.
    """
    @spec opt_lock_upsert_cmd(iodata, iodata, iodata, iodata, integer, iodata, integer) ::
            [integer] | binary()
    def opt_lock_upsert_cmd(
          session_set_key,
          exp_oset_key,
          lock_set_key,
          sid,
          lock_version,
          session,
          expires_at
        ) do
      call_redis_function_cmd(
        @upsert_function_name,
        [session_set_key, exp_oset_key, lock_set_key],
        [sid, lock_version, session, expires_at]
      )
    end

    @doc """
    Returns the Redis command to call Redis function "charon_maybe_prune_expired",
    which prunes expired sessions from all session sets, once an hour max.

    Returns `"SKIPPED"` when run again within an hour,
    otherwise returns `[n1, n2, n3]` with `n` being the number of elements removed from a respective set.
    """
    @spec maybe_prune_expired_cmd(iodata, iodata, iodata, iodata, integer) :: [integer] | binary
    def maybe_prune_expired_cmd(session_set_key, exp_oset_key, lock_set_key, prune_lock_key, now) do
      call_redis_function_cmd(
        @prune_expired_function_name,
        [session_set_key, exp_oset_key, lock_set_key, prune_lock_key],
        [now]
      )
    end

    @doc """
    Returns the Redis command to call a Redis function with keys and args.
    """
    @spec call_redis_function_cmd(binary, list, list) :: any
    def call_redis_function_cmd(name, keys, args) do
      key_count = keys |> Enum.count() |> Integer.to_string()
      ["FCALL", name, key_count] ++ keys ++ args
    end

    @doc """
    Create a separate, out-of-pool redix connection and register the Redis Lua functions with it.
    """
    @spec register_functions(keyword) :: :ok
    def register_functions(redix_opts) do
      with <<priv_dir::binary>> <- :code.priv_dir(:charon) |> to_string(),
           {:ok, script} <- File.read(priv_dir <> "/redis_functions.lua"),
           script = String.replace(script, "0.0.0+development", @hashed_version),
           {:ok, temp_redix} <- Redix.start_link(redix_opts),
           load_function_command = ["FUNCTION", "LOAD", "REPLACE", script],
           {:ok, "charon_redis_store_#{@hashed_version}"} <-
             Redix.command(temp_redix, load_function_command) do
        Process.exit(temp_redix, :normal)
        Logger.info("Redis functions registered successfully.")
      else
        error -> raise "Could not register Redis functions: #{inspect(error)}"
      end
    end
  end
end
