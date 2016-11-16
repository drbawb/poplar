defmodule Popura.DeckView do
  use Popura.Web, :view

  def card_class(body) do
    card_length = String.split(body, " ") |> Enum.count
    if String.length(body) > 75, do: "card-wordy"
  end
end
