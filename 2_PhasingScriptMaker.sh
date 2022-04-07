#!/bin/bash

## Overview:
## ==================

## This script will:
# 1) Create the Bash scripts used to execute Phasing jobs (autosomal and the X chromosome) on a system
# 2) Submit the Bash scripts to the HPC queue at the user's request

# Splash Screen
# --------------
source .TitleSplash.txt
printf "$Logo"

# Source from .config files (Program options via Settings.conf & Program execs via Programs.conf)
# ----------------------------
oddysseyPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source $oddysseyPath/Settings.conf

# Load Odysseys Dependencies -- pick from several methods
if [ "${OdysseySetup,,}" == "one" ]; then
	echo
	printf "\n\nLoading Odyssey's Singularity Container Image \n\n"
	source $oddysseyPath/Configuration/Setup/Programs-Singularity.conf

elif [ "${OdysseySetup,,}" == "two" ]; then
	echo
	printf "\n\nLoading Odyssey's Manually Configured Dependencies \n\n"
	source $oddysseyPath/Configuration/Setup/Programs-Manual.conf
else

	echo
	echo User Input Not Recognized -- Please specify One or Two for OdysseySetup
	echo Exiting Dependency Loading
	echo
	exit
fi

# Set Working Directory
# ------------------------
printf "\nCurrent Working Directory\n"
echo ----------------------------------------------
echo $PWD

# Creating Imputation Project Folders within Phase Directory
# -----------------------------------------------------------
printf "\nCreating Imputation Project Folder within Phase Directory\n\n"

mkdir Reference
mkdir ${BaseName}_Phasing
mkdir ${BaseName}_Phasing/Scripts2Shapeit

# Perform Lustre Stripping?
if [ "${LustreStrip,,}" == "t" ]; then
	lfs setstripe -c 2 $DATADIR${BaseName}_Phasing
fi

## --------------------------------------------------------------------------------------
## ===========================================
##         Download Default Ref Data
## ===========================================
## --------------------------------------------------------------------------------------

if [ "${DownloadDefaultRefPanel,,}" == "t" ]; then

	printf "\nDownloading Default Ref Panel \nDetermining Phasing and 
