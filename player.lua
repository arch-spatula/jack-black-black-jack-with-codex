local Player = {}

function Player.new(startingMoney)
	return {
		money = startingMoney,
		hand = {},
	}
end

function Player.resetHand(player)
	player.hand = {}
end

function Player.draw(player, card)
	table.insert(player.hand, card)
end

function Player.addMoney(player, amount)
	player.money = player.money + amount
end

return Player
