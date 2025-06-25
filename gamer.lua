json = require "json"

console.clear()
gui.clearGraphics()

NOM_SAVESTATE = "C:/Users/10131571/Documents/maria/Super Mario World (Europe) (Rev 1).Snes9x.QuickSave0.State"
BUTTONS = {
    --"A", -- saute en tournant
    "B", -- saute
    --"X", -- ?
    --"Y", -- ?
    --"Up", -- regarde en l'air ?
    --"Down",
    --"Left",
    --"Right",
}

-- Functions (uncomment target program)
PROGRAM = "IA"
--PROGRAM = "DEBUG SPRITES"
--PROGRAM = "DEBUG TILES"

-- Debug & Test
RESTORE = nil -- json.decode('')
DRAW = false

-- Réseau de neurones
NB_COUCHE_CACHEES = 2
TAILLE_COUCHE_CACHEE = 5

-- Algorithmes génétiques
NB_INDIVIDU_POPULATION = 10
NB_GENERATIONS = 5000
TOP_CLASSEMENT = 0.5 -- keep only part of the ranking
MUTATION_PROBA = 0.25
MUTATION_RATE = 0.2 -- ±%

-- Paramètres spécifiques au jeu
GAME_WEIGHT = 256 -- x (horizontal / to right)
GAME_HEIGHT = 224 -- y (vertical /to bottom)
TAILLE_TILE = 16
NB_SPRITES = 12 -- limit in this game

-- Constantes de facilitation
INPUTS_X_MAX = 256--[[GAME_WEIGHT]] / TAILLE_TILE -- x
INPUTS_Y_MAX = 256--[[GAME_HEIGHT]] / TAILLE_TILE -- y
NB_INPUTS = INPUTS_X_MAX * INPUTS_Y_MAX
ENEMY_NEURONNE_VALUE = 1

--- @alias Position { x: number, y: number } In custom grid (not in pixel graphic). Start at "1"
--- @alias Reseau { neuronsByLevel: number[][], weightsByLevel: number[][][] }
--- @alias Generation Reseau[]

--- @param position Position
function neuronIndexFromGridPosition(position)
    return position.x + position.y * INPUTS_X_MAX
end

function gridPositionFromNeuronIndex(neuronIndex)
    return {
        x = neuronIndex % INPUTS_X_MAX,
        y = math.floor(neuronIndex / INPUTS_X_MAX),
    }
end

