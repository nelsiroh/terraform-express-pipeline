#!/bin/bash
# To run script, execute "./bootstrap.sh --profile {aws-profile}  --region {aws-region}"

# Default values
AWS_REGION="us-east-2"
COMPANY_NAME="aethernubis"
AWS_PROFILE="default" # Fallback to default AWS profile if not specified

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --profile) AWS_PROFILE="$2"; shift ;;
        --region) AWS_REGION="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Validate required parameters
if [[ -z "$AWS_PROFILE" ]]; then
    echo "Error: AWS profile not specified."
    exit 1
fi
if [[ -z "$AWS_REGION" ]]; then
    echo "Error: AWS region not specified."
    exit 1
fi

# Terraform State Backend Resources
S3_BUCKET_NAME="${COMPANY_NAME}-tfstate-bucket-${AWS_REGION}"
DYNAMODB_TABLE_NAME="${COMPANY_NAME}-tf-lock-table-${AWS_REGION}"
KMS_KEY_ALIAS="alias/${COMPANY_NAME}-tfstate-key-${AWS_REGION}"

# IAM Role for Terraform Administration (Global, does not need per-region changes)
IAM_ROLE_NAME="${COMPANY_NAME}-terraform-admin"
IAM_ROLE_ARN="arn:aws:iam::$(aws sts get-caller-identity --query "Account" --output text --profile "$AWS_PROFILE"):role/${IAM_ROLE_NAME}"

# Create S3 bucket for Terraform state if it doesn't exist
if ! aws s3api head-bucket --bucket "$S3_BUCKET_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" 2>/dev/null; then
  echo "Creating S3 bucket: $S3_BUCKET_NAME"
  if [ "$AWS_REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$S3_BUCKET_NAME" --profile "$AWS_PROFILE"
  else
    aws s3api create-bucket --bucket "$S3_BUCKET_NAME" --region "$AWS_REGION" --create-bucket-configuration LocationConstraint="$AWS_REGION" --profile "$AWS_PROFILE"
  fi
  aws s3api put-bucket-versioning --bucket "$S3_BUCKET_NAME" --versioning-configuration Status=Enabled --region "$AWS_REGION" --profile "$AWS_PROFILE"
  aws s3api put-bucket-encryption --bucket "$S3_BUCKET_NAME" --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms","KMSMasterKeyID":"'$KMS_KEY_ALIAS'"}}]}' --region "$AWS_REGION" --profile "$AWS_PROFILE"
  aws s3api put-public-access-block --bucket "$S3_BUCKET_NAME" --public-access-block-configuration \
    '{"BlockPublicAcls":true,"IgnorePublicAcls":true,"BlockPublicPolicy":true,"RestrictPublicBuckets":true}' --region "$AWS_REGION" --profile "$AWS_PROFILE"
fi

# Create KMS CMK if it doesn't exist
if ! aws kms describe-key --key-id "$KMS_KEY_ALIAS" --region "$AWS_REGION" --profile "$AWS_PROFILE" 2>/dev/null; then
  echo "Creating KMS CMK for Terraform state encryption"
  KMS_KEY_ID=$(aws kms create-key --description "Terraform State Encryption Key (${AWS_REGION})" \
    --key-usage ENCRYPT_DECRYPT --customer-master-key-spec SYMMETRIC_DEFAULT \
    --query KeyMetadata.Arn --output text --region "$AWS_REGION" --profile "$AWS_PROFILE")
  aws kms create-alias --alias-name "$KMS_KEY_ALIAS" --target-key-id "$KMS_KEY_ID" --region "$AWS_REGION" --profile "$AWS_PROFILE"
fi

# Create DynamoDB table for state locking if it doesn't exist
if ! aws dynamodb describe-table --table-name "$DYNAMODB_TABLE_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" 2>/dev/null; then
  echo "Creating DynamoDB table: $DYNAMODB_TABLE_NAME"
  aws dynamodb create-table --table-name "$DYNAMODB_TABLE_NAME" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST --region "$AWS_REGION" --profile "$AWS_PROFILE"
fi

# Create IAM Role for Terraform Administration if it doesn't exist (Global)
if ! aws iam get-role --role-name "$IAM_ROLE_NAME" --profile "$AWS_PROFILE" 2>/dev/null; then
  echo "Creating IAM Role: $IAM_ROLE_NAME"
  aws iam create-role --role-name "$IAM_ROLE_NAME" --profile "$AWS_PROFILE" \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {"Service": "ec2.amazonaws.com"},
          "Action": "sts:AssumeRole"
        }
      ]
    }'
  aws iam attach-role-policy --role-name "$IAM_ROLE_NAME" --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess" --profile "$AWS_PROFILE"
fi

# Output Terraform backend configuration
cat <<EOF > backend.tf
terraform {
  backend "s3" {
    bucket         = "$S3_BUCKET_NAME"
    key            = "terraform.tfstate"
    region         = "$AWS_REGION"
    encrypt        = true
    dynamodb_table = "$DYNAMODB_TABLE_NAME"
    kms_key_id     = "$KMS_KEY_ALIAS"
  }
}
EOF

echo "Bootstrap complete for region $AWS_REGION using profile $AWS_PROFILE! Terraform backend and IAM role are ready."
