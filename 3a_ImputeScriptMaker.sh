#!/bin/bash

## Overview:
## ==================

## This script will:
# 1) Create the Bash scripts used to execute Imputation jobs (autosomal and the X chromosome) on a system
# 2) Submit the Bash scripts to the HPC queue at the user's request

## ==========================================================================================

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
	printf "\n\nLoading Odysseys Singularity Container Image \n\n\n"
	source $oddysseyPath/Configuration/Setup/Programs-Singularity.conf

elif [ "${OdysseySetup,,}" == "two" ]; then
	echo
	printf "\n\nLoading Odysseys Manually Configured Dependencies \n\n\n"
	source $oddysseyPath/Configuration/Setup/Programs-Manual.conf
else

	echo
	echo User Input Not Recognized -- Please specify One or Two
	echo Exiting Dependency Loading
	echo
	exit
fi
# Set Working Directory
# -------------------------------------------------
echo
echo Changing to Working Directory
echo ----------------------------------------------
echo $PWD
echo
echo
cd $dataPath

# ======================================================================================================
# ======================================================================================================
#                                       Error Check for Shapeit
# ======================================================================================================
# ======================================================================================================

if [ "${UseShapeit,,}" == "t" ]; then

	# Perform Error Analysis on Phasing Step -- grep looks for .out files containing 'Killed', 'Aborted', 'segmentation', or 'error'
	# -----------------------------

	if [ "${PhasingErrorAnalysis,,}" == "t" ]; then

		echo
		echo --------------------------------------------------------
		echo Performing Error Analysis on Phasing Jobs:
		echo --------------------------------------------------------
		echo
		echo
		echo Phasing jobs that should be reviewed are listed:
		echo It may take a while to scan all the .out files
		echo ==============================================
		echo
		find ./${BaseName}_Phasing/Scripts2Shapeit -maxdepth 1 -type f -print | xargs grep -rli 'Killed\|Aborted\|segmentation\|error' | sort -V
		echo
		echo ==============================================
		echo

		# Examine the failed files?
		echo
		echo "The files listed above appeared to have failed."
		echo "Would you like more details on why they failed (this will print the line that contains the error for each failed file)?"
		echo "(y/n)?"
		echo --------------------------------------------------
		read UserInput1
		echo
		echo

		if [ "${UserInput1}" == "y" ]; then

			echo
			echo "Outputting more details on failed file/s..."
			echo ===========================================
			echo
			find ./${BaseName}_Phasing/Scripts2Shapeit -maxdepth 1 -type f -print | xargs grep -ri 'Killed\|Aborted\|segmentation\|error' | sort -V
			echo
			echo ===========================================

		else
			if [ "${UserInput1,,}" == "n" ]; then

				echo "Alright, will not output more details on failed file/s"
				echo =========================================================
				echo

			else
				echo "Input not recognized -- specify either 'y' or 'n' -- exiting Error Analysis"
				echo ================================================================================
				echo
			fi
		fi

		# Re-submit the failed scripts
		echo
		echo "Would you like to resubmit the failed scripts?"
		echo "Script/s will be submitted to an HPS if specified in Settings.conf otherwise will submit via a simple 'sh' command"
		echo "(y/n)?"
		echo --------------------------------------------------
		read UserInput2
		echo
		echo

		if [ "${UserInput2,,}" == "y" ]; then

			# Specify text document of failed scripts to re-run; manual script re-submission
			echo
			echo "Normally ALL the failed scripts will be re-submitted"
			echo "However, you can provide a text doc that contains a list of the scripts you would like re-submitted"
			echo "Would you prefer to manually provide this list?"
			echo "Note: The file should contain the full path to the automatically created scripts you want re-submitted"
			echo "Note: Each script should be listed on a new line of the text document"
			echo "(y/n)?"
			echo --------------------------------------------------
			read UserInput3
			echo
			echo
			if [ "${UserInput3,,}" == "y" ]; then
				echo "You Said Yes to Manual Script Submission So Please Provide the Full Path to the Re-Submission Text Doc"
				read UserInput4
				echo "Using Text Doc: ${UserInput4} for manual script submission"

			elif [ "${UserInput3}" == "n" ]; then
				echo
			else
				echo "User Input not recognized -- please specify 'y' or 'n' -- ignoring input"

			fi

			if [ "${HPS_Submit,,}" == "t" ]; then

				echo
				echo Re-Submitting Failed Scripts to HPS...
				echo ===========================================
				echo
				# The following line does a lot:
				# 1) looks in the script directory that also contains output logs
				# 2) find .out files that contain the words 'Killed', 'Aborted', 'segmentation', or 'error'
				# 3,4) Sorts the .out files and subs .out for .sh to get the script
				# 5) Within .sh should be a manual execution command that starts with '# qsub', grep finds the line and trims the off the '# ' to get the qsub command and saves it to ReSubmitPhaseJobs.txt
				find ${BaseName}_Phasing/Scripts2Shapeit -maxdepth 1 -type f -print | xargs grep -rli 'Killed\|Aborted\|segmentation\|error' | sort -V | sed 's/.out/.sh/g' | xargs grep -r 'qsub' | sed 's/.*# //' >ReSubmitPhaseJobs.txt

				# Manually read in scripts that need to be re-run (comment out previous command if you want to use this manual override
				#cat ${BaseName}_Phasing/Scripts2Resubmit.txt | sort -V | sed 's/.out/.sh/g' | xargs grep -r 'qsub' | sed 's/.*# //' > ReSubmitPhaseJobs.txt

				# Remove the errored .out file (otherwise the new .out will be appended to the old and the error will never be reported as fixed)
				find ${BaseName}_Phasing/Scripts2Shapeit -maxdepth 1 -type f -print | xargs grep -rli 'Killed\|Aborted\|segmentation\|error' | sort -V | xargs rm -f

				# Read the file that contains the scripts that need to be re-submitted and submit then via Bash to the HPS queue
				cat ReSubmitPhaseJobs.txt | bash

				# Remove ReSubmitJobs.txt
				rm -f ReSubmitPhaseJobs.txt

				echo
				echo ===========================================
				echo

			else
				echo
				echo Re-Submitting Failed Scripts to Desktop...
				echo ===========================================
				echo
				# The following line does a lot:
				# 1) looks in the script directory that also contains output
				# 2) find .out files that contain the words 'Killed', 'Aborted', 'segmentation', or 'error'
				# 3,4) Sorts the .out files and subs .out for .sh to get the script
				# 5) Within .sh should be a manual execution command that starts with 'time ', grep finds the line and saves it to ReSubmitPhaseJobs.txt
				find ${BaseName}_Phasing/Scripts2Shapeit -maxdepth 1 -type f -print | xargs grep -rli 'Killed\|Aborted\|segmentation\|error' | sort -V | sed 's/.out/.sh/g' | xargs grep -r 'time ' >ReSubmitPhaseJobs.txt

				# Remove the errored .out file (otherwise the new .out will be appended to the old and the error will never be reported as fixed)
				find ${BaseName}_Phasing/Scripts2Shapeit -maxdepth 1 -type f -print | xargs grep -rli 'Killed\|Aborted\|segmentation\|error' | sort -V | xargs rm -f

				# Read the file that contains the scripts that need to be re-submitted and submit then via sh to the Linux workstation
				cat ReSubmitPhaseJobs.txt | bash

				# Remove ReSubmitJobs.txt
				rm -f ReSubmitPhaseJobs.txt

				echo
				echo ===========================================
				echo
			fi

		else

			if [ "${UserInput2,,}" == "n" ]; then

				echo "Alright, will not Re-Submit Failed Script/s"
				echo ==============================================
				echo
				echo

			else
				echo "Input Not Recognized -- Specify Either 'y' or 'n' -- Exiting Re-Submission"
				echo ==============================================================================
				echo
				echo
			fi
		fi
	fi
