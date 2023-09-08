-- Program parameters
NOM_SAVESTATE = "C:/Users/10131571/Documents/maria/Super Mario World (Europe) (Rev 1).Snes9x.QuickSave1.State"
NB_GENERATIONS = 1
NB_INDIVIDU_POPULATION = 1

-- Réseau parameters

-- configuration
lesBoutons = {
    "A", -- saute en tournant
    --"B", -- saute
    --"X", -- ?
    --"Y", -- ?
    --"Up", -- regarde en l'air ?
    --"Down",
    --"Left",
    "Right",
}
-- size: #(lesBoutons)

function displaySprites()
    local cameraX = memory.readbyte(0x001a)
    local cameraY = memory.readbyte(0x001c)

    local sprites = {}
    for i = 0, 12 - 1 do
        local stat = memory.readbyte(0x14c8 + i)
        if stat ~= 0 then
            local spriteX = memory.readbyte(0x14e0 + i) * 256 + memory.readbyte(0x00e4 + i)
            local spriteY = memory.readbyte(0x14d4 + i) * 256 + memory.readbyte(0x00d8 + i)

            local cameraSpriteX = spriteX - cameraX
            local cameraSpriteY = spriteY - cameraY

            if cameraSpriteX < 256 and cameraSpriteY < 256 then
                local sprite = { x = cameraSpriteX, y = cameraSpriteY }
                gui.drawBox(sprite.x - 1, sprite.y - 1, sprite.x + 1, sprite.y + 1, "blue", "blue")
                table.insert(sprites, sprite)
            end
        end
    end
    console.log(#sprites)
end

function printPopulation(population)
    for i, individu in ipairs(population) do
        printIndividu(individu)
    end
end

function printIndividu(individu)
    console.log("\t" .. individu.weight)
end

function mutateIndividu(individu)
    -- TODO
    return individu
end

-- Crée la nouvelle basée sur la mutation du #1 avec les N suivants
function nextGeneration(previousGeneration, scoreByIndividu)
    -- TODO

    table.sort(scoreByIndividu, function(a, b)
        return a.score < b.score
    end)
    local betterIndividu = scoreByIndividu[1].individu
    console.log("")

    for i = 0, NB_INDIVIDU_POPULATION do
        local individu = betterIndividu
        individu = mutateIndividu(individu)
        table.insert(population, individu)
    end

    return previousGeneration
end

function newIndividuReseau()
    return { weight = "bar" }
end

function generationInitiale()
    local population = {}
    for i = 0, NB_INDIVIDU_POPULATION do
        local individu = newIndividuReseau()
        individu = mutateIndividu(individu)
        table.insert(population, individu)
    end
    return population
end

function updateOutput()
    -- --random
    --newButtons = {}
    --for i, k in ipairs(lesBoutons) do
    --    newButtons[k] = ({ true, false })[math.random(1, 2)]
    --end

    newButtons = { Right = true }

    displaySprites()

    joypad.set(newButtons, 1)
    emu.frameadvance()
end

function startLevel()
    savestate.load(NOM_SAVESTATE)
end

function niveauFini()
    --return true
    return memory.readbyte(0x0100) == 12
end

function getScore()
    return math.random(0, 20)
end

function play()
    while true do
        updateOutput()
        if niveauFini() then
            return getScore()
        end
    end
end

console.clear()
gui.clearGraphics()
console.log("Starting...")

local population = generationInitiale()
for generation = 1, NB_GENERATIONS do
    console.log("Génération " .. generation)
    printPopulation(population)
    local scoreByIndividu = {}
    for i, individu in ipairs(population) do
        --console.log("\tIndividu " .. i)
        startLevel()
        local score = play()
        table.insert(scoreByIndividu, { individu = individu, score = score })
        --console.log("\t\tScore " .. score)
    end

    population = nextGeneration(population, scoreByIndividu)
end
