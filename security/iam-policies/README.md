# IAM Policies

Customer-managed IAM policies for the people running the BallotOnline migration. Workloads and AWS services use roles defined in the [CloudFormation stacks](../../infrastructure-as-code/cloudformation/), not these policies.

| Policy | Attach to | Purpose |
|---|---|---|
| [`require-mfa.json`](require-mfa.json) | Every IAM user group | Denies everything except MFA enrollment and password change until the user signs in with MFA |
| [`migration-operator.json`](migration-operator.json) | Migration engineers | Read migration state; run DMS and MGN steps on `Project=BallotOnline` resources with MFA; destructive actions explicitly denied |

## Who Gets What

| Principal | Access | How |
|---|---|---|
| Account administrators (2 people, break-glass) | Full | `AdministratorAccess` + `require-mfa` |
| Migration engineers | Run the migration | `migration-operator` + `require-mfa` |
| Security reviewers / auditors | Read-only security view | AWS managed `SecurityAudit` + `require-mfa` |
| MGN agent installation | Register source servers | AWS managed `AWSApplicationMigrationAgentInstallationPolicy`, temporary credentials, deleted afterwards |
| Migrated EC2 servers | Systems Manager, CloudWatch agent | Instance profile `ballotonline-ec2-managed` |
| AWS DMS | VPC access, CloudWatch logging | `dms-vpc-role`, `dms-cloudwatch-logs-role` |

## Design Choices

- **MFA in conditions.** Starting, stopping, or cutting over a migration requires `aws:MultiFactorAuthPresent`, so a leaked access key alone cannot change anything.
- **Tag-based scoping.** Mutating DMS and MGN actions only work on resources tagged `Project=BallotOnline`. The deploy script tags every stack, and CloudFormation passes the tag on to the DMS resources. MGN source servers are created by the agent install, so tag them once they appear:

  ```bash
  aws mgn tag-resource --resource-arn <SOURCE_SERVER_ARN> --tags Project=BallotOnline
  ```
- **Explicit denies.** Deleting the database, DMS endpoints, KMS keys, the CloudTrail trail, or GuardDuty is denied even if another policy allows it.
- **Resource ARNs where supported.** List and Describe calls that don't support resource-level permissions use `*`; everything else is scoped to ARNs.

## Validation

Both policies were checked with [Parliament](https://github.com/duo-labs/parliament), an IAM policy linter:

- `migration-operator.json`: no findings
- `require-mfa.json`: one expected finding, because the policy lets users manage their own password and MFA device (limited to `${aws:username}`)

Before using them in a real account, also run **IAM Access Analyzer policy validation** and test with the **IAM policy simulator**. AWS MGN can need extra EC2 permissions for launches, depending on how the account is set up.
