# T2T-CHM13v2.0 Alignment and Variant Calling Pipeline

This directory contains the workflows (as WDLs) used to perform alignment and variant calling on the T2T-CHM13v2.0 reference. The entire pipeline was run on the AnVIL cloud computing platform. For our paper (<a href="https://doi.org/10.1101/2022.12.01.518724" target="_blank">The complete sequence of a human Y chromosome</a>), we performed alignment and variant calling for all 3202 samples from the 1000 Genomes Project (1KGP) as well as 279 samples from the Simons Genome Diversity Project (SGDP). Alignments and variant calls (as well as statistics, metadata, and other resources) for both of these datasets are available from our <a href="https://anvil.terra.bio/#workspaces/anvil-datastorage/AnVIL_T2T_CHRY" target="_blank">public T2T-chrY AnVIL repository</a>.

Described below is each workflow used in the pipeline, listed in order, along with the expected inputs and outputs for each.

# Pipeline Workflows
## 1. `prepare_reference` Workflow
From a single unmasked reference, creates two separate masked references: one each for XX and XY samples (henceforth refered to as "karyotype-specific" references). The reasoning behind using separate reference genomes for XX and XY samples is described in detail in the <a href="https://doi.org/10.1101/2022.12.01.518724" target="_blank">paper</a> and on the <a href="https://anvil.terra.bio/#workspaces/anvil-datastorage/AnVIL_T2T_CHRY" target="_blank">AnVIL repo</a>, but briefly, it  improves alignment and variant calling on the sex chromosomes.

### Inputs
* `refFasta`: The input reference genome
* `refMask`: A bed file denoting the pseudo-autosomal regions (PARs) of both the X and Y chromosomes

### Outputs
* `XXref`: XX-specific reference (chrY masked)
* `XXrefDict`: GATK sequence dictionary for XX-specific reference
* `XXrefIndex`: Fasta index for XX-specific reference
* `XYref`: XY-specific reference (chrY PARs masked)
* `XYrefDict`: GATK sequence dictionary for XY-specific reference
* `XYrefIndex`: Fasta index for XY-specific reference

