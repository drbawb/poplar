# poplar

>it puts the words on the cards, or it gets the hose again

Yet another digital clone of the "Cards Against Humanity" game.

The game server does not come with any decks loaded by default, however 
it's fairly simple to populate the database using any number of decks you 
can find online in machine readable formats.

The basic format of a card is:

    body  :: string,  where each blank is a single underscore
    slots :: integer, number of cards required to respond to the prompt

Prompts ("black cards") are any card which has one or more slots, all 
other cards are considered Responses (or "white cards.")

The `Popura.Util` module contains several helpers for loading cards from
various third party formats and services. (txt, csv, cardcast API, etc.)

## Installation

This is a Phoenix web application. Install Elixir & Phoenix, then
you can perform the following to start a local copy of the web server:

0. `mix deps.get`     download & install dependencies
1. `mix ecto.create`  create the database specified by `config/<env>.exs`
2. `mix ecto.migrate` update database schema to latest version
3. `iex -S mix phoenix.server` start the development server on port 4000

To begin playing, you will need the following:

1. Create a `%Popura.Deck{}` entity and store it in the database
2. Import your cards into `%Popura.Card{}` entities, relate them to the deck
   created earlier, and store them in the database
3. Visit `/lobbies/new` to create a new lobby
4. Direct people to `/lobbies/:id/players/new` to join the lobby
5. On `/lobbies/:id` the host has controls to start/stop the game.

## Game Loop

The core game loop consists of the following phases:

- Pick Czar
  - Selects the next czar (in order, "clockwise")
  - Announces the next black card
  - Deals white cards to individual players (up to 10)
  - Enters `Wait (Players)` phase

- Wait Players
  - Waits for players to submit white cards
  - Stores submissions (in order)
  - Moves to `Wait (Czar)` phase

- Wait Czar
  - Waits for czar to select from the winning submissions
  - Stores winnining submission
  - Moves to `Announce Winner` phase (if applicable)

- Announce Winner
  - Announces the winner (or draw)
  - Resets for top of round

If the `wait` phases timeout then the announce winner phase displays
a message about a stalemate. The game is then reset to the top of the round.

## Plans / Known Issues / etc.

- Select multiple decks when building a lobby
- Security is pretty lax.
- Loads of queries are duplicated, O(N+1) association fetches, etc.
  Need to log queries in detail & figure out where waste can be eliminated.
- Timeouts should be configurable per lobby (up to "infinity")
- Game does not "reshuffle" discards when it runs out of cards
- The randomness is probably less than ideal, at some point I'd like
  to store precomputed random values in the `cards_piles` table which are
  set when the lobby loads the deck(s). This way the "shuffle" is consistent
  between rounds.
- Users can submit less cards than the prompt requires. (Including 0 cards!)
  This is probably never what the user intends to do.
- Better documentation (Sample privacy/tos, FAQ, etc.)

