# MCA - Minecraft Computer Audio (v1.0)

The Minecraft Computer Audio format is designed for use in Minecraft Computer mods.

## Definitions

The Resource Interchange File Format (RIFF) is a tagged file structure developed for use on multimedia platforms. It is not a format in and of itself (the "interchange file format" in its name comes from a file format developed by EA, which used a similar structure to RIFF), but a structure that other file formats can use. MCA is one such format.

A FourCC is a sequence of four ASCII alphanumeric characters, padded on the right with blank characters (ASCII character value 32) as required, with no embedded blanks.

`ckID` and `ckSize` are commonly used in definitions of chunks to refer to the chunk ID and size as prescribed by the RIFF format.

## MCA Format

MCA files have a master RIFF chunk (refer to the RIFF specification) of type "MCA ". Data is stored in little-endian order.

|Field|Length (bytes)|Contents|
|-|-|-|
|ckID|4|"RIFF" FourCC|
|ckSize|4|4+*n*|
|type|4|"MCA " FourCC|
|Chunks|*n*|RIFF chunks containing format info and data|

## fmt Chunk

The `fmt` chunk describes the format of the data.

|Field|Length (bytes)|Contents|
|-|-|-|
|ckID|4|"fmt " FourCC|
|ckSize|4|The length of the chunk, 16 bytes|
|wFormat|2|A format code (see below)|
|nChannels|2|The number of channels contained within each frame|
|nSampleRate|4|Sample rate (in Hz; 48KHz is recommended)|
|nFrameSize|4|Size of frames (see below)|
|fFormatFlags|1|Format-specific flags/values.|
|bCompressionType|1|The type of compression used (see below)|
|*RESERVED*|2|Reserved for future use. Applications should set these bytes to 0.|

Applicable format codes are:

|Value|Name|Meaning|`fFormatFlags`|
|-|-|-|-|
|0000|`MCA_FORMAT_RAW_PCM`|Raw PCM data|Bit 7 details whether the data is signed (1=signed, 0=unsigned), bit 6 details whether the data is an integer or float (1=float, 0=integer), bits 5-0 are the number of bits per sample shift right 1 (0b000100 (0x04) refers to 8 bits)|
|0001|`MCA_FORMAT_DFPWM`|Dynamic Filter Pulse Width Modulation|Reserved (all bits set to 0)|

Frames are expressed in terms of samples, rather than bytes. `nSampleRate` samples is 1 second of audio. For example, ComputerCraft can handle a max frame size of `00020000` (131072 samples; ~2.7 seconds of 48KHz audio).

Compression can be used to lower the filesize. Applicable compression type codes are:

|Value|Name|Meaning|
|-|-|-|
|00|`MCA_COMPRESS_NULL`|No compression; data is simply raw data of the format specified.|
|01|`MCA_COMPRESS_DEFLATE`|The DEFLATE compression algorithm (used by zlib, gzip, ZIP files, etc.) is used; data will decompress into the format specified.|

Changing the number of channels used in the middle of an MCA file will result in undefined behavior.

## data Chunk

The data chunk contains the file data, as described in the `fmt` chunk. The `fmt` chunk preceding a `data` chunk is considered to describe that chunk (therefore, a file could theoretically contain data in multiple formats, although a naive MCA reader would just happily play through all of the formats it could in order of their inclusion in the file).

|Field|Length (in bytes)|Contents|
|-|-|-|
|ckID|4|"data" FourCC|
|ckSize|4|*n*|
|ckData|*n*|The data. May be compressed (`bCompressionType != 0x00`).|

## Example Structure of an MCA File

The following table describes the structure of an MCA file containing unsigned 8-bit mono PCM data at 48KHz (the native PCM format of ComputerCraft speakers). 131072*n* refers to the fact that the data chunk should contain some multiple of 131072 samples, since it claims to have a frame size of 131072 (This is only really important for MCA files with `nChannels`>1, since a mono channel ending early will just result in the audio ending early).

|Field|Length (in bytes)|Contents|
|-|-|-|
|ckID|4|"RIFF" FourCC|
|ckSize|4|4+24+8+131072*n*|
|type|4|"MCA " FourCC|
|ckID|4|"fmt " FourCC|
|ckSize|4|16|
|wFormat|2|0x00 (`MCA_FORMAT_RAW_PCM`)|
|nChannels|2|1|
|nSampleRate|4|48000|
|nFrameSize|4|131072|
|fFormatFlags|1|0b10000100 (signed, integer, 8 bits)|
|bCompressionType|1|0x00 (`MCA_COMPRESS_NULL`)|
|*RESERVED*|2|0000|
|ckID|4|"data" FourCC|
|ckSize|4|131072*n*|
|ckData|131072*n*|The data. Uncompressed, unsigned, integer, 8 bit mono PCM.|

## Streaming Mode

Streaming mode is a special use of the MCA format in which chunks are transmitted one-at-a-time over the wire (i.e; `fmt` and `data` chunks are sent one-to-a-packet without being contained in a larger MCA file). Streaming mode introduces a new client-to-server `cmd` packet (in comparison to the `fmt` and `data` chunks, which in this case are server-to-client).

To initiate streaming mode, a client should use a `cmd` packet to request the format from the streaming source. Then, if the client can understand the format the source is streaming in, it can tune into the source's stream. If the source does not respond to a `cmd` packet, it should be assumed that the source is offline.

On the source side, sources should respond to `cmd` packets that request the format with the `fmt` packet. This allows the stream to be composed entirely of `data` packets. However, should the source change the format in which it streams (which is highly discouraged), it should send a `fmt` packet in-stream so that all clients can adjust their settings accordingly. Furthermore, when changing songs streamed in DFPWM format, sources should send a `fmt` packet in-stream. This should signal clients to flush their decoders, allowing them to play the next song from a clean slate.

When a source ceases transmission for whatever reason, it should send a `data` packet of length 0. This signals to all clients that the stream is ending, and allows them to gracefully exit.

### cmd Packet/Chunk

The `cmd` packet is encoded as if it were a RIFF chunk, despite not being one.

|Field|Length (in bytes)|Contents|
|-|-|-|
|ckID|4|"cmd " FourCC|
|ckSize|4|*n*+1+*v*|
|sCommand|*n*+1|Null-terminated string. The command to execute.|
|argData|*v*|Any arguments to the command.|

The only command defined at present is "format", which requests the source to send back a `fmt` chunk describing the data it is currently transmitting. It takes no arguments (*v* = 0).

## Compliance

A compliant encoder should output files that fit the standard.

A source in streaming mode must respond to `cmd` packets sent to it with `sCommand` of "format" with a `fmt` chunk describing the data it is transmitting at that moment.

A compliant decoder should attempt to load any files that fit the standard.

If the decoder is incapable of loading the data described by the `fmt` chunk (i.e; a ComputerCraft decoder that cannot resample audio, being given an MCA file at a sample rate other than 48KHz), it should continue reading the file for a `fmt` chunk that will contain settings it can understand. If no such `fmt` chunk is found, then processing ends, and the end result is that no audio is played. However, in streaming mode, there is no end of the file. Therefore, compliant decoders should error when being given a format they cannot understand in streaming mode.

If the data contains more channels than can be played at once (i.e; a ComputerCraft decoder being given a stereo MCA file while only having one speaker attached), it is the responsibility of the compliant decoder to mix the channels accordingly (in this case, mixing the left and right channels into one mono channel that can be played). However, how these channels are mixed is also up to the decoder (and will typically depend on configuration).