fi

## --------------------------------------------------------------------------------------
## ===========================================
##          Minimac Imputation
## ===========================================
## --------------------------------------------------------------------------------------

if [ "${UseMinimac,,}" == "t" ]; then
	# ---------------------------------------------
	## Toggle whether to Impute the Autosomes (Chr1-22)
	# ---------------------------------------------

	if [ "${ImputeAutosomes,,}" == "t" ]; then

		#Set Chromosome Start and End Parameters
		for chr in $(eval echo {$ImputeChrStart..$ImputeChrEnd}); do
			printf "\nProcessing Chromosome ${chr} Scripts \n"
			echo -----------------------------------

			#Search the reference directory for the chromosome specific reference map, legend, and hap files and create their respective variables on the fly
			echo "Looking in ./Reference For Minimac .m3vcf Reference Files "
			echo "Found the following references for Chromosome ${chr}: "

			MiniRef="$(ls ./Reference/ | egrep --ignore-case "^${chr}[^[:digit:]]{1}.*\.m3vcf\.gz")"
			printf "   $MiniRef \n"

			# Check to see if all reference files + genetic map exist
			if [[ -f ./Reference/${MiniRef} ]]; then

				# Create bash files to segment chromosomes by position and create imputation scripts
				echo
				echo All Necessary Reference Files Present for Chr${chr}
				echo
				echo Creating Scripts
				echo
				# Change to Working Directory
				cd ${WorkingDir}

				echo "#!/bin/bash
