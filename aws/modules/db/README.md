# RDS Module

AWS RDS MySQL 인스턴스를 생성하는 Terraform 모듈입니다.

## 📋 개요

이 모듈은 다음 리소스를 생성합니다:

- **DB Subnet Group**: Multi-AZ 배포를 위한 서브넷 그룹
- **DB Parameter Group**: MySQL 파라미터 설정 (UTF-8, 한국 시간대 기본 적용)
- **Security Group**: RDS 접근 제어
- **RDS Instance**: MySQL 데이터베이스 인스턴스

---

## 🏗️ 아키텍처

```
                    ┌──────────────────────────────────────┐
                    │              VPC                     │
                    │                                      │
  ┌─────────────────┼──────────────────────────────────────┼─────────────────┐
  │                 │         Private DB Subnet            │                 │
  │   ┌─────────────┼──────────────────────────────────────┼─────────────┐   │
  │   │             │                                      │             │   │
  │   │   AZ-2a     │         ┌──────────────┐             │   AZ-2c     │   │
  │   │             │         │    RDS       │             │             │   │
  │   │  Subnet     │         │   MySQL      │             │  Subnet     │   │
  │   │  10.0.150.0 │         │              │             │  10.0.160.0 │   │
  │   │             │         └──────────────┘             │             │   │
  │   │             │                ↑                     │             │   │
  │   └─────────────┼────────────────┼─────────────────────┼─────────────┘   │
  │                 │                │                     │                 │
  └─────────────────┼────────────────┼─────────────────────┼─────────────────┘
                    │                │                     │
                    │     Security Group Rule              │
                    │     (Port 3306)                      │
                    │                │                     │
  ┌─────────────────┼────────────────┼─────────────────────┼──────────────────┐
  │                 │         Private EKS Subnet           │                  │
  │                 │                │                     │                  │
  │   ┌─────────────┴────────────────┴─────────────────────┴──────────────┐   │
  │   │                                                                   │   │
  │   │              EKS Worker Nodes (Petclinic App)                     │   │
  │   │                                                                   │   │
  │   └───────────────────────────────────────────────────────────────────┘   │
  │                                                                           │
  └───────────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 사용법

### 기본 사용

```hcl
module "db" {
  source = "./modules/db"

  identifier = "${var.project_name}-mysql"
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_db_subnet_id

  # 데이터베이스 설정
  db_name  = "petclinic"
  username = "admin"
  password = var.db_password  # tfvars 또는 환경변수로 전달

  # 접근 허용 - EKS Worker Node에서 접근 가능하도록 설정
  allowed_security_group_ids = [module.eks.node_security_group_id]

  tags = {
    Project     = var.project_name
    Environment = "production"
  }
}
```

### 전체 옵션 사용

```hcl
module "db" {
  source = "./modules/db"

  # 필수 설정
  identifier = "${var.project_name}-mysql"
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_db_subnet_id

  # 엔진 설정
  engine                 = "mysql"
  engine_version         = "8.0"
  parameter_group_family = "mysql8.0"

  # 인스턴스 사양
  instance_class = "db.t3.small"

  # 스토리지
  allocated_storage     = 20
  max_allocated_storage = 100  # Storage Auto Scaling 활성화
  storage_type          = "gp3"
  storage_encrypted     = true

  # 데이터베이스
  db_name  = "petclinic"
  username = "admin"
  password = var.db_password

  # 네트워크
  port                = 3306
  publicly_accessible = false
  multi_az            = true  # 프로덕션 환경에서 권장

  # 접근 허용
  allowed_security_group_ids = [
    module.eks.node_security_group_id,
    module.ec2.mgmt_security_group_id
  ]

  # 백업
  backup_retention_period = 7
  backup_window           = "03:00-04:00"

  # 유지보수
  maintenance_window         = "Mon:04:00-Mon:05:00"
  auto_minor_version_upgrade = true

  # 삭제 보호 (프로덕션에서 true 권장)
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-mysql-final-snapshot"

  tags = {
    Project     = var.project_name
    Environment = "production"
  }
}
```

---

## 📥 입력 변수

### 필수 변수

| 변수명 | 타입 | 설명 |
|--------|------|------|
| `identifier` | string | RDS 인스턴스 식별자 |
| `vpc_id` | string | VPC ID |
| `subnet_ids` | list(string) | DB Subnet Group에 포함될 서브넷 ID |
| `password` | string | 마스터 사용자 비밀번호 (8자 이상) |

### 선택 변수

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `engine` | string | "mysql" | DB 엔진 |
| `engine_version` | string | "8.0" | DB 엔진 버전 |
| `instance_class` | string | "db.t3.micro" | 인스턴스 클래스 |
| `allocated_storage` | number | 20 | 스토리지 크기 (GB) |
| `db_name` | string | "petclinic" | 데이터베이스 이름 |
| `username` | string | "admin" | 마스터 사용자 이름 |
| `multi_az` | bool | false | Multi-AZ 배포 |
| `backup_retention_period` | number | 7 | 백업 보관 기간 (일) |

> 💡 전체 변수 목록은 `variables.tf`를 참조하세요.

---

## 📤 출력 값

| 출력명 | 설명 | 사용 예 |
|--------|------|---------|
| `endpoint` | RDS 엔드포인트 (host:port) | Kubernetes Secret |
| `address` | 호스트명 (포트 제외) | 환경변수 설정 |
| `port` | 데이터베이스 포트 | 연결 설정 |
| `connection_string` | JDBC 연결 문자열 | Spring Boot 설정 |
| `security_group_id` | RDS Security Group ID | 추가 규칙 설정 |

---

## 🔌 Spring Boot 연동

### Kubernetes Secret 생성

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: petclinic-db-secret
type: Opaque
stringData:
  SPRING_DATASOURCE_URL: "jdbc:mysql://<RDS_ENDPOINT>/petclinic?useSSL=true"
  SPRING_DATASOURCE_USERNAME: "admin"
  SPRING_DATASOURCE_PASSWORD: "<DB_PASSWORD>"
```

### application.yml 설정

```yaml
spring:
  datasource:
    url: ${SPRING_DATASOURCE_URL}
    username: ${SPRING_DATASOURCE_USERNAME}
    password: ${SPRING_DATASOURCE_PASSWORD}
    driver-class-name: com.mysql.cj.jdbc.Driver
```

---

## 🔐 보안 고려사항

1. **Private Subnet 배치**: RDS는 항상 Private Subnet에 배치됩니다.
2. **Security Group**: 명시적으로 허용된 소스만 접근 가능합니다.
3. **암호화**: 스토리지 암호화가 기본 활성화되어 있습니다.
4. **비밀번호 관리**: 비밀번호는 tfvars나 환경변수로 전달하고, 코드에 하드코딩하지 마세요.

---

## 💰 비용 최적화

### 개발 환경

```hcl
instance_class    = "db.t3.micro"  # 프리 티어
multi_az          = false
allocated_storage = 20
```

### 프로덕션 환경

```hcl
instance_class      = "db.t3.small" 이상
multi_az            = true
allocated_storage   = 50+
deletion_protection = true
```

---

## 📚 참고 자료

- [Amazon RDS 공식 문서](https://docs.aws.amazon.com/rds/)
- [Terraform AWS RDS Module](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance)