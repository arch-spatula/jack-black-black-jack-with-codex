local Session = {}

Session.PLAYER_STARTING_MONEY = 1000
Session.DEALER_STARTING_MONEY = 100000000
Session.DEFAULT_BET = 100

function Session.new()
	return {
		state = "start",
		result = nil,
		bet = Session.DEFAULT_BET,
		playerMoney = Session.PLAYER_STARTING_MONEY,
		dealerMoney = Session.DEALER_STARTING_MONEY,
	}
end

function Session.startBetting(session)
	session.state = "betting"
	session.result = nil
	session.bet = Session.DEFAULT_BET
end

function Session.resolveBet(session)
	if love.math.random() < 0.5 then
		session.result = "win"
		session.playerMoney = session.playerMoney + session.bet
		session.dealerMoney = session.dealerMoney - session.bet
	else
		session.result = "lose"
		session.playerMoney = session.playerMoney - session.bet
		session.dealerMoney = session.dealerMoney + session.bet
	end

	if session.playerMoney <= 0 then
		session.state = "playerBankrupt"
	elseif session.dealerMoney <= 0 then
		session.state = "houseBankrupt"
	else
		session.state = "result"
	end
end

function Session.reset(session)
	session.state = "start"
	session.result = nil
	session.bet = Session.DEFAULT_BET
	session.playerMoney = Session.PLAYER_STARTING_MONEY
	session.dealerMoney = Session.DEALER_STARTING_MONEY
end

return Session
