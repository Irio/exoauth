# RFC 6749

defmodule OAuth2.Service do
  use Behaviour

  defmacro __using__(_opts) do
    quote do
      @behaviour OAuth2.Service
      import OAuth2.Service

      def grant_access(opts) do
        try do
          grant_type    = Keyword.fetch!(opts, :grant_type)
          client_id     = Keyword.fetch!(opts, :client_id)
          client_secret = Keyword.fetch!(opts, :client_secret)

          if authenticate_client?(client_id, client_secret) do
            grant_access(grant_type, opts)
          else
            :invalid_client
          end
        rescue
          [ KeyError ] -> :invalid_request
        end
      end

      def grant_access(:password, opts) do
        username = Keyword.fetch!(opts, :username)
        password = Keyword.fetch!(opts, :password)

        if authenticate_user?(username, password) do
          client = opts[:client_id]
          scope  = opts[:scope]
          key    = generate_token(client, username, scope)
          assign_access_token(to: client, for: username, with: scope)
        else
          :invalid_credentials
        end
      end

      def grant_access(:client_credentials, opts) do
        client = opts[:client_id]
        scope  = opts[:scope]
        key    = generate_token(client, nil, scope)

        assign_access_token(to: client, with: scope)
      end

      def grant_access(:refresh_token, opts) do
        refresh_token = Keyword.fetch!(opts, :refresh_token)
        client        = opts[:client_id]
        new_scope     = opts[:scope]

        assign_access_token(to: client, via: refresh_token, with: new_scope)
      end

      def grant_access(_type, _opts), do: :unsupported_grant_type

      def generate_token(_client, _user, _scope) do
        OAuth2.Utils.UUID.v4
      end

      def error_description(error), do: atom_to_binary(error)

      defoverridable [ generate_token: 3, error_description: 1 ]
    end
  end

  @type response_error :: :inavlid_request     | :invalid_client         | :invalid_grant
                        | :unauthorized_client | :unsupported_grant_type | :invalid_scope

  @doc "authenticates a client id/secret pair"
  defcallback authenticate_client?(id :: binary, secret :: binary | nil) :: true | false

  @doc "authenticates a username/password pair"
  defcallback authenticate_user?(username :: binary, password :: binary) :: true | false

  @doc """
  There are currently 3 ways to assign an access token, one for each of the supported grant types

  1. Password: Assign to a client for a user [ with a specified scope ]

    iex> assign_access_token(to: client, for: user, with: scope)

  2. Client Credentials: Assign to a client [ with a specificed scope ]

    iex> assign_acces_token(to: client, with: scope)

  3. Refresh Token: Assign to a client via a refresh token [ with a specified scope ]

    iex> assign_access_token(to: client, via: refresh_token, with: new_scope)

  """
  defcallback assign_access_token(opts :: Keyword.t) :: OAuth2.AccessToken.t | response_error
  defcallback error_description(error :: response_error) :: binary
end
