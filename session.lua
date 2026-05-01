local Session = {}

Session.PLAYER_STARTING_MONEY = 1000
Session.DEALER_STARTING_MONEY = 100000000
Session.DEFAULT_BET = 100
Session.BET_STEP = 100

local function getMinimumBet(session)
	if session.playerMoney < Session.BET_STEP then
		return session.playerMoney
	end

	return Session.BET_STEP
end

local function getMaximumBet(session)
	if session.playerMoney < Session.BET_STEP then
		return session.playerMoney
	end

	return session.playerMoney - session.playerMoney % Session.BET_STEP
end

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
	session.bet = getMinimumBet(session)
end

function Session.increaseBet(session)
	local maximumBet = getMaximumBet(session)

	if session.bet < maximumBet then
		session.bet = math.min(session.bet + Session.BET_STEP, maximumBet)
	end
end

function Session.decreaseBet(session)
	local minimumBet = getMinimumBet(session)

	if session.bet > minimumBet then
		session.bet = math.max(session.bet - Session.BET_STEP, minimumBet)
	end
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
