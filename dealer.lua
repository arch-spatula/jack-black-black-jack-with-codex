local Dealer = {}

function Dealer.new(startingMoney)
	return {
		money = startingMoney,
		hand = {},
	}
end

function Dealer.resetHand(dealer)
	dealer.hand = {}
end

function Dealer.draw(dealer, card)
	table.insert(dealer.hand, card)
end

function Dealer.addMoney(dealer, amount)
	dealer.money = dealer.money + amount
end

return Dealer
