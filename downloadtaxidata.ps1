
$dataDirectories = @(
    'data\2022'
    'data\2019'
)

foreach ( $dir in $dataDirectories ) {
    If (!(test-path $dir)){    
        mkdir $dir
    }
}

# 2022

$dataFiles_2019 = @(
    "https://s3.amazonaws.com/nyc-tlc/trip+data/yellow_tripdata_2019-01.csv"
    #"https://s3.amazonaws.com/nyc-tlc/trip+data/yellow_tripdata_2019-02.csv"    
)

$dataFiles_2022 = @(
    "https://nyc-tlc.s3.amazonaws.com/trip+data/yellow_tripdata_2022-01.csv"
    #"https://nyc-tlc.s3.amazonaws.com/trip+data/yellow_tripdata_2022-02.csv"
)

Write-Host "This script will download NYC Yellow Taxi trip records for the months January and February for 2019 and 2022"
Write-Host ""
Write-Warning "If you have limited bandwidth please end the script now, approximately 1GB will be downloaded"

$proceed = Read-Host -Prompt "Proceed? [y/n]"

if ( $proceed -eq 'y' ) { 
    Write-Host "Creating directories"

    foreach ( $dir in $dataDirectories ) {
        If (!(test-path $dir)){    
            mkdir $dir
        }
    }

    Write-Host "Downloading 2019 NYC Yellow Taxi Trip Records"

    foreach ( $fileUrl in $dataFiles_2019 ) {
        Write-Host "Dowloading " $fileUrl
        Invoke-WebRequest $fileUrl -OutFile ".\data\2019\$(Split-Path -Leaf $fileUrl)"
    }

    Write-Host "Downloading 2022 NYC Yellow Taxi Trip Records"

    foreach ( $fileUrl in $dataFiles_2022 ) {
        Write-Host "Dowloading " $fileUrl
        Invoke-WebRequest $fileUrl -OutFile ".\data\2022\$(Split-Path -Leaf $fileUrl)"
    }
}