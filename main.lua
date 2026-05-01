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

local function drawResult(width, height)
	local message = "You Lose"

	if session.result == "win" then
		message = "You Win"
	end

	love.graphics.printf(message, 0, height / 2 + 48, width, "center")
	love.graphics.printf("Press Enter to Continue", 0, height / 2 + 80, width, "center")
end

local function drawBankrupt(width, height, message)
	love.graphics.printf(message, 0, height / 2 + 48, width, "center")
	love.graphics.printf("Press Enter to Start New Session", 0, height / 2 + 80, width, "center")
end

local drawByState = {
	start = drawStart,
	betting = drawBetting,
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
			Session.resolveBet(session)
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
