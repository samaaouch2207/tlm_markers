# TLM markers OPT-MPC study

To test the TLM markers added to Sentinel-2 processors L1C and L2A, request from JIRA ticket: [OMPC-3238](https://opt-mpc.atlassian.net/browse/OMPC-3238). 


## Activate environment 

### If environment not created: 
Create the environment with command: 

```bash
conda create -n jp2test -c conda-forge openjpeg=2.5.3 libgdal-jp2openjpeg gdal
```

### Environment created:
Activate the environment:

```bash 
conda activate jp2test
```

To deactivate it:

```bash 
conda deactivate
```

## Launch TLM conversion using KAYRROS method: 
### Prerequisities
Clone the Git repository from KAYRROS team [Kayrros/sentinel-2-jp2-tlm](https://github.com/Kayrros/sentinel-2-jp2-tlm.git):  
```bash 
git clone https://github.com/Kayrros/sentinel-2-jp2-tlm.git
```

### Install docker 
```bash 
cd /mount/opt-mpc/s2mpc/work/REPROCESSING/OMPC-3238/sentinel-2-jp2-tlm/s2tlm-indexer
```
```bash
docker build . -t s2tlm-indexer
```

### TLM image generation
```bash 
docker run --rm -v /mount/:/mount/ -w  /mount/opt-mpc/s2mpc/work/REPROCESSING/OMPC-3238/ s2tlm-indexer T38SND_20250527T073631_B03_10m.jp2 T38SND_20250527T073631_B03_10m_with_TLM_SA.jp2  --full-jp2
```

## Reprocessed L1 products in L2 and add TLM markers
### Install docker
```bash
docker load < /mount/opt-mpc/s2mpc/work/REPROCESSING/OMPC-3238/S2_L2_6.3.1_TLM_markers_2025-07-09_dockerImage.tar
```

To check if the Sentinel-2 IPF L2 image with TLM markers is installed, you can run `docker images`.  

Expected output:

| REPOSITORY | TAG                           | IMAGE ID     | CREATED      | SIZE  |
|------------|-------------------------------|-------------|------------|-------|
| s2level2   | 6.3.0_TLM_markers_OMPC-3238   | e626272d6b2c | 4 weeks ago | 2.31GB |

### Prepare and launch reprocessing
Prepare and launch reprocessing as it is explained in the procedure: [OMPC.ACR.MEM.017 -i3r0 - Ops Procedures - Reprocessing L1C to L2A](https://acricwe.sharepoint.com/:w:/r/sites/OPT-MPC/Documents%20partages/Workspace/Operators/Procedures/S2%20procedures/OMPC.ACR.MEM.017%20-i3r0%20-%20Ops%20Procedures%20-%20Reprocessing%20L1C%20to%20L2A.docx?d=w5b9868afcd3342ed83d07c53475cb2ed&csf=1&web=1&e=5KbcF7)

To launch the reprocessing the argument IPF must be: 
```bash 
./launch_ipf_l2.sh -o <output_dir> -g <gipp_folder> -i 6.3.0_TLM_markers_OMPC-3238 -f <tile_list_file> -d <ds_path> -t <tile_path>
```

## TLM Markers in JPEG2000
This section shows how to check if TLM markers were added to a Sentinel-2 JP2 band.

### Prerequisities 
Install **OpenJPEG**

### Usage
```bash 
opj_dump -i file.jp2
``` 
When reading a Sentinel-2 JP2 codestream, the IPF L2 generates Tile-part Length (TLM) markers to improve access to image tiles. A minimal snippet of the codestream index looks like this:

```bash
[INFO] Codestream index from main header:
Tile index: {
    nb of tile-part in tile [0]=1
    tile-part[0]: start_pos=3177, end_pos=979260
    nb of tile-part in tile [1]=1
    tile-part[0]: start_pos=979260, end_pos=2045881
    ...
}
``` 
Each tile-part corresponds to a TLM marker. These markers allow faster access to individual tiles in the JP2 file, reducing download time when reading subsets of the image. The start_pos and end_pos indicate the byte range of each tile-part.

## Add image on GitHub
### Prerequisities
1. Install `git-lfs` to push big files on GitHub
```bash
# Install Git LFS
sudo apt install git-lfs  # ou brew install git-lfs sur macOS
```

If not working install rpm from `download.rpm?distro_version_id=205`
```bash
sudo rpm -ivh download.rpm\?distro_version_id\=205
```

2. Create a git project on GitHub directly, in this project the images will be pushed.
### Initialize the git repository
```bash
# Initialize Git in the working folder
git init

# Connect to the git remote created before
git remote add origin https://github.com/yourusername/yourrepo.git

# Create a local branch (if don't want to work in main branch)
git checkout -b scripts

# Initialize LFS in your repo
git lfs install

# Apply LFS to big files as jp2
git lfs track "*.jp2"

# Add the files jp2 
git add .gitattributes
```
File `.gitattributes` must contain:
```git
*.jp2 filter=lfs diff=lfs merge=lfs -text
```

### Push image
Connect the remote service (if not done before):
```bash
# Connect to the service
git remote add origin https://github.com/youruser/your_repo.git

# Add image
git add *the_image.jp2*

# Commit message to the image add
git commit -m "Your message"

# Push everything
git push origin *your_branch*
```

## Benchmarking Script for TLM Markers in Sentinel-2 Data

This script benchmarks the impact of Tile Level Markers (TLM) on accessing Sentinel-2 JP2 images with gdal_translate.
It compares:

This script benchmarks the impact of **Tile Level Markers (TLM)** on accessing Sentinel-2 JP2 images using `gdal_translate`.  
It compares two scenarios:  
- **Without TLM markers** (original Sentinel-2 products)  
- **With TLM markers** (optimized products)  

For each band, the script measures:
- Access time (seconds)  
- Number of HTTP range requests  
- Bandwidth usage (MB)  
- Speedup ratio (`time_no_tlm / time_with_tlm`)  

Results are written to a CSV file.

### Usage
``` bash
./sentinel-2-jp2-tlm/benchmark_table.sh {DS1|DS2|KAYRROS|DS2_KAYRROS} {small|big|original} [online|local]
```

### Arguments
1. **Dataset:** `DS1`, `DS2`, `KAYRROS`, `DS2_KAYRROS`
2. **Crop size:** `small`, `big`, `original` *(also supported: `small2t`, `medium`, `huge`)*
3. **Mode** *(optional, default = `online`):*
    - `online`: fetch images via /vsicurl/ (GitHub)
    - `local`: use local files

### Datasets
- **DS1**  
  - **No TLM**: `CDSE/DS1/.../IMG_DATA` (Sentinel-2 L2A product from CDSE)  
  - **With TLM**: `outputs/DS1/S2_L2_ORCH/.../IMG_DATA` (reprocessed product with TLM markers)  

- **DS2**  
  - **No TLM**: `CDSE/DS2/.../IMG_DATA` (Sentinel-2 L2A product from CDSE)  
  - **With TLM**: `outputs/DS2/S2_L2_ORCH/.../IMG_DATA` (reprocessed product with TLM markers)  

- **KAYRROS**  
  - **No TLM**: `KAYRROS/`  
  - **With TLM**: same directory (`KAYRROS/`), containing versions with TLM markers  

- **DS2_KAYRROS**  
  - **No TLM**: `CDSE/DS2/.../IMG_DATA` (Sentinel-2 L2A product from CDSE)  
  - **With TLM**: `outputs/DS2/KAYRROS_L2_TLM/` (Kayrros reprocessed version with TLM markers)  

### Example
``` bash
./sentinel-2-jp2-tlm/benchmark_table.sh DS1 small online
```

Benchmarks all JP2 bands from **DS1**, extracts a small crop, and compares performance between TLM and non-TLM files.

### Output
**Dataset to CSV Pattern Mapping:**

| DS_NAME        | CSV_PATTERN                                      | Description                          |
|----------------|-------------------------------------------------|--------------------------------------|
| DS1            | DS_2CPS_20250527T092507_S20250527T074219       | Sentinel-2 test dataset 1            |
| DS2            | DS_2CPS_20250527T093652_S20250527T075023       | Sentinel-2 test dataset 2            |
| KAYRROS        | KAYRROS                                         | KAYRROS dataset                       |
| DS2_KAYRROS    | DS_2CPS_20250527T093652_S20250527T075023_KAYRROS | Combined DS2 and KAYRROS dataset     |

**CSV file format:** 

`benchmark_results/<CSV_PATTERN>_<mode>_<length>_crop.csv`

- **mode**: `online` or `local` (default=`online`)  
- **length**: crop size: `small`, `small2t`, `medium`, `big`, `huge`, `original`

**Example CSV file name:**

`benchmark_results/DS_2CPS_20250527T092507_S20250527T074219_online_small_crop.csv`

**CSV file content:**
```csv
Image,Resolution_Band,Nb_requests_without_TLM,Nb_requests_with_TLM,Bandwidth_without_TLM(MB),Bandwidth_with_TLM(MB),Time_without_TLM(s),Time_with_TLM(s),x_Faster
```

**Requirements:** GDAL with gdal_translate in PATH.

## Compare x_Faster Values

This Python script compares `x_Faster` values between different benchmark tables produced by the previous TLM marker extraction process.

### Features
- Computes **medians for R10m / R20m / R60m** bands (excluding *_TCI).  
- Keeps **direct *_TCI values** as-is.  
- Produces a **bar plot** showing the time ratio (time without TLM / time with TLM) for each crop type.  
- Handles multiple crops: SMALL, SMALL 2-TILES, MEDIUM, BIG, HUGE.  

### Usage

```bash
python3.9 generate_plots.py <DS_NAME> [mode]
```
- **DS_NAME**: `DS1`, `DS2`, `KAYRROS`, `DS2_KAYRROS`
- **Mode** *(optional, default = `online`):* local or online

### Example:
```bash
python3.9 generate_plots.py DS2 local
python3.9 generate_plots.py DS2
```

### Output

- Printed **summary tables** of median and standard deviation for times with and without TLM.
- A **bar plot** saved as: `<DS_NAME>_<mode>_bars_plot.png`

This allows quick visualization of performance gains when using TLM markers for each dataset and crop size.