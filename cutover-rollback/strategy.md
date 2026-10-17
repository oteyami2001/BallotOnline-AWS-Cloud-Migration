# Cutover and Rollback Strategy

## Cutover
1. Database validation
2. Application testing
3. Network testing
4. Security validation
5. Performance testing
6. User acceptance testing
7. Final data synchronization, then redirect traffic (DNS)

## Rollback
Keep the legacy environment available, take database backups and checkpoints, and be ready to revert DNS and application connections until the AWS environment is fully validated.
