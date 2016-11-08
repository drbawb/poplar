# popura

Anarchist bot's "put the words in the cards" server ...
Does the thing, wins the points, many lulz...


# Basic Design

The game consists of the following entities:

- Lobbies    :: Individual games, running some subset of available decks
- Players    :: Belongs to a lobby

- Deck :: Some collection of black cards and white cards
  - Black Card :: Has a prompt, some number of blanks e.g pick(n)
  - White card :: Can be used to fill in said blank



Play proceeds as follows:

- A player creates a lobby, they become the admin of the lobby.
- The lobby begins in a `joinable` state, during this time:
  - Players can freely join/leave
  - Admins can modify lobby parameters (decks, hand size, etc.)

- The admin starts the game (when it has >2 players)
- LOBBY :: JOINABLE -> RUNNING


Core game loop:

Following "piles":
- each players hands
- prompt
- staging (responses)
- discard (black)
- discard (white)


- Pick next czar
- Pick next black card (n = black card required answers)
- Prompt players (except czar!) to choose `n` white cards
- Begin round timer (30s)
  - security note: prevent replay attack !!!
  - send hmac'd nonce (?)
  - players must incl. this in response

During round timer players pick one or more cards as necessary,
then submit this to the server.

The server removes these cards from the player's hands (they
will be transferred to a "staging" pile.)

Once the timer runs out, and/or all players have submitted
cards to the staging area, the czar is prompted to choose a winner.

Game moves black/white cards to appropriate discard pile.
Game replenishes player hands to card max.
Nonce is invalidated, move to top of round ...

IF AT ANY POINT A PILE IS EXHAUSTED: THE GAME RESHUFFLES
THE APPROPRIATE DISCARD PILE AND REPLACES THE MAIN DECK.

IF THE GAME STILL CANNOT CONTINUE THEN A WINNER IS DECLARED
IMMEDIATELY ...
-  
