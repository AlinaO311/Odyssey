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
	source .TitleSplash.txt
	printf "$Logo"

# Source from .config files (Program options via Settings.conf & Program execs via Programs.conf)
# ----------------------------
	source Settings.conf
	
	# Load Odysseys Dependencies -- pick from several methods
	if [ "${OdysseySetup,,}" == "one" ]; then
		echo
		printf "\n\nLoading Odyssey's Singularity Container Image \n\n"
		source ./Configuration/Setup/Programs-Singularity.conf
	
	elif [ "${OdysseySetup,,}" == "two" ]; then
		echo
		printf "\n\nLoading Odyssey's Manually Configured Dependencies \n\n"
		source ./Configuration/Setup/Programs-Manual.conf
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
echo Current Working Directory
echo ----------------------------------------------
echo $PWD

#Get central data directory
#echo -n "Central directory for data files":  
read -p "Full path to location of data directories":

#Get the BaseName of the Data -- must have a Plink .bim file in the folder
RawData="$(ls $REPLY/*_oddysseyData/*.bim | awk -F/ '{print $NF}' | awk -F'.' '{print $1}')"

mkdir -p $REPLY/${RawData}_oddysseyData/${RawData}_Step0out #TargetData folder

# Controls whether BCFTools +Fixref is performed on the dataset

