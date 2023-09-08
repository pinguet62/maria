-- Program parameters
NOM_SAVESTATE = "C:/Users/10131571/Documents/maria/Super Mario World (Europe) (Rev 1).Snes9x.QuickSave1.State"
NB_INDIVIDU_POPULATION = 5

-- states
laPopulation = {}

-- configuration
lesBoutons = { "A", "B", "X", "Y", "Up", "Down", "Left", "Right", }
-- size: #(lesBoutons)

function newReseau()
    return {}
end

function newPopulation()
    population = {}
    for i = 0, NB_INDIVIDU_POPULATION do
        table.insert(population, newReseau())
    end
    return population
end

function updateOutput()
    -- random
    --newButtons = {}
    --for i, k in ipairs(lesBoutons) do
    --    newButtons[k] = ({ true, false })[math.random(1, 2)]
    --end

    newButtons = { Right = true }

    joypad.set(newButtons, 1)
    emu.frameadvance()
end

function startLevel()
    savestate.load(NOM_SAVESTATE)
end

function niveauFini()
    return memory.readbyte(0x0100) == 12
end

function getScore()
    return math.random(0, 100)
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
console.log("Starting...")
for generation = 1, 5 do
    console.log("Génération " .. generation)
    population = newPopulation()
    for i, individu in ipairs(population) do
        console.log("\tIndividu " .. i)
        startLevel()
        score = play()
        console.log("\t\tScore " .. score)
    end
end
