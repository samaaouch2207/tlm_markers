#!/bin/bash

print_usage() {
  echo "Usage: $0 {DS1|DS2|KAYRROS|DS2_KAYRROS} {small|big|original} [online]"
  echo "  1) Dataset: DS1, DS2, KAYRROS, DS2_KAYRROS"
  echo "  2) Length: small, big, original"
  echo "  3) Mode (optional, default=online): local, online"
  echo "Example: $0 DS1 small online"
}

# Check product to use 
case "$1" in
    DS1)
        DIR_NO_TLM="CDSE/DS1/S2C_MSIL2A_20250527T073631_N0511_R092_T38SND_20250527T104713.SAFE/GRANULE/L2A_T38SND_A003780_20250527T074219/IMG_DATA"
        DIR_WITH_TLM="outputs/DS1/S2_L2_ORCH/L2A_TL/output/S2C_OPER_MSI_L2A_TL_MPC__20250709T085444_A003780_T38SND_N05.11/IMG_DATA"
        CSV_PATTERN="DS_2CPS_20250527T092507_S20250527T074219"
    ;;
    DS2)
        DIR_NO_TLM="CDSE/DS2/S2C_MSIL2A_20250527T073631_N0511_R092_T38SND_20250527T113212.SAFE/GRANULE/L2A_T38SND_A003780_20250527T075023/IMG_DATA"
        DIR_WITH_TLM="outputs/DS2/S2_L2_ORCH/L2A_TL/output/S2C_OPER_MSI_L2A_TL_MPC__20250718T150241_A003780_T38SND_N05.11/IMG_DATA"
        CSV_PATTERN="DS_2CPS_20250527T093652_S20250527T075023"
    ;;
    KAYRROS)
        DIR_NO_TLM="KAYRROS"
        DIR_WITH_TLM="$DIR_NO_TLM"
        CSV_PATTERN="KAYRROS"
    ;;
    DS2_KAYRROS)
        DIR_NO_TLM="CDSE/DS2/S2C_MSIL2A_20250527T073631_N0511_R092_T38SND_20250527T113212.SAFE/GRANULE/L2A_T38SND_A003780_20250527T075023/IMG_DATA"
        DIR_WITH_TLM="outputs/DS2/KAYRROS_L2_TLM"
        CSV_PATTERN="DS_2CPS_20250527T093652_S20250527T075023_KAYRROS"
    ;;
    *)
        echo "ERROR: Invalid dataset '$1'."
        print_usage
        exit 1
    ;;
esac

# Check size of extraction
case "$2" in 
    big|small|small2t|original|huge|medium) length="$2" ;;
    *)
        echo "ERROR: Invalid length '$2'."
        print_usage
        exit 1
    ;;
esac

# Check location of the bands.
mode="${3:-online}"
case "$mode" in
    local|online)
        # valid mode, do nothing or any setup here
        ;;
    *)
        echo "ERROR: Invalid mode '$3'."
        print_usage
        exit 1
    ;;
esac

measure_time() {
    local input="$1"
    local output="$2"

    local log_file
    log_file=$(mktemp)

    # Set TIMEFORMAT to only show the 'real' time
    local real_time
    TIMEFORMAT=%R
    real_time=$( { time gdal_translate -srcwin $SRCWIN "$input" "$output" > /dev/null 2> "$log_file"; } 2>&1 )

    # Declare as global to persist outside function
    local num_requests
    local bandwidth_mb
    num_requests=$(grep -i '^Range: bytes=' "$log_file" | wc -l)
    bandwidth_mb=$(grep -i '^Range: bytes=' "$log_file" | awk -F'[-=]' '{sum += $3 - $2 + 1} END {printf "%.2f", sum / (1024*1024)}')

    rm -f "$log_file"

    echo "$real_time" "$num_requests" "$bandwidth_mb"

}

