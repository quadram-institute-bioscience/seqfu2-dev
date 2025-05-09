#[
    SeqFu 2.0 dev - a FASTQ and FASTA files bioinformatics toolkit
    Author: Andrea Telatin and the Core Bioinformatics team at the Quadram Institute Bioscience

    Copyright (C) 2025 Quadram Institute Bioscience
    
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or   
    (at your option) any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of  
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
    GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

]#
import os
import sequtils
import strutils
import tables
import algorithm
import docopt
import colorize
 

# Suite Version
import ./seqfu_version
import ./seqfu_utils

# Subprograms
include ./count_mod
 
var progs = {

       "count": fastx_count
}.toTable

proc main(args: var seq[string]): int =
  
  var 
    helps = {  "interleave [ilv]"  :  "interleave FASTQ pair ends",
               "deinterleave [dei]": "deinterleave FASTQ",
               "derep [der]"       : "feature-rich dereplication of FASTA/FASTQ files",
               "check"             : "check FASTQ file for errors",
               "bases"             : "count bases in FASTA/FASTQ files",
#              "merge [mrg]"       : "join Paired End reads",
               "count [cnt]"       : "count FASTA/FASTQ reads, pair-end aware",
               "lanes [mrl]"       : "merge Illumina lanes",
               "stats [st]"        : "statistics on sequence lengths",
               "rotate [rot]"      : "rotate a sequence with a new start position",
               "sort [srt]"        : "sort sequences by size (uniques)",
               "metadata [met]"    : "print a table of FASTQ reads (mapping files)",
               "list [lst]"        : "print sequences from a list of names",
               }.toTable

    helps_last = {"cat"            : "concatenate FASTA/FASTQ files",
                  "head"           : "print first sequences",
                  "tail"           : "view last sequences",
                  "grep"           : "select sequences with patterns",
                  "rc"             : "reverse complement strings or files",
                  "tab"            : "tabulate reads to TSV (and viceversa)",
                  "view"           : "view sequences with colored quality and oligo matches",
               }.toTable

  if len(args) == 1 and (args[0] == "--version" or args[0] == "version" or args[0] == "-v"):
    # If the first argument is either --version or version or -v, print the version
    echo(version())
    0
  elif len(args) == 1 and (args[0] == "--cite" or args[0] == "cite" or args[0] == "--citation" or args[0] == "citation"):
    echo "SeqFu ", version()
    echo "--------------------------------------------------------------------------------------------"
    echo "Telatin A, Fariselli P, Birolo G."
    echo "SeqFu: A Suite of Utilities for the Robust and Reproducible Manipulation of Sequence Files."
    echo "Bioengineering 2021, 8, 59. doi.org/10.3390/bioengineering8050059"
    echo ""
    echo "Repository:    https://github.com/telatin/seqfu2"
    echo "Documentation: https://telatin.github.io/seqfu2"
    0
  elif len(args) < 1 or not progs.contains(args[0]):
    # If the first argument is not a valid subprogram, print the help
    # No arguments: print help
    var 
      hkeys1 = toSeq(keys(helps))
      hkeys2 = toSeq(keys(helps_last))
      
    sort(hkeys1, proc(a, b: string): int =
      if a < b: return -1
      else: return 1
      )
    sort(hkeys2, proc(a, b: string): int =
      if a < b: return -1
      else: return 1
      )
    echo format("SeqFu $# - FASTX Tools\n", version())
    echo """
      ____             _____      
     / ___|  ___  __ _|  ___|   _ 
     \___ \ / _ \/ _` | |_ | | | |
      ___) |  __/ (_| |  _|| |_| |
     |____/ \___|\__, |_|   \__,_|
                    |_|           """.fgGreen
    for k in hkeys1:
      echo "  ", format("· $1: $2", k & repeat(" ", 20 - len(k)), helps[k])
    echo ""
    for k in hkeys2:
      echo "  ", format("· $1: $2", k & repeat(" ", 20 - len(k)), helps_last[k])
    
    
    echo "\nType 'seqfu version' or 'seqfu cite' to print the version and paper, respectively.\nAdd --help after each command to print its usage."
    if len(args) > 0 and args[0] != "--help":
      echo "Unknown subprogram: ", args[0]
      1
    else:
      0
  else:
    # If the first argument is a valid subprogram, run it
    # with its arguments
    var
      programName = args[0]
      pargs = args[1 .. ^1]
    progs[programName](pargs)

when isMainModule:
  try:
    main_helper(main)
  except IOError:
    stderr.writeLine("Quitting...")
    quit(0)
  
