defmodule Popura.Fortune do
  @fortunes [
    "has anyone ever been so far as decided to?",
    "calling me small, you're so mean!",
    "How did this get here? I'm not good with computers.",
    "it puts the words in the cards, or it gets the hose again.",
  ]

  def random(), do: Enum.shuffle(@fortunes) |> List.first
end
