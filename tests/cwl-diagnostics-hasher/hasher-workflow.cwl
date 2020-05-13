#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow

$namespaces:
  arv: "http://arvados.org/cwl#"
  cwltool: "http://commonwl.org/cwltool#"

inputs:
  inputfile: File
  hasher1_outputname: string
  hasher2_outputname: string
  hasher3_outputname: string

outputs:
  hasher_out:
    type: File
    outputSource: hasher3/hasher_out

hints:
  arv:ReuseRequirement:
    enableReuse: false

steps:
  hasher1:
    run: hasher.cwl
    in:
      inputfile: inputfile
      outputname: hasher1_outputname
    out: [hasher_out]
    hints:
      arv:IntermediateOutput:
        outputTTL: 3600

  hasher2:
    run: hasher.cwl
    in:
      inputfile: hasher1/hasher_out
      outputname: hasher2_outputname
    out: [hasher_out]
    hints:
      arv:IntermediateOutput:
        outputTTL: 3600

  hasher3:
    run: hasher.cwl
    in:
      inputfile: hasher2/hasher_out
      outputname: hasher3_outputname
    out: [hasher_out]
    hints:
      arv:IntermediateOutput:
        outputTTL: 3600

