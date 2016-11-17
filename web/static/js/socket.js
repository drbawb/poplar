// TODO(hime): use templates in render functions ?
// TODO(hime): req/rep initial state ...
// TODO(hime): common renderer prelude

// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "web/static/js/app.js".

// To use Phoenix channels, the first step is to import Socket
// and connect at the socket path in "lib/my_app/endpoint.ex":
import {Socket} from "phoenix"

let gameClient = document.querySelector("#game-client");
let playerInfo = document.querySelector("#player-info");
let channelId  = gameClient.dataset.topic;
let tokenId    = gameClient.dataset.token;

let _promptCard   = {body: "", num_slots: 0};
let _promptLocked = true;
let _choices      = [];
let _playerHand   = [];
let _submissions  = [];

function buildCard(style, text) {
	let cardBlock = document.createElement("div");
	cardBlock.classList.add("card", `card-${style}`);
	if (text.length > 75) { cardBlock.classList.add("card-wordy"); }

	cardBlock.innerHTML = text;
	return cardBlock;
}

// highlights chosen cards
function renderChoices() {
	let cards = document.querySelectorAll(".card-white");

	// HACK(hime): well shit, NodeList in Mozarella doesn't
	// support #forEach()
	
	for (let i = 0; i < cards.length; i++) {
		let el = cards[i];
	 	if (_choices.includes(el.dataset.id)) {
	 		el.classList.add("chosen");
	 	} else {
	 		el.classList.remove("chosen");
	 	}
	}
}

// redraws the czar's screen
function renderCzarClient() {
	gameClient.innerHTML = "";
	let handDiv = document.createElement("div");
	handDiv.classList.add("player-hand");
	
	let question = buildCard("black", _promptCard.body);
	let dialog   = document.createElement("span");
	dialog.innerHTML = "You are the czar, just wait a bit ...";

	handDiv.appendChild(question);
	handDiv.appendChild(dialog);
	gameClient.appendChild(handDiv);
}

// redraws the client pane based on currently known game state
function renderGameClient() {
	gameClient.innerHTML = "";

	let handDiv = document.createElement("div");
	handDiv.classList.add("player-hand");

	let question = buildCard("black", _promptCard.body);
	
	let cardList = document.createElement("div");
	_playerHand.forEach((el) => {
		let cardNode = buildCard("white", el.body);
		cardNode.dataset.id = el.id;
		cardList.appendChild(cardNode);
		cardNode.addEventListener("click", function() {
			console.log("clicked card: " + this.dataset.id);
			if (_choices.length >= _promptCard.slots) {
			   console.warn("can't pick that many cards");
			   return;
			}

			if (_promptLocked) {
				console.warn("prompt has not been sent yet");
				return;
			}

			_choices.push(this.dataset.id);
			renderChoices();
		});
	});

	let submitButton = document.createElement("button");
	let clearButton  = document.createElement("button");
	submitButton.innerHTML = "submit"; clearButton.innerHTML = "clear";

	clearButton.addEventListener("click", function(evt) {
		console.log("clearing choices");
		_choices = [];
		renderChoices();
	});

	submitButton.addEventListener("click", function(evt) {
		// submit choices to the server
		channel.push("pick", {choices: _choices})
		// console.log
		_choices = []; renderChoices();
	});

	handDiv.appendChild(question);
	handDiv.appendChild(submitButton);
	handDiv.appendChild(clearButton);
	handDiv.appendChild(cardList);
	gameClient.appendChild(handDiv);
}

function renderPlayerInfo(score) {
	let playerList = document.createElement("ul");
	for (name in score) {
		let player = score[name];
		let node = document.createElement("li");
		node.innerHTML = `${name} (czar? ${player.is_czar}), (won? ${player.rounds_won})`;
		playerList.appendChild(node);
	}

	playerInfo.innerHTML = "";
	playerInfo.appendChild(playerList);
}

