local Deck = require("deck")
local Dealer = require("dealer")
local Player = require("player")

local Session = {}

Session.PLAYER_STARTING_MONEY = 1000
Session.DEALER_STARTING_MONEY = 100000000
Session.DEFAULT_BET = 100
Session.BET_STEP = 100

local function getMinimumBet(session)
	if session.player.money < Session.BET_STEP then
		return session.player.money
	end

	return Session.BET_STEP
end

local function getMaximumBet(session)
	if session.player.money < Session.BET_STEP then
		return session.player.money
	end

	return session.player.money - session.player.money % Session.BET_STEP
end

function Session.new()
	return {
		state = "start",
		result = nil,
		resultReason = nil,
		bet = Session.DEFAULT_BET,
		deck = nil,
		player = Player.new(Session.PLAYER_STARTING_MONEY),
		dealer = Dealer.new(Session.DEALER_STARTING_MONEY),
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

local function settle(session, result, reason)
	session.result = result
	session.resultReason = reason

	if result == "win" then
		Player.addMoney(session.player, session.bet)
		Dealer.addMoney(session.dealer, -session.bet)
	elseif result == "lose" then
		Player.addMoney(session.player, -session.bet)
		Dealer.addMoney(session.dealer, session.bet)
	end

	if session.player.money <= 0 then
		session.state = "playerBankrupt"
	elseif session.dealer.money <= 0 then
		session.state = "houseBankrupt"
	else
		session.state = "result"
	end
end

local function settleLossAmount(session, lossAmount, reason)
	session.result = "lose"
	session.resultReason = reason
	Player.addMoney(session.player, -lossAmount)
	Dealer.addMoney(session.dealer, lossAmount)

	if session.player.money <= 0 then
		session.state = "playerBankrupt"
	else
		session.state = "result"
	end
end

local function settleWinAmount(session, winAmount, reason)
	session.result = "win"
	session.resultReason = reason
	Player.addMoney(session.player, winAmount)
	Dealer.addMoney(session.dealer, -winAmount)

	if session.dealer.money <= 0 then
		session.state = "houseBankrupt"
	else
		session.state = "result"
	end
end

local function roundToNearestHundredBankers(amount)
	local quotient = math.floor(amount / Session.BET_STEP)
	local remainder = amount % Session.BET_STEP

	if remainder < Session.BET_STEP / 2 then
		return quotient * Session.BET_STEP
	elseif remainder > Session.BET_STEP / 2 then
		return (quotient + 1) * Session.BET_STEP
	elseif quotient % 2 == 0 then
		return quotient * Session.BET_STEP
	end

	return (quotient + 1) * Session.BET_STEP
end

local function getSurrenderRefund(session)
	if session.bet <= Session.BET_STEP then
		return 0
	end

	return roundToNearestHundredBankers(session.bet / 2)
end

local function isBlackjack(hand)
	return #hand == 2 and Session.getHandValue(hand) == 21
end

local function getBlackjackPayout(session)
	return roundToNearestHundredBankers(session.bet * 1.5)
end

function Session.startBetting(session)
	session.state = "betting"
	session.result = nil
	session.resultReason = nil
	session.bet = getMinimumBet(session)
	session.deck = Deck.createShuffled()
	Player.resetHand(session.player)
	Dealer.resetHand(session.dealer)
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
	Player.draw(session.player, Deck.draw(session.deck))
	Player.draw(session.player, Deck.draw(session.deck))
	Dealer.draw(session.dealer, Deck.draw(session.deck))
	Dealer.draw(session.dealer, Deck.draw(session.deck))
	session.state = "playerTurn"
end

function Session.hit(session)
	Player.draw(session.player, Deck.draw(session.deck))

	if Session.getHandValue(session.player.hand) > 21 then
		settle(session, "lose", "Player busted")
	end
end

function Session.canSurrender(session)
	return session.state == "playerTurn" and #session.player.hand == 2
end

function Session.surrender(session)
	if not Session.canSurrender(session) then
		return
	end

	local refund = getSurrenderRefund(session)
	local lossAmount = session.bet - refund

	settleLossAmount(
		session,
		lossAmount,
		"Player surrendered. Refund: " .. refund .. " won"
	)
end

local function playDealerTurn(session)
	while Session.getHandValue(session.dealer.hand) <= 16 do
		Dealer.draw(session.dealer, Deck.draw(session.deck))
	end
end

function Session.stand(session)
	local playerValue = Session.getHandValue(session.player.hand)
	local playerHasBlackjack = isBlackjack(session.player.hand)
	local dealerHasBlackjack = isBlackjack(session.dealer.hand)

	if playerValue > 21 then
		settle(session, "lose", "Player busted")
		return
	elseif playerHasBlackjack and dealerHasBlackjack then
		settle(session, "push", "Both player and dealer have blackjack")
		return
	elseif playerHasBlackjack then
		local payout = getBlackjackPayout(session)

		settleWinAmount(
			session,
			payout,
			"Player blackjack. Payout: " .. payout .. " won"
		)
		return
	elseif dealerHasBlackjack then
		settle(session, "lose", "Dealer blackjack")
		return
	end

	playDealerTurn(session)

	local dealerValue = Session.getHandValue(session.dealer.hand)

	if dealerValue > 21 then
		settle(session, "win", "Dealer busted")
	elseif playerValue > dealerValue then
		settle(session, "win", "Player score is higher")
	elseif playerValue < dealerValue then
		settle(session, "lose", "Dealer score is higher")
	else
		settle(session, "push", "Player and dealer tied")
	end
end

function Session.reset(session)
	session.state = "start"
	session.result = nil
	session.resultReason = nil
	session.bet = Session.DEFAULT_BET
	session.deck = nil
	session.player = Player.new(Session.PLAYER_STARTING_MONEY)
	session.dealer = Dealer.new(Session.DEALER_STARTING_MONEY)
end

return Session
