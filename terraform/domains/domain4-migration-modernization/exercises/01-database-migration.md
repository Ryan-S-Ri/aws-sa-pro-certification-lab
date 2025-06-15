# Exercise 1: Database Migration with DMS

## Objective
Migrate a database from on-premises to AWS using Database Migration Service.

## Prerequisites
- DMS replication instance deployed
- Source and target databases ready
- Network connectivity established

## Duration
60 minutes

## Tasks

### Task 1: Configure DMS Endpoints
```bash
# Create source endpoint
aws dms create-endpoint \
  --endpoint-identifier source-mysql \
  --endpoint-type source \
  --engine-name mysql \
  --server-name source.example.com \
  --port 3306 \
  --username admin \
  --password password

# Create target endpoint
aws dms create-endpoint \
  --endpoint-identifier target-aurora \
  --endpoint-type target \
  --engine-name aurora \
  --server-name $(terraform output -raw aurora_endpoint) \
  --port 3306 \
  --username admin \
  --password password
```

### Task 2: Create Migration Task
1. Define table mappings
2. Configure migration type
3. Start migration task

### Task 3: Monitor Migration Progress
```bash
# Check task status
aws dms describe-replication-tasks \
  --query 'ReplicationTasks[].{Status:Status,Progress:ReplicationTaskStats}'
```

## Validation
- Data successfully migrated
- Target database contains all data
- Applications can connect to new database
