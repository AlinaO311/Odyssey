#!/bin/bash


# =================
## IMPORTANT NOTES:
# =================

# The bed/bim/fam trio must have the proper variant ID's as identified by NCBI (otherwise fixing the data to the reference will likely not work)
# You also need to make sure that you have the proper reference build in relation to your genetic data you are trying to fix (don't try and fix GRCh37 data to a GRCh38 reference)

# =================
## DEPENDENCIES:
# =================

# BCFtools v1.8 or later and the BCFtools plugin +fixref
# htslib v1.8 or later -- which is a BCFTools dependency

# Splash Screen
# --------------
#	source .TitleSplash.txt
#	printf "$Logo"

# Source from .config files (Program options via Settings.conf & Program execs via Programs.conf)
# ----------------------------

oddysseyPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

	source "$oddysseyPath/Settings.conf"

	# Load Odysseys Dependencies -- pick from several methods
	if [ "${OdysseySetup,,}" == "one" ]; then
		echo
		printf "\n\nLoading Odyssey's Singularity Container Image \n\n"
		source "$oddysseyPath/Configuration/Setup/Programs-Singularity.conf"
	
	elif [ "${OdysseySetup,,}" == "two" ]; then
		echo
		printf "\n\nLoading Odyssey's Manually Configured Dependencies \n\n"
		source "$oddysseyPath/Configuration/Setup/Programs-Manual.conf"
	else

		echo
		echo User Input Not Recognized -- Please specify One or Two
		echo Exiting Dependency Loading
		echo
		exit
	fi


# Get Working Directory
# -------------------------------------------------
echo
echo "Current working dir $PWD"
echo Data Directory added to Working Dir
echo ----------------------------------------------

##make sure data dir has same basename as *.bam and *.bam/*.fam/*.bed match 

#Get the BaseName of the Data -- must have a Plink .bim file in the folder
RawData="$(ls *.bim | awk -F/ '{print $NF}' | awk 'BEGIN{FS=OFS="."} NF--')"

#Match dirname to .bim filename

sampleBase="$(basename $PWD)"
if [ "${sampleBase}" = "$RawData" ]; then
    echo "Directory name matches sample names."
else
     echo "Directory name does not match sample names" 
     while true; do 
         read -p "Rename directory to match .bim name?" yn
         case $yn in
             [Yy]* ) mv ${PWD} "$(dirname $PWD)"/"$RawData" && echo $PWD && echo "Change dataPath"; exit;;
             [Nn]* ) echo "Exiting";exit;;
             * ) echo "Please answer yes or no.";;
         esac
     done
fi

# Match filenames

for i in  *; 
do   
   case "$i" in     
       $RawData.*) echo Filenames match: $i ;;     
       *) mv $i "$RawData.${i##*.}" ;;   
   esac
done


# Controls whether BCFTools +Fixref is performed on the dataset

