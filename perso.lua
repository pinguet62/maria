-- Program parameters
NOM_SAVESTATE = "C:/Users/10131571/Documents/maria/Super Mario World (Europe) (Rev 1).Snes9x.QuickSave1.State"
NB_INDIVIDU_POPULATION = 5

-- states
laPopulation = {}

-- configuration
lesBoutons = { "A", "B", "X", "Y", "Up", "Down", "Left", "Right", }
-- size: #(lesBoutons)

function startLevel()
    savestate.load(NOM_SAVESTATE)
end

console.clear()
console.log("Starting...")
startLevel()

function randomButtons()
    newButtons = {}
    for i, k in ipairs(lesBoutons) do
        newButtons[k] = ({ true, false })[math.random(1, 2)]
    end
    return newButtons
end

while true do
    joypad.set(randomButtons(), 1)
    emu.frameadvance()
end