// renders player submissions, potentially piles of more than
// one card, so they are enclosed in a containing group
function renderSubmissions() {
	gameClient.innerHTML = "";

	let handDiv = document.createElement("div");
	handDiv.classList.add("player-hand");

	let question = buildCard("black", _promptCard.body);

	// render a header explaining wtf to do
	let header = document.createElement("h2");
	if (_promptLocked) {
		header.innerHTML = `The czar is choosing, please wait...`;
	} else {
		header.innerHTML = `You are the czar, click a card below to choose winner`;
	}
	
	
	let cardList = document.createElement("div");
	_submissions.forEach((el) => {
		let pairNode = document.createElement("div");
		pairNode.classList.add("card-pair");

		el.forEach((card) => {
			let cardNode = buildCard("white", card.body);
			cardNode.dataset.id = card.id;
			pairNode.appendChild(cardNode);
			cardNode.addEventListener("click", function() {
				if (_promptLocked) {
					console.warn("you're not the boss of me!");
					return;
				}

				var pair = pairNode.children;
				for (let i = 0; i < pair.length; i++) {
					let el = pair[i];
					_choices.push(el.dataset.id); 
					el.classList.add("chosen");
				}

				channel.push("declare", {choices: _choices});
			});
		});

		cardList.appendChild(pairNode);
	});

	handDiv.appendChild(question);
	handDiv.appendChild(cardList);
	gameClient.appendChild(header);
	gameClient.appendChild(handDiv);
}

function renderWinner(msg) {
	gameClient.innerHTML = "";

	// build win announcement
	let header = document.createElement("h2");
	header.innerHTML = `${msg.winner} won the round!`;

	// build hand
	let handDiv = document.createElement("div");
	handDiv.classList.add("player-hand");
	
	let question = buildCard("black", _promptCard.body);
	handDiv.appendChild(question);

	msg.choices.forEach((el) => {
		let answer = buildCard("white", el.body);
		handDiv.appendChild(answer);
	});

	gameClient.appendChild(header);
	gameClient.appendChild(handDiv);
}

function renderDraw(msg) {
	gameClient.innerHTML = "";

	// build win announcement
	let header = document.createElement("h2");
	header.innerHTML = `No winner selected.`;

	let dialog = document.createElement("p");
	dialog.innerHTML = msg;

	gameClient.appendChild(header);
	gameClient.appendChild(dialog);
}

// connect & auth socket
let socket = new Socket("/socket", {params: {token: tokenId}})
socket.connect();

// connect to lobby
let channel = socket.channel(channelId, {})
channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

// server has announced a winner
channel.on("announce", (payload) => {
	if (payload.error) { renderDraw(payload.error); } else { renderWinner(payload) };
});

// server has said we are the czar!
channel.on("czar", (payload) => {
	console.warn("YOU ARE CZAR");
	_promptCard   = payload.prompt;
	_playerHand   = [];
	_promptLocked = true;
	renderCzarClient();
});

// server has dealt us a new hand @ top of round
channel.on("deal", (payload) => {
	_choices = [];
	_promptCard = payload.prompt;
	_playerHand = payload.cards;
	_promptLocked = false;
	renderGameClient();
});

// server has confirmed our submission
channel.on("confirm", (payload) => {
	_playerHand = payload.cards;
	_promptLocked = true;
	renderGameClient();
});

channel.on("reveal", (payload) => {
	_promptLocked = !payload.is_czar;  // unless czar
	_choices      = [];
	_submissions  = payload.cards;    // [[a,b], [a,b], etc...]
	renderSubmissions();
});

channel.on("tick", (payload) => {
	document.querySelector("#game-timer").innerHTML = `${payload.mode} => ${payload.tick_no}`;
});

channel.on("oobping", (payload) => {
	console.log("got ping from oob");
});

channel.on("score", (payload) => {
	renderPlayerInfo(payload);
});

export default socket