if [ "${PerformFixref,,}" == "t" ]; then
	echo "Performing BCFTools +Fixref on dataset"
		echo ----------------------------------------------
		
	#Make Temp Directory in which all Temp files will populate
		mkdir TEMP && mkdir TargetData

	# Download all the Reference Data to Reformat the files
	# ----------------------------------------------------------------------------
	
	if [ "${DownloadRef,,}" == "t" ]; then
	
		echo
		echo Downloading Reference Data and index files from 1K Genomes and NCBI
		echo ----------------------------------------------
	
		echo Downloading: ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/human_g1k_v37.fasta.gz
		echo
		wget -nc --directory-prefix=$oddysseyPath/0_DataPrepModule/RefAnnotationData/ ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/human_g1k_v37.fasta.gz
		wget -nc --directory-prefix=$oddysseyPath/0_DataPrepModule/RefAnnotationData/ ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/human_g1k_v37.fasta.fai	
                #wget -nc --directory-prefix=$oddysseyPath/0_DataPrepModule/RefAnnotationData/ https://console.cloud.google.com/storage/browser/_details/broad-references/hg19/v0/Homo_sapiens_assembly19.fasta	
                #wget -nc --directory-prefix=$oddysseyPath/0_DataPrepModule/RefAnnotationData/ https://console.cloud.google.com/storage/browser/_details/broad-references/hg19/v0/Homo_sapiens_assembly19.fasta.fai
 

		# Unzip Fasta file
                gzip -d $oddysseyPath/0_DataPrepModule/RefAnnotationData/human_g1k_v37.fasta.gz
                bgzip $oddysseyPath/0_DataPrepModule/RefAnnotationData/human_g1k_v37.fasta 
		
 
	# Download the annotation files (make sure the the build version is correct) to flip/fix the alleles
		echo
		echo Downloading https://ftp.ncbi.nih.gov/snp/organisms/human_9606/VCF/All_20180418.vcf.gz
		echo
                wget -nc --directory-prefix=$oddysseyPath/0_DataPrepModule/RefAnnotationData/ https://ftp.ncbi.nih.gov/snp/organisms/human_9606/VCF/All_20180418.vcf.gz	
                wget -nc --directory-prefix=$oddysseyPath/0_DataPrepModule/RefAnnotationData/ https://ftp.ncbi.nih.gov/snp/organisms/human_9606/VCF/All_20180418.vcf.gz.tbi
	
	fi
	
	printf "\n\nSTEP 1: Convert the Plink BED/BIM/FAM into a VCF into a BCF so that it may be fixed with BCFtools \n"
	echo --------------------------------------------------------------------------------------------------

	if [ "${DataPrepStep1,,}" == "t" ]; then
		
		# Convert Plink file into a VCF
		
		printf "\n\nConverting $RawData Plink files into VCF format \n"
		echo ----------------------------------------------
		echo
		echo
                
                # try to recode plink files ot vcf
	        if (${Plink2_Exec} --bfile $RawData --export bcf-4.2 --out DataFixStep1_${RawData}) ; then
                    printf "\n\nConverting $RawData Plink files into VCF format \n"
                else # if some error code
                    echo		
		    echo
                    ## for split chr plink 1.9
                    ## switch for 2.0, need pgen instead to sort for to make-bed   ## switch to export either the fixed split chr in *bgen format or recode to vcf from pgen format
                    (${Plink2_Exec} --bfile $RawData --keep-allele-order --fa $oddysseyPath/0_DataPrepModule/RefAnnotationData/human_g1k_v37.fasta --ref-from-fa --make-bed --out ${RawData}_chrFix || ${Plink2_Exec} --bfile $RawData --make-pgen --sort-vars --out ${RawData}_chrSort && ${Plink2_Exec} --pfile ${RawData}_chrSort --make-bed --out ${RawData}_chrFix)  \
                                    && ( ${Plink2_Exec} --bfile ${RawData} --export vcf --id-delim '_' --out DataFixStep1_${RawData} || ${Plink2_Exec} --pfile ${RawData}_chrSort --keep-allele-order  --export vcf --id-delim '_' --out DataFixStep1_${RawData})
                    echo
                    echo
                fi
                  
      
                cp DataFix*  TEMP && cp Data*  TargetData

	# Convert from a VCF into a BCF and also rename the chromosomes to match the reference fasta (where [chr]23 is X, 24 is Y, etc.)
		 

		printf "\n\nConverting VCF into a BCF with chromosome names that match the reference .fasta annotation \n\nNOTE: You may need to manually adjust $oddysseyPath/Odyssey/RefAnnotationData/PlinkChrRename.txt depending on the fasta reference you use in order to match the chromosome names \n"
		echo ----------------------------------------------
		echo
		echo
                ${bcftools} annotate -Ob --rename-chrs $oddysseyPath/0_DataPrepModule/RefAnnotationData/Plink*.txt DataFixStep1_${RawData}.vcf >  DataFixStep1_${RawData}.bcf || ${bcftools} index DataFixStep1_${RawData}.vcf.bgz  &&  ${bcftools} convert -Ou DataFixStep1_${RawData}.vcf.bgz  >  DataFixStep1_${RawData}.bcf
	        cp DataFix* TargetData
                printf "\n\nStep 1 Done!\n" 
	fi
	
	
	
	
	# STEP 2: Align Input File to the Reference Annotation (Fix with BCFtools)
	# --------------------------------------------------------------------------------------------------
	
	if [ "${DataPrepStep2,,}" == "t" ]; then
	
	# Run bcftools +fixref to see the number of wrong SNPs
		printf "\n\nRun bcftools +fixref to first view the number of correctly annotated/aligned variants to the Reference annotation \n"
		echo ----------------------------------------------
		echo
		echo
	
		${bcftools} +fixref DataFixStep1_${RawData}.bcf -- -f $oddysseyPath/0_DataPrepModule/RefAnnotationData/human_g1k_v37.fasta.gz
	
	# Run bcftools to fix/swap the allels based on the downloaded annotation file
		printf "\n\nRun bcftools +fixref to fix allels based on the downloaded annotation file \n"
		echo ----------------------------------------------
		echo
		echo
	
		${bcftools} +fixref DataFixStep1_${RawData}.bcf -Ob -o DataFixStep2_${RawData}-RefFixed.bcf -- -d -f $oddysseyPath/0_DataPrepModule/RefAnnotationData/human_g1k_v37.fasta.gz -i  $oddysseyPath/0_DataPrepModule/RefAnnotationData/All_20180418.vcf.gz
                cp DataFix*  ${dataPath}/TargetData/

	# Rerun the bcftool +fixref check to see if the file has been fixed and all unmatched alleles have been dropped
		printf "\n\nRun bcftools +fixref to see if the file has been fixed - all alleles are matched and all unmatched alleles have been dropped \n"
		echo ----------------------------------------------
		echo
		echo
	
		${bcftools} +fixref  DataFixStep2_${RawData}-RefFixed.bcf -- -f  $oddysseyPath/0_DataPrepModule/RefAnnotationData/human_g1k_v37.fasta
		cp DataFix* ${dataPath}/TargetData/
	fi
	
	
	# STEP 3: Sort the Ref-Aligned BCF output and convert back into Plink format for Odyssey Pipeline
	# --------------------------------------------------------------------------------------------------
	
	if [ "${DataPrepStep3,,}" == "t" ]; then
	
	
	# Sort the BCF output
		printf "\n\nSorting the BCF output since fixing it may have made it unsorted \n"
		echo ----------------------------------------------
	
		(${bcftools} view -h DataFixStep2_${RawData}-RefFixed.bcf; ${bcftools} view -H  DataFixStep2_${RawData}-RefFixed.bcf | sort -k1,1d -k2,2n;) | ${bcftools} view -Ob -o  DataFixStep3_${RawData}-RefFixedSorted.bcf
		
                cp DataFixStep*  ${dataPath}/TEMP/ && cp DataFixStep* ${dataPath}/TargetData

		printf "Done \n\n\n"
	
	# Convert BCF back into Plink .bed/.bim/.fam for Shapeit2 Phasing
		printf "\n\nConverting Fixed and Sorted BCF back into Plink .bed/.bim/.fam \n"
		echo ----------------------------------------------
		echo
		echo
	
		${Plink2_Exec} --bcf  DataFixStep3_${RawData}-RefFixedSorted.bcf --make-bed --out DataFixStep3_${RawData}-RefFixSorted
		
		cp DataFixStep*  ${dataPath}/TEMP/ &&  cp DataFixStep* ${dataPath}/TargetData

		
	# Finally Remove any positional duplicates 
		# i.e. same position and alleles, but differently named variants since Shapeit will not tolerate these
	
	
		printf "\n\nFinding Positional and Allelic Duplicates \n"
		echo ----------------------------------------------
		echo
		echo
	
		${Plink2_Exec} --bfile DataFixStep3_${RawData}-RefFixSorted --list-duplicate-vars ids-only suppress-first --out Dups2Remove
		
                cp Dups2Remove*  ${dataPath}/TEMP/ && cp *log ${dataPath}/TargetData

		# Report Number of duplicates:
		DuplicateNumber="$(wc Dups2Remove.dupvar | awk '{print $1}')"
		
		printf "\n\nRemoving Positional and Allelic Duplicates if they exist\nFound ${DuplicateNumber} Duplicate Variant/s\n"
		echo ----------------------------------------------
		echo
		echo
	
		${Plink2_Exec} --bfile DataFixStep3_${RawData}-RefFixSorted --exclude Dups2Remove.dupvar --make-bed --out DataFixStep4_${RawData}-RefFixSortedNoDups
		
		cp DataFixStep4_*  ${dataPath}/TEMP && cp DataFixStep4_*  ${dataPath}/TargetData

	# Add back in the sex information
		printf "\n\nRestoring Sample Sex Information \n"
		echo ----------------------------------------------
		echo
		echo
		
		
		${Plink2_Exec} --bfile DataFixStep4_${RawData}-RefFixSortedNoDups --update-sex  ${RawData}.fam 3 --make-bed --out DataFixStep5_${RawData}-PhaseReady
		
                cp DataFixStep5_${RawData}-PhaseReady  ${dataPath}/TEMP/  && mv  DataFixStep*  ${dataPath}/TargetData  

		echo
		echo
		echo ----------------------------------------------
		printf "Analysis Ready Data -- DataFixStep5_${RawData}-PhaseReady -- Output to --> ${dataPath}/TargetData/DataFixStep5_${RawData}-PhaseReady \n"
		echo ----------------------------------------------
	        rm Dups* && rm *log && rm DataFix*
	fi
	
	# After Step: Cleanup File Intermediates 
	# --------------------------------------------------------------------------------------------------
	
	if [ "${SaveDataPrepIntermeds,,}" == "f" ]; then
	
		echo 
		echo ----------------------------------------------
		echo Tidying Up -- Cleanup Intermediate Files
		echo ----------------------------------------------
	
		if [ -d "${dataPath}/TEMP" ]; then rm -r ${dataPath}/TEMP; fi
	
	fi
	
