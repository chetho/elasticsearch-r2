# Migration Guide: Docker Hub → AWS ECR Public

## Overview
This guide will help you migrate your Elasticsearch Docker images from Docker Hub to AWS ECR Public. ECR Public provides free public container registries with better performance and no rate limits.

## Benefits of ECR Public vs Docker Hub
✅ **No rate limits** for public repositories  
✅ **Better performance** (especially for AWS workloads)  
✅ **Free hosting** for public images  
✅ **Integration** with AWS services  
✅ **Global replication** automatically handled  
✅ **No Docker Hub account** required for pulling images  

## Setup Steps

### 1. Create AWS Account (Required for Publishing)
Even though pulling is free without an account, you need an AWS account to push images.

1. Go to [AWS Console](https://aws.amazon.com/)
2. Create a free AWS account
3. Navigate to ECR Public (only available in `us-east-1`)

### 2. Create ECR Public Repository

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS CLI
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key  
# Default region: us-east-1
# Default output format: json

# Create ECR Public repository
aws ecr-public create-repository \
    --repository-name elasticsearch-r2 \
    --region us-east-1
```

### 3. Get Your Registry Alias

```bash
# Get your registry alias (you'll need this for the pipeline)
aws ecr-public describe-registries --region us-east-1 --query 'registries[0].aliases[0].name' --output text
```

### 4. Update GitHub Secrets

Add these secrets to your GitHub repository:

```
Settings → Secrets and variables → Actions → New repository secret
```

**Required Secrets:**
- `AWS_ACCESS_KEY_ID` - Your AWS access key
- `AWS_SECRET_ACCESS_KEY` - Your AWS secret key

**Remove Old Secrets:**
- `DOCKER_USERNAME` (no longer needed)
- `DOCKER_ACCESS_TOKEN` (no longer needed)

### 5. Update Pipeline Configuration

In your `pipeline.yml`, update the `ECR_REGISTRY_ALIAS`:

```yaml
env:
  DOCKER_REGISTRY: public.ecr.aws
  ECR_REGISTRY_ALIAS: your-actual-alias  # Replace with your alias from step 3
  IMAGE_NAME: elasticsearch-r2
```

### 6. Test the Migration

1. **Push to develop branch** to test the new pipeline
2. **Check ECR Public** to see your images
3. **Test pulling** the new images

## New Image URLs

### Before (Docker Hub):
```bash
docker pull chetho/elasticsearch-r2:9.1.1
docker pull chetho/elasticsearch-r2:develop
docker pull chetho/elasticsearch-r2:latest
```

### After (ECR Public):
```bash
docker pull public.ecr.aws/your-alias/elasticsearch-r2:9.1.1
docker pull public.ecr.aws/your-alias/elasticsearch-r2:develop  
docker pull public.ecr.aws/your-alias/elasticsearch-r2:latest
```

## Update Your Nomad Jobs

### Old Nomad Configuration:
```hcl
config {
  image = "chetho/elasticsearch-r2:9.1.1"
}
```

### New Nomad Configuration:
```hcl
config {
  image = "public.ecr.aws/your-alias/elasticsearch-r2:9.1.1"
}
```

## Pipeline Features (Same as Before)

✅ **Automatic version tagging** from Dockerfile  
✅ **Security scanning** with Trivy  
✅ **Develop branch cleanup** after PR merge  
✅ **Multi-platform builds** (ARM64 primary)  
✅ **Cache optimization** for faster builds  

## ECR Public Specific Features

### Viewing Your Repository
```bash
# List repositories
aws ecr-public describe-repositories --region us-east-1

# List images in repository
aws ecr-public describe-images \
    --repository-name elasticsearch-r2 \
    --region us-east-1
```

### Manual Image Management
```bash
# Delete specific image
aws ecr-public batch-delete-image \
    --repository-name elasticsearch-r2 \
    --image-ids imageTag=old-tag \
    --region us-east-1

# Get image details
aws ecr-public describe-images \
    --repository-name elasticsearch-r2 \
    --image-ids imageTag=9.1.1 \
    --region us-east-1
```

## Cost Comparison

| Feature | Docker Hub | ECR Public |
|---------|------------|------------|
| Public repositories | 1 free, then $5/month | Unlimited free |
| Bandwidth | Rate limited | No limits |
| Storage | 1GB free | 50GB free |
| Pulls | 100/6h anonymous, 200/6h authenticated | Unlimited |
| Team accounts | $5/month per user | Free |

## Migration Checklist

- [ ] Create AWS account
- [ ] Create ECR Public repository
- [ ] Get registry alias
- [ ] Update GitHub secrets
- [ ] Update pipeline with your registry alias
- [ ] Test pipeline with develop branch
- [ ] Update Nomad job configurations
- [ ] Update documentation/README
- [ ] Notify team of new image URLs
- [ ] (Optional) Delete old Docker Hub repository

## Rollback Plan

If you need to rollback to Docker Hub:

1. Revert the pipeline changes
2. Add back Docker Hub secrets
3. Update Nomad jobs back to Docker Hub URLs

## Best Practices

1. **Use specific version tags** in production: `public.ecr.aws/your-alias/elasticsearch-r2:9.1.1`
2. **Monitor repository size** in AWS Console
3. **Set up lifecycle policies** if needed to manage old images
4. **Use ECR scanning** features for additional security
5. **Document the new URLs** for your team

## Support

- **ECR Public Documentation**: https://docs.aws.amazon.com/AmazonECR/latest/public/
- **AWS CLI ECR Commands**: https://docs.aws.amazon.com/cli/latest/reference/ecr-public/
- **Pricing**: https://aws.amazon.com/ecr/pricing/ (Public repositories are free!)

## Next Steps

1. Complete the setup steps above
2. Test the migration thoroughly
3. Update all dependent systems (Nomad, docs, etc.)
4. Enjoy better performance and no rate limits! 🚀
