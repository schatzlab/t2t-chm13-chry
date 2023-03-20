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
For an input reference, create a BWA index for alignment. This workflow should be run on each of the karyotype-specific references created in [step 1](#1-prepare_reference-workflow).

### Inputs
* `fasta`: The input reference genome

### Outputs
* `bwa_index`: The BWA index for the input reference

## 3. `t2t_realignment` Workflow
This workflow performs alignment for a single sample, outputting a compressed CRAM file, as well as samtools stats and mosdepth stats.

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
For a single sample, run the GATK `HaplotypeCaller` tool to call variants in that sample.

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
* `filePath`: The path to the directory containing the 25 sample maps generated in [step 5](#5-creating_sample_maps)
* `chromosome`: The chromosome of the input genomic interval
* `marginedStart`: The margined start position of the input genomic interval
* `marginedEnd`: The margined end position of the input genomic interval
* `interval`: The name of the interval, to be used in output files
* `regionType`: Either "non_PAR", "PAR1", or "PAR2" based on which of these categories the input region falls under

### Outputs
* `genomicsDBtar`: A tar file containing the genomicsDB information for the input interval across the samples specified in the sample map

<!-- 
## 6. `interval_calling` Workflow
- You should run this workflow with the `PAR_interval` data table, same as Step 5.

### Inputs
- `chromosome`, `interval`, `marginedStart`, `marginedEnd`, `start`, `end`: The appropriate columns from the Data Table. These should not need to be changed.
- `genomicsDBtar`: The name of the column created in Step 5.
- `refFasta`, `refDict`, `refIndex`: These are absolute file paths to files Samantha uploaded. You should not need to change these.

### Outputs
- `genotypeIntervalVCF`, `genotypedIntervalVCFgz`, `genotypedIntervalVCFtabix`: The columns in the `PAR_interval` data table to store the outputs to. As with Step 5, these **SHOULD** be new columns, for whichever set of samples you chose to run.

## 7. `concat_vcfs_chromosome` Workflow
- You should run this workflow with the `PAR_interval_set` data table. This is a bit different than `PAR_interval`.  Instead, it notes all the intervals in `PAR_interval` belonging to each chromosome. You can run the workflow on a single chromosome at a time, or all chromosomes at once (select `Choose existing sets of PAR_interval_sets`).

### Inputs
- `chromosome`: The appropriate column in the data table. This should not need to be changed.
- `indexes`, `VCFs`: The names of the appropriate columns created in Step 6. You'll have to do `this.PAR_intervals.<column_name>`, as `PAR_interval_set` is a set of multiple `PAR_intervals`.
	- Note: You can used the gzipped VCFs for the `VCFs` input.

### Outputs
- The outputs of running this workflow aren't stored in a data frame, but can be added to the `chromosome` data table in a new column, labeled in a similar way to how you labeled the outputs of Steps 5 and 6.

## 8. `recalibration` Workflow
- You should run this workflow with the `chromosome` data table.

### Inputs
- `chromosome`: The appropriate column in the data table. This should not need to be changed.
- `VCF`: This should the be output of Step 7. You will either need to add the output of Step 7 to a new column in the `chromosome` data table, or use an absolute file path here. If you choose to use an absolute file path, you'll need to run each chromosome separately.
- The rest of the inputs are absolute file paths to files Samantha uploaded. You should not need to change these.

### Outputs
- `recalibratedVCF`, `recalibratedVCFgz`, `recalibratedVCFtabix`: The columns in the `chromosome` data table to store the outputs to. As with Steps 5-7, these **SHOULD** be new columns, for whichever set of samples you chose to run.

## 9. `get_pass_records` Workflow
- You should run this workflow with the `chromosome` data table.

### Inputs
- `inputVCFgz`: The name of the appropriate column created in Step 8.

### Outputs
- `pass_bgzip`, `pass_index`, `pass_stats`, `passVCF`:  The columns in the `chromosome` data table to store the outputs to. As with previous steps, these **SHOULD** be new columns, for whichever set of samples you chose to run.
- 
-->
