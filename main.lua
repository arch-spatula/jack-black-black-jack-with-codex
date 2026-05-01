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

	if session.state == "start" then
		love.graphics.printf("Press Enter to Start", 0, height / 2 + 48, width, "center")
	elseif session.state == "result" then
		local message = "You Lose"

		if session.result == "win" then
			message = "You Win"
		end

		love.graphics.printf(message, 0, height / 2 + 48, width, "center")
		love.graphics.printf("Press Enter to Return", 0, height / 2 + 80, width, "center")
	end
end

function love.keypressed(key)
	if key ~= "return" and key ~= "kpenter" then
		return
	end

	if session.state == "start" then
		Session.play(session)
	elseif session.state == "result" then
		Session.reset(session)
	end
end
