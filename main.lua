local Session = require("session")
local session = Session.new()
local cardImages = {}

local CARD_SCALE = 0.35
local CARD_WIDTH = 200 * CARD_SCALE
local CARD_HEIGHT = 280 * CARD_SCALE
local CARD_OVERLAP_OFFSET = 34
local CARD_ASSET_PATH = "assets/cards/"

---@param amount number
---@return string
local function formatWon(amount)
	local formatted = tostring(amount)

	while true do
		local changes
		formatted, changes = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")

		if changes == 0 then
			break
		end
	end

	return formatted .. " won"
end

---@param width number
---@param height number
local function drawStart(width, height)
	love.graphics.printf("Press Enter to Start", 0, height / 2 + 48, width, "center")
end

local function drawBetting(width, height)
	love.graphics.printf("Bet: " .. formatWon(session.bet), 0, height / 2 + 48, width, "center")
	love.graphics.printf("Left/Down: -100  Right/Up: +100", 0, height / 2 + 80, width, "center")
	love.graphics.printf("Press Enter to Bet", 0, height / 2 + 112, width, "center")
end

local function getCardImageKey(card)
	return card.suit .. card.rank
end

local function getHandWidth(hand)
	if #hand == 0 then
		return 0
	end

	return CARD_WIDTH + (#hand - 1) * CARD_OVERLAP_OFFSET
end

local function getVisibleDealerValue(hand)
	if #hand == 0 then
		return 0
	end

	return Session.getHandValue({ hand[1] })
end

local function drawCardBack(x, y)
	love.graphics.setColor(0.78, 0.78, 0.7)
	love.graphics.rectangle("fill", x, y, CARD_WIDTH, CARD_HEIGHT, 6, 6)
	love.graphics.setColor(0.08, 0.14, 0.28)
	love.graphics.rectangle("fill", x + 6, y + 6, CARD_WIDTH - 12, CARD_HEIGHT - 12, 4, 4)
	love.graphics.setColor(0.9, 0.9, 0.82)
	love.graphics.rectangle("line", x + 12, y + 12, CARD_WIDTH - 24, CARD_HEIGHT - 24, 3, 3)
	love.graphics.setColor(1, 1, 1)
end

local function drawCard(card, x, y)
	local image = cardImages[getCardImageKey(card)]

	if image then
		love.graphics.setColor(1, 1, 1)
		love.graphics.draw(image, x, y, 0, CARD_SCALE, CARD_SCALE)
		return
	end

	love.graphics.setColor(0.95, 0.95, 0.88)
	love.graphics.rectangle("fill", x, y, CARD_WIDTH, CARD_HEIGHT, 6, 6)
	love.graphics.setColor(0.1, 0.1, 0.1)
	love.graphics.rectangle("line", x, y, CARD_WIDTH, CARD_HEIGHT, 6, 6)
	love.graphics.printf(card.label, x, y + CARD_HEIGHT / 2 - 8, CARD_WIDTH, "center")
	love.graphics.setColor(1, 1, 1)
end

local function drawHand(hand, x, y, hideSecondCard)
	for index, card in ipairs(hand) do
		local cardX = x + (index - 1) * CARD_OVERLAP_OFFSET

		if hideSecondCard and index == 2 then
			drawCardBack(cardX, y)
		else
			drawCard(card, cardX, y)
		end
	end
end

local function drawHandCentered(hand, y, width, hideSecondCard)
	drawHand(hand, (width - getHandWidth(hand)) / 2, y, hideSecondCard)
end

local function drawPlayerTurn(width, height)
	love.graphics.printf(
		"Dealer Score: " .. getVisibleDealerValue(session.dealer.hand),
		0,
		108,
		width,
		"center"
	)
	drawHandCentered(session.dealer.hand, 132, width, true)
	love.graphics.printf(
		"Player Score: " .. Session.getHandValue(session.player.hand),
		0,
		300,
		width,
		"center"
	)
	drawHandCentered(session.player.hand, 324, width, false)

	if Session.canCashOutCharlie(session) then
		love.graphics.printf("H: Hit  C: Cash Out", 0, height - 64, width, "center")
	elseif Session.canEvenMoney(session) then
		love.graphics.printf("E: Even Money  S: Stand", 0, height - 64, width, "center")
	elseif Session.canFold(session) and Session.canDoubleDown(session) then
		love.graphics.printf("H: Hit  S: Stand  F: Fold  D: Double", 0, height - 76, width, "center")
		love.graphics.printf("Double adds: " .. formatWon(session.bet), 0, height - 52, width, "center")
	elseif Session.canFold(session) then
		love.graphics.printf("H: Hit  S: Stand  F: Fold", 0, height - 64, width, "center")
	elseif Session.canDoubleDown(session) then
		love.graphics.printf("H: Hit  S: Stand  D: Double", 0, height - 76, width, "center")
		love.graphics.printf("Double adds: " .. formatWon(session.bet), 0, height - 52, width, "center")
	else
		love.graphics.printf("H: Hit  S: Stand", 0, height - 64, width, "center")
	end
end

local function drawResult(width, height)
	local message = "Push"

	if session.result == "win" then
		message = "You Win"
	elseif session.result == "lose" then
		message = "You Lose"
	end

	love.graphics.printf(message, 0, 96, width, "center")
	love.graphics.printf(session.resultReason or "", 0, 120, width, "center")
	love.graphics.printf(
		"Dealer Score: " .. Session.getHandValue(session.dealer.hand),
		0,
		152,
		width,
		"center"
	)
	drawHandCentered(session.dealer.hand, 176, width, false)
	love.graphics.printf(
		"Player Score: " .. Session.getHandValue(session.player.hand),
		0,
		336,
		width,
		"center"
	)
	drawHandCentered(session.player.hand, 360, width, false)
	love.graphics.printf("Press Enter to Continue", 0, height - 32, width, "center")
end

local function drawBankrupt(width, height, message)
	love.graphics.printf(message, 0, height / 2 + 48, width, "center")
	love.graphics.printf(session.resultReason or "", 0, height / 2 + 80, width, "center")
	love.graphics.printf("Press Enter to Start New Session", 0, height / 2 + 112, width, "center")
end

local drawByState = {
	[Session.State.START] = drawStart,
	[Session.State.BETTING] = drawBetting,
	[Session.State.PLAYER_TURN] = drawPlayerTurn,
	[Session.State.RESULT] = drawResult,
	[Session.State.PLAYER_BANKRUPT] = function(width, height)
		drawBankrupt(width, height, "Player Bankrupt")
	end,
	[Session.State.HOUSE_BANKRUPT] = function(width, height)
		drawBankrupt(width, height, "House Bankrupt")
	end,
}

local function isEnter(key)
	return key == "return" or key == "kpenter"
end

local function keyPressedStart(key)
	if isEnter(key) then
		Session.startBetting(session)
	end
end

local function keyPressedBetting(key)
	if key == "left" or key == "down" then
		Session.decreaseBet(session)
	elseif key == "right" or key == "up" then
		Session.increaseBet(session)
	elseif isEnter(key) then
		Session.deal(session)
	end
end

local function keyPressedPlayerTurn(key)
	if Session.canCashOutCharlie(session) then
		if key == "h" then
			Session.hit(session)
		elseif key == "c" then
			Session.cashOutCharlie(session)
		end
	elseif key == "h" then
		Session.hit(session)
	elseif key == "s" then
		Session.stand(session)
	elseif key == "f" then
		Session.fold(session)
	elseif key == "d" then
		Session.doubleDown(session)
	elseif key == "e" then
		Session.takeEvenMoney(session)
	end
end

local function keyPressedResult(key)
	if isEnter(key) then
		Session.startBetting(session)
	end
end

local function keyPressedBankrupt(key)
	if isEnter(key) then
		Session.reset(session)
	end
end

local keyPressedByState = {
	[Session.State.START] = keyPressedStart,
	[Session.State.BETTING] = keyPressedBetting,
	[Session.State.PLAYER_TURN] = keyPressedPlayerTurn,
	[Session.State.RESULT] = keyPressedResult,
	[Session.State.PLAYER_BANKRUPT] = keyPressedBankrupt,
	[Session.State.HOUSE_BANKRUPT] = keyPressedBankrupt,
}

function love.load()
	love.graphics.setBackgroundColor(0.08, 0.1, 0.08)

	for _, suit in ipairs({ "D", "C", "H", "S" }) do
		for _, rank in ipairs({ "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }) do
			local key = suit .. rank
			local path = CARD_ASSET_PATH .. key .. ".png"

			if love.filesystem.getInfo(path) then
				cardImages[key] = love.graphics.newImage(path)
			end
		end
	end
end

function love.update(dt)
	--
end

function love.draw()
	local width = love.graphics.getWidth()
	local height = love.graphics.getHeight()

	love.graphics.setColor(1, 1, 1)
	love.graphics.printf("Jack Black Black Jack", 0, 24, width, "center")
	love.graphics.printf("Player: " .. formatWon(session.player.money), 0, 52, width, "center")
	love.graphics.printf("Dealer: " .. formatWon(session.dealer.money), 0, 76, width, "center")

	local drawState = drawByState[session.state]

	if drawState then
		drawState(width, height)
	end
end

function love.keypressed(key)
	local keyPressedState = keyPressedByState[session.state]

	if keyPressedState then
		keyPressedState(key)
	end
end