if [ "${PerformFixref,,}" == "t" ]; then
	echo "Performing BCFTools +Fixref on dataset"
		echo ----------------------------------------------
		
	#Make Temp Directory in which all Temp files will populate
		mkdir -p $REPLY/${RawData}_oddysseyData/TEMP

	# Download all the Reference Data to Reformat the files
	# ----------------------------------------------------------------------------
	
	if [ "${DownloadRef,,}" == "t" ]; then
	
		echo
		echo Downloading Reference Data and index files from 1K Genomes and NCBI
		echo ----------------------------------------------
	
		echo Downloading: ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/human_g1k_v37.fasta.gz
		echo
		wget --directory-prefix=$REPLY/RefAnnotationData/ ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/human_g1k_v37.fasta.gz
		wget --directory-prefix=$REPLY/RefAnnotationData/ ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/human_g1k_v37.fasta.fai	
		
		# Unzip Fasta file
		${gunzip_Exec} -d $REPLY/RefAnnotationData/human_g1k_v37.fasta.gz
		
		# Rezip Fasta File in bgzip
		${bgzip_Exec} $REPLY/RefAnnotationData/human_g1k_v37.fasta
		rm $REPLY/RefAnnotationData/human_g1k_v37.fasta
		
	
	# Download the annotation files (make sure the the build version is correct) to flip/fix the alleles
		echo
		echo Downloading ftp://ftp.ncbi.nih.gov/snp/organisms/human_9606_b150_GRCh37p13/VCF/All_20170710.vcf.gz
		echo
		wget --directory-prefix=$REPLY/RefAnnotationData/ ftp://ftp.ncbi.nih.gov/snp/organisms/human_9606_b150_GRCh37p13/VCF/All_20170710.vcf.gz
		wget --directory-prefix=$REPLY/RefAnnotationData/ ftp://ftp.ncbi.nih.gov/snp/organisms/human_9606_b150_GRCh37p13/VCF/All_20170710.vcf.gz.tbi
	
	
	fi
	
	
	
	# STEP 1: Convert the Plink BED/BIM/FAM into a VCF into a BCF so that it may be fixed with BCFtools
	# --------------------------------------------------------------------------------------------------
	
	if [ "${DataPrepStep1,,}" == "t" ]; then
		
		
		# Convert Plink file into a VCF
		
		printf "\n\nConverting $RawData Plink files into VCF format \n"
		echo ----------------------------------------------
		echo
		echo
	
		${Plink_Exec} --bfile $REPLY/${RawData}_oddysseyData --recode vcf --out $REPLY/${RawData}_oddysseyData/TEMP/DataFixStep1_${RawData}
	
	# Convert from a VCF into a BCF and also rename the chromosomes to match the reference fasta (where [chr]23 is X, 24 is Y, etc.)
		
		printf "\n\nConverting VCF into a BCF with chromosome names that match the reference .fasta annotation \n\nNOTE: You may need to manually adjust $REPLY/Odyssey/RefAnnotationData/PlinkChrRename.txt depending on the fasta reference you use in order to match the chromosome names \n"
		echo ----------------------------------------------
		echo
		echo
	
		bcftools annotate -Ob --rename-chrs $REPLY/RefAnnotationData/PlinkChrRename.txt $REPLY/${RawData}_oddysseyData/TEMP/DataFixStep1_${RawData}.vcf > $REPLY/${RawData}_oddysseyData/TEMP/DataFixStep1_${RawData}.bcf
	
	fi
	
	
	
	
	# STEP 2: Align Input File to the Reference Annotation (Fix with BCFtools)
	# --------------------------------------------------------------------------------------------------
	
	if [ "${DataPrepStep2,,}" == "t" ]; then
	
	# Run bcftools +fixref to see the number of wrong SNPs
		printf "\n\nRun bcftools +fixref to first view the number of correctly annotated/aligned variants to the Reference annotation \n"
		echo ----------------------------------------------
		echo
		echo
	
		bcftools +fixref $REPLY/${RawData}_oddysseyData/TEMP/DataFixStep1_${RawData}.bcf -- -f $REPLY/RefAnnotationData/human_g1k_v37.fasta.gz
	
	# Run bcftools to fix/swap the allels based on the downloaded annotation file
		printf "\n\nRun bcftools +fixref to fix allels based on the downloaded annotation file \n"
		echo ----------------------------------------------
		echo
		echo
	
		bcftools +fixref $REPLY/${RawData}_oddysseyData/TEMP/DataFixStep1_${RawData}.bcf -Ob -o $REPLY/${RawData}_oddysseyData/TEMP/DataFixStep2_${RawData}-RefFixed.bcf -- -d -f $REPLY/RefAnnotationData/human_g1k_v37.fasta.gz -i $REPLY/RefAnnotationData/All_20170710.vcf.gz
	
	# Rerun the bcftool +fixref check to see if the file has been fixed and all unmatched alleles have been dropped
		printf "\n\nRun bcftools +fixref to see if the file has been fixed - all alleles are matched and all unmatched alleles have been dropped \n"
		echo ----------------------------------------------
		echo
		echo
	
		bcftools +fixref $REPLY/${RawData}_oddysseyData/TEMP/DataFixStep2_${RawData}-RefFixed.bcf -- -f $REPLY/RefAnnotationData/human_g1k_v37.fasta.gz
		
	fi
	
	
	# STEP 3: Sort the Ref-Aligned BCF output and convert back into Plink format for Odyssey Pipeline
	# --------------------------------------------------------------------------------------------------
	
	if [ "${DataPrepStep3,,}" == "t" ]; then
	
	
	# Sort the BCF output
		printf "\n\nSorting the BCF output since fixing it may have made it unsorted \n"
		echo ----------------------------------------------
	
		(bcftools view -h $REPLY/${RawData}_oddysseyData/TEMP/DataFixStep2_${RawData}-RefFixed.bcf; bcftools view -H $REPLY/${RawData}_oddysseyData/TEMP/DataFixStep2_${RawData}-RefFixed.bcf | sort -k1,1d -k2,2n;) | bcftools view -Ob -o $REPLY/${RawData}_oddysseyData/TEMP/DataFixStep3_${RawData}-RefFixedSorted.bcf
		
		printf "Done \n\n\n"
	
	# Convert BCF back into Plink .bed/.bim/.fam for Shapeit2 Phasing
		printf "\n\nConverting Fixed and Sorted BCF back into Plink .bed/.bim/.fam \n"
		echo ----------------------------------------------
		echo
		echo
	
		${Plink_Exec} --bcf $REPLY/${RawData}_oddysseyData/TEMP/DataFixStep3_${RawData}-RefFixedSorted.bcf --make-bed --out $REPLY/${RawData}_oddysseyData/TEMP/DataFixStep3_${RawData}-RefFixSorted
		
		
	# Finally Remove any positional duplicates 
		# i.e. same position and alleles, but differently named variants since Shapeit will not tolerate these
	
	
		printf "\n\nFinding Positional and Allelic Duplicates \n"
		echo ----------------------------------------------
		echo
		echo
	
		${Plink_Exec} --bfile $REPLY/${RawData}_oddysseyData/TEMP/DataFixStep3_${RawData}-RefFixSorted --list-duplicate-vars ids-only suppress-first --out $REPLY/${RawData}_oddysseyData/TEMP/Dups2Remove
		
		# Report Number of duplicates:
		DuplicateNumber="$(wc $REPLY/${RawData}_oddysseyData/TEMP/Dups2Remove.dupvar | awk '{print $1}')"
		
		printf "\n\nRemoving Positional and Allelic Duplicates if they exist\nFound ${DuplicateNumber} Duplicate Variant/s\n"
		echo ----------------------------------------------
		echo
		echo
	
		${Plink_Exec} --bfile $REPLY/${RawData}_oddysseyData/TEMP/DataFixStep3_${RawData}-RefFixSorted --exclude $REPLY/TEMP/Dups2Remove.dupvar --make-bed --out $REPLY/${RawData}_oddysseyData/TEMP/DataFixStep4_${RawData}-RefFixSortedNoDups
		
		
		
	
	# Add back in the sex information
		printf "\n\nRestoring Sample Sex Information \n"
		echo ----------------------------------------------
		echo
		echo
		
		mkdir -p $REPLY/${RawData}_oddysseyData/${RawData}_Step0out/TargetData
		
		${Plink_Exec} --bfile $REPLY/${RawData}_oddysseyData/TEMP/DataFixStep4_${RawData}-RefFixSortedNoDups --update-sex $REPLY/${RawData}_oddysseyData/${RawData}.fam 3 --make-bed --out $REPLY/${RawData}_oddysseyData/${RawData}_Step0out/TargetData/DataFixStep5_${RawData}-PhaseReady
		

		echo
		echo
		echo ----------------------------------------------
		printf "Analysis Ready Data -- DataFixStep5_${RawData}-PhaseReady -- Output to --> $REPLY/${RawData}_oddysseyData/${RawData}_Step0out/TargetData/DataFixStep5_${RawData}-PhaseReady \n"
		echo ----------------------------------------------
	
	
	
	fi
	
	# After Step: Cleanup File Intermediates 
	# --------------------------------------------------------------------------------------------------
	
	if [ "${SaveDataPrepIntermeds,,}" == "f" ]; then
	
		echo 
		echo ----------------------------------------------
		echo Tidying Up -- Cleanup Intermediate Files
		echo ----------------------------------------------
	
		if [ -d "$REPLY/${RawData}_oddysseyData/TEMP" ]; then rm -r $REPLY/${RawData}_oddysseyData/TEMP; fi
	
	fi
	
