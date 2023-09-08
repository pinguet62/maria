-- Program parameters
NOM_SAVESTATE = "C:/Users/10131571/Documents/maria/Super Mario World (Europe) (Rev 1).Snes9x.QuickSave1.State"
NB_INDIVIDU_POPULATION = 5

-- states
laPopulation = {}

-- configuration
lesBoutons = { "A", "B", "X", "Y", "Up", "Down", "Left", "Right", }
-- size: #(lesBoutons)

function mutateIndividu(individu)
    return individu
end

-- Crée la nouvelle basée sur la mutation du #1 avec les N suivants
function nextGeneration(previousGeneration, scoreByIndividu)
    table.sort(scoreByIndividu, function(a, b)
        return a.score < b.score
    end)
    betterIndividu = scoreByIndividu[1].individu

    for i = 0, NB_INDIVIDU_POPULATION do
        individu = betterIndividu
        individu = mutateIndividu(individu)
        table.insert(population, individu)
    end
end

function newIndividuReseau()
    return { foo = "bar" }
end

function generationInitiale()
    population = {}
    for i = 0, NB_INDIVIDU_POPULATION do
        individu = newIndividuReseau()
        individu = mutateIndividu(individu)
        table.insert(population, individu)
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
    return true
    --return memory.readbyte(0x0100) == 12
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
console.log("Starting...")

population = generationInitiale()
for generation = 1, 1 do
    console.log("Génération " .. generation)
    scoreByIndividu = {}
    for i, individu in ipairs(population) do
        console.log("\tIndividu " .. i)
        startLevel()
        score = play()
        table.insert(scoreByIndividu, { individu = individu, score = score })
        console.log("\t\tScore " .. score)
    end

    population = nextGeneration(population, scoreByIndividu)
end
