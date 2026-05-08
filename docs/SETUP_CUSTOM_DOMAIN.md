# Setup Custom Domain (diegoayala.click)

Una vez que tengas registrado el dominio en AWS, sigue estos pasos:

## 1. Habilitar Route53 en Terraform

En `infra/main.tf`, descomenta el módulo DNS:

```terraform
module "dns" {
  source = "./modules/dns"

  domain_name = var.domain_name

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1  # ACM requiere us-east-1 para CloudFront
  }
}
```

Y descomenta la sección de providers al inicio:

```terraform
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
```

## 2. Descomenta los A records

En `infra/main.tf`, descomenta:

```terraform
resource "aws_route53_record" "root" {
  # ...
}

resource "aws_route53_record" "www" {
  # ...
}
```

## 3. Agrega la variable en infra/variables.tf

```terraform
variable "domain_name" {
  type = string
  description = "Custom domain for the website"
}
```

## 4. Actualiza infra/terraform.tfvars

```
domain_name = "diegoayala.click"
```

## 5. Actualiza CORS en Terraform

En `infra/main.tf`, pasa el dominio al módulo API:

```terraform
module "api" {
  source = "./modules/api"

  project_name    = var.project_name
  aws_region      = var.aws_region
  allowed_origins = ["https://diegoayala.click", "https://www.diegoayala.click"]
}
```

## 6. Apply Terraform

```bash
cd infra
terraform apply
```

Terraform va a:
- Crear zona Route53 para el dominio
- Generar certificado SSL con ACM (automático)
- Apuntar A records a CloudFront

## 7. Verifica en AWS Console

- Route53 → Hosted zones → diegoayala.click
- Copia los nameservers si el dominio está en otro registrador
- CloudFront → Distributions → verifica que esté usando el certificado personalizado

---

## Troubleshooting

**Error: Certificate not validated**
- Route53 valida automáticamente
- Espera ~10 minutos

**CORS aún da error**
- Verifica que el dominio en CORS sea exactamente el que usas (https://, www, etc)
- Redeploy el Lambda

**DNS no resuelve**
- Verifica que los nameservers apunten correctamente
- Espera propagación (hasta 48h en algunos casos)