elif [ "${PerformFixref,,}" == "f" ]; then

	#Make Temp Directory in which all Temp files will populate
		mkdir -p $REPLY/${RawData}_oddysseyData/TEMP

		
	# Finally Remove any positional duplicates 
		# i.e. same position and alleles, but differently named variants since Shapeit will not tolerate these
	
		printf "\n\nFinding Positional and Allelic Duplicates \n"
		echo ----------------------------------------------
		echo
		echo
	
		${Plink_Exec} --bfile $REPLY/${RawData}_oddysseyData --list-duplicate-vars ids-only suppress-first --out $REPLY/${RawData}_oddysseyData/TEMP/Dups2Remove
		
		printf "\n\nRemoving Positional and Allelic Duplicates \n"
		echo ----------------------------------------------
		echo
		echo
	
		${Plink_Exec} --bfile $REPLY/${RawData}_oddysseyData --exclude $REPLY/${RawData}_oddysseyData/TEMP/Dups2Remove.dupvar --make-bed --out $REPLY/$${RawData}_oddysseyData/${RawData}_Step0out/TargetData/DataFixStep5_${RawData}-PhaseReady
		
	if [ "${SaveDataPrepIntermeds,,}" == "f" ]; then
	
		echo 
		echo ----------------------------------------------
		echo Tidying Up -- Cleanup Intermediate Files
		echo ----------------------------------------------
	
		if [ -d "$REPLY/${RawData}*/TEMP" ]; then rm -r $REPLY/${RawData}*/TEMP; fi
		#rm ./0_DataPrepModule/DataFixStep*
	
	fi
		
		
		echo
		echo
		echo ----------------------------------------------
		printf "Analysis Ready Data -- DataFixStep5_${RawData}-PhaseReady -- Output to --> $REPLY/${RawData}_oddysseyData/${RawData}_Step0out/TargetData/DataFixStep5_${RawData}-PhaseReady \n"
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
	printf "Data QC-Visualization\n----------------\n\nPreparing to perform QC analysis on the SINGLE Plink .bed/.bim/.fam dataset within:\n.$REPLY/${RawData}_oddysseyData/${RawData}_Step0out/TargetData/\n\nNOTE: If no data is present, then this analysis will be skipped \n\nAll Data and Plots will be saved to $REPLY/${RawData}*/${RawData}_Step0out/TargetData"
	printf "\n--------------------------------\n\n"

	# Executes the Rscript to analyze and visualize the GWAS analysis

		Arg6="$REPLY/${RawData}_oddysseyData/${RawData}_Step0out/TargetData";
		Arg7="${X11}";

		${Rscript} ./1_Target/.1_PreGWAS-QC.R $Arg6 $Arg7

	# Copy the Analysis Data to the Quick Results Folder
		echo
		echo
		echo "Copying Analysis Data and Visualizations to Quick Results Folder"
		echo ------------------------------------------------------------------
		cp -R $REPLY/${RawData}_oddysseyData/${RawData}_Step0out/TargetData/Dataset_QC-Visualization $REPLY/${RawData}_oddysseyData/5_QuickResults/${RawData}_results/

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


# export VARIABLENAME=$REPLY/${RawData}
 #echo -e 'source("./1_Target/.1_PreGWAS-QC.R") \n \n q()' | R --no-save --slave

	
# Termination Message
	echo
	echo ============
	echo " Phew Done!"
	echo ============
	echo
	echo
	