elif [ "${PerformFixref,,}" == "f" ]; then

	#Make Temp Directory in which all Temp files will populate
		mkdir  ${dataPath}/TEMP && mkdir ${dataPath}/TargetData
                
	# Finally Remove any positional duplicates 
		# i.e. same position and alleles, but differently named variants since Shapeit will not tolerate these
	
		printf "\n\nFinding Positional and Allelic Duplicates \n"
		echo ----------------------------------------------
		echo
		echo
	        
                (${Plink_Exec} --bfile ${RawData} --list-duplicate-vars ids-only suppress-first --out Dups2Remove) || (${Plink_Exec} --bfile ${RawData} --make-bed -out ${RawData}_chrFix && ${Plink_Exec} --bfile ${RawData}_chrFix --list-duplicate-vars ids-only suppress-first --out Dups2Remove) 
                ##uncomment plink2, no dups removal needed
                ### ${Plink2_Exec} --bfile ${RawData} --set-all-var-ids --rm-dup --out DataFixStep5_${RawData}-PhaseReady || (${Plink2_Exec} --bfile ${RawData} --make-pgen --sort-vars --out ${RawData}_chrSort && ${Plink2_Exec} --pfile ${RawData}_chrSort --make-bed --out ${RawData}_chrFix) 
		
		printf "\n\nRemoving Positional and Allelic Duplicates \n"
		echo ----------------------------------------------
		echo
		echo
	        
                ##plink1
                ${Plink_Exec} --bfile ${RawData} --exclude Dups2Remove.dupvar --make-bed --out  DataFixStep5_${RawData}-PhaseReady || (${Plink_Exec} --bfile ${RawData}_chrFix --exclude Dups2Remove.dupvar --make-bed --out  DataFixStep5_${RawData}-PhaseReady)
                cp  *  TEMP ;  mv Dup* ${dataPath}/TEMP ; cp DataFixStep5* TargetData ; rm -f -- *chrFix*

	if [ "${SaveDataPrepIntermeds,,}" == "f" ]; then
	
		echo 
		echo ----------------------------------------------
		echo Tidying Up -- Cleanup Intermediate Files
		echo ----------------------------------------------
	
		if [ -d  "${dataPath}/TEMP" ]; then rm -r  ${dataPath}/TEMP; fi
		    rm -r ${dataPath}/TEMP && rm  ~/Dup*
	
	fi
		
		
		echo
		echo
		echo ----------------------------------------------
		printf "Analysis Ready Data -- DataFixStep5_${RawData}-PhaseReady -- Output to --> ${dataPath}/TargetData/DataFixStep5_${RawData}-PhaseReady \n"
		echo ----------------------------------------------
 
