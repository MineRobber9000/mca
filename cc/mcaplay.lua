local mca = require"mca"
require"mcainfo"

local file = ...
local speaker = peripheral.find("speaker")

-- wait for an event to occur
function waitFor(filter)
    local event
    repeat
        event = {os.pullEventRaw()}
    until event[1]==filter or event[1]=="terminate"
    if event[1]=="terminate" then
        speaker.stop()
        term.clear()
        term.setCursorPos(1,1)
        error("",0)
    end
end

-- use a streaming decoder
-- as opposed to the monolithic decoder exposed by Decoder.parse_file
local decoder = mca.Decoder.spawn()

-- load the file into chunks
local chunks = mca.parse_mca_file(file).nested

local playing = false
for i=1,#chunks do
    local output = decoder:handle_chunk(chunks[i])
    if #output>0 then
        -- #output is how many speakers we think we have
        -- this program only uses 1 speaker
        -- the full version of this program will eventually
        -- either find more speakers or mix the audio down
        -- but for the sake of demonstrating playing a
        -- mono audio file, this'll do
        for j=1,#output[1] do
            if playing then waitFor("speaker_audio_empty") end
            playing = true
            speaker.playAudio(output[1][j])
        end
    end
    if output.contains_info then
        term.clear()
        term.setCursorPos(1,1)
        if output.title then print("Title: "..output.title) end
        if output.artist then print("Artist: "..output.artist) end
        for i, v in pairs(output) do
            -- not easily displayable info
            if i=="contains_info" or i=="undefined" then
                -- already shown (vvvv)
            elseif i=="title" or i=="artist" then
            else
                print(i:gsub("_"," "):gsub("%a+",function(s) return s:sub(1,1):upper()..s:sub(2) end)..": "..v)
            end
        end
    end
end
