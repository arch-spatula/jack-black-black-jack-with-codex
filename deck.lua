local Deck = {}

local RANKS = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }
local SUITS = { "D", "C", "H", "S" }

function Deck.create()
	local deck = {}

	for _, suit in ipairs(SUITS) do
		for _, rank in ipairs(RANKS) do
			table.insert(deck, {
				rank = rank,
				suit = suit,
				label = rank .. suit,
			})
		end
	end

	return deck
end

function Deck.shuffle(deck)
	for index = #deck, 2, -1 do
		local swapIndex = love.math.random(index)
		deck[index], deck[swapIndex] = deck[swapIndex], deck[index]
	end

	return deck
end

function Deck.draw(deck)
	return table.remove(deck)
end

function Deck.createShuffled()
	return Deck.shuffle(Deck.create())
end

return Deck