## 2. `bwaIndex` Workflow
For an input reference, creates a BWA index for alignment. This workflow should be run on each of the karyotype-specific references created in [step 1](#1-prepare_reference-workflow).

### Inputs
* `fasta`: The input reference genome

### Outputs
* `bwa_index`: The BWA index for the input reference

## 3. `t2t_realignment` Workflow
For a given sample, performs alignment with BWA, outputting a compressed CRAM file, as well as samtools stats and mosdepth stats.

### Inputs
* `sampleName`: The name of the selected sample, to be used in output files
* `inputFastq1` and `inputFastq2`: The fastq files for the selected sample
* `targetRef`: The appropriate karyotype-specific reference from [step 1](#1-prepare_reference-workflow)
* `bwaIndexTar`: The appropriate karyotype-specific BWA index from [step 2](#2-bwaIndex-workflow)
* `dedupDistance`: `distance` parameter for `samtools markdup` (default 100)

### Outputs
* `cram`: Output alignment, compressed with karyotype-specific reference
* `cramIndex`: CRAM index for output alignment
* `mosdepth_globalDist`, `mosdepth_regionsBed`, `mosdepth_regionsBedIndex`, `mosdepth_regionsDist`, and `mosdepth_summary`: Output of running `mosdepth` on alignment CRAM file
* : `samtools_stats`: Output of running `samtools stats` on alignment CRAM file

## 4. `haplotype_calling` Workflow
For a single sample, runs the GATK `HaplotypeCaller` tool to call variants in that sample.

### Inputs
* `sampleName`: The name of the selected sample, to be used in output files
* `sampleKaryotype`: The sex chromosome complement of the sample (either XX or XY)
* `cram`, `cramIndex`: Output from [step 3](#3-t2t_realignment-workflow) for the selected sample
* `refFasta`, `fastaDict`, `fastaIndex`: The appropriate karyotype-specific reference and indicies from [step 1](#1-prepare_reference-workflow)
* `nonparXbed`,`parXbed`,`parYbed`: Bed files describing the non-PAR regions of chrX, the PARs of chrX, and the PARs of chrY, respectively

### Outputs
* `chr{1-22}_hcVCF`: The output VCF for for each autosomal chromosome. These variant calls will be diploid
* `chr{1-22}_hcVCF_gz`: The gzipped output VCF for each autosome
* `chr{1-22}_hcVCF_gz_tbi`: The tabix index for each output autosome VCF
* `XX_X_hcVCF`, `XX_X_hcVCF_gz`, `XX_X_hcVCF_gz_tbi`: The output VCF (and index) for chrX in XX samples. These variant calls will be diploid. If the input sample is XY, these outputs will not be created
* `XY_X_non_PAR_hcVCF`, `XY_X_non_PAR_hcVCF_gz`, `XY_X_non_PAR_hcVCF_gz_tbi`: The output VCF (and index) for the non-PAR regions of chrX in XY samples. These variant calls will be haploid. If the input sample is XX, these outputs will not be created
* `XY_X_PAR_hcVCF`, `XY_X_PAR_hcVCF_gz`, `XY_X_PAR_hcVCF_gz_tbi`: The output VCF (and index) for the chrX PARs in XY samples. These variant calls will be diploid because, in our analysis, the chrX PARs represent variation originating from both the chrX PARs and chrY PARs. If the input sample is XX, these outputs will not be created
* `XY_Y_nonPAR_hcVCF`, `XY_Y_nonPAR_hcVCF_gz`, `XY_Y_nonPAR_hcVCF_gz_tbi`: The output VCF (and index) for the non-PAR regions of chrY in XY samples. These variant calls will be haploid. If the input sample is XX, these outputs will not be created

## 5. Creating sample maps
For the next step in the pipeline, you will need 25 sample maps: tab-separated files that describe the filepaths of the per-sample VCFs generated in [step 4](#4-haplotype_calling-workflow). These are described in detail below, and example sample maps are available in the `example_sample_maps` directory in this directory. Note: you CANNOT change the names of these files.
* `chr{1-22}_sample_map.tsv`
	* For chr1, for example, you will create a file called `chr1_sample_map.tsv`
	* Map `sample_id` to `chr{1-22}_hcVCF_gz` output from step 4
* `chrX_PAR_sample_map.tsv`
	* For XY samples, map `sample_id` to `XY_X_PAR_hcVCF_gz` output from step 4
	* For XX samples, map `sample_id` to `XX_X_hcVCF_gz` output from step 4
* `chrX_non_PAR_sample_map.tsv`
	* For XY samples, map `sample_id` to `XY_X_non_PAR_hcVCF_gz` output from step 4
	* For XX samples, map `sample_id` to `XX_X_hcVCF_gz` output from step 4
* `chrY_sample_map.tsv`
	* For XY samples, map `sample_id` to `XY_Y_nonPAR_hcVCF_gz` output from step 4
	* Do not include XX samples

## 6. `generate_genomics_db` Workflow
For a input genomic interval, generates a GATK GenomicsDB file for a set of samples, in preparation for joint genotyping. GenomicsDB files are created in small (100kb) intervals to facilitate parellelization of joint genotyping. The intervals used in this analysis are described in the <a href="https://anvil.terra.bio/#workspaces/anvil-datastorage/AnVIL_T2T_CHRY" target="_blank">AnVIL repo</a> in the `PAR_interval` table. 

### Inputs
* `filePath`: The path to the directory containing the 25 sample maps generated in [step 5](#5-creating-sample-maps)
* `chromosome`: The chromosome of the input genomic interval
* `marginedStart`: The margined start position of the input genomic interval (1kb upstream of interval start position)
* `marginedEnd`: The margined end position of the input genomic interval (1kb downstream of interval end position)
* `interval`: The name of the interval, to be used in output files
* `regionType`: Either "non_PAR", "PAR1", or "PAR2" based on which of these categories the input region falls under

### Outputs
* `genomicsDBtar`: A tar file containing the genomicsDB information for the input interval across the samples specified in the sample map

## 7. `interval_calling` Workflow
For a input genomic interval, runs the GATK `GenotypeGVCFs` tool with the GenomicsDB created in [step 6](#6-generate_genomics_db-workflow) to perform joint genotyping across all samples in the GenomicsDB file. The output interval VCFs will be merged into single chromosome VCFs in the next step.

### Inputs
* `chromosome`: The chromosome of the input genomic interval
* `start`: The start position of the input genomic interval
* `end`: The end position of the input genomic interval
* `marginedStart`: The margined start position of the input genomic interval (1kb upstream of interval start position)
* `marginedEnd`: The margined end position of the input genomic interval (1kb downstream of interval end position)
* `interval`: The name of the interval, to be used in output files
* `genomicsDBtar`: The output genomicsDB tar file from [step 6](#6-generate_genomics_db-workflow) corresponding to the input interval
* `refFasta`, `refIndex`, `refDict`: The unmasked reference and indicies (used as input in [step 1](#1-prepare_reference-workflow))

### Outputs
* `genotypeIntervalVCF`: The output VCF for the input interval
* `genotypedIntervalVCFgz`: The gzipped output VCF for the input interval
* `genotypedIntervalVCFtabix`: The tabix index for the output interval VCF

## 8. `concat_vcfs_chromosome` Workflow
For a single chromosome, merges the VCFs for all intervals (from [step 7](#7-interval_calling-workflow)) on that chromosome into a single VCF. Note: You no longer need to distinguish between the PAR and non-PAR regions of chrX or chrY.

### Inputs
* `chromosome`: The input chromosome
* `VCFs`: An array containing the names of all of the interval VCFs (gzipped) generated from [step 7](#7-interval_calling-workflow) for intervals on the input chromosome
* `indexes`: An array containing the names of all the tabix indicies corresponding to the files in the `VCFs` array

### Outputs
* `chromosomeVCF`: The output VCF for the input chromosome
* `chromosomeVCF_gz`: The gzipped output VCF for the input chromosome
* `chromosomeVCF_tbi`: The tabix index for the output chromosome VCF

## 9. `recalibration` Workflow
For an input VCF, performs [Variant Qaulity Score Recalibration](https://gatk.broadinstitute.org/hc/en-us/articles/360036510892-VariantRecalibrator) using the GATK `VariantRecalibrator` tool with a number of different databases of human variation from the [Broad Resource bundle](https://gatk.broadinstitute.org/hc/en-us/articles/360035890811-Resource-bundle). You'll run this workflow on each of the chromosome VCFs generated in [step 8](#8-concat_vcfs_chromosome-workflow).

### Inputs
* `VCF`: The input VCF
* `chromosome`: The chromosome of the input VCF
* `refFasta`, `refIndex`, `refDict`: The unmasked reference and indicies (used as input in [step 1](#1-prepare_reference-workflow) and [step 7](#7-interval_calling-workflow))
* `{dataBase}` and `{dataBase}_index` for each of dbdnp, hapmap, kg_mills, kg_omni, and kg_snps: The VCFs and tabix indicies respectively of the databases of "true-positive" human genetic variation available in the [Broad Resource bundle](https://gatk.broadinstitute.org/hc/en-us/articles/360035890811-Resource-bundle)

### Outputs
* `recalibratedVCF`: The recalibrated output VCF for the input chromosome
* `recalibratedVCFgz`: The gzipped recalibrated output recVCF for the input chromosome
* `recalibratedVCFtabix`: The tabix index for the recalibrated output chromosome VCF


<!-- 


## 9. `get_pass_records` Workflow
- You should run this workflow with the `chromosome` data table.

### Inputs
- `inputVCFgz`: The name of the appropriate column created in Step 8.

### Outputs
- `pass_bgzip`, `pass_index`, `pass_stats`, `passVCF`:  The columns in the `chromosome` data table to store the outputs to. As with previous steps, these **SHOULD** be new columns, for whichever set of samples you chose to run.
- 
-->
