local Chip = require("chip")
local Deck = require("deck")
local Dealer = require("dealer")
local Player = require("player")

local Session = {}

Session.PLAYER_STARTING_MONEY = 1000
Session.DEALER_STARTING_MONEY = 100000000
Session.DEFAULT_BET = 100
Session.BET_STEP = 100
Session.CHARLIE_PAYOUT_BY_COUNT = {
	[5] = 1,
	[6] = 2,
	[7] = 3,
}
Session.State = {
	START = "start",
	BETTING = "betting",
	PLAYER_TURN = "playerTurn",
	RESULT = "result",
	PLAYER_BANKRUPT = "playerBankrupt",
	HOUSE_BANKRUPT = "houseBankrupt",
}

local function createStartingPlayerChips()
	local chips = Chip.createEmpty()

	chips[100] = 10
	return chips
end

local function syncPlayerMoney(session)
	session.player.money = Chip.total(session.playerChips)
end

local function syncDealerChips(session)
	session.dealerChips = Chip.fromAmountHigh(session.dealer.money)
end

local function syncBetAmount(session)
	session.bet = Chip.total(session.betChips)
end

local function moveSelectedChip(source, target, session)
	if not Chip.moveChip(source, target, session.selectedChipValue) then
		return false
	end

	syncBetAmount(session)
	syncPlayerMoney(session)
	return true
end

local function addBetAmount(session, amount)
	local remainingPlayerMoney = session.player.money - amount

	if remainingPlayerMoney < 0 then
		return false
	end

	Chip.replaceWithAmountHigh(session.playerChips, remainingPlayerMoney)
	Chip.addAmountHigh(session.betChips, amount)
	syncPlayerMoney(session)
	syncBetAmount(session)
	return true
end

