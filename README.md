# Using Azure Data Factory to copy historical data into Azure Data Explorer

Loading of historical data is a common requirement and Azure Data Factory provides a great visual interface for designing and executing re-usable pipelines. Bulk loading can be achieved using an Azure Data Factory copy activity but it's important to consider the impact this has on the hot cache. 

During data ingestion Azure Data Explorer adds the data to a table and makes it available for querying. During ingestion properties can be specified to modify how this data is made available for querying such as influencing the mapping of source data to columns or flags being set on the extents written to storage. A detailed discussion of these properties are availabe [here](https://docs.microsoft.com/en-us/azure/data-explorer/ingestion-properties).

In the context of bulk loading data into Data Explorer a key ingestion property is the ```creationTime```. This property determines the creation time associated with the ingested data and most importanly this is used by the retention policy to determine which data resides in the hot cache. If a value is not specified the current time is used as default which has the effect of the historical data being in the hot cache rather than the more commonly expected situation of recent data being cached. The resolution is to specify a creationTime property during a bulk load.

The data factory pipeline shown in the screenshots below shows how csv files from blob storage can be bulk loaded into Azure Data Explorer with the ```creationTime``` ingestion property being set for each COPY activity.

# Historical Load Pipeline

## Azure Data Explorer Setup
This sample will ingest NYC Taxi Trip records. The following table will be used as the destination. 
```
.create table NYCTaxi(VendorID:int32, tpep_pickup_datetime:datetime, tpep_dropoff_datetime:datetime, passenger_count:real, trip_distance:real, RatecodeID:real, store_and_fwd_flag:string, PULocationID:int, DOLocationID:int, payment_type:int, fare_amount:real, extra:real, mta_tax:real, tip_amount:real, tolls_amount:real, improvement_surcharge:real, total_amount:real, congestion_surcharge:real)
```

Create this table in a database that will written to by the Data Factory Pipeline. Ensure the Azure Data Factory managed identity has the ingestor role, if not it can be assigned as follows:
```
.add table NYCTaxi ingestors ('aadapp=<ADF managed identity client id GUID>;<Subscription Id GUID>') '<App Name shown in ADX>'
```

## Azure Storage Account Setup
The ADF pipeline relines on a specific folder structure to ingest the NYC Taxi Trip records. The PowerShell script included in this repository downloads as subset of this dataset for use by the pipeline. The downloaded files need to be added to the storage account using the following structure. NOTE: The script will download almost 1GB of data. The csv files can easily be substituted, just ensure the destination table structure is updated as well.

Here's a view of the required container named ```nyctaxi```
<TBD: container diagram>

And here is a view of the folder structure within the container:
- ```dt=2019``` stores csv files for the year 2019
- ```dt=2022``` stores csv files for the year 2022. We'd like to have these in the hot cache after loading

**Blob Container**

![image](https://user-images.githubusercontent.com/50959956/166411422-e7ed6dcf-2f81-465a-ade6-589399b919d7.png)

**Folders for each year, using Hive naming convention** 
![image](https://user-images.githubusercontent.com/50959956/166411947-f3405471-8255-4f39-a1dc-cc95b49109ce.png)

**Taxi data for a single month of the year, all files for a year will be processed by a single copy activity**
![image](https://user-images.githubusercontent.com/50959956/166411908-4022691c-80a2-4cc6-b41f-02ed3ada0f57.png)



## Azure Data Factory Pipeline

The pipeline is metadata driven with a copy activity being run for each folder containing csv files to be loaded. Each copy activity also specifies the ```creationTime``` as in ingestion property. The list of folders to ingest and the associated creation time is specified using a pipeline parameter ```PartitionsToLoad``` with an array of JSON objects as the value. This allows the pipeline to be reusable across multiple input folders.


The ```PartitionsToLoad``` parameter value is structured as follows. The ```partitionTimestamp``` field is used as the creation time for all files within the source folder. Each array entry is of a string data type.
```json
[
"{'sourceFolder': 'dt=2022', 'partitionTimestamp': '2022-04-26'}", 
"{'sourceFolder': 'dt=2019', 'partitionTimestamp': '2019-01-01'}"
]
```
**Reuse pipeline across input folders by modifying the json parameter value**
<img width="596" alt="image" src="https://user-images.githubusercontent.com/50959956/165667772-401b8bac-b127-47a3-9190-da27aaeddc6d.png">

The ```ForEach``` activity loops over each json object in the ```PartitionsToLoad``` parameter value. 

**A parameter is the source of the items array, could also use Lookup activity**
<img width="599" alt="image" src="https://user-images.githubusercontent.com/50959956/165667885-9cf96f95-5d84-4eaf-b131-afab9306f6be.png">

A Copy activity is run for each JSON object in the array. Each entry in the array is actually a string and needs to parsed as a JSON object to retrieve the individual field values. The ```json``` function is used to conver the string to an object to access the individual fields, in the diagram below the ```sourceFolder``` field is being used.

<img width="598" alt="image" src="https://user-images.githubusercontent.com/50959956/165668026-d3fd0d14-3ff7-4ba8-9416-af114c261062.png">

The sink or destination is an Azure Data Explorer table. The ingestion property is specified as an additional property.

<img width="599" alt="image" src="https://user-images.githubusercontent.com/50959956/165668075-c306a7f6-1ca9-4205-9480-d7d2d9703b34.png">

 Note that dynamic content is used to construct the json object whose fields represent the individual ingestion properties. In this case only the ```creationTime``` property is set and it's value is derived from the ```partitionTImestamp``` field of the input parameter.

<img width="598" alt="image" src="https://user-images.githubusercontent.com/50959956/165668150-fe2ea8f9-8a97-45c6-8a14-7b41f32ff586.png">

For simplicity the field mapping from csv file to Azure Data Explorer table columns is managed by Azure Data Factory. This is done by importing the schemas and using the default mapping of columns. 

<img width="501" alt="image" src="https://user-images.githubusercontent.com/50959956/165668194-be5241bf-7f28-48e0-8675-acf3c8724336.png">

Two linked services are used, one for the Azure Storage Account and Azure Data Explorer.

<img width="590" alt="image" src="https://user-images.githubusercontent.com/50959956/165669284-6573fe2e-34b7-4810-b8c7-d88cabe47859.png">

A dataset is created for the target Azure Data Explorer table. 

<img width="584" alt="image" src="https://user-images.githubusercontent.com/50959956/165669446-15a6287d-62c8-48a3-9f0f-8a368bbdfe85.png">

For flexibility the table name is parameterised.

<img width="524" alt="image" src="https://user-images.githubusercontent.com/50959956/165669478-efd1eae8-7d56-458c-b5ab-5676cb03f8be.png">

The input data set is of type CSV.

<img width="628" alt="image" src="https://user-images.githubusercontent.com/50959956/165669530-d8cbf3ea-9e13-4145-940a-17a7ae740f15.png">

## Verifying the pipeline output
After triggering the pipeline the ADF monitoring output should like the diagram below showing successful completion of all the copy activities, one for each year (or source folder).

<img width="433" alt="image" src="https://user-images.githubusercontent.com/50959956/166181441-25862326-8ec5-4ce4-b6c4-8522c97ac0ec.png">

The number of ingested rows can be confirmed by running the KQL query below:

```
NYCTaxi
| count
```
To confirm that the ```creationTime``` ingestion property has been used run the following query:
```
.show table NYCTaxi extents 
```

The ```MaxCreatedOn``` column will reflect the time specificed by the additional parameters used by the ADF Copy Activity. 

<img width="391" alt="image" src="https://user-images.githubusercontent.com/50959956/166181542-9fe760e0-8e07-4462-98f6-1ab764331d5e.png">

We can also verify that the 2022 taxi data resides in the hot cache by running the following query. The extents created for the 2022 data set should appear in the list.
```
.show table NYCTaxi extents hot
```

<img width="389" alt="image" src="https://user-images.githubusercontent.com/50959956/166181613-d82b54a8-c9f2-4aae-96c4-30d2f4316b8c.png">

