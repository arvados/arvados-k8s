#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool

baseCommand: md5sum
inputs:
  inputfile:
    type: File
    inputBinding:
      position: 1
  outputname:
    type: string

stdout: $(inputs.outputname)

outputs:
  hasher_out:
    type: File
    outputBinding:
      glob: $(inputs.outputname)
