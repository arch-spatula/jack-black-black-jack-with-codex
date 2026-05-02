local Session = require("session")
local session = Session.new()

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

local function formatHand(hand)
	local labels = {}

	for _, card in ipairs(hand) do
		table.insert(labels, card.label)
	end

	return table.concat(labels, " ")
end

local function formatVisibleDealerHand(hand)
	if #hand == 0 then
		return ""
	end

	return hand[1].label .. " ??"
end

local function getVisibleDealerValue(hand)
	if #hand == 0 then
		return 0
	end

	return Session.getHandValue({ hand[1] })
end

local function drawPlayerTurn(width, height)
	love.graphics.printf(
		"Dealer: " .. formatVisibleDealerHand(session.dealer.hand),
		0,
		height / 2 + 40,
		width,
		"center"
	)
	love.graphics.printf(
		"Dealer Score: " .. getVisibleDealerValue(session.dealer.hand),
		0,
		height / 2 + 64,
		width,
		"center"
	)
	love.graphics.printf("Player: " .. formatHand(session.player.hand), 0, height / 2 + 96, width, "center")
	love.graphics.printf(
		"Player Score: " .. Session.getHandValue(session.player.hand),
		0,
		height / 2 + 120,
		width,
		"center"
	)

	if Session.canCashOutCharlie(session) then
		love.graphics.printf("H: Hit  C: Cash Out", 0, height / 2 + 152, width, "center")
	elseif Session.canEvenMoney(session) then
		love.graphics.printf("E: Even Money  S: Stand", 0, height / 2 + 152, width, "center")
	elseif Session.canFold(session) and Session.canDoubleDown(session) then
		love.graphics.printf("H: Hit  S: Stand  F: Fold  D: Double", 0, height / 2 + 152, width, "center")
		love.graphics.printf("Double adds: " .. formatWon(session.bet), 0, height / 2 + 176, width, "center")
	elseif Session.canFold(session) then
		love.graphics.printf("H: Hit  S: Stand  F: Fold", 0, height / 2 + 152, width, "center")
	elseif Session.canDoubleDown(session) then
		love.graphics.printf("H: Hit  S: Stand  D: Double", 0, height / 2 + 152, width, "center")
		love.graphics.printf("Double adds: " .. formatWon(session.bet), 0, height / 2 + 176, width, "center")
	else
		love.graphics.printf("H: Hit  S: Stand", 0, height / 2 + 152, width, "center")
	end
end

local function drawResult(width, height)
	local message = "Push"

	if session.result == "win" then
		message = "You Win"
	elseif session.result == "lose" then
		message = "You Lose"
	end

	love.graphics.printf(message, 0, height / 2 + 32, width, "center")
	love.graphics.printf(session.resultReason or "", 0, height / 2 + 56, width, "center")
	love.graphics.printf(
		"Dealer: " .. formatHand(session.dealer.hand) .. " (" .. Session.getHandValue(session.dealer.hand) .. ")",
		0,
		height / 2 + 88,
		width,
		"center"
	)
	love.graphics.printf(
		"Player: " .. formatHand(session.player.hand) .. " (" .. Session.getHandValue(session.player.hand) .. ")",
		0,
		height / 2 + 112,
		width,
		"center"
	)
	love.graphics.printf("Press Enter to Continue", 0, height / 2 + 144, width, "center")
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
end

function love.update(dt)
	--
end

function love.draw()
	local width = love.graphics.getWidth()
	local height = love.graphics.getHeight()

	love.graphics.setColor(1, 1, 1)
	love.graphics.printf("Jack Black Black Jack", 0, height / 2 - 48, width, "center")
	love.graphics.printf("Player: " .. formatWon(session.player.money), 0, height / 2 - 16, width, "center")
	love.graphics.printf("Dealer: " .. formatWon(session.dealer.money), 0, height / 2 + 8, width, "center")

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
