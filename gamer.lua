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
--PROGRAM = "DEBUG SCORE"

-- Debug & Test
RESTORED_STATE = nil
--RESTORED_STATE = json.decode(io.open("./state.json", "rb"):read())
DRAW = false

-- Réseau de neurones
NB_COUCHE_CACHEES = 1
TAILLE_COUCHE_CACHEE = 5

-- Algorithmes génétiques
NB_INDIVIDU_POPULATION = 10
NB_GENERATIONS = 5000 -- stop program
TOP_CLASSEMENT = 0.5 -- keep only part of the ranking
MUTATION_PROBA = 0.25
MUTATION_DELTA_MAX = 0.2 -- max value of delta on weight mutation (e.g. for "0.1" the previous weight of "0.5" will be in [0.4 ; 0.6])

-- Paramètres spécifiques au jeu
SCREEN_WEIGHT = 256 -- x (horizontal / to right)
SCREEN_HEIGHT = 224 -- y (vertical /to bottom)
NB_SPRITES = 12 -- limited in this game

-- Constantes de facilitation
TAILLE_TILE = 16
--- @deprecated Depending "sprite"|"tile" input group size
INPUTS_X_MAX = SCREEN_WEIGHT / TAILLE_TILE -- x
--- @deprecated Depending "sprite"|"tile" input group size
INPUTS_Y_MAX = SCREEN_HEIGHT / TAILLE_TILE -- y
NB_INPUTS_SPRITES = INPUTS_X_MAX * INPUTS_Y_MAX
NB_INPUTS_TILES = INPUTS_X_MAX * INPUTS_Y_MAX

--- @alias Position { x: number, y: number } In custom grid (not in pixel graphic). Start at "1"
--- @alias Reseau { neuronsByLevel: number[][], weightsByLevel: number[][][] }
--- @alias Generation Reseau[]

function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

--[[
 1  17  ..
 2  18  ..
..  ..  ..
16  32  ..
--]]
--- Starts at "0"
--- @param position Position
function neuronIndexFromGridPosition(position)
    return position.x + position.y * INPUTS_X_MAX
end