function Session.new()
	local player = Player.new(Session.PLAYER_STARTING_MONEY)
	local dealer = Dealer.new(Session.DEALER_STARTING_MONEY)

	return {
		state = Session.State.START,
		result = nil,
		resultReason = nil,
		payoutItems = {},
		payoutTotal = 0,
		pendingBankruptState = nil,
		bet = Session.DEFAULT_BET,
		playerChips = createStartingPlayerChips(),
		dealerChips = Chip.fromAmountHigh(Session.DEALER_STARTING_MONEY),
		betChips = Chip.createEmpty(),
		selectedChipValue = 100,
		chipSwapMode = "down",
		deck = nil,
		hasOneEyedJackEvent = false,
		player = player,
		dealer = dealer,
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

local function getOneEyedJackBonus(session)
	if session.hasOneEyedJackEvent then
		return roundToNearestHundredBankers(session.bet)
	end

	return 0
end

local function addPayoutItem(breakdown, label, amount)
	table.insert(breakdown.items, {
		label = label,
		amount = amount,
	})

	breakdown.total = breakdown.total + amount
end

local function createPayoutBreakdown(result, reason)
	return {
		result = result,
		reason = reason,
		items = {},
		total = 0,
	}
end

local function addOneEyedJackBonus(session, breakdown)
	if breakdown.result ~= "win" then
		return
	end

	local bonus = getOneEyedJackBonus(session)

	if bonus > 0 then
		addPayoutItem(breakdown, "One-eyed jack bonus", bonus)
	end
end

local function createWinBreakdown(session, label, amount, reason)
	local breakdown = createPayoutBreakdown("win", reason)

	addPayoutItem(breakdown, label, amount)
	addOneEyedJackBonus(session, breakdown)

	return breakdown
end

local function createLossBreakdown(label, lossAmount, reason)
	local breakdown = createPayoutBreakdown("lose", reason)

	addPayoutItem(breakdown, label, -lossAmount)

	return breakdown
end

local function createFoldBreakdown(session, refund)
	local breakdown = createPayoutBreakdown("lose", "Player folded")

	addPayoutItem(breakdown, "Lost bet", -session.bet)

	if refund > 0 then
		addPayoutItem(breakdown, "Fold refund", refund)
	end

	return breakdown
end

local function createPushBreakdown(reason)
	return createPayoutBreakdown("push", reason)
end

local function applyPayoutBreakdown(session, breakdown)
	local returnAmount = session.bet + breakdown.total

	session.result = breakdown.result
	session.resultReason = breakdown.reason
	session.payoutItems = breakdown.items
	session.payoutTotal = breakdown.total
	session.pendingBankruptState = nil

	if returnAmount > 0 then
		Chip.addAmountHigh(session.playerChips, returnAmount)
	end

	session.betChips = Chip.createEmpty()
	syncPlayerMoney(session)
	Dealer.addMoney(session.dealer, -breakdown.total)
	syncDealerChips(session)

	if session.player.money <= 0 then
		session.pendingBankruptState = Session.State.PLAYER_BANKRUPT
	elseif session.dealer.money <= 0 then
		session.pendingBankruptState = Session.State.HOUSE_BANKRUPT
	end

	session.state = Session.State.RESULT
end

local function settle(session, result, reason)
	local breakdown

	if result == "win" then
		breakdown = createWinBreakdown(session, "Base win", session.bet, reason)
	elseif result == "lose" then
		breakdown = createLossBreakdown("Lost bet", session.bet, reason)
	else
		breakdown = createPushBreakdown(reason)
	end

	applyPayoutBreakdown(session, breakdown)
end

local function settleWinAmount(session, label, winAmount, reason)
	applyPayoutBreakdown(session, createWinBreakdown(session, label, winAmount, reason))
end

local function getFoldRefund(session)
	if session.bet <= Session.BET_STEP then
		return 0
	end

	return roundToNearestHundredBankers(session.bet / 2)
end

local function isBlackjack(hand)
	return #hand == 2 and Session.getHandValue(hand) == 21
end

local function isDealerShowingAce(session)
	return #session.dealer.hand > 0 and session.dealer.hand[1].rank == "A"
end

local function getBlackjackPayout(session)
	return roundToNearestHundredBankers(session.bet * 1.5)
end

local function hasOneEyedJack(hand)
	for _, card in ipairs(hand) do
		if Deck.isOneEyedJack(card) then
			return true
		end
	end

	return false
end

function Session.startBetting(session)
	session.state = Session.State.BETTING
	session.result = nil
	session.resultReason = nil
	session.payoutItems = {}
	session.payoutTotal = 0
	session.pendingBankruptState = nil
	session.hasOneEyedJackEvent = false
	session.betChips = Chip.createEmpty()
	session.selectedChipValue = 100
	session.chipSwapMode = "down"
	syncPlayerMoney(session)
	syncDealerChips(session)
	session.bet = 0
	session.deck = Deck.createShuffled()
	Player.resetHand(session.player)
	Dealer.resetHand(session.dealer)
end

function Session.increaseBet(session)
	session.selectedChipValue = Chip.getNextValue(session.selectedChipValue)
end

function Session.decreaseBet(session)
	session.selectedChipValue = Chip.getPreviousValue(session.selectedChipValue)
end

function Session.placeSelectedChip(session)
	return moveSelectedChip(session.playerChips, session.betChips, session)
end

function Session.reclaimSelectedChip(session)
	return moveSelectedChip(session.betChips, session.playerChips, session)
end

function Session.setChipSwapMode(session, mode)
	if mode == "up" or mode == "down" then
		session.chipSwapMode = mode
	end
end

function Session.swapBetChips(session)
	local didSwap

	if session.chipSwapMode == "up" then
		didSwap = Chip.swapUp(session.betChips, session.selectedChipValue)
	else
		didSwap = Chip.swapDown(session.betChips, session.selectedChipValue)
	end

	if didSwap then
		syncBetAmount(session)
	end

	return didSwap
end

function Session.deal(session)
	if session.bet < Session.BET_STEP then
		return
	end

	Player.draw(session.player, Deck.draw(session.deck))
	Player.draw(session.player, Deck.draw(session.deck))
	Dealer.draw(session.dealer, Deck.draw(session.deck))
	Dealer.draw(session.dealer, Deck.draw(session.deck))
	session.hasOneEyedJackEvent = hasOneEyedJack(session.player.hand)
	session.state = Session.State.PLAYER_TURN
end

function Session.hit(session)
	Player.draw(session.player, Deck.draw(session.deck))

	local playerValue = Session.getHandValue(session.player.hand)
	local charliePayout = Session.CHARLIE_PAYOUT_BY_COUNT[#session.player.hand]

	if playerValue > 21 then
		settle(session, "lose", "Player busted")
	elseif #session.player.hand == 7 then
		settleWinAmount(session, "Seven Card Charlie", session.bet * charliePayout, "Seven Card Charlie")
	end
end

function Session.canFold(session)
	return session.state == Session.State.PLAYER_TURN and #session.player.hand == 2
end

function Session.canDoubleDown(session)
	return session.state == Session.State.PLAYER_TURN
		and #session.player.hand == 2
		and session.player.money >= session.bet
end

function Session.canEvenMoney(session)
	return session.state == Session.State.PLAYER_TURN
		and isBlackjack(session.player.hand)
		and isDealerShowingAce(session)
end

function Session.canCashOutCharlie(session)
	local cardCount = #session.player.hand

	return session.state == Session.State.PLAYER_TURN
		and (cardCount == 5 or cardCount == 6)
		and Session.getHandValue(session.player.hand) <= 21
end

function Session.fold(session)
	if not Session.canFold(session) then
		return
	end

	local refund = getFoldRefund(session)

	applyPayoutBreakdown(session, createFoldBreakdown(session, refund))
end

local function playDealerTurn(session)
	while Session.getHandValue(session.dealer.hand) <= 16 do
		Dealer.draw(session.dealer, Deck.draw(session.deck))
	end
end

local function settleStand(session, playerValue)
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

function Session.takeEvenMoney(session)
	if not Session.canEvenMoney(session) then
		return
	end

	settleWinAmount(session, "Even money", session.bet, "Player took even money")
end

function Session.cashOutCharlie(session)
	if not Session.canCashOutCharlie(session) then
		return
	end

	local cardCount = #session.player.hand
	local payout = Session.CHARLIE_PAYOUT_BY_COUNT[cardCount]
	local reason = "Five Card Charlie"

	if cardCount == 6 then
		reason = "Six Card Charlie"
	end

	settleWinAmount(session, reason, session.bet * payout, reason)
end

function Session.doubleDown(session)
	if not Session.canDoubleDown(session) then
		return
	end

	if not addBetAmount(session, session.bet) then
		return
	end

	Player.draw(session.player, Deck.draw(session.deck))

	local playerValue = Session.getHandValue(session.player.hand)

	if playerValue > 21 then
		settle(session, "lose", "Player busted after double down")
	else
		settleStand(session, playerValue)
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
			"Blackjack payout",
			payout,
			"Player blackjack. Payout: " .. payout .. " won"
		)
		return
	elseif dealerHasBlackjack then
		settle(session, "lose", "Dealer blackjack")
		return
	end

	settleStand(session, playerValue)
end

function Session.reset(session)
	session.state = Session.State.START
	session.result = nil
	session.resultReason = nil
	session.payoutItems = {}
	session.payoutTotal = 0
	session.pendingBankruptState = nil
	session.bet = Session.DEFAULT_BET
	session.playerChips = createStartingPlayerChips()
	session.dealerChips = Chip.fromAmountHigh(Session.DEALER_STARTING_MONEY)
	session.betChips = Chip.createEmpty()
	session.selectedChipValue = 100
	session.chipSwapMode = "down"
	session.deck = nil
	session.hasOneEyedJackEvent = false
	session.player = Player.new(Session.PLAYER_STARTING_MONEY)
	session.dealer = Dealer.new(Session.DEALER_STARTING_MONEY)
end

function Session.continueAfterResult(session)
	if session.pendingBankruptState then
		session.state = session.pendingBankruptState
		session.pendingBankruptState = nil
		return
	end

	Session.startBetting(session)
end

function Session.getCurrentPayoutPreview(session)
	if session.state ~= Session.State.PLAYER_TURN then
		return nil
	end

	if Session.canCashOutCharlie(session) then
		local cardCount = #session.player.hand
		local payout = Session.CHARLIE_PAYOUT_BY_COUNT[cardCount]
		local reason = "Five Card Charlie"

		if cardCount == 6 then
			reason = "Six Card Charlie"
		end

		return createWinBreakdown(session, reason, session.bet * payout, reason)
	elseif Session.canEvenMoney(session) then
		return createWinBreakdown(session, "Even money", session.bet, "Player took even money")
	elseif isBlackjack(session.player.hand) then
		local payout = getBlackjackPayout(session)

		return createWinBreakdown(session, "Blackjack payout", payout, "Player blackjack")
	end

	return createWinBreakdown(session, "Base win", session.bet, "Projected win")
end

return Session
