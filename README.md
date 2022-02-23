# MCA - Minecraft Computer Audio

You ever just spend 3 days working on an audio format for computers in a Minecraft mod?

Yeah, me neither.

## Specification

The full text of the specification is in `mca.md`. It should be mostly stable; outside of adding new formats as such formats pop up, and maybe adding compression methods as supporting them becomes viable, I don't see much of a reason to change too much about the format.

## Rationale

(a.k.a. "why the hell did you do this?")

ComputerCraft speakers (as of CC:Tweaked 1.100) can play signed 8-bit PCM audio at 48000Hz. There are many ways of encoding such audio; one such way is as raw bytes (two's complement), and another such way is DFPWM (the superior solution, cutting the filesize in 1/8th). There's just one problem:

How do you know what format your audio is in?

Sure, I can write my program to handle DFPWM, but maybe your program uses compression to reduce the file size. And maybe a third person's program uses an entirely different kind of compression. A file that loads in one of the three programs won't load in either of the others (it'll sound garbled, if it loads at all).

The solution? Spend 3 days writing the spec (and library) for a container format that only I will likely ever use.

Ugh.

## Code

The `cc` folder contains a ComputerCraft library (`mca.lua`) for loading MCA audio files. I'll write the docs for it later, but `mcaplay.lua` should give you a rough idea of how decoding works, and `testmca.lua` should give you a rough idea of how encoding works. (Also, there's functionality for handling custom data chunks; `mcainfo.lua` has you covered there).
