console.clear()
gui.clearGraphics()

-- Program parameters
DEBUG = true
NOM_SAVESTATE = "C:/Users/10131571/Documents/maria/Super Mario World (Europe) (Rev 1).Snes9x.QuickSave1.State"
NB_GENERATIONS = 1
NB_INDIVIDU_POPULATION = 1

-- Réseau parameters
NB_COUCHE_CACHEES = 1
TAILLE_COUCHE_CACHEE = 5

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

function drawReseau(reseau)
    local gridWidthOrHeight = math.sqrt(NB_INPUTS)
    local gridCellSize = 6
    -- input
    local distanceFromEdge = 0
    for i = 0, NB_INPUTS - 1 do
        local x = distanceFromEdge + (i % gridWidthOrHeight) * gridCellSize
        local y = distanceFromEdge + math.floor(i / gridWidthOrHeight) * gridCellSize
        local color = reseau.neuronsByLevel[1][i + 1].value == -1 and "red" or "white"
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
        return a.score < b.score
    end)
    local betterIndividu = scoreByIndividu[1].individu

    for i = 0, #previousGeneration do
        local individu = betterIndividu
        -- TODO évolution: reproduction entre meilleur et N suivants
        mutateIndividu(individu)
        table.insert(population, individu)
    end

    return previousGeneration
end

function firstRandomIndividu(nbInputs, nbOutputs)
    local neuronsByLevel = {}
    local initialValue = 0.5
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
        table.insert(linksByLevel, fromNeuron)
        for from = 1, #neuronsByLevel[c] do
            local toNeuron = {}
            table.insert(fromNeuron, toNeuron)
            for to = 1, #neuronsByLevel[c + 1] do
                table.insert(toNeuron, { weight = 0.5 })
            end
        end
    end

    return {
        neuronsByLevel = neuronsByLevel,
        linksByLevel = linksByLevel,
    }
end

function mutateIndividu(individu)
    for c, level in ipairs(individu.linksByLevel) do
        for f, from in ipairs(level) do
            for l, link in ipairs(from) do
                local delta = (math.random() - 0.5) * 1.05 -- ±5%
                link.weight = link.weight * delta
            end
        end
    end
end

-- TODO
function outputActivated(value)
    return value / (1 + math.abs(value)) >= 0.5
end

-- TODO
function updateInputsRecomputeOutputs(reseau, inputs)
    -- 1st level: inputs
    for i, input in ipairs(inputs) do
        reseau.neuronsByLevel[1][i].value = input
    end

    -- TODO compute
    -- intermediates
    for c = 2, #reseau.neuronsByLevel do
        for n, neuron in ipairs(reseau.neuronsByLevel[c]) do
            local newValue = 0
            for p, previous in ipairs(reseau.neuronsByLevel[c - 1]) do
                local link = reseau.linksByLevel[c - 1][p][n]
                newValue = newValue + link.weight * previous.value
            end
            reseau.neuronsByLevel[c][n].value = newValue
        end
    end

    local outputs = {}
    for o, neuron in ipairs(reseau.neuronsByLevel[#reseau.neuronsByLevel]) do
        table.insert(outputs, outputActivated(neuron.value))
    end
    return outputs
end

function computeOutputAndUpdateButtons(individu)
    local inputs = {}
    for i = 1, NB_INPUTS do
        table.insert(inputs, 0)
    end
    for _, sprite in ipairs(getSprites()) do
        local width = math.sqrt(256)
        local iX = math.floor((sprite.x / width)) + 1
        local iY = math.floor((sprite.y / width)) + 1
        local i = iX + iY * width
        inputs[i] = -1
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
    return memory.readbyte(0x13d6)
end

function play(individu)
    savestate.load(NOM_SAVESTATE)
    while true do
        computeOutputAndUpdateButtons(individu)
        drawReseau(individu)
        if niveauFini() then
            return getScore()
        end
    end
end

local population = firstRandomGeneration()
for generation = 1, NB_GENERATIONS do
    local scoreByIndividu = {}
    for _, individu in ipairs(population) do
        local score = play(individu)
        table.insert(scoreByIndividu, { individu = individu, score = score })
    end

    population = nextGeneration(population, scoreByIndividu)
end
