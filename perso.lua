-- TODO field "weight" not necessary in linksByLevel

json = require "json"

console.clear()
gui.clearGraphics()

-- Program
NOM_SAVESTATE = "C:/Users/10131571/Documents/maria/Super Mario World (Europe) (Rev 1).Snes9x.QuickSave1.State"
NB_GENERATIONS = 100

-- Réseau
NB_COUCHE_CACHEES = 1
TAILLE_COUCHE_CACHEE = 5
-- Génétique
NB_INDIVIDU_POPULATION = 5
TOP_CLASSEMENT = 0.5 -- keep only part of the ranking
MUTATION_PROBA = 0.5
MUTATION_RATE = 0.25 -- ±%

-- game configuration
NB_INPUTS = (256 / 16) * (256 / 16)
BUTTONS = {
    "A", -- saute en tournant
    "B", -- saute
    --"X", -- ?
    --"Y", -- ?
    --"Up", -- regarde en l'air ?
    --"Down",
    --"Left",
    --"Right",
}

ENEMY_NEURONNE_VALUE = 1

function drawReseau(reseau)
    local gridWidthOrHeight = math.sqrt(NB_INPUTS)
    local gridCellSize = 6
    -- input
    local distanceFromEdge = 0
    for i = 0, NB_INPUTS - 1 do
        local x = distanceFromEdge + (i % gridWidthOrHeight) * gridCellSize
        local y = distanceFromEdge + math.floor(i / gridWidthOrHeight) * gridCellSize
        local color = reseau.neuronsByLevel[1][i + 1].value == ENEMY_NEURONNE_VALUE and "red" or "white"
        gui.drawRectangle(x, y, gridCellSize, gridCellSize, "black", color)
    end

    -- intermediates
    -- TODO
    local largerIntermediates = 0

    -- outputs
    local outputCellSize = 12
    for o = 0, #BUTTONS - 1 do
        gui.drawRectangle(
                gridWidthOrHeight * gridCellSize + largerIntermediates + 10,
                outputCellSize * o,
                outputCellSize,
                outputCellSize,
                "white",
                "black")
    end
end

function getSprites()
    local cameraX = memory.read_s16_le(0x1462)
    local cameraY = memory.read_s16_le(0x1464)

    local sprites = {}
    for i = 0, 12 - 1 do
        local stat = memory.readbyte(0x14c8 + i)
        if stat ~= 0 then
            local spriteX = memory.readbyte(0x14e0 + i) * 256 + memory.readbyte(0x00e4 + i)
            local spriteY = memory.readbyte(0x14d4 + i) * 256 + memory.readbyte(0x00d8 + i)

            local cameraSpriteX = spriteX - cameraX
            local cameraSpriteY = spriteY - cameraY

            -- visible by player?
            if cameraSpriteX < 256 and cameraSpriteY < 256 then
                local sprite = { x = cameraSpriteX, y = cameraSpriteY }
                --gui.drawBox(sprite.x - 1, sprite.y - 1, sprite.x + 1, sprite.y + 1, "blue", "blue")
                table.insert(sprites, sprite)
            end
        end
    end
    return sprites
end

