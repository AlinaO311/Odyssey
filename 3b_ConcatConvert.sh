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
echo ${WorkingDir}
echo
echo

# =-=-=-=-==========================================================
#  ================================================================
#   ====================== Error Check ===========================
#  ================================================================
# ==================================================================

if [ "${UseImpute,,}" == "t" ]; then
	# Perform Error Analysis on Phasing Step -- grep looks for .out files containing 'Killed', 'Aborted', 'segmentation', or 'error'
	# -----------------------------
	if [ "${ImputationErrorAnalysis,,}" == "t" ]; then

		echo
		echo --------------------------------------------------------
		echo Performing Error Analysis on Imputation Jobs:
		echo --------------------------------------------------------
		echo
		echo Note: Some errors are caused by no SNPs being in the imputed area -- this is not really an issue -- skip the segment
		echo Note: Other errors are listed as segmentation faults -- memory access issues -- try re-running or use Impute2 and re-run
		echo
		echo
		echo Imputation jobs that should be reviewed are listed:
		echo It may take a while to scan all the .out files
		echo ==============================================
		echo
		find ${BaseName}_Imputation/Scripts2Impute -maxdepth 1 -type f -print | xargs grep -rli 'Killed\|Aborted\|segmentation\|error' | sort -V
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

		if [ "${UserInput1,,}" == "y" ]; then

			echo
			echo "Outputting more details on failed file/s..."
			echo ===========================================
			echo
			find ${BaseName}_Imputation/Scripts2Impute -maxdepth 1 -type f -print | xargs grep -ri 'Killed\|Aborted\|segmentation\|error' | sort -V
			echo
			echo ===========================================

		elif [ "${UserInput1,,}" == "n" ]; then

			echo "Alright, will not output more details on failed file/s"
			echo =========================================================
			echo

		else
			echo "Input not recognized -- specify either 'y' or 'n' -- exiting Error Analysis"
			echo ================================================================================
			echo
		fi

		# Re-submit the failed scripts
		echo
		echo "Would you like to resubmit the failed scripts?"
		echo "Script/s will be submitted to an HPS if specified in Conf.conf otherwise will submit via a simple 'sh' command"
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
				if [ "${UserInput3,,}" == "y" ]; then
					echo "Manually reading in scripts to re-submit from $UserInput4"

					# Manually read in scripts that need to be re-run
					cat $UserInput4 | sort -V | xargs grep -r 'qsub' | sed 's/.*# //' >ReSubmitImputeJobs.txt

					# Remove the errored .out file (otherwise the new .out will be appended to the old and the error will never be reported as fixed)
					find ${BaseName}_Imputation/Scripts2Impute -maxdepth 1 -type f -print | xargs grep -rli 'Killed\|Aborted\|segmentation\|error' | sort -V | xargs rm -f

					# Read the file that contains the scripts that need to be re-submitted and submit then via Bash to the HPS queue
					cat ReSubmitImputeJobs.txt | bash
					# Remove ReSubmitJobs.txt
					rm -f ReSubmitImputeJobs.txt
					echo
					echo ===========================================
					echo
				elif [ "${UserInput3,,}" == "n" ]; then
					echo "Looking up all failed scripts from .out files for re-submission"
					# The following line does a lot:
					# 1) looks in the script directory that also contains output logs
					# 2) find .out files that contain the words 'Killed', 'Aborted', 'segmentation', or 'error'
					# 3,4) Sorts the .out files and subs .out for .sh to get the script
					# 5) Within .sh should be a manual execution command that starts with '# qsub', grep finds the line and trims the off the '# ' to get the qsub command and saves it to ReSubmitPhaseJobs.txt
					find ${BaseName}_Imputation/Scripts2Impute -maxdepth 1 -type f -print | xargs grep -rli 'Killed\|Aborted\|segmentation\|error' | sort -V | sed 's/.out/.sh/g' | xargs grep -r 'qsub' | sed 's/.*# //' >ReSubmitImputeJobs.txt
					# Remove the errored .out file (otherwise the new .out will be appended to the old and the error will never be reported as fixed)
					find ${BaseName}_Imputation/Scripts2Impute -maxdepth 1 -type f -print | xargs grep -rli 'Killed\|Aborted\|segmentation\|error' | sort -V | xargs rm -f
					# Read the file that contains the scripts that need to be re-submitted and submit then via Bash to the HPS queue
					cat ReSubmitImputeJobs.txt | bash
					# Remove ReSubmitJobs.txt
					rm -f ReSubmitImputeJobs.txt
					echo
					echo ===========================================
					echo
				else
					echo
					echo "User Input not recognized -- please specify 'y' or 'n'"
					echo "Exiting Script Re-Submission"
					echo
				fi

			else
				echo
				echo Re-Submitting Failed Scripts to Desktop...
				echo ===========================================
				echo
				if [ "${UserInput3,,}" == "y" ]; then
					echo "Manually reading in scripts to re-submit from $UserInput4"
					# Manually read in scripts that need to be re-run
					cat $UserInput4 | sort -V | xargs grep -r 'qsub' | sed 's/.*# //' >ReSubmitImputeJobs.txt
					# Remove the errored .out file (otherwise the new .out will be appended to the old and the error will never be reported as fixed)
					find /Scripts2Impute -maxdepth 1 -type f -print | xargs grep -rli 'Killed\|Aborted\|segmentation\|error' | sort -V | xargs rm -f
					# Read the file that contains the scripts that need to be re-submitted and submit then via Bash to the HPS queue
					cat ReSubmitImputeJobs.txt | sh
					# Remove ReSubmitJobs.txt
					rm -f ReSubmitImputeJobs.txt
					echo
					echo ===========================================
					echo
				elif [ "${UserInput3,,}" == "n" ]; then
					# The following line does a lot:
					# 1) looks in the script directory that also contains output
					# 2) find .out files that contain the words 'Killed', 'Aborted', 'segmentation', or 'error'
					# 3,4) Sorts the .out files and subs .out for .sh to get the script
					# 5) Within .sh should be a manual execution command that starts with 'time ', grep finds the line and saves it to ReSubmitPhaseJobs.txt
					find ${BaseName}_Imputation/Scripts2Impute -maxdepth 1 -type f -print | xargs grep -rli 'Killed\|Aborted\|segmentation\|error' | sort -V | sed 's/.out/.sh/g' | xargs grep -r 'time ' >ReSubmitImputeJobs.txt
					# Remove the errored .out file (otherwise the new .out will be appended to the old and the error will never be reported as fixed)
					find ${BaseName}_Imputation/Scripts2Impute -maxdepth 1 -type f -print | xargs grep -rli 'Killed\|Aborted\|segmentation\|error' | sort -V | xargs rm -f
					# Read the file that contains the scripts that need to be re-submitted and submit then via sh to the Linux workstation
					cat ReSubmitImputeJobs.txt | sh
					# Remove ReSubmitJobs.txt
					rm -f ReSubmitImputeJobs.txt
					echo
					echo ===========================================
					echo
				else
					echo
					echo "User Input not recognized -- please specify 'y' or 'n'"
					echo "Exiting Script Re-Submission"
					echo
				fi
			fi
		elif [ "${UserInput2,,}" == "n" ]; then

			echo "Alright, will not Re-Submit Failed Script/s"
			echo ==============================================
			echo
			echo

		else
			echo "Input Not Recognized -- Specify Either 'yes' or 'no' -- Exiting Re-Submission"
			echo ==============================================================================
			echo
			echo

		fi
	elif [ "${ImputationErrorAnalysis,,}" == "f" ]; then
		echo
	else
		echo
		echo User Input Not Recognized -- please specify T or F in Conf.conf
		echo
	fi
