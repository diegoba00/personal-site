# Bootstrap — Pasos manuales previos a Terraform

Estos recursos deben crearse **una sola vez** antes de poder usar Terraform,
ya que son los que almacenan el estado de Terraform mismo.

## 1 — Crear S3 bucket para el estado de Terraform

```bash
aws s3api create-bucket \
  --bucket dha-personal-site-tfstate \
  --region us-east-1 \
  --profile cloud-resume

aws s3api put-bucket-versioning \
  --bucket dha-personal-site-tfstate \
  --versioning-configuration Status=Enabled \
  --profile cloud-resume

aws s3api put-bucket-encryption \
  --bucket dha-personal-site-tfstate \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }' \
  --profile cloud-resume

aws s3api put-public-access-block \
  --bucket dha-personal-site-tfstate \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --profile cloud-resume
```

## 2 — Crear tabla DynamoDB para el lock de estado

```bash
aws dynamodb create-table \
  --table-name dha-personal-site-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1 \
  --profile cloud-resume
```

## 3 — Crear IAM Role para GitHub Actions (OIDC)

```bash
# Crear el Identity Provider de GitHub en IAM
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --profile cloud-resume

# Crear el rol (reemplazar TU_USUARIO con diegoba00)
aws iam create-role \
  --role-name github-actions-personal-site \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::447437755844:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:diegoba00/personal-site:*"
        }
      }
    }]
  }' \
  --profile cloud-resume

# Adjuntar política AdministratorAccess (se puede reducir luego)
aws iam attach-role-policy \
  --role-name github-actions-personal-site \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --profile cloud-resume
```

## 4 — Guardar el ARN del rol en GitHub Secrets

El ARN del rol tiene este formato:
`arn:aws:iam::447437755844:role/github-actions-personal-site`

En el repo de GitHub → **Settings** → **Secrets and variables** → **Actions**:
- Nombre: `AWS_ROLE_ARN`
- Valor: el ARN del rol de arriba
