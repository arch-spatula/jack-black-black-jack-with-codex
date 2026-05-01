local Session = {}

Session.PLAYER_STARTING_MONEY = 1000
Session.DEALER_STARTING_MONEY = 100000000

function Session.new()
	return {
		state = "start",
		result = nil,
		playerMoney = Session.PLAYER_STARTING_MONEY,
		dealerMoney = Session.DEALER_STARTING_MONEY,
	}
end

function Session.play(session)
	if love.math.random() < 0.5 then
		session.result = "win"
	else
		session.result = "lose"
	end

	session.state = "result"
end

function Session.reset(session)
	session.state = "start"
	session.result = nil
	session.playerMoney = Session.PLAYER_STARTING_MONEY
	session.dealerMoney = Session.DEALER_STARTING_MONEY
end

return Session