srcwin_selection() {
    local length_res=$1
        
    case $length_res in
        small_10m)  SRCWIN="9500 9500 180 180" ;;
        small_20m)  SRCWIN="4500 4500 90 90" ;;
        small_60m)  SRCWIN="1600 1600 30 30" ;;

        small2t_10m)  SRCWIN="9500 9200 180 180" ;;
        small2t_20m)  SRCWIN="4500 4400 90 90" ;;
        small2t_60m)  SRCWIN="1600 1530 30 30" ;;
        
        medium_10m)  SRCWIN="3000 3000 900 900" ;;
        medium_20m)  SRCWIN="1900 1900 450 450" ;;
        medium_60m)  SRCWIN="500 500 150 150" ;;

        big_10m)    SRCWIN="8000 8000 1800 1800" ;;
        big_20m)    SRCWIN="1200 1200 900 900" ;;
        big_60m)    SRCWIN="500 500 300 300" ;;

        huge_10m)  SRCWIN="1030 1030 7150 7150" ;;
        huge_20m)  SRCWIN="1000 1000 3600 3600" ;;
        huge_60m)  SRCWIN="300 300 1200 1200" ;;

        original_10m|original_20m|original_60m)
                    SRCWIN="9500 9500 500 500" ;;
        *)
            echo "Invalid length/res combination: $length / $res" >&2
            exit 1
            ;;
    esac

    echo "$SRCWIN"
}

WD_DIR=$(pwd)

CSV_FILE="benchmark_results/${CSV_PATTERN}_${mode}_${length}_crop.csv"
echo "Image,Resolution_Band,Nb_requests_without_TLM,Nb_requests_with_TLM,Bandwidth_without_TLM(MB),Bandwidth_with_TLM(MB),Time_without_TLM(s),Time_with_TLM(s),x_Faster" > $CSV_FILE

# extract a crop of size 500x500 pixels, from a Sentinel-2 raster hosted on Github
export GDAL_DISABLE_READDIR_ON_OPEN=EMPTY_DIR
export CPL_VSIL_CURL_ALLOWED_EXTENSIONS=jp2,tiff
export GDAL_NUM_THREADS=1
export CPL_CURL_VERBOSE=YES  # needed to count the number of requests