function firstRandomGeneration()
    local population = {}
    for i = 1, NB_INDIVIDU_POPULATION do
        local individu = firstRandomIndividu(NB_INPUTS, #BUTTONS)
        mutateIndividu(individu)
        table.insert(population, individu)
    end
    return population
end

-- Crée la nouvelle basée sur la mutation du #1 avec les N suivants
function nextGeneration(previousGeneration, scoreByIndividu)
    table.sort(scoreByIndividu, function(a, b)
        return a.score > b.score
    end)
    local betterIndividu = scoreByIndividu[1].individu
    --console.log("Better: " .. json.encode(betterIndividu))

    if #previousGeneration > 1 and scoreByIndividu[1].score ~= scoreByIndividu[2].score then
        console.log("New generation with a #1 !!!")
    end

    local nextGeneration = {}
    for i = 1, #previousGeneration do
        local otherIndex = 1 + math.floor(math.random() * TOP_CLASSEMENT * #previousGeneration)
        local goodIndividu = previousGeneration[otherIndex]
        local childIndividu = reproduireIndividus(goodIndividu, betterIndividu)
        childIndividu = mutateIndividu(childIndividu)
        table.insert(nextGeneration, childIndividu)
    end
    return nextGeneration
end

function firstRandomIndividu(nbInputs, nbOutputs)
    local neuronsByLevel = {}
    local initialValue = 0
    -- first = input
    local inputs = {}
    table.insert(neuronsByLevel, inputs)
    for x = 1, nbInputs do
        table.insert(inputs, { value = initialValue })
    end
    -- intermediates
    for x = 1, NB_COUCHE_CACHEES do
        local level = {}
        table.insert(neuronsByLevel, level)
        for x = 1, TAILLE_COUCHE_CACHEE do
            table.insert(level, { value = initialValue })
        end
    end
    -- last = outputs
    local outputs = {}
    table.insert(neuronsByLevel, outputs)
    for x = 1, nbOutputs do
        table.insert(outputs, { value = initialValue })
    end

    local linksByLevel = {} -- from level > source neuron index > target neuron index
    for c = 1, #neuronsByLevel - 1 do
        local fromNeuron = {}
        for from = 1, #neuronsByLevel[c] do
            local toNeuron = {}
            for to = 1, #neuronsByLevel[c + 1] do
                table.insert(toNeuron, { weight = 0 })
            end
            table.insert(fromNeuron, toNeuron)
        end
        table.insert(linksByLevel, fromNeuron)
    end

    return {
        neuronsByLevel = neuronsByLevel,
        linksByLevel = linksByLevel,
    }
end

function mutateWeight(weight)
    if math.random() < MUTATION_PROBA then
        local rate = MUTATION_RATE * (math.random() - 0.5)
        weight = weight + rate
        if weight < 0 then
            weight = 0
        end
        if weight > 1 then
            weight = 1
        end
    end
    return weight
end

function mutateIndividu(reseau)
    for c, level in ipairs(reseau.linksByLevel) do
        for f, from in ipairs(level) do
            for l, link in ipairs(from) do
                link.weight = mutateWeight(link.weight)
            end
        end
    end
    return reseau
end

function reproduireIndividus(reseau1, reseau2)
    local neuronsByLevel = {}
    for c = 1, #reseau1.neuronsByLevel do
        local level = {}
        for n = 1, #reseau1.neuronsByLevel[c] do
            table.insert(level, { value = 0 }) -- computed during propagation
        end
        table.insert(neuronsByLevel, level)
    end

    local linksByLevel = {}
    for c = 1, #reseau1.linksByLevel do
        local fromNeuron = {}
        for from = 1, #reseau1.linksByLevel[c] do
            local toNeuron = {}
            for to = 1, #reseau1.linksByLevel[c][from] do
                local weight = (reseau1.linksByLevel[c][from][to].weight + reseau2.linksByLevel[c][from][to].weight) / 2
                table.insert(toNeuron, { weight = weight })
            end
            table.insert(fromNeuron, toNeuron)
        end
        table.insert(linksByLevel, fromNeuron)
    end

    return {
        neuronsByLevel = neuronsByLevel,
        linksByLevel = linksByLevel,
    }
end

-- TODO
function outputActivated(value)
    return value >= 0.5
end

function sigmoid(value)
    return value / (1 + math.exp(-1 * value))
end

-- TODO
function updateInputsRecomputeOutputs(reseau, inputs)
    -- 1st level: inputs
    for i, input in ipairs(inputs) do
        -- TODO remove debug
        if reseau == nill or reseau.neuronsByLevel == nill or reseau.neuronsByLevel[1] == nill or reseau.neuronsByLevel[1][i] == nill then
            console.log("reseau: " .. json.encode(reseau))
        end
        reseau.neuronsByLevel[1][i].value = input
    end

    -- intermediates
    for c = 2, #reseau.neuronsByLevel do
        for n, neuron in ipairs(reseau.neuronsByLevel[c]) do
            local weightedSum = 0.0
            for p, previous in ipairs(reseau.neuronsByLevel[c - 1]) do
                local link = reseau.linksByLevel[c - 1][p][n]
                weightedSum = weightedSum + link.weight * previous.value
            end
            reseau.neuronsByLevel[c][n].value = sigmoid(weightedSum)
        end
    end

    local outputs = {}
    for o, neuron in ipairs(reseau.neuronsByLevel[#reseau.neuronsByLevel]) do
        table.insert(outputs, outputActivated(neuron.value))
        --if outputActivated(neuron.value) then
        --    console.log("Activated! " .. json.encode(reseau))
        --end
    end
    return outputs
end

function computeOutputsThenUpdateButtons(individu)
    local inputs = {}
    for i = 1, NB_INPUTS do
        table.insert(inputs, 0)
    end
    for _, sprite in ipairs(getSprites()) do
        local width = math.sqrt(256)
        local iX = math.floor((sprite.x / width)) + 1
        local iY = math.floor((sprite.y / width)) + 1
        local i = iX + iY * width
        inputs[i] = ENEMY_NEURONNE_VALUE
    end

    local outputs = updateInputsRecomputeOutputs(individu, inputs)

    local newButtons = {}
    for o, enabled in ipairs(outputs) do
        newButtons[BUTTONS[o]] = enabled
    end
    newButtons.Right = true -- TODO remove test
    joypad.set(newButtons, 1)
    emu.frameadvance()
end

function niveauFini()
    return memory.readbyte(0x0100) == 12
end

function getScore()
    return memory.readbyte(0x0f34)
end

function play(individu)
    savestate.load(NOM_SAVESTATE)
    while true do
        computeOutputsThenUpdateButtons(individu)
        drawReseau(individu)
        if niveauFini() then
            return getScore() -- TODO append time
        end
    end
end

local population = firstRandomGeneration()
for generation = 1, NB_GENERATIONS do
    console.log("Génération " .. generation .. "/" .. NB_GENERATIONS)
    local scoreByIndividu = {}
    for i, individu in ipairs(population) do
        console.log("> Individu " .. i .. "/" .. #population)
        local score = play(individu)
        table.insert(scoreByIndividu, { individu = individu, score = score })
    end

    population = nextGeneration(population, scoreByIndividu)
end
