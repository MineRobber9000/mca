--[[
mca.lua v1.0.0
by Robert "khuxkm/minerobber" Miles

Licensed under MIT.

The MIT License (MIT)

Copyright © 2022 Robert 'khuxkm' Miles, https://khuxkm.tilde.team <khuxkm@tilde.team>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]
local riff = require"riff"
local dfpwm = require"cc.audio.dfpwm"

-- small utility function used here
local function saferequire(s)
    local ok, lib = pcall(function() return require(s) end)
    if ok then return lib end
end

-- start with the decoder because that's likely going to
-- be easiest (just interface with the Blob)

local Decoder = {}

local MCA_FORMAT_RAW_PCM = 0
local MCA_FORMAT_DFPWM = 1
local MCA_COMPRESS_NULL = 0

-- Format handling
Decoder.format = {}
-- Raw PCM handler (currently only handles signed 8-bit PCM)
Decoder.format[MCA_FORMAT_RAW_PCM] = function(dc, s)
    local output = {}
    for i=1,dc.nChannels do
        output[i]={}
    end
    -- we only currently handle signed 8-bit PCM
    if dc.fFormatFlags~=132 then
        for i=1,math.floor(#s/dc.nFrameSize/dc.nChannels) do
            for j=1,dc.nChannels do
                table.insert(output[j],0)
            end
        end
        return output
    end
    local channel = 0
    local data
    while #s>=dc.nFrameSize do
        data, s = s:sub(1,dc.nFrameSize), s:sub(dc.nFrameSize+1)
        local p = {}
        for i=1,#data do
            c = string.byte(data:sub(i,i))
            if bit32.band(c,128)>0 then -- convert to two's complement signed
                c = -1*bit32.bxor(c-1,255)
            end
            table.insert(p,c)
        end
        table.insert(output[channel+1],p)
        channel = (channel+1)%dc.nChannels
    end
    if #s>0 then
        assert(dc.nChannels==1,"data chunk ends before it should!")
        local p = {}
        for i=1,#s do
            c = string.byte(s:sub(i,i))
            if bit32.band(c,128)>0 then
                c = -1*bit32.bxor(c-1,255)
            end
            table.insert(p,c)
        end
        table.insert(output[channel+1],p)
    end
    return output
end
-- DFPWM format
Decoder.format[MCA_FORMAT_DFPWM] = function(dc,s)
    local output = {}
    for i=1,dc.nChannels do
        output[i]={}
    end
    if not dc.dfpwm then
        dc.dfpwm = {}
        for i=1,dc.nChannels do
            dc.dfpwm[i]=dfpwm.make_decoder()
        end
    end
    local fs = math.floor(dc.nFrameSize/8)
    local channel = 0
    local data
    -- this is a little more complicated
    while #s>=fs do
        -- note the change in criteria above; DFPWM encodes 8 samples in 1 byte
        data, s = s:sub(1,fs), s:sub(fs+1)
        local p = dc.dfpwm[channel+1](data)
        assert(#p==dc.nFrameSize)
        table.insert(output[channel+1],p)
        channel=(channel+1)%dc.nChannels
    end
    if #s>0 then
        assert(dc.nChannels==1,"data chunk ends before it should!")
        table.insert(output[channel+1],dc.dfpwm[channel+1](s))
    end
    return output
end

-- Compression handlers
Decoder.compression = {}
-- Null compression (no compression)
Decoder.compression[MCA_COMPRESS_NULL] = function(dc,s) return s end

-- Custom chunk handlers
-- Allows you to decode more than just fmt, data, and cmd
-- Functions are passed the decoder object and the chunk
-- Whatever they return (customarily a table with attributes set) is
-- sent to the consumer.
Decoder.custom = setmetatable({},{__index=function() return function(dc,chk) return {unknown_chunk=chk} end end})

Decoder.empty_audio_chunk = function(dc)
    local output = {}
    for i=1,dc.nChannels do
        output[i]={}
    end
    return output
end

Decoder.handle_chunk = function (dc, chk)
    if chk.id=="fmt " then
        local wFormat = chk.content:uint16()
        local nChannels = chk.content:uint16()
        local nSampleRate = chk.content:uint32()
        local nFrameSize = chk.content:uint32()
        local fFormatFlags = chk.content:uint8()
        local bCompressionType = chk.content:uint8()
        local reserved = chk.content:word()
        dc.wFormat = wFormat
        if wFormat==MCA_FORMAT_DFPWM then
            dc.dfpwm = nil
        end
        dc.nChannels = nChannels
        dc.nSampleRate = nSampleRate
        dc.nFrameSize = nFrameSize
        dc.fFormatFlags = fFormatFlags
        dc.bCompressionType = bCompressionType
        return {wFormat=wFormat,nChannels=nChannels,nSampleRate=nSampleRate,nFrameSize=nFrameSize,fFormatFlags=fFormatFlags,bCompressionType=bCompressionType,reserved=reserved}
    elseif chk.id=="data" then
        assert(dc.wFormat and dc.bCompressionType and dc.nFrameSize,"MCA file missing fmt chunk!")
        if (not Decoder.compression[dc.bCompressionType]) or (not Decoder.format[dc.wFormat]) then
            return dc:empty_audio_chunk()
        end
        local decompressed = Decoder.compression[dc.bCompressionType](dc,chk.raw)
        if not decompressed then
            return dc:empty_audio_chunk()
        end
        return Decoder.format[dc.wFormat](dc,decompressed)
    elseif chk.id=="cmd " then
        local command = chk.content:zerostring()
        return {command=command,data=chk.content}
    else
        -- prefer form type over chunk id
        -- since if the chunk has a form type it's a RIFF or LIST
        -- which is ambiguous anyways
        return Decoder.custom[(chk.form_type and chk.form_type or chk.id)](dc, chk)
    end
end

Decoder.parse_chunk = function (dc,chk)
    return dc:handle_chunk(riff.parse_chunk(chk))
end

Decoder.spawn = function ()
    return setmetatable({},{__index=function(t,k)
        return Decoder[k]
    end})
end

Decoder.parse_file = function(f)
    local dc = Decoder.spawn()
    local chunks = riff.parse_riff_file(f,"MCA ","MCA decoder cannot parse non-MCA file!")
    for i=1,#riff.nested do
        local out = dc:handle_chunk(riff.nested[i])
        if #out>0 then table.insert(chunks,out) end
    end
    local frames
    if #chunks>1 then
        frames = {}
        for i=1,#chunks[1] do frames[i]={} end
        for i=1,#chunks do
            local chunk = chunks[i]
            for j=1,#frames do
                for k=1,#chunk[j] do
                    table.insert(frames[j],chunk[j][k])
                end
            end
        end
    else
        frames = chunks[1]
    end
    if close_fh then fh.close() end
    return frames
end

-- now for the encoder, which will be... harder, to say the least

local Encoder = {}

-- Format handling
Encoder.format = {}
local function common(ec,aud)
    assert(#aud==ec.nChannels,"encoder mismatch (make sure the encoder is set to the same number of channels you're feeding it)")
    local max=0
    for i=1,ec.nChannels do
        if #aud[i]>max then max=#aud[i] end
        for j=1,#aud[i] do
            while #aud[i][j]<ec.nFrameSize do
                table.insert(aud[i][j],0)
            end
        end
    end
    local emptyFrame = setmetatable({},{__index=function(t,k) if k<1 or k>ec.nFrameSize then return nil end return 0 end,__len=function() return ec.nFrameSize end})
    for i=1,ec.nChannels do
        while #aud[i]<max do
            table.insert(aud[i],emptyFrame)
        end
    end
    return aud
end
Encoder.format[MCA_FORMAT_RAW_PCM] = function(ec,aud)
    aud = common(ec,aud)
    local buffer = ""
    for i=1,#aud[1] do
        for j=1,ec.nChannels do
            local b = ""
            for k=1,#aud[j][i] do
                b=b..string.pack(aud[j][i][k])
            end
            buffer=buffer..b
        end
    end
    return buffer
end
Encoder.format[MCA_FORMAT_DFPWM] = function(ec,aud)
    aud = common(ec,aud)
    if not ec.dfpwm then
        ec.dfpwm={}
        for i=1,ec.nChannels do
            ec.dfpwm[i]=dfpwm.make_encoder()
        end
    end
    local buffer = ""
    for i=1,#aud[1] do
        for j=1,ec.nChannels do
            buffer=buffer..ec.dfpwm[j](aud[j][i])
        end
    end
    return buffer
end

-- Compression handlers
Encoder.compression = {}
-- Null compression (no compression)
Encoder.compression[MCA_COMPRESS_NULL] = function(ec, s) return s end

-- Custom chunk handling
-- An analogue to the Decoder feature of the same name
-- Functions are passed the encoder object and all other arguments
-- If they return a string it's saved in the encoder as a chunk
Encoder.custom = {}

Encoder.config_audio = function(ec, wFormat, nChannels, nSampleRate, nFrameSize, fFormatFlags, bCompressionType)
    if not ec.chunks then ec.chunks={} end
    table.insert(ec.chunks,riff.encode_chunk("fmt ",string.pack("I2I2I4I4I1I1I2",wFormat,nChannels,nSampleRate,nFrameSize,fFormatFlags,bCompressionType,0)))
    ec.wFormat = wFormat
    if ec.wFormat == MCA_FORMAT_DFPWM then
        ec.dfpwm = nil
    end
    ec.nChannels = nChannels
    ec.nSampleRate = nSampleRate
    ec.nFrameSize = nFrameSize
    ec.fFormatFlags = fFormatFlags
    ec.bCompressionType = bCompressionType
    return ec.chunks[#ec.chunks]
end

Encoder.encode_audio = function(ec, aud)
    if not ec.chunks then ec.chunks={} end
    table.insert(ec.chunks,riff.encode_chunk("data",Encoder.compression[ec.bCompressionType](ec,Encoder.format[ec.wFormat](ec,aud))))
    return ec.chunks[#ec.chunks]
end

-- Like encode_audio, but encode one frame per chunk
-- Which allows for faster "streaming" decode later
Encoder.encode_audio_smart = function(ec,aud)
    aud = common(ec,aud) -- treat this almost like we treat encoding
    for i=1,#aud[1] do
        local frame = {}
        for j=1,#aud do
            frame[j]={aud[j][i]}
        end
        ec:encode_audio(frame)
    end
end

Encoder.output = function(ec)
    return riff.encode_riff_or_list("RIFF","MCA ",ec.chunks)
end

Encoder.spawn = function()
    return setmetatable({},{__index=function(t,k)
        if not Encoder[k] and k:find("encode_",1,1)==1 and Encoder.custom[k:sub(8)] then
            return function(ec, ...)
                if not ec.chunks then ec.chunks={} end
                local ret = Encoder.custom[k:sub(8)](ec, ...)
                if ret and type(ret)=="string" then table.insert(ec.chunks,ret) return ret end
            end
        end
        return Encoder[k]
    end})
end

Encoder.to_file = function(f, aud, wFormat, nChannels, nSampleRate, nFrameSize, fFormatFlags, bCompressionType)
    wFormat = wFormat or MCA_FORMAT_RAW_PCM
    nChannels = nChannels or #aud
    nSampleRate = nSampleRate or 48000
    nFrameRate = nFrameRate or 131072
    fFormatFlags = fFormatFlags or (wFormat==MCA_FORMAT_RAW_PCM and 132 or 0)
    bCompressionType = bCompressionType or 0
    local ec = Encoder.spawn()
    ec:config_audio(wFormat,nChannels,nSampleRate,nFrameRate,fFormatFlags,bCompressionType)
    ec:encode_audio(aud)
    riff.encode_riff_file(f,"MCA ",ec.chunks)
end

local exports = {
    Decoder = Decoder,
    Encoder = Encoder,

    -- expose parse_mca_file as an alias of parse_riff_file with form type and error preset
    parse_mca_file = function(f) return riff.parse_riff_file(f,"MCA ","MCA decoder cannot parse non-MCA file!") end,

    MCA_FORMAT_RAW_PCM = MCA_FORMAT_RAW_PCM,
    MCA_FORMAT_DFPWM = MCA_FORMAT_DFPWM,
    MCA_COMPRESS_NULL = MCA_COMPRESS_NULL
}

-- BEFORE WE RETURN THE EXPORTS...
-- Deflate support, if we have the LibDeflate to do so
local LibDeflate = saferequire"LibDeflate"
if LibDeflate then
    local MCA_COMPRESS_DEFLATE = 1
    exports.MCA_COMPRESS_DEFLATE = MCA_COMPRESS_DEFLATE
    Decoder.compression[MCA_COMPRESS_DEFLATE] = function(dc, s)
        local decompressed = LibDeflate:DecompressDeflate(s)
        return decompressed
    end
    Encoder.compression[MCA_COMPRESS_DEFLATE] = function(ec, s)
        local compressed = LibDeflate:CompressDeflate(s)
        return compressed
    end
end

return exports
