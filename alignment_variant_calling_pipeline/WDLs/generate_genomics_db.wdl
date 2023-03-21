version 1.0

workflow t2t_genomics_db {
    input {
        String filePath
        String interval
        String chromosome
        Int marginedStart
        Int marginedEnd
        String regionType
    }

    call generateGenomicsDB {
        input:
            filePath = filePath,
            interval = interval,
            chromosome = chromosome,
            start = marginedStart,
            end = marginedEnd,
            regionType = regionType
    }

    output {
        File genomicsDBtar = generateGenomicsDB.genomicsDB
    }
}

task generateGenomicsDB {
    input {
        String filePath
        String interval
        String chromosome
        Int start
        Int end
        String regionType
    }

    String sampleMapName = if chromosome != "chrX" then chromosome else (if regionType == "PAR1" then "chrX_PAR" else (if regionType == "PAR2" then "chrX_PAR" else "chrX_non_PAR"))

    command <<<
        gatk \
            --java-options "-Xmx32G -XX:+UseParallelGC -XX:ParallelGCThreads=$(nproc) -Djava.io.tmpdir=/dev/shm" \
            GenomicsDBImport \
            --sample-name-map "~{filePath}/~{sampleMapName}_sample_map.tsv" \
            --genomicsdb-workspace-path "./~{interval}" \
            --reader-threads $(nproc) \
            -L "~{chromosome}:~{start}-~{end}" \
            --batch-size 50
        
        tar -cf "~{interval}.tar" "./~{interval}"
    >>>

    runtime {
        docker : "szarate/t2t_variants"
        disks : "local-disk 100 SSD"
        memory: "32G"
        cpu : 4
        preemptible: 3
        maxRetries: 3
    }

    output {
        File genomicsDB = "~{interval}.tar"
    }
}