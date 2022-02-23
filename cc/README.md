This folder contains the ComputerCraft librar(ies) for loading MCA files. (Yes, all of them are needed/are used. In fact, there's an additional library you'll need to download for decompression that I haven't included here, but that one isn't required), as well as a program that extends the MCA decoder, a program that encodes a mono DFPWM file into an MCA file, and a program to play such a file.

The basic gist is:

 - `Blob.lua` - [not mine](https://github.com/25A0/blob), but used in the RIFF library for loading. Licensed under Unlicense.
 - `riff.lua` - mine. The decoding function is basically the example from the Blob README with a bugfix and some convenience features, but the encoding function is all mine. Useful for BMP (Microsoft's Device Independent Bitmap format), WAV (Microsoft's wave audio format), MCA (whaddaya know?), and any other file that starts with "RIFF". Licensed under CC0 (with a fallback to Unlicense if I need to).
 - `mca.lua` - mine. Features Decoder and Encoder objects that should (mostly) stick to spec. (If anything, they only diverge in tiny details like what a compliant encoder/decoder should put up with.) Licensed under MIT.
 - `mcainfo.lua` - mine. An example of how to extend MCA to understand data from chunks not otherwise implemented (in this case, the `INFO` LIST form type).
 - `mcaplay.lua` - mine. A short and sweet MCA player. Takes the filename of an MCA file as an argument, and plays said file.
 - `LibDeflate.lua` - [not included](https://gist.github.com/MineRobber9000/bdc3ce6c73b32cb1e4a56817eb392222). Required for Deflate compression/decompression. (Note that the version linked is not the original; I took some of the functions out for space saving purposes (and then used a minifier to save even more space). The original can be found [here](https://github.com/SafeteeWoW/LibDeflate).) Licensed under zlib license.

`bach.dfpwm` is a DFPWM file containing a recording of Bach's Bradenburg Concerto No 3, 1st movement, Allegro. The original recording was of a performance of the piece by the Advent Chamber Orchestra, licensed under the EFF Open Audio License/CC BY-SA 2.0. As such, `bach.dfpwm` (and the MCA file that results from running `testmca.lua` over it) are similarly licensed under CC BY-SA.
