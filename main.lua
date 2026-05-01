local Session = require("session")
local session = Session.new()

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
	love.graphics.printf("Dealer: " .. formatVisibleDealerHand(session.dealerHand), 0, height / 2 + 40, width, "center")
	love.graphics.printf("Dealer Score: " .. getVisibleDealerValue(session.dealerHand), 0, height / 2 + 64, width, "center")
	love.graphics.printf("Player: " .. formatHand(session.playerHand), 0, height / 2 + 96, width, "center")
	love.graphics.printf("Player Score: " .. Session.getHandValue(session.playerHand), 0, height / 2 + 120, width, "center")

	if Session.canSurrender(session) then
		love.graphics.printf("H: Hit  S: Stand  D: Die", 0, height / 2 + 152, width, "center")
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
	love.graphics.printf("Dealer: " .. formatHand(session.dealerHand) .. " (" .. Session.getHandValue(session.dealerHand) .. ")", 0, height / 2 + 88, width, "center")
	love.graphics.printf("Player: " .. formatHand(session.playerHand) .. " (" .. Session.getHandValue(session.playerHand) .. ")", 0, height / 2 + 112, width, "center")
	love.graphics.printf("Press Enter to Continue", 0, height / 2 + 144, width, "center")
end

local function drawBankrupt(width, height, message)
	love.graphics.printf(message, 0, height / 2 + 48, width, "center")
	love.graphics.printf(session.resultReason or "", 0, height / 2 + 80, width, "center")
	love.graphics.printf("Press Enter to Start New Session", 0, height / 2 + 112, width, "center")
end

local drawByState = {
	start = drawStart,
	betting = drawBetting,
	playerTurn = drawPlayerTurn,
	result = drawResult,
	playerBankrupt = function(width, height)
		drawBankrupt(width, height, "Player Bankrupt")
	end,
	houseBankrupt = function(width, height)
		drawBankrupt(width, height, "House Bankrupt")
	end,
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
	love.graphics.printf("Player: " .. formatWon(session.playerMoney), 0, height / 2 - 16, width, "center")
	love.graphics.printf("Dealer: " .. formatWon(session.dealerMoney), 0, height / 2 + 8, width, "center")

	local drawState = drawByState[session.state]

	if drawState then
		drawState(width, height)
	end
end

function love.keypressed(key)
	if session.state == "start" then
		if key ~= "return" and key ~= "kpenter" then
			return
		end

		Session.startBetting(session)
	elseif session.state == "betting" then
		if key == "left" or key == "down" then
			Session.decreaseBet(session)
		elseif key == "right" or key == "up" then
			Session.increaseBet(session)
		elseif key == "return" or key == "kpenter" then
			Session.deal(session)
		end
	elseif session.state == "playerTurn" then
		if key == "h" then
			Session.hit(session)
		elseif key == "s" then
			Session.stand(session)
		elseif key == "d" then
			Session.surrender(session)
		end
	elseif session.state == "result" then
		if key ~= "return" and key ~= "kpenter" then
			return
		end

		Session.startBetting(session)
	elseif session.state == "playerBankrupt" or session.state == "houseBankrupt" then
		if key ~= "return" and key ~= "kpenter" then
			return
		end

		Session.reset(session)
	end
end
