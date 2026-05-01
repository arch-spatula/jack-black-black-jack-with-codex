local sessionState = "start"
local sessionResult = nil

local function playSession()
	if love.math.random() < 0.5 then
		sessionResult = "win"
	else
		sessionResult = "lose"
	end

	sessionState = "result"
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

	if sessionState == "start" then
		love.graphics.printf("Press Enter to Start", 0, height / 2, width, "center")
	elseif sessionState == "result" then
		local message = "You Lose"

		if sessionResult == "win" then
			message = "You Win"
		end

		love.graphics.printf(message, 0, height / 2, width, "center")
		love.graphics.printf("Press Enter to Return", 0, height / 2 + 32, width, "center")
	end
end

function love.keypressed(key)
	if key ~= "return" and key ~= "kpenter" then
		return
	end

	if sessionState == "start" then
		playSession()
	elseif sessionState == "result" then
		sessionState = "start"
		sessionResult = nil
	end
end