cd ${WorkingDir}
# Minimac Manual Command Used to re-run autosomal imputation in case of failure
	# qsub -l nodes=1:ppn=${ImputeThreads},vmem=${Impute_Memory}gb,walltime=${Impute_Walltime} -M ${Email} -m a -j oe -o ${BaseName}_Imputation/Scripts2Impute/Chr${chr}_${BaseName}_I.out -N IChr${chr}_${BaseName} ./${BaseName}_Imputation/Scripts2Impute/Chr${chr}_${BaseName}_I.sh
# Convert Chr Phased haps to VCF
printf '\n\n'	
echo ========================================
printf 'Convert Chr${chr} Phased .haps to .vcf\n'
echo ========================================
printf '\n\n'
${Shapeit2_Exec} -convert --input-haps ${BaseName}_Phasing/Ody3_${BaseName}_Chr${chr}_Phased --output-vcf ${BaseName}_Phasing/Ody3_${BaseName}_Chr${chr}_Phased.vcf.gz --output-log ${BaseName}_Phasing/Ody3_${BaseName}_Chr${chr}_Phased.vcf.log.temp
# Minimac Command ${BaseName}_Phasing
printf '\n\n'	
echo ========================================
printf 'Impute Chr${chr} Using Minimac\n'
echo ========================================
printf '\n\n'
${Minimac4_Exec} \
--cpus $ImputeThreads \
--allTypedSites --minRatio 0.00001 \
--refHaps ./Reference/${MiniRef} \
--haps ${BaseName}_Phasing/Ody3_${BaseName}_Chr${chr}_Phased.vcf.gz \
--prefix ./${BaseName}_Imputation/RawImputation/Ody4_${BaseName}_Chr${chr}" >./${BaseName}_Imputation/Scripts2Impute/Chr${chr}_${BaseName}_I.sh

				# Toggle that will turn script submission on/off
				# -----------------------------------------------

				if [ "${ExecuteImputationScripts,,}" == "t" ]; then

					if [ "${HPS_Submit,,}" == "t" ]; then

						echo
						echo
						echo Submitting Impute script to HPC Queue
						echo
						qsub -l nodes=1:ppn=${ImputeThreads},vmem=${Impute_Memory}gb,walltime=${Impute_Walltime} -M ${Email} -m a -j oe -o ${BaseName}_Imputation/Scripts2Impute/Chr${chr}_${BaseName}_I.out -N IChr${chr}_${BaseName} ./${BaseName}_Imputation/Scripts2Impute/Chr${chr}_${BaseName}_I.sh
					else

						echo
						echo Submitting Impute script to Desktop Queue
						echo
						bash ./${BaseName}_Imputation/Scripts2Impute/Chr${chr}_${BaseName}_I.sh >${BaseName}_Imputation/Scripts2Impute/Chr${chr}_${BaseName}_I.out 2>&1 &

					fi

				fi

			else
				echo
				echo All Necessary Reference Files Not Present
				echo Will Not Segment or Create Scripts
				echo
			fi
		done
	fi

	# ---------------------------------------------
	## Toggle whether to Impute the X Chromosome
	# ---------------------------------------------

	if [ "${ImputeX,,}" == "t" ]; then
		echo
		echo Processing X Chromosome Scripts
		echo -----------------------------------

		#Search the reference directory for the chromosome specific reference map, legend, and hap files and create their respective variables on the fly
		echo "Looking in ./Reference For Minimac .m3vcf Reference Files "
		echo "Found the following references for Chromosome X: "

		XMiniRef="$(ls ./Reference/ | egrep --ignore-case "^${XChromIdentifier}[^[:digit:]]{1}.*\.m3vcf\.gz")"
		printf "   Minimac Ref File: $XMiniRef \n"

		# Check to see if all reference files + genetic map exist
		if [[ -f ./Reference/${XMiniRef} ]]; then

			# Create bash files to segment chromosomes by position and create imputation scripts
			echo
			echo All Necessary Reference Files Present for Chr X
			echo Creating Scripts
			echo

			# Change to Working Directory
			cd ${WorkingDir}

			echo "#!/bin/bash
