version 1.0

workflow perturbSeq {
    input {
        String PIPseq_chemistry
        Array[File] fastqs
        String sample_id
        Array[File] mapping_references
        Array[File] snt_fastqs
        File snt_tags
        File? annotation
    }
    # version of the pipeline
    String pipeline_version = "beta_0.0.1"
    parameter_meta {
        PIPseq_chemistry : {help: "Versions of the PIPseq assay", suggestions: ["v3", "v4", "v5"]}
        fastqs : {help: "The path to the input FASTQ files"}
        sample_id : {help: "Sample ID for the perturb-seq data. It will be used as the prefix for the output files."}
        mapping_references : {help: "The path to STAR reference files to use for mapping"}
        annotation : {help: "(Optional) The path to reference file for cell type annotation of the clustering results."}
        snt_fastqs : {help: "The path to the input SNT FASTQ files"}
        snt_tags : {help: "The path to the SNT tags file"}
    }
    meta {
        author: "Yueyao Gao"
        email: "gaoyueya@broadinstitute.org"
        description: "This is a workflow to process perturb-seq data."
    }

    call PIPseeker{
        input:
            PIPseq_chemistry = PIPseq_chemistry,
            fastqs = fastqs,
            sample_id = sample_id,
            mapping_references = mapping_references,
            snt_fastqs = snt_fastqs,
            snt_tags = snt_tags,
            annotation = annotation
    }

    output {
        File PIPseeker_report = PIPseeker.PIPseeker_report
        File PIPseeker_out_bam = PIPseeker.star_out_bam
    }
}

task PIPseeker {
    input {
        String PIPseq_chemistry
        Array[File] fastqs
        String sample_id
        Array[File] mapping_references
        Array[File] snt_fastqs
        File snt_tags
        String pipseeker_docker = "public.ecr.aws/w3e1n2j6/fluent-pipseeker:3.1.3"
        File? annotation
        Int mem_size = 32
        Int cpu_count = 4
        Int disk_size = 100
        Int preemptible = 0
    }
    command <<<
        echo "Creating SAMPLE_FASTQS directory to store input fastq files"
        # ensure the the fastq files all begin with a common prefix
        mkdir SAMPLE_FASTQS
        declare -a FASTQ_ARRAY=(~{sep=' ' fastqs})
        for f in "${FASTQ_ARRAY[@]}"; do mv $f SAMPLE_FASTQS; done

        echo "Creating REFERNCE directory to store input reference files"
        # Create a directory for the reference files
        mkdir REFERNCE
        declare -a REF_ARRAY=(~{sep=' ' mapping_references})
        for f in "${REF_ARRAY[@]}"; do mv $f REFERNCE; done


        echo "Creating SNT_FASTQS directory to store input SNT fastq files"
        mkdir SNT_FASTQS
        declare -a SNT_ARRAY=(~{sep=' ' snt_fastqs})
        for f in "${SNT_ARRAY[@]}"; do mv $f SNT_FASTQS; done
        SNT_FASTQ_OPTION="--snt-fastq SNT_FASTQS"


        echo "Running PIPseeker"
        echo "PIPseeker version: ~{pipseeker_docker}"

        /app/pipseeker full \
        --chemistry ~{PIPseq_chemistry} \
        --fastq SAMPLE_FASTQS/. \
        --star-index-path REFERNCE \
        --snt-fastq SNT_FASTQS/. \
        --snt-tags ~{snt_tags} \
        ~{'--annotation '+ annotation} \
        --id ~{sample_id} \
        --output-path RESULTS \
        --threads ~{cpu_count}

        mv RESULTS/*.html ~{sample_id}_report.html
        mv RESULTS/*.bam ~{sample_id}_star_out.bam
    >>>
    runtime {
        docker: pipseeker_docker
        disk: "local-disk ~{disk_size} HDD"
        cpu: 8
        memory: mem_size + " GB"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: preemptible
  }

  output {
    File PIPseeker_report = "~{sample_id}_report.html"
      File star_out_bam = "~{sample_id}_star_out.bam"
    }
}
