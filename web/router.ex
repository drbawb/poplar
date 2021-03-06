defmodule Popura.Router do
  use Popura.Web, :router

  pipeline :core do
    plug Popura.Auth
    plug RemoteIp
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Popura do
    pipe_through [:browser, :core] # Use the default browser stack

    get "/",        PageController, :index
    get "/landing", PageController, :landing

    resources "/decks", DeckController

    # TODO(hime): admin access, better routes
    get "/lobbies/:id/start", LobbyController, :start
    get "/lobbies/:id/stop",  LobbyController, :stop
    get "/lobbies/:id/reset", LobbyController, :reset

    resources "/lobbies", LobbyController do
      resources "/players", PlayerController
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", Popura do
  #   pipe_through :api
  # end
end