cd ${WorkingDir}
# Minimac Manual Command Used to re-run X chromosome imputation in case of failure
	# qsub -l nodes=1:ppn=${ImputeThreads},vmem=${Impute_Memory}gb,walltime=${Impute_Walltime} -M ${Email} -m a -j oe -o ${BaseName}_Imputation/Scripts2Impute/Chr23_${BaseName}_I.out -N IChr23_${BaseName} ./${BaseName}_Imputation/Scripts2Impute/Chr23_${BaseName}_I.sh
# Convert Chr Phased haps to VCF
	printf '\n\n'	
	echo ========================================
	printf 'Convert ChrX Phased .haps to .vcf\n'
	echo ========================================
	printf '\n\n'
	${Shapeit2_Exec} -convert --input-haps ${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased --output-vcf ${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased.vcf.temp --output-log ${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased.vcf.log.temp
# Format the VCF.gz so that Chr23 is XChromIdentifier
	printf '\n\n'	
	echo ========================================
	printf 'Relabel Chr23 .vcf to X and Gzip\n'
	echo ========================================
	printf '\n\n'
	
	# Get the header # rows from the VCF
		grep -w \"#\" ${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased.vcf.temp > ${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased.vcf
	
	# For some readon the column header row isn't taken so specifically ask for it	
		grep -w \"CHROM\" ${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased.vcf.temp >> .${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased.vcf
	
	#Get the rest of the VCF except this time replace 23 with 'X'
		awk '/^[^#]/ { first = \$1; \$1 = \"X\"; print \$0}' OFS='\t' ${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased.vcf.temp >> ${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased.vcf
		
	# Remove the Temp file
		rm .${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased.vcf.temp
	# Gzip the output 
		${gzip_Exec} ${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased.vcf
# Minimac Command
	printf '\n\n'	
	echo ========================================
	printf 'Impute ChrX Using Minimac\n'
	echo ========================================
	printf '\n\n'
# Minimac Command
	${Minimac4_Exec} \
	--cpus $ImputeThreads \
	--allTypedSites --minRatio 0.00001 \
	--refHaps ./Reference/${XMiniRef} \
	--haps ${BaseName}_Phasing/Ody3_${BaseName}_Chr23_Phased.vcf.gz \
	--prefix ${BaseName}_Imputation/RawImputation/Ody4_${BaseName}_Chr23" >${BaseName}_Imputation/Scripts2Impute/Chr23_${BaseName}_I.sh

			# Toggle that will turn script submission on/off
			# -----------------------------------------------
			if [ "${ExecuteImputationScripts,,}" == "t" ]; then

				if [ "${HPS_Submit,,}" == "t" ]; then

					echo
					echo Submitting Impute script to HPC Queue
					echo
					qsub -l nodes=1:ppn=${ImputeThreads},vmem=${Impute_Memory}gb,walltime=${Impute_Walltime} -M ${Email} -m a -j oe -o ${BaseName}_Imputation/Scripts2Impute/Chr23_${BaseName}_I.out -N IChr23_${BaseName} ${BaseName}_Imputation/Scripts2Impute/Chr23_${BaseName}_I.sh

				elif [ "${HPS_Submit,,}" == "f" ]; then

					echo
					echo Submitting Impute script to Desktop Queue
					echo
					bash ${BaseName}_Imputation/Scripts2Impute/Chr23_${BaseName}_I.sh >${BaseName}_Imputation/Scripts2Impute/Chr23_${BaseName}_I.out 2>&1 &

				else

					echo
					echo User Input Not Recognized -- Please specify T or F
					echo Exiting script submission
					echo
				fi
			elif [ "${ExecuteImputationScripts,,}" == "f" ]; then

				echo
				echo Not Submitting Scripts
				echo

			else
				echo
				echo User Input Not Recognized -- Please specify T or F
				echo Exiting Script Submission
				echo
			fi
		else
			echo
			echo All Necessary Reference Files Not Present
			echo Will Not Segment or Create Scripts
			echo
		fi
	fi
fi

# Termination Message
echo
echo ============
echo " Phew Done!"
echo ============
echo
echo