SECONDS=0
echo "[INFO] Script started at `date '+%Y-%m-%dT%H:%M:%S'`"
# Find all jp2 files under no-TLM directory
find "$WD_DIR/$DIR_NO_TLM" -type f -name '*.jp2' | while read -r file_no_tlm; do

    base_no_tlm=$(basename "$file_no_tlm")
    res=$(echo "$base_no_tlm" | grep -o -E '[0-9]{1,2}m')
    band=$(echo "$base_no_tlm" | grep -o -E 'B[0-9]{2,3}|B8A|TCI|SCL|AOT|WVP')
   
    SRCWIN=$(srcwin_selection "${length}_${res}")
    echo "$length: $SRCWIN"
    
    if [ "$1" == "KAYRROS" ]; then 
        file_with_tlm_path="$DIR_WITH_TLM/T32TQM_20241115T100159_B03_10m_with_TLM.jp2"
    else
        file_with_tlm_path=$(find "$DIR_WITH_TLM" -type f -path "*/R${res}/*" -name "$base_no_tlm" | head -1)
        file_with_tlm=$file_with_tlm_path
    fi
    
    runs=100   # number of repetitions; default 1000
    for ((i = 1; i <= runs; i++)); do
        echo "Run number: $i" 
        # Define output TIFF filenames (unique for each image)
        out_no_tlm="crop_no_tlm_${base_no_tlm%.jp2}_${CSV_PATTERN}_${length}_`date '+%Y%m%d%H%M%S'`.tif"
        out_with_tlm="crop_with_tlm_${base_no_tlm%.jp2}_${CSV_PATTERN}_${length}_`date '+%Y%m%d%H%M%S'`.tif"

        # Set file_no_tlm based on mode
        if [ "$mode" == "online" ]; then 
            baseurl="/vsicurl/https://media.githubusercontent.com/media/samaaouch2207/tlm_markers/img"
            if [[ "$1" == "KAYRROS" ]]; then
                file_no_tlm="$baseurl/T32TQM_20241115T100159_B03_10m.jp2"
                file_with_tlm="$baseurl/T32TQM_20241115T100159_B03_10m_with_TLM.jp2"
            else
                # For other datasets, construct the URL based on the directory structure
                file_no_tlm="$baseurl/$DIR_NO_TLM/R${res}/$base_no_tlm"
                file_with_tlm="$baseurl/$DIR_WITH_TLM/R${res}/$base_no_tlm"
            fi
        fi
        # Check if file with TLM exists
        if [[ -f "$file_with_tlm_path" ]]; then
            # Warm up the CDN only at the first iteration of the loop, as we see that the first run is always slower
            if [ "$mode" == "online" ]; then
                # sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
                if [ $i -eq 1 ]; then
                    echo "GitHub CDN cache warm up..."
                    # Warm up CDN GitHub cache 
                    measure_time "$file_with_tlm" "$out_with_tlm"  >/dev/null 2>/dev/null
                    measure_time "$file_no_tlm" "$out_no_tlm" >/dev/null 2>/dev/null
                fi
            fi
            # Clear cache to simulate cold run to simulate first access each time and launch time access to gdal_translate 
            # sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
            
            echo "Time without TLM markers: $file_no_tlm"
            requests_time_no_tlm=$(measure_time "$file_no_tlm" "$out_no_tlm")
            requests_no_tlm=$(echo "$requests_time_no_tlm" | awk '{print $2}')
            time_no_tlm=$(echo "$requests_time_no_tlm" | awk '{print $1}')
            bandwidth_mb_no_tlm=$(echo "$requests_time_no_tlm" | awk '{print $3}')

            echo "Time with TLM markers: $file_with_tlm"
            requests_time_with_tlm=$(measure_time "$file_with_tlm" "$out_with_tlm")
            requests_tlm=$(echo "$requests_time_with_tlm" | awk '{print $2}')
            time_with_tlm=$(echo "$requests_time_with_tlm" | awk '{print $1}')
            bandwidth_mb_with_tlm=$(echo "$requests_time_with_tlm" | awk '{print $3}')

            # Compute ratio: how much faster is time_with_tlm vs time_no_tlm
            xfaster=$(awk -v t1="$time_no_tlm" -v t2="$time_with_tlm" 'BEGIN {
                if (t1 > 0 && t2 != "N/A") {
                    printf "%.2f", t1 / t2;
                } else {
                    print "N/A"
                }
            }')
        else
            time_with_tlm="N/A"
            xfaster="N/A"
        fi
        echo "Results:"
        echo "  No TLM time   : $time_no_tlm s"
        echo "  With TLM time : $time_with_tlm s"
        echo "  Speedup ratio : $xfaster"
        echo "  Requests (no TLM): $requests_no_tlm"
        echo "  Requests (with TLM): $requests_tlm"
        echo "  Bandwidth (no TLM): $bandwidth_mb_no_tlm MB"
        echo "  Bandwidth (with TLM): $bandwidth_mb_with_tlm MB"
        # Save in CSV
        echo "$base_no_tlm,R${res}_$band,$requests_no_tlm,$requests_tlm,$bandwidth_mb_no_tlm,$bandwidth_mb_with_tlm,$time_no_tlm,$time_with_tlm,$xfaster" >> $CSV_FILE

        # Optionally, delete the output TIFFs after timing:
        rm -f "$out_no_tlm" "$out_with_tlm"
    done
done
duration=$SECONDS
hours=$((duration / 3600))
mins=$(((duration % 3600) / 60))
secs=$((duration % 60))

echo "Elapsed time: $hours h $mins min $secs sec"
echo "[INFO] Script finished at `date '+%Y-%m-%dT%H:%M:%S'`. Exiting"