--- @param reseau Reseau
function drawReseau(reseau)
    -- input
    local inputDrawOffset = { x = 0, y = 0 }
    local inputCellSize = { x = 6, y = 6 } -- TODO x & y depending INPUTS_WEIGHT & INPUTS_HEIGHT
    for i, inputNeuron in ipairs(reseau.neuronsByLevel[1]) do
        local position = gridPositionFromNeuronIndex(i - 1)
        gui.drawRectangle(
                inputDrawOffset.x + inputCellSize.x * position.x,
                inputDrawOffset.y + inputCellSize.y * position.y,
                inputCellSize.x,
                inputCellSize.y,
                "black",
                inputNeuron == ENEMY_NEURONNE_VALUE and "red" or nil)
    end
    local lastInputX = gridPositionFromNeuronIndex(#reseau.neuronsByLevel[1] - 1).x * inputCellSize.x + inputCellSize.x

    -- intermediates
    -- TODO debug&draw
    local lastIntermediatesX = lastInputX

    -- outputs
    local outputDrawOffset = { x = 24, y = 0 }
    local outputCellSize = { x = 12, y = 12 }
    for o, outputNeuron in ipairs(reseau.neuronsByLevel[#reseau.neuronsByLevel]) do
        gui.drawRectangle(
                lastIntermediatesX + outputDrawOffset.x,
                outputDrawOffset.y + outputCellSize.y * (o - 1),
                outputCellSize.x,
                outputCellSize.y,
                "white",
                outputActivated(outputNeuron) and "red" or "black")
    end
end

--- @return Position[]
function getSprites()
    local cameraX = memory.read_s16_le(0x1462)
    local cameraY = memory.read_s16_le(0x1464)

    local sprites = {}
    for i = 0, NB_SPRITES - 1 do
        local status = memory.readbyte(0x14c8 + i)
        if status ~= 0 then
            local spriteX = memory.readbyte(0xe4 + i) + memory.readbyte(0x14e0 + i) * 256
            local spriteY = memory.readbyte(0xd8 + i) + memory.readbyte(0x14d4 + i) * 256

            local screenX = spriteX - cameraX
            local screenY = spriteY - cameraY

            -- visible by player?
            if 0 < screenX and screenX < GAME_WEIGHT
                    and 0 < screenY and screenY < GAME_HEIGHT then
                local gridX = math.floor(TAILLE_TILE * (screenX / 256)) + 1
                local gridY = math.floor(TAILLE_TILE * (screenY / 256)) + 1
                table.insert(sprites, { x = gridX, y = gridY })
            end
        end
    end
    return sprites
end
function runDebugSprites()
    savestate.load(NOM_SAVESTATE)
    local interval = 10
    local rep = 0
    while true do
        rep = rep + 1
        if rep % interval == 0 then
            console.clear()
            gui.clearGraphics()
            for i = 0, 15 do
                for j = 0, 15 do
                    gui.drawRectangle(i * 16, j * 16, 16, 16, "black")
                end
            end

            for _, sprite in ipairs(getSprites()) do
                gui.drawRectangle((sprite.x - 1) * TAILLE_TILE, (sprite.y - 1) * TAILLE_TILE, TAILLE_TILE, TAILLE_TILE, "black", "red")
            end
        end
        emu.frameadvance()
    end
end

--- @return Position[]
function getTiles()
    local cameraX = memory.read_s16_le(0x1462)
    local cameraY = memory.read_s16_le(0x1464)
    local sprites = {}
    for i = 1, GAME_WEIGHT / TAILLE_TILE, 1 do
        local xT = math.floor((cameraX + ((i - 1) * TAILLE_TILE) + 8) / TAILLE_TILE)
        for j = 1, GAME_HEIGHT / TAILLE_TILE, 1 do
            local yT = math.floor((cameraY + ((j - 1) * TAILLE_TILE)) / TAILLE_TILE)
            if xT > 0 and yT > 0 then
                local tile = memory.readbyte(0x1C800 + math.floor(xT / TAILLE_TILE) * 0x1B0 + yT * TAILLE_TILE + xT % TAILLE_TILE)
                if tile == 1 then
                    table.insert(sprites, { x = i, y = j })
                end
            end
        end
    end
    return sprites
end
function runDebugTiles()
    savestate.load(NOM_SAVESTATE)
    local interval = 10
    local rep = 0
    while true do
        rep = rep + 1
        if rep % interval == 0 then
            console.clear()
            gui.clearGraphics()
            for _, tile in ipairs(getTiles()) do
                console.log(tile.x .. "/" .. tile.y)
                gui.drawRectangle((tile.x - 1) * TAILLE_TILE, (tile.y - 1) * TAILLE_TILE, TAILLE_TILE, TAILLE_TILE, "black", "red")
            end
        end
        emu.frameadvance()
    end
end

--- @return Generation
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
--- @param previousGeneration Generation
--- @return Generation
function nextGeneration(previousGeneration, scoreByIndividu)
    table.sort(scoreByIndividu, function(a, b)
        return a.score > b.score
    end)
    local bestIndividu = scoreByIndividu[1].individu
    if #previousGeneration > 1 and scoreByIndividu[1].score ~= scoreByIndividu[2].score then
        console.log("New generation with a #1 !!!")
    end

    local nextGeneration = {}
    -- evolve the best (for little population)
    if #previousGeneration > 1 then
        local bestItself = reproduireIndividus(bestIndividu, bestIndividu)
        bestItself = mutateIndividu(bestItself)
        table.insert(nextGeneration, bestItself)
    end
    -- keep the best (for little population)
    table.insert(nextGeneration, bestIndividu)
    -- reproduce the best with the others
    while #nextGeneration < #previousGeneration do
        local skipBest = 1
        local otherIndex = math.floor(math.random() * TOP_CLASSEMENT * (#previousGeneration - skipBest)) + skipBest
        local goodIndividu = previousGeneration[otherIndex + 1]
        local childIndividu = reproduireIndividus(goodIndividu, bestIndividu)
        childIndividu = mutateIndividu(childIndividu)
        table.insert(nextGeneration, childIndividu)
    end
    return nextGeneration
end

--- @param nbInputs number
--- @param nbOutputs number
--- @return Reseau
function firstRandomIndividu(nbInputs, nbOutputs)
    if RESTORE ~= nill then
        return RESTORE
    end

    local initialValue = 0

    local neuronsByLevel = {}
    -- first = input
    local inputs = {}
    for x = 1, nbInputs do
        table.insert(inputs, initialValue)
    end
    table.insert(neuronsByLevel, inputs)
    -- intermediates
    for x = 1, NB_COUCHE_CACHEES do
        local level = {}
        for x = 1, TAILLE_COUCHE_CACHEE do
            table.insert(level, initialValue)
        end
        table.insert(neuronsByLevel, level)
    end
    -- last = outputs
    local outputs = {}
    for x = 1, nbOutputs do
        table.insert(outputs, initialValue)
    end
    table.insert(neuronsByLevel, outputs)

    local weightsByLevel = {} -- from level > source neuron index > target neuron index
    for c = 1, #neuronsByLevel - 1 do
        local fromNeuron = {}
        for from = 1, #neuronsByLevel[c] do
            local toNeuron = {}
            for to = 1, #neuronsByLevel[c + 1] do
                table.insert(toNeuron, 0)
            end
            table.insert(fromNeuron, toNeuron)
        end
        table.insert(weightsByLevel, fromNeuron)
    end

    print(json.encode({
        neuronsByLevel = neuronsByLevel,
        weightsByLevel = weightsByLevel,
    }))
    return {
        neuronsByLevel = neuronsByLevel,
        weightsByLevel = weightsByLevel,
    }
end

--- @param weight number
--- @return number
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

--- @param reseau Reseau
--- @return Reseau
function mutateIndividu(reseau)
    for c, level in ipairs(reseau.weightsByLevel) do
        for f, from in ipairs(level) do
            for l, weight in ipairs(from) do
                from[l] = mutateWeight(from[l])
            end
        end
    end
    return reseau
end

--- @param reseau1 Reseau
--- @param reseau2 Reseau
--- @return Reseau
function reproduireIndividus(reseau1, reseau2)
    local neuronsByLevel = {}
    for c = 1, #reseau1.neuronsByLevel do
        local level = {}
        for n = 1, #reseau1.neuronsByLevel[c] do
            table.insert(level, 0) -- computed during propagation
        end
        table.insert(neuronsByLevel, level)
    end

    local weightsByLevel = {}
    for c = 1, #reseau1.weightsByLevel do
        local fromNeuron = {}
        for from = 1, #reseau1.weightsByLevel[c] do
            local toNeuron = {}
            for to = 1, #reseau1.weightsByLevel[c][from] do
                local avgWeight = (reseau1.weightsByLevel[c][from][to] + reseau2.weightsByLevel[c][from][to]) / 2
                table.insert(toNeuron, avgWeight)
            end
            table.insert(fromNeuron, toNeuron)
        end
        table.insert(weightsByLevel, fromNeuron)
    end

    return {
        neuronsByLevel = neuronsByLevel,
        weightsByLevel = weightsByLevel,
    }
end

--- @param value number
--- @return boolean
function outputActivated(value)
    return value >= 0.5
end

--- @param value number
--- @return number
function sigmoid(value)
    return value / (1 + math.exp(-1 * value))
end

--- @param reseau Reseau
--- @param inputs TODO
--- @return TODO
function updateInputsRecomputeLinkToOutputs(reseau, inputs)
    -- 1st level: inputs
    for i, input in ipairs(inputs) do
        reseau.neuronsByLevel[1][i] = input
    end

    -- intermediates
    for c = 2, #reseau.neuronsByLevel do
        for n, neuron in ipairs(reseau.neuronsByLevel[c]) do
            local weightedSum = 0.0
            for p, previous in ipairs(reseau.neuronsByLevel[c - 1]) do
                local weight = reseau.weightsByLevel[c - 1][p][n]
                weightedSum = weightedSum + weight * previous
            end
            reseau.neuronsByLevel[c][n] = sigmoid(weightedSum)
        end
    end

    local outputs = {}
    for o, neuron in ipairs(reseau.neuronsByLevel[#reseau.neuronsByLevel]) do
        table.insert(outputs, outputActivated(neuron))
    end
    return outputs
end

--- @param individu Reseau
function computeOutputsThenUpdateButtons(individu)
    local inputs = {}
    for i = 1, NB_INPUTS do
        table.insert(inputs, 0)
    end
    for _, sprite in ipairs(getSprites()) do
        local i = neuronIndexFromGridPosition({ x = sprite.x, y = sprite.y })

        inputs[i + 1] = ENEMY_NEURONNE_VALUE
    end

    local outputs = updateInputsRecomputeLinkToOutputs(individu, inputs)

    local newButtons = {}
    for o, enabled in ipairs(outputs) do
        newButtons[BUTTONS[o]] = enabled
    end
    newButtons.Right = true -- first version: all the way to the right
    joypad.set(newButtons, 1)
    emu.frameadvance()
end

--- @return boolean
function niveauFini()
    return memory.readbyte(0x0100) == 12
end

--- @return number
function getScore()
    return memory.read_u24_le(0x0f34)
end

--- @param individu Reseau
function play(individu)
    savestate.load(NOM_SAVESTATE)
    while true do
        computeOutputsThenUpdateButtons(individu)
        if DRAW then
            drawReseau(individu)
        end
        if niveauFini() then
            return getScore() -- TODO append time
        end
    end
end

function runIA()
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
end

if PROGRAM == "IA" then
    runIA()
elseif PROGRAM == "DEBUG SPRITES" then
    runDebugSprites()
elseif PROGRAM == "DEBUG TILES" then
    runDebugTiles()
end