--- @param reseau Reseau
--- @param couche number
--- @param neuron number
function neuronDrawPosition(reseau, couche, neuron, cellSize)
    if couche == 1 then
        local group = neuron <= NB_INPUTS_SPRITES and 0 or 1
        return {
            x = cellSize * ((neuron - 1) % INPUTS_X_MAX),
            y = cellSize * math.floor((neuron - 1) / INPUTS_X_MAX) + (group * 12),
        }
    else
        local deltaInputsX = INPUTS_X_MAX * cellSize
        local sizeCellCouches = (#reseau.neuronsByLevel - 1) * cellSize
        local spaceBetweenCouchesX = math.floor((SCREEN_WEIGHT - deltaInputsX - sizeCellCouches) / (#reseau.neuronsByLevel - 1))
        local spaceBetweenCouchesY = math.floor((SCREEN_HEIGHT - (TAILLE_COUCHE_CACHEE * cellSize)) / TAILLE_COUCHE_CACHEE)
        return {
            x = deltaInputsX + spaceBetweenCouchesX + (couche - 2) * (spaceBetweenCouchesX + cellSize),
            y = (neuron - 1) * (cellSize + spaceBetweenCouchesY),
        }
    end
end
--- Recursive fonction to remonter: de l'output activé, jusqu'au(x) (différents?) input(s) activé(s)
--- @param tgtCouche number Couche where the neuron is activated (target)
--- @param tgtNeuron number Neuron activated (target)
function drawLinkToActivatedNeuron(reseau, tgtCouche, tgtNeuron, weightDetection, cellSize)
    local srcCouche = tgtCouche - 1
    if srcCouche == 0 then
        return
    end

    -- create single link with best input
    local bestPreviousNeuronIndex = nil
    local bestPreviousNeuronWeight = nil
    for p, previousNeuron in ipairs(reseau.neuronsByLevel[srcCouche]) do
        if previousNeuron then
            local weight = reseau.weightsByLevel[srcCouche][p][tgtNeuron]
            if bestPreviousNeuronWeight == nil or weight > bestPreviousNeuronWeight then
                bestPreviousNeuronWeight = weight
                bestPreviousNeuronIndex = p
            end
        end
    end

    local fromScreenPosition = neuronDrawPosition(reseau, srcCouche, bestPreviousNeuronIndex, cellSize)
    local toScreenPosition = neuronDrawPosition(reseau, tgtCouche, tgtNeuron, cellSize)
    gui.drawLine(
            fromScreenPosition.x + cellSize / 2,
            fromScreenPosition.y + cellSize / 2,
            toScreenPosition.x + cellSize / 2,
            toScreenPosition.y + cellSize / 2,
            "white")
    drawLinkToActivatedNeuron(reseau, srcCouche, bestPreviousNeuronIndex, weightDetection, cellSize)
end
--- @param reseau Reseau
function drawReseau(reseau)
    if not DRAW then
        return
    end

    local cellSize = 6

    for c = 1, #reseau.neuronsByLevel do
        for n, neuron in ipairs(reseau.neuronsByLevel[c]) do
            local screenPosition = neuronDrawPosition(reseau, c, n, cellSize)
            gui.drawRectangle(
                    screenPosition.x,
                    screenPosition.y,
                    cellSize,
                    cellSize,
                    "black",
                    neuron and "red" or nil)
        end
    end

    local linksFromCouche = #reseau.neuronsByLevel
    for n, neuron in ipairs(reseau.neuronsByLevel[linksFromCouche]) do
        if neuron then
            drawLinkToActivatedNeuron(reseau, linksFromCouche, n, 0.3, cellSize)
        end
    end
end

function getPositionCamera()
    return {
        x = memory.read_s16_le(0x1462),
        y = memory.read_s16_le(0x1464),
    }
end
function getPositionMario()
    return {
        x = memory.read_s16_le(0x94),
        y = memory.read_s16_le(0x96),
    }
end

--- @return Position[]
function getSprites()
    local mario = getPositionMario()
    local relativePosition = {
        x = mario.x - TAILLE_TILE * 7,
        y = mario.y - TAILLE_TILE * 5,
    }

    local sprites = {}
    for i = 0, NB_SPRITES - 1 do
        local status = memory.readbyte(0x14c8 + i)
        if status ~= 0 then
            local spriteX = memory.readbyte(0xe4 + i) + memory.readbyte(0x14e0 + i) * 256
            local spriteY = memory.readbyte(0xd8 + i) + memory.readbyte(0x14d4 + i) * 256

            local screenX = spriteX - relativePosition.x
            local screenY = spriteY - relativePosition.y

            -- visible by player?
            if 0 < screenX and screenX < SCREEN_WEIGHT
                    and 0 < screenY and screenY < SCREEN_HEIGHT then
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
            for x = 1, SCREEN_WEIGHT / TAILLE_TILE do
                for y = 1, SCREEN_HEIGHT / TAILLE_TILE do
                    gui.drawRectangle((x - 1) * TAILLE_TILE, (y - 1) * TAILLE_TILE, TAILLE_TILE, TAILLE_TILE, "black", nil)
                end
            end
            gui.drawRectangle(
                    ((SCREEN_WEIGHT / TAILLE_TILE) / 2 - 1) * TAILLE_TILE - (TAILLE_TILE / 2),
                    ((SCREEN_HEIGHT / TAILLE_TILE) / 2 - 1) * TAILLE_TILE - (TAILLE_TILE / 2),
                    TAILLE_TILE, 1.5 * TAILLE_TILE,
                    "blue", "blue")
            for _, sprite in ipairs(getSprites()) do
                console.log(sprite.x .. "/" .. sprite.y)
                if sprite.x < 1 or sprite.x > SCREEN_WEIGHT / TAILLE_TILE or sprite.y < 1 or sprite.y > SCREEN_HEIGHT / TAILLE_TILE then
                    error("Invalid sprite: " .. sprite)
                end
                gui.drawRectangle((sprite.x - 1) * TAILLE_TILE, (sprite.y - 1) * TAILLE_TILE, TAILLE_TILE, TAILLE_TILE, "black", "red")
            end
        end
        emu.frameadvance()
    end
end

--- @return Position[]
function getTiles()
    local mario = getPositionMario()
    local relativePosition = {
        x = mario.x - TAILLE_TILE * 7,
        y = mario.y - TAILLE_TILE * 5,
    }

    local sprites = {}
    for i = 1, SCREEN_WEIGHT / TAILLE_TILE, 1 do
        local xT = math.floor((relativePosition.x + ((i - 1) * TAILLE_TILE) + 8) / TAILLE_TILE)
        for j = 1, SCREEN_HEIGHT / TAILLE_TILE, 1 do
            local yT = math.floor((relativePosition.y + ((j - 1) * TAILLE_TILE)) / TAILLE_TILE)
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
            for x = 1, SCREEN_WEIGHT / TAILLE_TILE do
                for y = 1, SCREEN_HEIGHT / TAILLE_TILE do
                    gui.drawRectangle((x - 1) * TAILLE_TILE, (y - 1) * TAILLE_TILE, TAILLE_TILE, TAILLE_TILE, "black", nil)
                end
            end
            gui.drawRectangle(
                    ((SCREEN_WEIGHT / TAILLE_TILE) / 2 - 1) * TAILLE_TILE - (TAILLE_TILE / 2),
                    ((SCREEN_HEIGHT / TAILLE_TILE) / 2 - 1) * TAILLE_TILE - (TAILLE_TILE / 2),
                    TAILLE_TILE, 1.5 * TAILLE_TILE,
                    "blue", "blue")
            for _, tile in ipairs(getTiles()) do
                console.log(tile.x .. "/" .. tile.y)
                if tile.x < 1 or tile.x > SCREEN_WEIGHT / TAILLE_TILE or tile.y < 1 or tile.y > SCREEN_HEIGHT / TAILLE_TILE then
                    error("Invalid tile: " .. tile)
                end
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
        local individu = firstRandomIndividu(NB_INPUTS_SPRITES + NB_INPUTS_TILES, #BUTTONS)
        table.insert(population, individu)
    end
    return population
end

-- Crée la nouvelle basée sur la mutation du #1 avec les N suivants
--- @param previousGeneration Generation
--- @param scoreByIndividu { individu: Reseau, score: number }[]
--- @return Generation
function nextGeneration(previousGeneration, scoreByIndividu)
    shuffle(scoreByIndividu) -- avoid keep same individu when scores are equals

    table.sort(scoreByIndividu, function(a, b)
        return a.score > b.score
    end)
    local bestIndividu = scoreByIndividu[1].individu
    if #previousGeneration > 1 and scoreByIndividu[1].score ~= scoreByIndividu[2].score then
        console.log("Generation with a #1 !!!")
    end

    local nextGeneration = {}
    -- keep the best
    table.insert(nextGeneration, bestIndividu)
    -- try improve the best
    if #nextGeneration < #previousGeneration then
        local bestItself = reproduireIndividus(bestIndividu, bestIndividu)
        bestItself = mutateIndividu(bestItself)
        table.insert(nextGeneration, bestItself)
    end
    -- reproduce #1 with #2
    if #nextGeneration < #previousGeneration and #previousGeneration >= 2 then
        local second = scoreByIndividu[2].individu
        local bestChild = reproduireIndividus(bestIndividu, second)
        bestChild = mutateIndividu(bestChild)
        table.insert(nextGeneration, bestChild)
    end
    -- reproduce the best with the others
    while #nextGeneration < #previousGeneration do
        local skipBestAndSecond = 2
        local otherIndex = skipBestAndSecond + math.floor(math.random() * TOP_CLASSEMENT * (#previousGeneration - skipBestAndSecond))
        local candidateIndividu = previousGeneration[otherIndex + 1]
        local childIndividu = reproduireIndividus(candidateIndividu, bestIndividu)
        childIndividu = mutateIndividu(childIndividu)
        table.insert(nextGeneration, childIndividu)
    end
    return nextGeneration
end

--- @param nbInputs number
--- @param nbOutputs number
--- @return Reseau
function firstRandomIndividu(nbInputs, nbOutputs)
    if RESTORED_STATE ~= nill then
        return RESTORED_STATE
    end

    local initialNeuronValue = false

    local neuronsByLevel = {}
    -- first = input
    local inputs = {}
    for x = 1, nbInputs do
        table.insert(inputs, initialNeuronValue)
    end
    table.insert(neuronsByLevel, inputs)
    -- intermediates
    for x = 1, NB_COUCHE_CACHEES do
        local level = {}
        for x = 1, TAILLE_COUCHE_CACHEE do
            table.insert(level, initialNeuronValue)
        end
        table.insert(neuronsByLevel, level)
    end
    -- last = outputs
    local outputs = {}
    for x = 1, nbOutputs do
        table.insert(outputs, initialNeuronValue)
    end
    table.insert(neuronsByLevel, outputs)

    local initialWeightValue = 0 -- neutral (neither advantageous nor disadvantageous)
    local weightsByLevel = {} -- from level > source neuron index > target neuron index
    for c = 1, #neuronsByLevel - 1 do
        local fromNeuron = {}
        for from = 1, #neuronsByLevel[c] do
            local toNeuron = {}
            for to = 1, #neuronsByLevel[c + 1] do
                table.insert(toNeuron, initialWeightValue)
            end
            table.insert(fromNeuron, toNeuron)
        end
        table.insert(weightsByLevel, fromNeuron)
    end

    local individu = {
        neuronsByLevel = neuronsByLevel,
        weightsByLevel = weightsByLevel,
    }

    mutateIndividu(individu)

    return individu
end

--- @param weight number
--- @return number
function mutateWeight(weight)
    if math.random() < MUTATION_PROBA then
        local delta = MUTATION_DELTA_MAX * (2 * math.random() - 1)
        return weight + delta
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

--- Simple AVG between 2 individus
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

--- @param value number Computed
--- @return boolean
function activated(value)
    return value > 0.5
end

--- @param reseau Reseau
--- @param inputs number[]
function updateInputsRecomputeLinkToOutputs(reseau, inputs)
    -- 1st level: inputs
    for i, input in ipairs(inputs) do
        reseau.neuronsByLevel[1][i] = input
    end

    -- intermediates
    for c = 2, #reseau.neuronsByLevel do
        for n, neuron in ipairs(reseau.neuronsByLevel[c]) do
            local weightedSum = 0.0
            for p, previousNeuron in ipairs(reseau.neuronsByLevel[c - 1]) do
                local weight = reseau.weightsByLevel[c - 1][p][n]
                weightedSum = weightedSum + weight * (previousNeuron and 1 or 0)
            end
            reseau.neuronsByLevel[c][n] = activated(weightedSum)
        end
    end

    local outputs = {}
    for o, neuron in ipairs(reseau.neuronsByLevel[#reseau.neuronsByLevel]) do
        table.insert(outputs, neuron)
    end
    return outputs
end

--- @param individu Reseau
function determineInputsThenRecomputeNetworkThenDetermineOutputs(individu)
    local inputs = {}
    for i = 1, NB_INPUTS_SPRITES + NB_INPUTS_TILES do
        table.insert(inputs, false)
    end
    -- #1: sprites
    for _, sprite in ipairs(getSprites()) do
        local i = neuronIndexFromGridPosition({ x = sprite.x, y = sprite.y })
        inputs[i + 1] = true
    end
    -- #2: tiles
    for _, sprite in ipairs(getTiles()) do
        local i = NB_INPUTS_SPRITES + neuronIndexFromGridPosition({ x = sprite.x, y = sprite.y })
        inputs[i + 1 - 1--[[because append to existing]]] = true
    end

    local outputs = updateInputsRecomputeLinkToOutputs(individu, inputs)

    local newButtons = {}
    for o, enabled in ipairs(outputs) do
        newButtons[BUTTONS[o]] = enabled
    end
    newButtons.Right = true -- first version: all the way to the right
    joypad.set(newButtons, 1)
end

--- @return boolean
function niveauFini()
    return memory.readbyte(0x0100) == 12
end

--- @return number
function getMarioScore()
    return memory.read_u24_le(0x0f34)
end
--- 1 per digit
--- @return number
function getTimer()
    return memory.read_u8(0x0F31 + 0) * 100 + memory.read_u8(0x0F31 + 1) * 10 + memory.read_u8(0x0F31 + 2) * 1
end
function computeScore()
    local maxTime = 300
    local totalTime = maxTime - getTimer()
    if totalTime == maxTime then
        -- blocked
        return (0) + getMarioScore()
    else
        return totalTime + getMarioScore()
    end
end
function runDebugScore()
    savestate.load(NOM_SAVESTATE)
    local interval = 10
    local rep = 0
    while true do
        rep = rep + 1
        if rep % interval == 0 then
            console.log(getMarioScore())
            console.log(getTimer())
            console.log("=> " .. computeScore())
        end
        emu.frameadvance()
    end
end

--- @param individu Reseau
function play(individu)
    savestate.load(NOM_SAVESTATE)
    while true do
        determineInputsThenRecomputeNetworkThenDetermineOutputs(individu)
        drawReseau(individu)
        emu.frameadvance()
        if niveauFini() then
            return computeScore() -- TODO append time
        end
    end
end

function runIA()
    local population = firstRandomGeneration()
    for generation = 1, NB_GENERATIONS do
        console.log("Génération " .. generation .. "/" .. NB_GENERATIONS)
        local scoreByIndividu = {}
        for i, individu in ipairs(population) do
            local score = play(individu)
            console.log("> Individu " .. i .. "/" .. #population .. " with score " .. score)
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
elseif PROGRAM == "DEBUG SCORE" then
    runDebugScore()
end
