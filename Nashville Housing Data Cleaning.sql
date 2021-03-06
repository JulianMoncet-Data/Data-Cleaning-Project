CREATE TABLE IF NOT EXISTS NashvilleHousing (
    UniqueID VARCHAR (255),
    ParcelID VARCHAR(255),
    LandUse VARCHAR (255),
    PropertyAddress VARCHAR (255),
    SaleDate date,
    SalePrice INTEGER,
    LegalReference VARCHAR (255),
    SoldAsVacant VARCHAR (255),
    OwnerName VARCHAR (255),
    OwnerAddress VARCHAR (255),
    Acreage VARCHAR (255),
    TaxDistrict VARCHAR (255),
    LandValue INTEGER,
    BuildingValue INTEGER,
    TotalValue INTEGER,
    YearBuilt INTEGER,
    Bedrooms INTEGER,
    FullBath INTEGER,
    HalfBath INTEGER
    );
    
SET SQL_SAFE_UPDATES =1;
SET @@GLOBAL.local_infile = 1;
select * from NashvilleHousing;
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Nashville_Housing_Data_Cleaning_csv.csv' 
INTO TABLE NashvilleHousing 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

-- Populate NULL Values in Property Adress--

select PropertyAddress
from NashvilleHousing;

Select *
From NashvilleHousing
-- Where PropertyAddress is null
order by ParcelID;

-- Above statement is showing all NULL values that NEED to have the Property Address. How? Using Owner Address and doing a JOIN in the same table using UniqueID, since ParcelID is Duplicated. --

Select a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, COALESCE(b.PropertyAddress,a.PropertyAddress)
From nashvillehousing a
JOIN nashvillehousing b
	on a.ParcelID = b.ParcelID
	AND a.UniqueID <> b.UniqueID
Where a.PropertyAddress = '';

Update nashvillehousing a
JOIN nashvillehousing b
on a.ParcelID = b.ParcelID
	AND a.UniqueID <> b.UniqueID
	SET a.PropertyAddress= COALESCE(b.PropertyAddress,a.PropertyAddress)
Where a.PropertyAddress = '';

-- In the above Query, I needed to diisable Safe mode in MySql so I could run the query using WHERE without a Key Column. Suspect I would not have that error if I have 2 tables --
-- Using UniqueID, we for sure know the date will not repeat itself, and we can use it to Populate the NULL data in PropertyAdress --

-- Dividing Address into Individual Columns (Address, City, State) In Mysql we use LOCATE and not CHARINDEX like Microsoft--
Select *
from nashvillehousing;

SELECT
SUBSTRING(PropertyAddress, 1, LOCATE(',', PropertyAddress) -1 ) as Address
, SUBSTRING(PropertyAddress, LOCATE(',', PropertyAddress) + 1 , CHAR_LENGTH(PropertyAddress)) as Address
From nashvillehousing;

-- Now ADD Tables with the Data divided. Also disable Safe Mode to Update the data in the new row --
SET SQL_SAFE_UPDATES =1;

ALTER TABLE nashvillehousing
Add PropertySplitAddress char(255);

Update NashvilleHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, LOCATE(',', PropertyAddress) -1 );

ALTER TABLE NashvilleHousing
Add PropertySplitCity char(255);

Update NashvilleHousing
SET PropertySplitCity = SUBSTRING(PropertyAddress, LOCATE(',', PropertyAddress) + 1 , CHAR_LENGTH(PropertyAddress));

Select OwnerAddress
From nashvillehousing;

-- Whith the above query, we see that the Owner Adress is also all in one. So now, we need to do the same as before --

SELECT
SUBSTRING(OwnerAddress, 1, LOCATE(',', OwnerAddress) -1 ) as Address
, SUBSTRING(OwnerAddress, 21, LOCATE(',', OwnerAddress) -5 ) as Address
, SUBSTRING(OwnerAddress, LOCATE(',', OwnerAddress) + 18 , CHAR_LENGTH(OwnerAddress)) as Address
From nashvillehousing;
-- Remember to turn off safe mode to update tables --

SET SQL_SAFE_UPDATES =0;

ALTER TABLE nashvillehousing
Add OwnerSplitAddress  char(255);

Update nashvillehousing
SET OwnerSplitAddress  = SUBSTRING(OwnerAddress, 1, LOCATE(',', OwnerAddress) -1 );

ALTER TABLE nashvillehousing
Add OwnerSplitCity  char(255);

Update nashvillehousing
SET OwnerSplitCity  = SUBSTRING(OwnerAddress, 21, LOCATE(',', OwnerAddress) -5 );

ALTER TABLE nashvillehousing
Add OwnerSplitState char(255);

Update nashvillehousing
SET OwnerSplitState = SUBSTRING(OwnerAddress, LOCATE(',', OwnerAddress) + 18 , CHAR_LENGTH(OwnerAddress));

Select *
From nashvillehousing

-- It wasn??t the best Query of all time, adn have errors on it. Will read MySql manual to see other query shorter and more effective than these one --
-- Now change Y and N to Yes and No in "Sold as Vacant" field --

Select Distinct(SoldAsVacant), Count(SoldAsVacant)
From nashvillehousing
Group by SoldAsVacant
order by 2;

Select SoldAsVacant
, CASE When SoldAsVacant = 'Y' THEN 'Yes'
	   When SoldAsVacant = 'N' THEN 'No'
	   ELSE SoldAsVacant
	   END
From nashvillehousing;

Update nashvillehousing
SET SoldAsVacant = CASE When SoldAsVacant = 'Y' THEN 'Yes'
	   When SoldAsVacant = 'N' THEN 'No'
	   ELSE SoldAsVacant
	   END;
       
-- Now it??ss time to remove duplicates --

Select *,
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
				 PropertyAddress,
				 SalePrice,
				 SaleDate,
				 LegalReference
				 ORDER BY
					UniqueID
					) row_num

From nashvillehousing;
-- order by ParcelID --
-- Now we delete them so we have valuable data in place --

DELETE FROM nashvillehousing WHERE ParcelID(
Select *,
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
				 PropertyAddress,
				 SalePrice,
				 SaleDate,
				 LegalReference
				 ORDER BY
					UniqueID
					) row_num

From nashvillehousing
-- order by ParcelID
);

SELECT *, ROW_NUMBER()   
OVER (PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference ORDER BY PropertyAddress) AS row_num
FROM nashvillehousing; 

-- Now we search all duplicates using row_num>1 --

SELECT * FROM (SELECT ParcelID, ROW_NUMBER()   
OVER (PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference ORDER BY PropertyAddress) AS row_num   
FROM nashvillehousing) AS temp_table WHERE row_num>1;

-- We now have 104 records duplicated, and it's time to delet them --

DELETE FROM nashvillehousing WHERE UniqueID IN(
SELECT UniqueID FROM (SELECT UniqueID, ROW_NUMBER()   
OVER (PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference ORDER BY PropertyAddress) AS row_num   
FROM nashvillehousing) AS temp_table WHERE row_num>1
);

-- Double check using above query if everything was deleted --

SELECT * FROM (SELECT ParcelID, ROW_NUMBER()   
OVER (PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference ORDER BY PropertyAddress) AS row_num   
FROM nashvillehousing) AS temp_table WHERE row_num>1;

-- And to finish, delete rows we are not going to use anymore --

Select *
From nashvillehousing;

ALTER TABLE nashvillehousing
DROP COLUMN OwnerAddress,
DROP COLUMN PropertyAddress,
DROP COLUMN TaxDistrict;

-- Project finished --