Imputation Program Requested From Settings.conf\n "
	echo "---------------------------------------------"
	echo

	# Make sure troublesome combos are not coded -- i.e. requesting several phasing or several imputations
	if ([ "${UseShapeit,,}" == "t" ] && [ "${UseEagle,,}" == "t" ]) || ([ "${UseShapeit,,}" == "f" ] && [ "${UseEagle,,}" == "f" ]); then

		printf "\nCombo Not Possible. Specify a single Phasing Program to Use -- Exiting\n\n "
		exit

	# Valid Phase/Impute Combinations
	elif ([ "${UseShapeit,,}" == "t" ] && [ "${UseMinimac,,}" == "t" ]) || ([ "${UseEagle,,}" == "t" ] && [ "${UseMinimac,,}" == "t" ]); then

		printf "Good Phase/Impute Combination Proceeding...\n\n"

		# ================================Use Shapeit================================
		if [ "${UseShapeit,,}" == "t" ]; then

			# ====================================== Use Shapeit-Minimac ====================================
			if [ "${UseMinimac,,}" == "t" ]; then
				printf "Using a Shapeit-Minimac Combo Downloading Necessary Default Ref Files"

				# Retrieves the (default) Reference Genome from the IMPUTE Website
				# ----------------------------------------------------------------------------------
				# Collects the 1000Genome Reference Build from the Impute Site
				#(https://mathgen.stats.ox.ac.uk/impute/1000GP_Phase3.html)
				# Reference Build Specs: 1,000 Genomes haplotypes -- Phase 3 integrated variant set release in NCBI build 37 (hg19) coordinates
				# Ref Build Updated Aug 3 2015

				printf "\n\nRetrieving 1K Genome Phase 3 Ref Panel and hg19 Genetic Map from Impute2 Website \n-------------------------------------------------------------------------------\n\n\n"
				wget -nc --directory-prefix=./Reference/ https://mathgen.stats.ox.ac.uk/impute/1000GP_Phase3.tgz --no-check-certificate
				wget -nc --directory-prefix=./Reference/ https://mathgen.stats.ox.ac.uk/impute/1000GP_Phase3_chrX.tgz --no-check-certificate

				#Unzip the packaged ref panel
				printf "\n\nUnpackaging Ref Panel \n--------------------------\n\n"
				tar -xvzf ./Reference/1000GP_Phase3.tgz -C Reference/
				tar -xvzf ./Reference/1000GP_Phase3_chrX.tgz -C Reference/

				# Since untar makes an additional directory, move all the files from the 1000GP_Phase3 folder and move it into the Ref Directory
				printf "\n\nCleaning Up \n-------------------\n\n"
				mv ./Reference/1000GP_Phase3/* ./Reference/

				# Delete the now empty directory and the tgz zipped Ref panel
				rmdir ./Reference/1000GP_Phase3/
				rm ./Reference//1000GP_Phase3.tgz

				# Remove the .hap.gz and .legend.gz files since we are using the Minimac mvcf Ref Panel
				rm ./Reference/*hap.gz
				rm ./Reference/*legend.gz

				# Download the Minimac4 mvcf
				wget -nc --directory-prefix=./Reference/ ftp://share.sph.umich.edu/minimac3/G1K_P3_M3VCF_FILES_WITH_ESTIMATES.tar.gz

				#Unpack
				tar -xvzf ./Reference/G1K_P3_M3VCF_FILES_WITH_ESTIMATES.tar.gz -C Reference/

				# Remove original .tar.gz Minimac Ref Panel
				rm ./Reference/G1K_P3_M3VCF_FILES_WITH_ESTIMATES.tar.gz

			else
				printf "Invalid Phasing/Imputation Program Combo -- Exiting \n\n"
				exit
			fi

		# ================================Use Eagle================================
		elif [ "${UseEagle,,}" == "t" ]; then

			# ====================================== Use Eagle-Minimac ======================================
			if [ "${UseMinimac,,}" == "t" ]; then
				printf "Using a Eagle-Minimac Combo Downloading Necessary Default Ref Files"

				# Download the Minimac4 mvcf
				wget -nc --directory-prefix=./Reference/ ftp://share.sph.umich.edu/minimac3/G1K_P3_M3VCF_FILES_WITH_ESTIMATES.tar.gz
				wget -nc --directory-prefix=./Reference/ https://data.broadinstitute.org/alkesgroup/Eagle/downloads/tables/genetic_map_hg19_withX.txt.gz

				#Unpack
				printf "\n\nUnpackaging Ref Panel \n--------------------------\n\n"
				tar -xzf ./Reference/G1K_P3_M3VCF_FILES_WITH_ESTIMATES.tar.gz -C ./Reference/
				${gzip_Exec} -dc <./Reference/genetic_map_hg19_withX.txt.gz >./Reference/genetic_map_hg19_withX.txt

				# Remove original .tar.gz Minimac Ref Panel
				rm ./Reference/*tar.gz

			else
				printf "Invalid Phasing/Imputation Program Combo -- Exiting \n\n"
				exit
			fi
		fi

	else
		printf "Invalid Phasing/Imputation Program Combo -- Exiting \n\n"
		exit
	fi

elif [ "${DownloadDefaultRefPanel,,}" == "f" ]; then

	printf "\nWill Not Download Default Phasing and Imputation Ref Panels\nIn This Case Make Sure the Proper Genetic Map File/s and Ref Panel are Located in the ./Reference Directory \n\nRefer to the Reference Dataset Section in Settings.conf for Supported Reference Naming Schemes\n"
	echo "---------------------------------------------"
	echo

else
	printf "Command Not Recognized Please Specify either T or F for DownloadRefPanel -- Exiting \n\n"
	exit
fi

## --------------------------------------------------------------------------------------
## ===========================================
##          Phasing Using Shapeit2
## ===========================================
## --------------------------------------------------------------------------------------

if [ "${UseShapeit,,}" == "t" ]; then

	printf "\n\nUsing Shapeit for Phasing\n=======================\n\n"

	## -------------------------------------------
	## Phasing Script Creation for Autosomes (Chr1-22)
	## -------------------------------------------
	if [ "${PhaseAutosomes,,}" == "t" ]; then

		#Set Chromosome Start and End Parameters
		for chr in $(eval echo {$PhaseChrStart..$PhaseChrEnd}); do

			#Search the reference directory for the chromosome specific reference map, legend, and hap files and create their respective variables on the fly

			printf "\n\nProcessing Chromosome ${chr} Script \n"
			echo -----------------------------------

			echo "Pre-Check: Looking in ./Reference For Reference Files "
			echo "Found the Following Shapeit References for Chromosome ${chr}: "

			GeneticMap="$(ls ./Reference/ | egrep --ignore-case ".*map.*chr${chr}[^[:digit:]]{1}.*|.*chr${chr}[^[:digit:]]{1}.*map.*")"
			printf "   Genetic Map File: $GeneticMap \n"
			HapFile="$(ls ./Reference/ | egrep --ignore-case ".*chr${chr}[^[:digit:]]{1}.*hap\.gz")"
			printf "   Haplotpe File: $HapFile \n"
			LegendFile="$(ls ./Reference/ | egrep --ignore-case ".*chr${chr}[^[:digit:]]{1}.*legend\.gz")"
			printf "   Legend File: $LegendFile \n \n"

			echo "#!/bin/bash


# Phase Command to Phase Chromosomes
	# Manual Command to Run:
	# qsub -l nodes=1:ppn=${PhaseThreads},vmem=${Phase_Memory}gb,walltime=${Phase_Walltime} -M ${Email} -m ae -j oe -o  ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr${chr}_P.out -N PChr${chr}_${BaseName}  ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr${chr}_P.sh
			

${Shapeit2_Exec} \
--thread ${PhaseThreads} \
--input-bed ${BaseName}_Imputation/Ody2_${BaseName}_PhaseReady.chr${chr} \
--input-map ./Reference/${GeneticMap} \
-O ${BaseName}_Phasing/Ody3_${BaseName}_Chr${chr}_Phased.haps.gz ${BaseName}_Phasing/Ody3_${BaseName}_Chr${chr}_Phased.sample \
--output-log ${BaseName}_Phasing/Ody3_${BaseName}_Chr${chr}_Phased.log" >${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr${chr}_P.sh

			# Toggle that will turn script submission on/off
			# -----------------------------------------------

			if [ "${ExecutePhasingScripts,,}" == "t" ]; then

				if [ "${HPS_Submit,,}" == "t" ]; then

					echo
					echo Submitting Phasing script to HPC Queue
					echo
					qsub -l nodes=1:ppn=${PhaseThreads},vmem=${Phase_Memory}gb,walltime=${Phase_Walltime} -M ${Email} -m ae -j oe -o ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr${chr}_P.out -N PChr${chr}_${BaseName} ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr${chr}_P.sh
					sleep 0.2
				else
					echo
					echo Submitting Phasing script to Desktop Queue
					echo
					bash ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr${chr}_P.sh >${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr${chr}_P.out 2>&1 &

				fi
			fi

		done
	elif [ "${PhaseAutosomes,,}" == "f" ]; then
		printf "\n\n---Ok Will Not Phase the Autosomes---\n\n"

	fi

	## ---------------------------------------
	## Extra Step to Phase the X Chromosome
	## ---------------------------------------

	if [ "${PhaseX,,}" == "t" ]; then

		## -------------------------------------------
		## Phasing Script Creation for HPC (Chr23/X)
		## -------------------------------------------

		printf "\n\nProcessing X Chromosome Script \n"
		echo -----------------------------------

		# Search the reference directory for the X chromosome specific reference map, legend, and hap files and create their respective variables on the fly

		echo "Pre-Check: Looking in ./Reference For Reference Files "
		echo "Found the Following Shapeit References for Chromosome X: "

		XGeneticMap="$(ls ./Reference/ | egrep --ignore-case ".*map.*${XChromIdentifier}.*|.*${XChromIdentifier}.*map.*")"
		printf "   Genetic Map: $XGeneticMap \n"
		XHapFile="$(ls ./Reference/ | egrep --ignore-case ".*${XChromIdentifier}.*hap\.gz")"
		printf "   Haplotpe File: $XHapFile \n"
		XLegendFile="$(ls ./Reference/ | egrep --ignore-case ".*${XChromIdentifier}.*legend\.gz")"
		printf "   Legend File: $XLegendFile \n \n"

		echo "#!/bin/bash

#cd .

# Phase Command to Phase X Chromosome
	# Manual Command to Run:
	# qsub -l nodes=1:ppn=${PhaseThreads},vmem=${Phase_Memory}gb,walltime=${Phase_Walltime} -M ${Email} -m ae -j oe -o  ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr23_P.out -N PChr23_${BaseName}  ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr23_P.sh



${Shapeit2_Exec} \
--thread ${PhaseThreads} \
--chrX \
--input-bed ${BaseName}_Imputation/Ody2_${BaseName}_PhaseReady.chr23 \
--input-map ./Reference/${XGeneticMap} \
-O ${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased.haps.gz ${BaseName}_Phasing/Ody3_${BaseName}_Chr23}_Phased.sample \
--output-log ${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased.log" >${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr23_P.sh

		# Toggle that will turn script submission on/off
		# -----------------------------------------------

		if [ "${ExecutePhasingScripts,,}" == "t" ]; then

			if [ "${HPS_Submit,,}" == "t" ]; then

				echo
				echo Submitting Phasing script to HPC Queue
				echo
				qsub -l nodes=1:ppn=${PhaseThreads},vmem=${Phase_Memory}gb,walltime=${Phase_Walltime} -M ${Email} -m ae -j oe -o ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr23_P.out -N PChr23_${BaseName} ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr23_P.sh
				sleep 0.2
			else
				echo
				echo Submitting Phasing script to Desktop Queue
				echo
				sh ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr23_P.sh >${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr23_P.out 2>&1 &
			fi
		fi
	elif [ "${PhaseX,,}" == "f" ]; then
		printf "\n\n---Ok Will Not Phase the X Chromosome---\n\n"
	fi
fi

## --------------------------------------------------------------------------------------
## ===========================================
##          Phasing Using Eagle2
## ===========================================
## --------------------------------------------------------------------------------------

if [ "${UseEagle,,}" == "t" ]; then

	printf "\n\nUsing Eagle for Phasing\n=======================\n\n"

	## -------------------------------------------
	## Phasing Script Creation for Autosomes (Chr1-22)
	## -------------------------------------------
	if [ "${PhaseAutosomes,,}" == "t" ]; then

		#Set Chromosome Start and End Parameters
		for chr in $(eval echo {$PhaseChrStart..$PhaseChrEnd}); do

			#Search the reference directory for the chromosome specific reference map, legend, and hap files and create their respective variables on the fly

			printf "\n\nProcessing Chromosome ${chr} Script \n"
			echo -----------------------------------

			echo "Pre-Check: Looking in ./Reference For Reference Files "
			echo "Found the Following Eagle References for Chromosome ${chr}: "

			GeneticMap="$(ls ./Reference/ | egrep --ignore-case ".*genetic_map.*")"
			printf "   Genetic Map File: $GeneticMap \n"

			echo "#!/bin/bash


#cd .

# Phase Command to Phase Chromosomes
	# Manual Command to Run:
	# qsub -l nodes=1:ppn=${PhaseThreads},vmem=${Phase_Memory}gb,walltime=${Phase_Walltime} -M ${Email} -m ae -j oe -o  ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr${chr}_P.out -N PChr${chr}_${BaseName}  ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr${chr}_P.sh
			

## Execute Phasing without a ref dataset

printf '\n\n'	
echo ========================================
printf 'Phase Chr${chr} Using Eagle\n'
echo ========================================
printf '\n\n'
	
${Eagle2_Exec} --bfile ${BaseName}_Imputation/Ody2_${BaseName}_PhaseReady.chr${chr} \
--geneticMapFile=./Reference/${GeneticMap} \
--outPrefix=${BaseName}_Phasing/Ody3_${BaseName}_Chr${chr}_Phased \
--chrom ${chr} \
--numThreads ${PhaseThreads}

#Unzip Phased Output

printf '\n\n'	
echo ========================================
printf 'Gzip Chr${chr}\n'
echo ========================================
printf '\n\n'

${gzip_Exec} -dc <  ${BaseName}_Phasing/Ody3_${BaseName}_Chr${chr}_Phased.haps.gz >  ${BaseName}_Phasing/Ody3_${BaseName}_Chr${chr}_Phased.haps" >${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr${chr}_P.sh

			# Toggle that will turn script submission on/off
			# -----------------------------------------------

			if [ "${ExecutePhasingScripts,,}" == "t" ]; then

				if [ "${HPS_Submit,,}" == "t" ]; then

					echo Submitting Phasing script to HPC Queue
					echo
					qsub -l nodes=1:ppn=${PhaseThreads},vmem=${Phase_Memory}gb,walltime=${Phase_Walltime} -M ${Email} -m ae -j oe -o ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr${chr}_P.out -N PChr${chr}_${BaseName} ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr${chr}_P.sh
					sleep 0.2
				else

					echo Submitting Phasing script to Desktop Queue
					echo
					bash ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr${chr}_P.sh >${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr${chr}_P.out 2>&1 &

				fi
			fi

		done
	elif [ "${PhaseAutosomes,,}" == "f" ]; then
		printf "\n\n---Ok Will Not Phase the Autosomes---\n\n"
	fi

	## ---------------------------------------
	## Extra Step to Phase the X Chromosome
	## ---------------------------------------

	if [ "${PhaseX,,}" == "t" ]; then

		## -------------------------------------------
		## Phasing Script Creation for HPC (Chr23/X)
		## -------------------------------------------

		printf "\n\nProcessing X Chromosome Script \n"
		echo -----------------------------------

		#Search the reference directory for the chromosome specific reference map, legend, and hap files and create their respective variables on the fly

		echo "Pre-Check: Looking in ./Reference For Reference Files "
		echo "Found the Following Eagle References for Chromosome X: "

		GeneticMap="$(ls ./Reference/ | egrep --ignore-case ".*genetic_map.*")"
		printf "   Genetic Map File: $GeneticMap \n"

		echo "#!/bin/bash

#cd .

# Phase Command to Phase X Chromosome
	# Manual Command to Run:
	# qsub -l nodes=1:ppn=${PhaseThreads},vmem=${Phase_Memory}gb,walltime=${Phase_Walltime} -M ${Email} -m ae -j oe -o  ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr23_P.out -N PChr23_${BaseName}  ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr23_P.sh
			

## Execute Phasing without a ref dataset
	
${Eagle2_Exec} --bfile ${BaseName}_Imputation/Ody2_${BaseName}_PhaseReady.chr23 \
--geneticMapFile=./Reference/${GeneticMap} \
-O  ${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased.haps.gz  ${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased.sample \
--chrom 23 \
--numThreads ${PhaseThreads}

#Unzip Phased Output

${gzip_Exec} -dc <  ${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased.haps.gz >  ${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased.haps" >${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr23_P.sh

		# Toggle that will turn script submission on/off
		# -----------------------------------------------

		if [ "${ExecutePhasingScripts,,}" == "t" ]; then

			if [ "${HPS_Submit,,}" == "t" ]; then

				echo Submitting Phasing script to HPC Queue
				echo
				qsub -l nodes=1:ppn=${PhaseThreads},vmem=${Phase_Memory}gb,walltime=${Phase_Walltime} -M ${Email} -m ae -j oe -o ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr23_P.out -N PChr23_${BaseName} ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr23_P.sh
				sleep 0.2
			else

				echo Submitting Phasing script to Desktop Queue
				echo
				bash ${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr23_P.sh >${BaseName}_Phasing/Scripts2Shapeit/${BaseName}_Chr23_P.out 2>&1 &
			fi
		fi
	elif [ "${PhaseX,,}" == "f" ]; then
		printf "\n\n---Ok Will Not Phase the X Chromosome---\n\n"
	fi
fi

# Termination Message
echo
echo ============
echo " Phew Done!"
echo ============
echo
echo
