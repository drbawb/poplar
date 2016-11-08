// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "web/static/js/app.js".

// To use Phoenix channels, the first step is to import Socket
// and connect at the socket path in "lib/my_app/endpoint.ex":
import {Socket} from "phoenix"

let gameClient = document.querySelector("#game-client");
let channelId  = gameClient.dataset.topic;
let tokenId    = gameClient.dataset.token;

let _promptCard   = {body: "", num_slots: 0};
let _promptLocked = true;
let _playerHand   = [];
let _choices      = [];


function buildCard(style, text) {
	let cardBlock = document.createElement("div");
	cardBlock.classList.add("card", `card-${style}`);
	cardBlock.innerHTML = text;
	return cardBlock;
}

// highlights chosen cards
function renderChoices() {
	let cards = document.querySelectorAll(".card-white");
	cards.forEach((el) => {
		if (_choices.includes(el.dataset.id)) {
			el.classList.add("chosen");
		} else {
			el.classList.remove("chosen");
		}
	});
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
		cardList.append(cardNode);
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

// connect & auth socket
let socket = new Socket("/socket", {params: {token: tokenId}})
socket.connect();

// connect to lobby
let channel = socket.channel(channelId, {})
channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

// server has dealt us a new hand @ top of round
channel.on("deal", (payload) => {
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

channel.on("oobping", (payload) => {
	console.log("got ping from oob");
});

export default socket
