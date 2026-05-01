local Deck = require("deck")

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
		deck = nil,
		playerHand = {},
		dealerHand = {},
		playerMoney = Session.PLAYER_STARTING_MONEY,
		dealerMoney = Session.DEALER_STARTING_MONEY,
	}
end

local function getCardValue(card)
	if card.rank == "A" then
		return 11
	elseif card.rank == "J" or card.rank == "Q" or card.rank == "K" then
		return 10
	end

	return tonumber(card.rank)
end

function Session.getHandValue(hand)
	local value = 0
	local aces = 0

	for _, card in ipairs(hand) do
		value = value + getCardValue(card)

		if card.rank == "A" then
			aces = aces + 1
		end
	end

	while value > 21 and aces > 0 do
		value = value - 10
		aces = aces - 1
	end

	return value
end

local function settle(session, result)
	session.result = result

	if result == "win" then
		session.playerMoney = session.playerMoney + session.bet
		session.dealerMoney = session.dealerMoney - session.bet
	elseif result == "lose" then
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

function Session.startBetting(session)
	session.state = "betting"
	session.result = nil
	session.bet = getMinimumBet(session)
	session.deck = Deck.createShuffled()
	session.playerHand = {}
	session.dealerHand = {}
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

function Session.deal(session)
	session.playerHand = {
		Deck.draw(session.deck),
		Deck.draw(session.deck),
	}
	session.dealerHand = {
		Deck.draw(session.deck),
		Deck.draw(session.deck),
	}
	session.state = "playerTurn"
end

function Session.hit(session)
	table.insert(session.playerHand, Deck.draw(session.deck))

	if Session.getHandValue(session.playerHand) > 21 then
		settle(session, "lose")
	end
end

function Session.stand(session)
	local playerValue = Session.getHandValue(session.playerHand)
	local dealerValue = Session.getHandValue(session.dealerHand)

	if playerValue > 21 then
		settle(session, "lose")
	elseif playerValue > dealerValue or dealerValue > 21 then
		settle(session, "win")
	elseif playerValue < dealerValue then
		settle(session, "lose")
	else
		settle(session, "push")
	end
end

function Session.reset(session)
	session.state = "start"
	session.result = nil
	session.bet = Session.DEFAULT_BET
	session.deck = nil
	session.playerHand = {}
	session.dealerHand = {}
	session.playerMoney = Session.PLAYER_STARTING_MONEY
	session.dealerMoney = Session.DEALER_STARTING_MONEY
end

return Session