fi

if [ "${UseMinimac,,}" == "t" ]; then
	echo
	echo
	echo ----------------------------------------------------------------
	printf "Performing Post Imputation File Clean Up on Minimac4 Files\n"
	echo ================================================================
	# Make Directory in which to place merged concatenated files
	#----------------------------------------------------------------------------
	echo
	echo Creating Concat Cohort Folder within Impute Directory
	echo ----------------------------------------------
	echo
	mkdir ${BaseName}_Imputation/ConcatImputation
	# Use Lustre Stripping?
	if [ "${LustreStrip,,}" == "t" ]; then
		lfs setstripe -c 5 ./${BaseName}_Imputation/ConcatImputation
	fi
	# =-=-=-=====================================================================================
	#   Cleanup .dose.vcf.gz File in in parallel using GNU-Parallel
	#  =========================================================================================
	# ===========================================================================================
	if [ "${Cleanup,,}" == "t" ]; then
		if [ "${CleanupParallel,,}" == "t" ]; then
			echo
			echo =========================================================
			printf " Running Parallel .dose.vcf.gz Cleanup with GNU-Parallel\n"
			printf "     Each CPU will analyze 1 chromosome at a time\n\n"
			printf "    You may have to configure GNU-Parallel manually\n"
			printf "  See Settings.conf for instructions on how to do this\n"
			echo =========================================================
			echo
			# GNU-Parallel Function that Performs multiple steps to cleanup the Minimac4 concatenated .dose.vcf.gz
			function CleanupFunc() {
				#       Use Plink to Filter .dose.vcf.gz with built in R2 score to .vcf.gz
				# =-=-=====================================================================================
				# =========================================================================================
				printf "\n\nUsing Plink to Filter the Chr$1.dose.vcf.gz to an R2 filtered .vcf.gz\n"
				echo ----------------------------------------------------------------------
				# Conditional statement to see if there is a .dose.vcf.gz to convert to .vcf.gz
				if ls ./${BaseName}_Imputation/RawImputation/*Chr$1.dose.vcf.gz 1>/dev/null 2>&1; then

					# Conditional Statement to look to see if a Plink Created .vcf is already present
					if ls ./${BaseName}_Imputation/ConcatImputation/"$BaseName"_Chr$1.vcf.gz 1>/dev/null 2>&1; then
						printf "\nA .VCF.gz file for Chromosome $1 already exists -- What Should I do?\n"
						# If a file for the particular chromosome is already present and overwrite is set to false, then skip the file creation
						if [ "${OverwriteIfExist,,}" == "f" ]; then
							echo Do not overwrite ./${BaseName}_Imputation/RawImputation/"$BaseName"_Chr$1.vcf.gz -- Skipping Plink VCF Filtration for Chr $1
							echo
						# If a file for the particular chromosome is already present and overwrite set to true, then overwrite it
						elif [ "${OverwriteIfExist,,}" == "t" ]; then
							echo Will overwrite ./${BaseName}_Imputation/RawImputation/"$BaseName"_Chr$1.vcf.gz
							echo
							# Get chromosome number from the name of the file
							#FetchChr=$(echo $1 | egrep -o --ignore-case "chr[[:digit:]]{1,2}[^[:digit:]]{1}" | egrep -o --ignore-case "[[:digit:]]{1,2}")
							# Runs Plink to convert the concatenated dosage VCF to an R2 Filtered VCF 4.3
							${Plink2_Exec} --memory 2000 require --vcf ./${BaseName}_Imputation/RawImputation/Ody4_${BaseName}_Chr$1.dose.vcf.gz dosage=HDS --exclude-if-info "R2<=0.3" --export vcf vcf-dosage=GP --out ./${BaseName}_Imputation/ConcatImputation/${BaseName}_Chr$1
							# Runs Plink to convert the concatenated dosage VCF to an R2 Filtered VCF 4.3
							#${Plink2_Exec} --memory 2000 require \
							--vcf ./${BaseName}_Imputation/RawImputation/Ody4_${BaseName}_Chr$1.dose.vcf.gz dosage=HDS \
								--exclude-if-info "R2<=0.3" \
								--make-pgen \
								--out ./${BaseName}_Imputation/ConcatImputation/${BaseName}_Chr$1
							# Zip the Resulting File
							printf "\n\n\nZipping the Plink Filtered .VCF.gz file for Chromosome $1 \n"
							echo --------------------------------------------------------------
							${gzip_Exec} -f ./${BaseName}_Imputation/ConcatImputation/${BaseName}_Chr$1.vcf
						else
							echo ERROR -- Specify Either T or F for OverwriteIfExist Variable
						fi
					else
						# If does not exist then perform the conversion
						# Get chromosome number from the name of the file
						#FetchChr=$(echo $1 | egrep -o --ignore-case "chr[[:digit:]]{1,2}[^[:digit:]]{1}" | egrep -o --ignore-case "[[:digit:]]{1,2}")
						# Runs Plink to filter the concatenated dosage VCF to an R2 Filtered VCF 4.3
						${Plink2_Exec} --memory 2000 require --vcf ./${BaseName}_Imputation/RawImputation/Ody4_${BaseName}_Chr$1.dose.vcf.gz dosage=HDS --exclude-if-info "R2<=${INFOThresh}" --export vcf vcf-dosage=GP --out ./${BaseName}_Imputation/ConcatImputation/${BaseName}_Chr$1
						# Zip the Resulting File
						printf "\n\n\nZipping the Plink Filtered .VCF.gz file for Chromosome $1 \n"
						echo --------------------------------------------------------------
						${gzip_Exec} -f ./${BaseName}_Imputation/ConcatImputation/${BaseName}_Chr$1.vcf
					fi
				else
					# Otherwise if there are no files with which to filter to make a .vcf.gz then say so
					printf " \n\nNo Chromosomal .dosage.vcf.gz File Present for Chromosome ${chr} with which to filter to a VCF.gz -- Skipping \n"
				fi
			}

			# ----- Configure GNU-Parallel (GNU-Parallel Tag) --------
			# On our system gnu-parallel is loaded via a module load command specified in Config.conf under the variable $LOAD_PARALLEL
			# As an alternative you could simply configure GNU-Parallel manually so that calling "parallel" runs GNU-Parallel
			# by adjusting the following lines so that GNU-Parallel runs on your system
			# Load/Inititalize GNU-Parallel
			$LOAD_PARALLEL
			# -------- Configure GNU-Parallel --------
			# Exports the BaseName and other variables as well as the exec path for SNPTEST so the child process (GNU-Parallel) can see it
			export BaseName
			export -f CleanupFunc
			export CleanupStart
			export CleanupEnd
			export OverwriteIfExist
			export INFOThresh
			export Plink2_Exec
			export gzip_Exec
			# GNU-Parallel Command: Takes all the chromosomal .gen files and analyzes them in parallel
			# GNU-Parallel Request ETA: ETA output should only be run on interactive jobs
			if [ "${GNU_ETA,,}" == "t" ]; then
				seq $CleanupStart $CleanupEnd | parallel --eta CleanupFunc {} ">" ./${BaseName}_Imputation/ConcatImputation/${BaseName}_Chr{}.Out
			elif [ "${GNU_ETA,,}" == "f" ]; then
				seq $CleanupStart $CleanupEnd | parallel CleanupFunc {} ">" ./${BaseName}_Imputation/ConcatImputation/${BaseName}_Chr{}.Out
			else
				echo 'Input not recognized for GNU_ETA -- specify either T or F'
			fi
		elif [ "${CleanupParallel,,}" == "f" ]; then
			# =-=-=-=====================================================================================
			#   Cleanup .dosage.vcf.gz File in Serial
			# ==========================================================================================
			# ===========================================================================================
			for chr in $(eval echo {${CleanupStart}..${CleanupEnd}}); do
				#       Use Plink to Filter .dosage.vcf.gz with in-built R2 to .dosage.vcf.gz
				# =========================================================================================
				# =========================================================================================
				printf "\n\nUsing Plink to Filter the Chr${chr}.dosage.vcf.gz to an R2 filtered .vcf.gz\n"
				echo -------------------------------------------------------------------------------

				# Conditional statement to see if there is a .dosage.vcf.gz to convert to .vcf.gz
				if ls ./${BaseName}_Imputation/RawImputation/*Chr${chr}.dose.vcf.gz 1>/dev/null 2>&1; then

					# Conditional Statement to look to see if a Plink Created .vcf.gz is already present
					if ls ./${BaseName}_Imputation/ConcatImputation/${BaseName}_Chr${chr}.vcf.gz 1>/dev/null 2>&1; then

						printf "A .VCF.gz file for Chromosome ${chr} already exists -- What Should I do?\n"

						# If a vcf.gz file for the particular chromosome is already present and overwrite is set to false, then skip the file creation
						if [ "${OverwriteIfExist,,}" == "f" ]; then

							echo Do not overwrite ./${BaseName}_Imputation/ConcatImputation/${BaseName}_Chr${chr}.vcf.gz -- Skipping Plink VCF Filtration for Chr ${chr}
							echo
							echo
						# If a vcf.gz file for the particular chromosome is already present and overwrite set to true, then overwrite it
						elif [ "${OverwriteIfExist,,}" == "t" ]; then
							echo Will overwrite ./${BaseName}_Imputation/ConcatImputation/"$BaseName"_Chr${chr}.vcf.gz
							echo
							echo
							# Get chromosome number from the name of the file
							#FetchChr=$(echo $1 | egrep -o --ignore-case "chr[[:digit:]]{1,2}[^[:digit:]]{1}" | egrep -o --ignore-case "[[:digit:]]{1,2}")
							# Runs Plink to filter the concatenated dosage VCF to an R2 Filtered VCF 4.3
							echo ${Plink2_Exec}
							${Plink2_Exec} --memory 2000 require --vcf ./${BaseName}_Imputation/RawImputation/Ody4_${BaseName}_Chr${chr}.dose.vcf.gz dosage=HDS --exclude-if-info "R2<=${INFOThresh}" --export vcf vcf-dosage=GP --out ./${BaseName}_Imputation/ConcatImputation/${BaseName}_Chr${chr}
							# Zip the Resulting File
							printf "\n\n\nZipping the Plink Filtered .VCF.gz file for Chromosome $1 \n"
							echo --------------------------------------------------------------
							${gzip_Exec} -f ./${BaseName}_Imputation/ConcatImputation/${BaseName}_Chr${chr}.vcf
						else
							echo ERROR -- Specify Either T or F for OverwriteIfExist Variable
						fi
					else
						# If file does not yet exist then perform the filtration to make one
						# Runs Plink to filter the concatenated dosage VCF to an R2 Filtered VCF 4.3
						${Plink2_Exec} --memory 2000 require --vcf ./${BaseName}_Imputation/RawImputation/Ody4_${BaseName}_Chr${chr}.dose.vcf.gz dosage=HDS --exclude-if-info "R2<=${INFOThresh}" --export vcf vcf-dosage=GP --out ./${BaseName}_Imputation/ConcatImputation/${BaseName}_Chr${chr}

						# Zip the Resulting File
						printf "\n\n\nZipping the Plink Filtered .VCF.gz file for Chromosome $1 \n"
						echo --------------------------------------------------------------
						${gzip_Exec} -f ./${BaseName}_Imputation/ConcatImputation/${BaseName}_Chr${chr}.vcf
					fi
				else
					# Otherwise if there are no files with which to filter to make a .vcf.gz then say so
					printf " \n\nNo Chromosomal .dosage.vcf.gz File Present for Chromosome ${chr} with which to filter to a VCF.gz -- Skipping \n"
				fi
			done
		else
			printf "\n\nERROR -- Specify Either T or F for CleanupParallel Variable\n\n"
		fi
	elif [ "${Cleanup,,}" == "f" ]; then
		printf "\n\n\n------ Skipping Minimac4 .dose.vcf.gz Cleanup ------\n\n"
	else
		printf "\n\nERROR -- Specify Either T or F for Cleanup Variable\n\n"
	fi

	# ======================================================================================================
	# ======================================================================================================
	#                  Use BCFTools to Merge the VCF Files Created by Plink
	# ======================================================================================================
	# ======================================================================================================

	if [ "${MergeVCF,,}" == "t" ]; then
		# Conditional statement to find if there are files to concatenate for chromosomes
		if ls ./${BaseName}_Imputation/ConcatImputation/*.vcf.gz 1>/dev/null 2>&1; then
			# If there are .vcf.gz files to concatenate then list them (in order) on the screen
			echo
			printf "\nConcatenating the following VCF.gz files using BCFTools:\n"
			echo ---------------------------------------------------
			ls -1av ./${BaseName}_Imputation/ConcatImputation/*.vcf.gz
			echo ---------------------------------------------------
			echo ...to ./${BaseName}_Imputation/ConcatImputation/Imputed_${BaseName}_Merged.vcf.gz
			# Set List entries as a variable
			VCF2Merge="$(find ./${BaseName}_Imputation/ConcatImputation/ -maxdepth 1 -type f -name "*.vcf.gz" | sort -V)"
			# Use BCFTools to Merge the VCF Files Listed in the variable
			${bcftools} concat --threads ${ConcatThreads} ${VCF2Merge} --output-type z --output ./${BaseName}_Imputation/ConcatImputation/1Imputed__${BaseName}_Merged.vcf.gz
			# Change Permission so the cat script can access it
			chmod -f 700 ./${BaseName}_Imputation/ConcatImputation/1Imputed__${BaseName}_Merged.vcf.gz || true
		# Otherwise if there are no files to concatenate for the currently iterated chromosome then say so
		else
			printf "\nNo VCF.gz Files for BCFTools to Concatenate\n\n"
		fi
	elif [ "${MergeVCF,,}" == "f" ]; then
		printf "\n------ Skipping the Merging of Impute4 Chromosomal VCFs to a Single VCF ------\n\n"
	else
		printf "\nERROR -- Specify Either T or F for MergeVCF Variable\n\n"
	fi
	# Remove Temporary Files to Save Space
	if [ "${RmTemp,,}" == "t" ]; then
		echo --------------------------------
		printf "Tidying Up\n"
		echo ================================
		# Delete Raw Imputation Files
		if [ -d ./${BaseName}_Imputation/RawImputation/ ]; then rm -r ./${BaseName}_Imputation/RawImputation/; fi
	else
		printf "\n\nKeeping Temporary Files\n"
		echo ---------------------------------------
		echo
		echo
	fi
	# Super Clean to Remove all but the bare bones
	if [ "${SuperClean,,}" == "t" ]; then
		printf "\n\nRemoving All But Essential Files\n"
		echo ---------------------------------------
		echo
		echo
		# Delete Raw Imputation Files
		#rm -r ./${BaseName}_Imputation/ConcatImputation/*.snpstat.gz
		rm -r ./${BaseName}_Imputation/ConcatImputation/$BaseName*Chr*.vcf.gz
	fi
else
	printf "\n\n Exiting\n\n"
fi

# Termination Message
echo
echo ============
printf " Phew Done!\n"
echo ============
echo
echo
