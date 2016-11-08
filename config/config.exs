# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :popura,
  ecto_repos: [Popura.Repo]

# Configures the endpoint
config :popura, Popura.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Y/C5vxQQrEQ6m38hDXQRHFB38kTmdV8zBzcKhu9HXS7eIp9hU+yNYeLCXOutjSdY",
  render_errors: [view: Popura.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Popura.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
