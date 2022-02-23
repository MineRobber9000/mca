local mca=require"mca"
local Blob=require"Blob"

print("Recipe for MCA file")
print("1. Spawn encoder")
ec = mca.Encoder.spawn()
fmt=ec:config_audio(mca.MCA_FORMAT_DFPWM,1,48000,128*1024,0,mca.MCA_COMPRESS_NULL)
ec.chunks = {}
-- Decoder to the same parameters
print("2. Spawn decoder (not necessary but I don't feel like writing a DFPWM decoding loop)")
dc = mca.Decoder.spawn()
print("3. Load a format chunk into decoder so it'll decode the DFPWM file")
dc:parse_chunk(Blob.new(fmt))
-- throw us a curveball and actually convince the encoder we're
-- using compression
print("4. Setup encoder for mono DFPWM with deflate compression")
fmt=ec:config_audio(mca.MCA_FORMAT_DFPWM,1,48000,128*1024,0,mca.MCA_COMPRESS_DEFLATE)
-- add info chunk
print("5. Add info chunk (not necessary but it's neat)")
require"mcainfo"
info=ec:encode_info{title="Bradenburg Concerto No. 3, 1st movement, Allegro",artist="Johann Sebastian Bach",genre="classical"}
--sleep()
-- Force feed dc a mono DFPWM file
print("6. Load DFPWM file into memory")
fh = fs.open("bach.dfpwm","rb")
s = fh.readAll()
fh.close()
-- might want a sleep before this bit
sleep()
print("7. Trick decoder into decoding DFPWM for us")
chk = string.pack("c4I4","data",#s)..s
frame = dc:parse_chunk(Blob.new(chk))
print(5)
-- definitely need a sleep before this bit
sleep()
-- Pass this frame into the encoder to re-encode it
print("8. Re-encode audio smartly (so we can load it one chunk at a time)")
ec:encode_audio_smart(frame)
print(6)
--sleep()
-- now output the whole thing to file
print("9. Output MCA file to taste!")
fh = fs.open("bach.mca","wb")
fh.write(ec:output())
fh.close()
