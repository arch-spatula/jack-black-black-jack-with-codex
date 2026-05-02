local Chip = {}

Chip.DENOMINATIONS = {
	{ value = 100, label = "100" },
	{ value = 500, label = "500" },
	{ value = 1000, label = "1K" },
	{ value = 5000, label = "5K" },
	{ value = 10000, label = "10K" },
	{ value = 50000, label = "50K" },
	{ value = 100000, label = "100K" },
}

local valueToIndex = {}
local valueToLabel = {}

for index, denomination in ipairs(Chip.DENOMINATIONS) do
	valueToIndex[denomination.value] = index
	valueToLabel[denomination.value] = denomination.label
end

function Chip.createEmpty()
	local chips = {}

	for _, denomination in ipairs(Chip.DENOMINATIONS) do
		chips[denomination.value] = 0
	end

	return chips
end

function Chip.copy(chips)
	local copied = Chip.createEmpty()

	for value, count in pairs(chips) do
		copied[value] = count
	end

	return copied
end

function Chip.total(chips)
	local total = 0

	for _, denomination in ipairs(Chip.DENOMINATIONS) do
		total = total + denomination.value * (chips[denomination.value] or 0)
	end

	return total
end

function Chip.fromAmountHigh(amount)
	local chips = Chip.createEmpty()

	if amount <= 0 then
		return chips
	end

	for index = #Chip.DENOMINATIONS, 1, -1 do
		local value = Chip.DENOMINATIONS[index].value
		local count = math.floor(amount / value)

		chips[value] = count
		amount = amount - count * value
	end

	return chips
end

function Chip.addAmountHigh(chips, amount)
	local added = Chip.fromAmountHigh(amount)

	for value, count in pairs(added) do
		chips[value] = (chips[value] or 0) + count
	end
end

function Chip.addChip(chips, value, count)
	chips[value] = (chips[value] or 0) + (count or 1)
end

function Chip.removeChip(chips, value, count)
	count = count or 1

	if (chips[value] or 0) < count then
		return false
	end

	chips[value] = chips[value] - count
	return true
end

function Chip.moveChip(source, target, value)
	if not Chip.removeChip(source, value, 1) then
		return false
	end

	Chip.addChip(target, value, 1)
	return true
end

function Chip.replaceWithAmountHigh(chips, amount)
	local replaced = Chip.fromAmountHigh(amount)

	for _, denomination in ipairs(Chip.DENOMINATIONS) do
		chips[denomination.value] = replaced[denomination.value]
	end
end

function Chip.getLabel(value)
	return valueToLabel[value] or tostring(value)
end

function Chip.getPreviousValue(value)
	local index = valueToIndex[value]

	if not index or index <= 1 then
		return value
	end

	return Chip.DENOMINATIONS[index - 1].value
end

function Chip.getNextValue(value)
	local index = valueToIndex[value]

	if not index or index >= #Chip.DENOMINATIONS then
		return value
	end

	return Chip.DENOMINATIONS[index + 1].value
end

function Chip.swapDown(chips, value)
	local lowerValue = Chip.getPreviousValue(value)

	if lowerValue == value or (chips[value] or 0) < 1 then
		return false
	end

	local lowerCount = value / lowerValue

	Chip.removeChip(chips, value, 1)
	Chip.addChip(chips, lowerValue, lowerCount)
	return true
end

function Chip.swapUp(chips, value)
	local lowerValue = Chip.getPreviousValue(value)

	if lowerValue == value then
		return false
	end

	local lowerCount = value / lowerValue

	if (chips[lowerValue] or 0) < lowerCount then
		return false
	end

	Chip.removeChip(chips, lowerValue, lowerCount)
	Chip.addChip(chips, value, 1)
	return true
end

return Chip
