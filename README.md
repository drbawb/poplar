# popura

Anarchist bot's "put the words in the cards" server ...
Does the thing, wins the points, many lulz...

# basic schema

The game consists of the following entities:

- Lobbies    :: Individual games, running some subset of available decks
- Players    :: Belongs to a lobby

- Deck :: Some collection of black cards and white cards

- Cards :: Either a prompt or response card
  - Black Card :: Has a prompt, some number of blanks e.g pick(n)
  - White card :: Can be used to fill in said blank

Lobbies have 4 decks:
  - black & white (in play)
  - black & white (discarded)

Players have one hand. The hand is initially empty, every round
the lobby server ensures each player has 10 cards before prompting
for responses.

Play proceeds as follows:

- Some player creates a lobby, they become the admin of the lobby.
- Said player passes out a link to join the lobby (/lobbies/:id:/new)
- The admin starts the game ...



## Game Loop

The core game loop consists of the following phases:

* Pick Czar
* Wait (Players)
* Wait (Czar)
* Announce Winner



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
  - Announces the winner
  - Resets for top of round


Both of the `wait` phases have timeouts associated with them.
If the czar does not choose a winner the game immediately resets
to the top of the round.
