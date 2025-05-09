# Package information
packageName = "SeqFu"
version     = "2.0.0"
author      = "Andrea Telatin"
description = "Bioinformatics toolkit to manipulate, summarise and interact with FASTQ and FASTA files"
license     = "MIT"

# Dependencies
requires "nim >= 1.6.0", 
  "readfx#head",
  "docopt#v0.7.1",
  "colorize",
  "malebolgia"

# Binaries
srcDir = "src"
binDir = "bin"
namedBin = {
    "main":          "seqfu",
}.toTable()

# Skip directories that aren't part of the package
skipDirs = @["tests"]


task buildbin, "Build all binaries to bin/ directory":
    exec "mkdir -p bin"

