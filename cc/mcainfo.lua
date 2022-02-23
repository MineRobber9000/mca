-- Implements INFO chunk decoding/encoding for MCA files

local mca = require"mca"

local chunkIDToHumanName = {
    IART = "artist",
    INAM = "title",
    IGNR = "genre",
    IKEY = "keywords"
}

local humanNameToChunkID = {}
for i, v in pairs(chunkIDToHumanName) do
    humanNameToChunkID[v]=i
end

mca.Decoder.custom.INFO=function(dc, chk)
    local ret = {contains_info=true}
    -- any INFO sub-chunk we don't understand gets its last reported
    -- value dumped here
    ret.undefined = {}
    -- parse each chunk within and update ret as required
    -- ret is what gets returned as the frame
    for i=1,#chk.nested do
        local ichk = chk.nested[i]
        if chunkIDToHumanName[ichk.id] then
            ret[chunkIDToHumanName[ichk.id]]=ichk.content:zerostring()
        else
            ret.undefined[ichk.id]=ichk.content:zerostring()
        end
    end
    return ret
end

local function encode_arb_chunk(fourcc,rawdata)
    return string.pack("c4I4",fourcc,#rawdata)..rawdata
end

mca.Encoder.custom.info=function(ec, tbl)
    local ret = {}
    for i, v in pairs(tbl) do
        if humanNameToChunkID[i] then
            table.insert(ret,encode_arb_chunk(humanNameToChunkID[i],string.pack("z",v)))
        elseif i=="undefined" then
            for j, v2 in pairs(v) do
                table.insert(ret,encode_arb_chunk(j,string.pack("z",v2)))
            end
        elseif #i==4 and i==i:upper() then
            table.insert(ret,encode_arb_chunk(i,string.pack("z",v)))
        elseif i=="contains_info" then -- someone passed the decoded info back in, ignore it
        else
            error("Unknown chunk type "..i,3)
        end
    end
    if #ret>0 then
        local buffer = ""
        for i=1,#ret do
            buffer=buffer..ret[i]
            if (#buffer%2)==1 then buffer=buffer..string.char(0) end
        end
        return encode_arb_chunk("LIST","INFO"..buffer)
    end
end
