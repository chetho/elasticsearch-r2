# Elasticsearch 9.1.0 → 9.1.1 Upgrade Strategy for Nomad

## Pre-Upgrade Checklist

### 1. Backup Your Data
```bash
# Create a snapshot before upgrade
curl -X PUT "localhost:9200/_snapshot/my_backup/snapshot_before_911_upgrade?wait_for_completion=true" -H 'Content-Type: application/json' -d'
{
  "indices": "*",
  "ignore_unavailable": true,
  "include_global_state": true
}'
```

### 2. Check Cluster Health
```bash
# Verify cluster is green before starting
curl -X GET "localhost:9200/_cluster/health?pretty"
curl -X GET "localhost:9200/_cat/nodes?v"
```

### 3. Disable Shard Allocation (Important!)
```bash
# Prevent shard rebalancing during upgrade
curl -X PUT "localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d'
{
  "persistent": {
    "cluster.routing.allocation.enable": "primaries"
  }
}'
```

## Upgrade Strategies

### Option 1: Rolling Upgrade (Recommended for patch versions)

#### Step 1: Update Your Nomad Job File
```hcl
job "elasticsearch" {
  datacenters = ["dc1"]
  type = "service"
  
  # Use update stanza for controlled rolling deployment
  update {
    max_parallel = 1          # Upgrade one node at a time
    health_check = "checks"   # Wait for health checks
    min_healthy_time = "30s"  # Wait 30s after health checks pass
    healthy_deadline = "5m"   # Max time to wait for health
    progress_deadline = "10m" # Max time for entire deployment
    auto_revert = true        # Auto-revert on failure
    auto_promote = true       # Auto-promote when all healthy
  }
  
  group "elasticsearch" {
    count = 3  # Your cluster size
    
    # Add restart policy
    restart {
      attempts = 2
      interval = "5m"
      delay = "25s"
      mode = "delay"
    }
    
    task "elasticsearch" {
      driver = "docker"
      
      config {
        image = "chetho/elasticsearch-r2:9.1.1"  # Updated version
        # ...existing config...
      }
      
      # Health check configuration
      service {
        name = "elasticsearch"
        port = "http"
        
        check {
          type = "http"
          path = "/_cluster/health"
          interval = "10s"
          timeout = "5s"
          check_restart {
            limit = 3
            grace = "30s"
          }
        }
      }
      
      # ...rest of your configuration...
    }
  }
}
```

#### Step 2: Deploy the Update
```bash
# Deploy with controlled rollout
nomad job run elasticsearch.nomad

# Monitor the deployment
nomad job status elasticsearch
nomad alloc logs -f <allocation-id>
```

#### Step 3: Monitor Each Node Upgrade
```bash
# Watch cluster health during upgrade
watch -n 5 'curl -s "localhost:9200/_cluster/health?pretty"'

# Check node versions
curl -X GET "localhost:9200/_cat/nodes?v&h=name,version,node.role"
```

### Option 2: Blue-Green Deployment (Safer but more complex)

#### Step 1: Create New Job with Different Name
```hcl
job "elasticsearch-v911" {
  # Same config as above but with new image
  # Deploy alongside existing cluster
}
```

#### Step 2: Migrate Data
```bash
# Use reindex API to move data
curl -X POST "localhost:9200/_reindex" -H 'Content-Type: application/json' -d'
{
  "source": {
    "remote": {
      "host": "http://old-cluster:9200"
    },
    "index": "*"
  },
  "dest": {
    "index": "*"
  }
}'
```

## Post-Upgrade Steps

### 1. Re-enable Shard Allocation
```bash
curl -X PUT "localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d'
{
  "persistent": {
    "cluster.routing.allocation.enable": null
  }
}'
```

### 2. Verify Cluster Health
```bash
# Wait for cluster to return to green
curl -X GET "localhost:9200/_cluster/health?wait_for_status=green&timeout=30s"

# Check all nodes are on new version
curl -X GET "localhost:9200/_cat/nodes?v&h=name,version"
```

### 3. Performance Check
```bash
# Run some basic queries to ensure everything works
curl -X GET "localhost:9200/_cat/indices?v"
curl -X GET "localhost:9200/_cluster/stats?pretty"
```

## Monitoring During Upgrade

### Key Metrics to Watch
```bash
# Cluster health
curl -X GET "localhost:9200/_cluster/health"

# Node status
curl -X GET "localhost:9200/_cat/nodes?v"

# Shard allocation
curl -X GET "localhost:9200/_cat/shards?v"

# Pending tasks
curl -X GET "localhost:9200/_cat/pending_tasks?v"
```

### Nomad Monitoring
```bash
# Watch deployment progress
nomad job status elasticsearch

# Check allocation health
nomad alloc status <allocation-id>

# View logs
nomad alloc logs <allocation-id> elasticsearch
```

## Rollback Plan

If issues occur during upgrade:

### Automatic Rollback (if auto_revert enabled)
```bash
# Nomad will automatically rollback if health checks fail
nomad job status elasticsearch
```

### Manual Rollback
```bash
# Revert to previous job version
nomad job revert elasticsearch <previous-version>

# Or redeploy with old image
# Update job file with old image and run
nomad job run elasticsearch.nomad
```

### Data Rollback (if needed)
```bash
# Restore from snapshot
curl -X POST "localhost:9200/_snapshot/my_backup/snapshot_before_911_upgrade/_restore"
```

## Best Practices

1. **Test in staging first** - Always test the upgrade process in a non-production environment
2. **Upgrade during maintenance window** - Plan for potential downtime
3. **Monitor closely** - Watch logs and metrics during the entire process
4. **One node at a time** - Never upgrade multiple nodes simultaneously
5. **Verify at each step** - Check cluster health after each node upgrade
6. **Have rollback ready** - Prepare rollback procedure before starting

## Common Issues and Solutions

### Split Brain Prevention
- Ensure `discovery.zen.minimum_master_nodes` is set correctly
- Use odd number of master-eligible nodes (3, 5, 7)

### Memory Issues
- Monitor heap usage during upgrade
- Consider temporarily increasing heap size if needed

### Network Partitions
- Ensure all nodes can communicate during upgrade
- Check Nomad client connectivity

## Elasticsearch 9.x Specific Notes

- S3 repository plugin (for R2) should be compatible across 9.1.x versions
- Check release notes for any breaking changes between 9.1.0 and 9.1.1
- Verify plugin compatibility if using additional plugins