else

	echo
	echo User Input Not Recognized -- Please specify T or F
	echo Exiting
	echo


fi

# Visualize genomic data for missingness, heterozygosity, and relatedness
if [ "${DataVisualization,,}" == "t" ]; then
	printf "\n\n===================================================\n"
	printf "Data QC-Visualization\n----------------\n\nPreparing to perform QC analysis on the SINGLE Plink .bed/.bim/.fam dataset within:\n. ${dataPath}/TargetData/ \n\nNOTE: If no data is present, then this analysis will be skipped \n\nAll Data and Plots will be saved to ${dataPath}/TargetData"
	printf "\n--------------------------------\n\n"

	# Executes the Rscript to analyze and visualize the GWAS analysis

		Arg6="${dataPath}/TargetData";
		Arg7="${X11}";
                 
		${Rscript}  $oddysseyPath/1_Target/1_PreGWAS-QC.R $Arg6 $Arg7
                 
                mkdir ${dataPath}/5_QuickResults/ && mkdir ${dataPath}/5_QuickResults/${RawData}_results 

	# Copy the Analysis Data to the Quick Results Folder
		echo
		echo
		echo "Copying Analysis Data and Visualizations to Quick Results Folder"
		echo ------------------------------------------------------------------
		cp -R  ${dataPath}/TargetData/Dataset_QC-Visualization ${dataPath}/5_QuickResults/${RawData}_results 
 
elif [ "${DataVisualization,,}" == "f" ]; then

	echo
	echo "Skipping Data Visualization and QC"
	echo ----------------------------------------------

else

	echo
	echo User Input Not Recognized -- Please specify T or F
	echo Exiting
	echo

fi

	
# Termination Message
	echo
	echo ============
	echo " Phew Done!"
	echo ============
	echo
	echo


