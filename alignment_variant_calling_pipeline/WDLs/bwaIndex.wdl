version 1.0

workflow bwa_index {
    input {
        File fasta
    }

    call bwaIndex {
        input:
            fasta = fasta
    }

    output {
        File bwa_index = bwaIndex.bwa_index
    }

}

task bwaIndex {
    input {
        File fasta
    }

    String fastaName='~{basename(fasta)}'

    String tmp='~{basename(fasta,".fasta")}'
    String outputName='~{basename(tmp,".fa")}'

    command <<<
        cp "~{fasta}" .
        bwa index "./~{fastaName}"

        rm "./~{fastaName}"

        tar -czvf "~{outputName}.tar.gz" *fa*
    >>>

    Int diskGb = ceil(10.0 * size(fasta, "G"))

    runtime {
        docker : "szarate/t2t_variants"
        disks : "local-disk ${diskGb} SSD"
        memory: "12G"
        cpu : 24
    }

    output {
        File bwa_index = "~{outputName}.tar.gz"
    }
}
