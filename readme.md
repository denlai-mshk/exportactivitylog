#  Powershell script for exporting Activity log as CSV
This Powershell script is designed for for exporting Activity log as CSV across multiple subscriptions and multiple resource groups.


##  Step 1: Install the Azure PowerShell Module
    If you haven't install the following Azure PowerShell module, please send these commands:
```
    Install-Module -Name Az.Accounts -AllowClobber -Force
    Install-Module -Name Az.Sql -AllowClobber -Force
    Install-Module -Name Az.Compute -AllowClobber -Force
    Install-Module -Name powershell-yaml -AllowClobber -Force
```

##  Step 2: Verify the Installation
Verify the modules are installed completely by sending these commands:
```
Get-Module -ListAvailable -Name Az.Sql
Get-Module -ListAvailable -Name Az.Accounts
Get-Module -ListAvailable -Name Az.Compute
Get-Module -ListAvailable -Name powershell-yaml
```   

##  Step 3: Single sign-on with your Azure account
Send "Connect-AzAccount" command to sign on with your browser, you may need to have Azure Subscription Reader role or corresponding role privilege above.

```
Connect-AzAccount -TenantId "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyy"
``` 

##  Step 4: Modify the sublist.txt
Edit the **sublist.txt** and place your subscription name and id after the 1st header row "SubscriptionName", "SubscriptionId"
```
"SubscriptionName", "SubscriptionId", "TenantId"
your-sub-name1, xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx1, yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyy
your-sub-name2, xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx2, yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyy
```  
##  Step 5: Change the config.yaml value
Edit the config.yaml file: Update the values for Days, MaxRecord, and OperationNames according to your requirements.

**Days**: This parameter specifies the number of days in the past from which to retrieve activity logs. For example, setting Days: 60 will retrieve logs from the past 60 days.

**MaxRecord**: This parameter sets the maximum number of records to retrieve for each query. For example, MaxRecord: 100 will limit the query to 100 records.

**OperationNames**: This is a list of operation names to filter the activity logs. Only logs matching these operation names will be processed. You can add or remove operation names as needed. Examples include:

```
- Create new or update existing SQL virtual machine
- Create or Update Virtual Machine
- Delete Virtual Machine
- Delete existing SQL virtual machine
```

##  Step 6: Execute the checksqlahb.ps1 for checking
Open powershell, locate to the script folder, execute  [export](export.ps1)
``` 
.\export.ps1
``` 

Check the activity log may takes 1-2 minutues for each resource group approximately. Please be patient if your subscriptions have a lot of resource groups.

After you see "Exporting is completed. Check the output-xxxxx.csv for details.", then it is done.

