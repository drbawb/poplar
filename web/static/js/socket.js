// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "web/static/js/app.js".

// To use Phoenix channels, the first step is to import Socket
// and connect at the socket path in "lib/my_app/endpoint.ex":
import {Socket} from "phoenix"

let gameClient = document.querySelector("#game-client");
let channelId  = gameClient.dataset.topic;
let tokenId    = gameClient.dataset.token;

let _promptCard = "";
let _playerHand = [];

function buildCard(style, text) {
	let cardBlock = document.createElement("div");
	cardBlock.classList.add("card", `card-${style}`);
	cardBlock.innerHTML = text;
	return cardBlock;
}

// redraws the client pane based on currently known game state
function renderGameClient() {
	gameClient.innerHTML = "";

	let handDiv = document.createElement("div");
	handDiv.classList.add("player-hand");

	let question = buildCard("black", _promptCard);
	
	let cardList = document.createElement("div");
	_playerHand.forEach((el) => {
		cardList.append(buildCard("white", el));
	});

	handDiv.appendChild(question);
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

// server has pubilshed our most recent hand
channel.on("hand", (payload) => {
	_promptCard = payload.prompt;
	_playerHand = payload.cards;
	renderGameClient();
});

channel.on("oobping", (payload) => {
	console.log("got ping from oob");
});

export default socket
