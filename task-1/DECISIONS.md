# Initial assumptions

- No regulatory compliance necessary
- Each service has its own image repository (ECR) in its respective account
- Each service has its own code repository (not a mono repository)
- Using eu-west-1/Ireland region
- Production access to SES
- Web platform URL is `my-app.com`
- API URL is `api.my-app.com`
- Service A is running on port 8000
- Service B is running on port 8001
- Service A's "calls to [...] other external services" require outbound traffic to the public internet
- Inbound traffic is moderate

# Decisions

## Frontend

To serve a SPA via HTTPS, we will use S3 paired with CloudFront, WAF, ACM for TLS certificates and Route53 for DNS and routing.

S3 is perfect for serving a SPA as it is cheap, scalable and reliable. We don't need to worry about maintaing a web server and it integrates seamlessly with CloudFront. The S3 bucket will have all public access blocked.

CloudFront gives us performance, the ability to use a custom domain when serving the content and provides security for the application/S3 origin as without it we would need to make the S3 bucket publicly accessible. Users cannot bypass CloudFront to access the application. CloudFront is configured with a custom domain name, `my-app.com`, generated via the ACM service. It should be noted that this certificate was generated in the us-east-1 region, as is required to work with CloudFront.

Comparitavely, using EC2 or ECS to host the frontend comes with unnecessary extra management overhead and extra cost. For a more complex application maybe these alternatives are a viable consideration, but for a SPA they are overkill.

Route53 has an alias record pointing `my-app.com` to the CloudFront distribution domain, and an alias record pointing `api.my-app.com` to the ALB.

## Networking and security

The VPCs have been designed with public (in Account A) and private subnets that span across two availability zones for fault tolerance and high availability. Optionally, a third availability zone could be added but seemed like overkill for the platform. 

The frontend, S3 + CloudFront, are AWS-managed globally-accessible services and we don't need to worry about managing their underlying network architecture. The ECS Fargate instances and databases we will use are under our control and will be placed into secure private subnets as we have no desire for external users to be able to access them directly from the public internet. There are two public subnets, in each AZ, in Account A's VPC to host an ALB which will be used to direct traffic to Service A's ECS instances. In Account B, a private NLB is used to direct traffic to Service B's ECS instances. An NLB has been chosen as it is a requirement for PrivateLink.

Both the ALB and CloudFront have WAF integrated to protect against common web exploits, improving the overall security of the platform. 

The ALB is deployed automatically across the availability zones in Account A's VPC's public subnets. It is configured, via security groups, to allow traffic from the public internet on ports 80 and 443, i.e. allow inbound public HTTP/HTTPS traffic and to block all other traffic. A rewrite rule is configured on the ALB to redirect any insecure HTTP traffic (port 80) to HTTPS. Its target group contains Service A's ECS instances [target port 8000].

The NLB deployed automatically across the availability zones in Account B's VPC's private subnets, the same AZs as Account A uses, and is used to provide access (via PrivateLink) to ECS Service B. More notes in the Cross-account connectivity section.

Both ECS services will also be deployed into secure private subnets across both availability zones.

The database will be placed in a private subnet and its security group will only allow access via port 3306 from Service B security group in Account B (more notes in the Database section).

### Outbound traffic

Whilst Service B does not require any access to the public internet, it does need access to AWS services like ECR for image pulling, Secrets Manager to fetch credentials, etc. To allow access to the AWS services, interface endpoints for the following AWS services have been created within Account B's VPC, since only Service B needs access to them:

- Secrets Manager
- CloudWatch logs
- CloudWatch monitoring
- SQS
- ECR API
- ECR DKR
- S3 (ECR image layer storage)

Access to each interface endpoint is restricted via security groups that only allow inbound traffic from the Service B's ECS tasks security group.

Service A makes calls to external APIs over the public internet (from assumptions). To achieve this NAT functionality is required, which brings the decision of using an AWS-managed NAT Gateway or creating our own via a hardened EC2 instance.

Using a managed NAT Gateway has been chosen as the solution as, despite its higher overall cost, NAT Gateways provide reliability and scalability that we would have to manage in a self hosted NAT instance, not to mention the need to manage things like operating system upgrades, applying patches, etcetera. Using the managed solution reduces operational overhead.

To enable outbound traffic via the NAT Gateway, the private subnets in Account A's route tables have been configured to route all traffic bound for the public internet (`0.0.0.0/0`) to the NAT Gateway. 

However, as NAT Gateway ultimately is more costly, and Service A still needs to make requests to external AWS APIs such as ECR and CloudWatch, interface endpoints have also been created, in the same way as for Service B, for Service A to reach these APIs without having to use the NAT Gateway. In this way, the NAT Gateway costs are reduced as only traffic that is truly intended for the public internet will pass through it.

### Service to service authentication

PrivateLink provides a secure means of communication between the services' ECS tasks but doesn't provide secure application level authentication or authorisation. In order to ensure that only Service A can call Service B, application level auth. must be implemented. There are several options for this:

|Method|Advantages|Disadvantages|
|---|---|---|
|API keys|simple implementation, doesn't require any additional AWS services, low latency|risks key leakage, difficult to scale, no identity context|
|mTLS|uses strong cryptographic mutual auth., no shared secrets|requires additional infrastructure to implement, difficult implementation, complex to operate|
|JWT/OAuth2|provides identity context, wide adoption, scalable|requires mechanism to issue tokens, requires management of keys|

JWT has been chosen as the service-to-service authentication mechanism. Service A signs a JWT with an expiry time of 3 minutes using an RSA private key stored in Secrets Manager. Service B verifies the token on every inbound request using the corresponding RSA public key which is also stored in Secrets Manager. Each token contains `iss`, `sub`, `aud` and `exp` claims to provide identity context and prevent reuse after expiry.

JWT eliminates the need for a shared secret between services. Service B holds the public key and cannot impersonate Service A. Limiting the expiry time to 3 minutes means that even if a token is leaked then the blast radius is limited.

## Cross-account connectivity

To tackle cross-account connectivity, there is the option of using PrivateLink, VPC Peering or Transit Gateway. All 3 achieve cross-account connectivity without use of the public internet.

VPC Peering is a viable option but exposes both VPCs to each other in their entirety, which is not desired in this configuration. If the platform were ever to grow and require more accounts/VPCs it would require very careful planning as CIDR overlap is an issue with VPC Peering and could result in access issues. 

Transit Gateway was rejected due to its complexity and overkill for the platform. In a scenario where the platform has 10s of VPCs and multiple landing zones, Transit Gateway would be a viable option.

Because of the requirement for Account A accessing _only_ Account B/Service B's ECS service, PrivateLink has been chosen to achieve cross-account connectivity. PrivateLink enables exposing a specific endpoint in the provider's (Account B) VPC, rather than the whole VPC (as is the case in VPC Peering). To do so, we use an interface endpoint in the consumer's (Account A) VPC's private subnets which will connect to an endpoint service in the provider's VPC, which then connects to a network load balancer to distribute the traffic between Service B's Fargate instances.

### Security

The interface endpoint in Account A has been configured with a security group to only allow traffic Service A's ECS instances security group.

The endpoint service in Account B has been configured to only allow traffic from Account A's account ID via an endpoint policies. On top of this, the acceptance required option is set to true on Account B's endpoint service which means that manual approval must be given to Account A's connection request.

## Containers

The task specifies to use ECS, which brings the decision of using Fargate or EC2 instances. In this scenario, Fargate is the chosen platform. The web application is fairly simple and using EC2 for hosting adds management overhead as we need to manage the launch templates, instance type/resource assignments, applying patches, etc. With Fargate, we don't need to worry about the underlying infrastructure of the services.

### Scaling

The ECS Fargate services are configured with auto-scaling enabled to allow horizontal scaling. This ensures the services will scale dynamically according to spikes or lows in traffic. There are a number of decisions to be made when configuring auto scaling, and the following have been made:

- Minimum number of tasks: 2
- Desired number of tasks: 2
- Maximum number of tasks: 8
- Auto scaling policy: target tracking
- Scale-in/scale-out cooldowns

The platform is initially setup with both Services A and B service running 1 task in each availability zone, making the minimum number of tasks and desired count = 2. Since we are assuming a moderate traffic rate, the maximum number of tasks will be 8 for each service, meaning 4 tasks running in each AZ.

For the scaling policy, a target tracking policy has been chosen over a step scaling policy. This, because we can define a target metric to maintain and the services will be continuously scaled to try and maintain it, rather than step scaling which requires manually defining step sizes and scaling thresholds.

The services have different workloads and purposes and as such will have different scaling metrics tracked. Service A is used to orchestrate calls to Service B and other services and will likely be I/O bound as it doesn't execute CPU processing or memory intensive tasks. As such, the tracked target will be the request count, per target, from the ALB in front of the service. This will allow the service to scale in proportion to the traffic recieved.

Service B is responsible for interacting with the database and as a result likely executes CPU intensive tasks. As such, it makes sense to track the average CPU utilisation, with a target of 70% average utilisation across the tasks. This prevents a scenario in which the service is already oversaturated by the time new tasks are added.

## Database

For the database, RDS with MySQL has been chosen because of the simplicity of the web application and the simplicity of management. 

Self hosted MySQL wasn't considered as it would mean that we have to manage it ourselves, i.e. plan timeframes to apply patches, configure automatic backups, configure multi-AZ and data sync which requires significant effort and is easier achieved by using the AWS-managed RDS service. 

Aurora MySQL was considered but costs more to run and is slightly more complex to manage. However, if the web application were to grow in complexity or we needed a more performant database, Aurora would be the chosen option.

For high availability, the database will be configured with "`multi-az=true`", creating a secondary instance in another availability zone, however, this does come with the caveat that the cost doubles. If cost were to be an issue, and potential downtime could be tolerated for the non-production environments, the multi-AZ configuration could be reserved only for the live/production environment and the dev/stage environments would have single-AZ databases.

All databases in all environments will be encrypted using an encryption key from KMS (and enforce the use of encryption on initial deployment) and will enforce deletion protection.

### Database backups

AWS Backups is chosen as the primary database backup solution for its native integration with RDS (and other services). AWS Backup executes a backup job on a given time period and we can easily monitor that using CloudWatch and generate alarms when/if a backup job failes to execute (and, optionally, when it successfully executes). Since we are assuming no regulatory compliance in the platform, and therefore no data residency regulations, the backup will be replicated across regions for extra availability, should the "main" region ever become unavailable. 

All backups will be encrypted at rest using an encryption key from KMS.

## Message queue/Email

To achieve the message queue, SQS with a Lambda worker have been chosen. For sending the emails we will use SES. 

### SES

To start, ideally we will have production level access to SES. This involves a manual request/ticket to AWS explaining our use case, guarantees that we won't use the service to send spam, how bounced/rejected emails will be handled, etc. We will assume that production level access is already granted.

SES is configured with a verified domain which allows emails to be sent from any email address in the domain, such as `noreply@my-app.com` and `help@my-app.com`.

### SQS

Two queues will be used:

- A "main" queue which will recieve messages from Service B and will trigger the Lambda function
- A dead-letter queue which will recieve failed messages

Using a queue system to send emails means that, should SES ever slow down or become unavailable altogether, emails that have failed to send will remain in the queue up until the end of the retention period defined - in this case, the default of 4 days is sufficient. It also improves API service performance as email sending functionality is handed off to another dedicated system.

Use of the dead-letter queue will prevent failed messages/emails from clogging the main queue, enabling further inspection and investigation of why it/they failed.

### Lambda

SQS triggers the Lambda function which is responsible for calling the SES API to send the email. 

Pseudocode for the function:

```
initialise logging module
initialise ses client

lambda_handler(event):
    failed_messages = []

    for email in event[records]:
        message_id = email[id]
        data = email[body]

        recipient = data[recipient]
        subject = data[subject]
        body = data[body]

        try:
            send email via ses
            log success + message_id
        except transient_error:
            log error + message_id
            failed_messages.append[message_id]
        except permanent_error:
            log error + message_id

    return dictionary {failed_items: failed_messages[msg_id]}
```

## Secrets

Secrets Manager is the chosen solution for sensitive credentials management due to its native integration with other AWS services, support for automatic rotation, is auditable via CloudTrail and the ECS services (tasks) can access it at runtime. The secrets will be encrypted at rest using the KMS service and each environment will have its own set of secrets, such as:

- RDS credentials
- JWT RSA private key on Service A
- JWT RSA public key on Service B

No secrets or sensitive data will be stored in the source code, Docker images or configuration files. Instead, secrets will be injected into the ECS services at runtime and are referenced via the task definitions. They are injected into the containers via their stored ARN values to avoid appearing in plaintext in the ECS console.

Service A will have access to the RSA private key used to sign JWTs issued to Service B.

Service B will have access to the RSA public key used to verify inbound JWTs from Service A and to the RDS credentials.

The secrets are isolated to their respective AWS accounts. Sevice A has no need to know the credentials used to access the RDS or SES service.

### Auditing

Any calls to Secrets Manager are logged in CloudTrail with a 90 day retention/history. By combining CloudTrail with CloudWatch, alerts are created for unusual access/API calls and can be stored in S3 for a longer retention period/long term auditing.

### Rotation

Secrets Manager natively integrates with RDS, allowing for the automatic rotation of credentials used for access. There are two options for how the secrets will be rotated:

- Single-user rotation
- Multi-user rotation

In this scenario, multi-user rotation has been chosen over single-user as it allows the credentials to be rotated/changed without any downtime for Service B. 

With single-user rotation, the credentials would be changed but the ECS service wouldn't be aware of the new credentials, so connections to the database would fail until the service had been redeployed, triggering a new pull of the credentials. Multi-user rotation creates a new database user with the new credentials, leaving the old credentials valid until the rotation is complete. Service B's code must account for the multi-user strategy by requesting and caching the new credentials from Secret Manager if/when the database connection fails with an authentication error.

## Observability (point 5. on task)

To monitor the platform, CloudWatch combined with Xray are the chosen solutions. Their seamless integrations with the other AWS services used in the platform/infrastructure makes them an easy choice for this project.

Account B is designated to be the monitoring account of all resources across the two accounts. Cross-account observability is enabled, which allows CloudWatch in Account B to view and read the metrics, logs, dashboards of Account A. This centralises monitoring and allows for easier and more efficient incident response. This is the most cost effective solution.

A viable alternative is to have an AWS account dedicated to monitoring, acting as the central account and pulling monitoring data from all other accounts. In this configuration, a dedicated IR team can quickly resolve issues and access management is simplified since the IR team can view all relevant data from a single account. Considering the simplicity of the platform and the low number of AWS accounts in use, this strategy was seen as overkill.

An alternative which is also viable but ultimately rejected is to use streaming with subscription filters and Data Firehose to stream monitoring data from Account A to Account B. However, this comes with a cost trade-off as Data Firehose charges per GB ingested whereas the chosen solution has no extra cost. Streaming the data also means copying the data, which means a higher cost as now the data would reside in both accounts, whereas the chosen solution simply allows Account B to read data in Account A.

Per-account monitoring adds complexity with access management and incident response as the responder may have to jump between multiple accounts,and may not have the appropriate level of access to do so, to find the cause of a problem and keep a manual log/following of any traces and was rejected as a solution.

### Alarms and alerting

Some key metrics to monitor include:

- ECS CPU and memory utilisation
- RDS database free storage space left
- RDS database read/write latency
- CloudFront error rate 
- ALB error rate 
- ALB response time
- SQS queue depth
- SQS dead-letter queue depth
- SES bounce/complaint rate
- Access/calls to Secrets Manager
- Secret rotations
- AWS Backup number of failed jobs

Because we are using CloudWatch, we can easily create alarms based on built in and custom metrics. Alarms based on the above metrics will be sent via SNS via fan-out strategy to a number of endpoints, namely: email, SMS and Slack (via a Lambda webhook). 

### Logging strategy

A decision has to be made on log data retention. For this project, since we are assuming no regulatory compliances, the "dev" environment has a 7 day log retention, "staging" has 30 day retention and "prod" has 90 day retention. This is because CloudWatch logs can grow quickly and, as a result, so does the cost to retain them. 

In a world where the platform must be compliant with regulations (healthcare, banking, etc.) then the retention period will need adjusted accordingly.

### Log format

All application logs (Service A, Service B, and Lambda) will use structured JSON logs, rather than plain text logs. This enables efficient querying, filtering and correlation in CloudWatch Logs Insights.

#### Traceability

To correlate logs across Service A, Service B and Lambda a unique `request_id` (UUID) is generated at the point of ingress, when Service A receives a request from the ALB. The ID is:

- Included in every log generated by Service A for the duration of that request
- Forwarded to Service B as an HTTP header (e.g. `X-Request-ID`) on every PrivateLink call
- Included in every log generated by Service B for the duration of that request
- Written into the SQS message body when Service B queues an email job. The Lambda worker can include it in its logs

This means a single `request_id` can be used in CloudWatch Logs Insights to query across all three log groups and follow the full request path without jumping between accounts manually.

Using Xray, the trace can be automatically propagated via an `X-Amzn-Trace-Id` header on outbound calls. The receiving service picks up the header and attaches its segments to the same trace. This gives a visual breakdown of the full request in the CloudWatch Service Map, including latency at each hop.

#### Ingestion

All logs are written to CloudWatch Logs via IAM permissions/roles:

- ECS task execution role
- Lambda execution role

### Dashboards

CloudWatch Dashboards can be created in Account B which provides a single pane of glass-view into the entire platform. On this dashboard we can list all of the alarms that have been created (and whether they are triggered), list the logs of the ECS services, create graphs for resource utilisation/error rates, etc. They are a massively helpful tool for incident response.

The dashboards will include:

- Individual Service (A and B) resource usages and alarms
- A broader system level overview, such as traffic/error rates and latencies

## IAM

IAM roles will be configured to follow the principle of least privilege across both AWS accounts to control access to services. No long-lived IAM users or static keys will be used anywhere in the platform as their use poses the risk of credential leakage.

Use of IAM roles grants the use of temporary credentials which have much less risk of credential leakage. Their use also means that services can automatically recieve/generate credentials when needed.

### ECS

Each ECS service and the Lambda email function have 2 IAM roles:

- task execution role
  - controls access to AWS operations such as pulling ECR images, writing logs to CloudWatch, etc
- task role
  - controls application level permissions such as reading from Secrets Manager, sending messages to SQS

### Secrets Manager

The ECS task roles for both services are granted `secretsmanager:GetSecretValue`, limited to the specific secret ARNs they need — Service A for its RSA private key, Service B for its RSA public key and RDS credentials. Neither service has access to the other's private secrets.

The Lambda email worker has no Secrets Manager access as it has no credentials to manage. SES is called directly via the execution role.

The Secrets Manager rotation Lambda requires `secretsmanager:RotateSecret` and `secretsmanager:DescribeSecret` on the RDS secret, plus `rds-db:connect` to create and update database users during the multi-user rotation cycle.

### Deployment

The CodeDeploy service role is granted `ecs:*`, `elasticloadbalancing:*`, `cloudwatch:DescribeAlarms`, `sns:Publish` and `iam:PassRole` scoped to the respective ECS services and load balancers. This is the minimum set of permissions for CodeDeploy to manage the blue/green deployment.

The `tofu-deploy` role in each account (assumed by the CI/CD pipeline via OIDC) is granted the permissions required to create and manage all resources defined in the IaC (VPC, ECS, RDS, SQS, Secrets Manager, CodeDeploy, etc.) This role is scoped to the target account only and is not granted cross-account permissions.

The remote state reader role (`read-tofu-states`) in the state account is granted read-only access (`s3:GetObject`, `dynamodb:GetItem`) on the state bucket and lock table. Service A's pipeline assumes this role to read Service B's output (the PrivateLink endpoint service name, for example) from the state file.

### Observability

The ECS task execution roles for both services are granted `logs:CreateLogStream` and `logs:PutLogEvents` scoped to their respective CloudWatch log group ARNs. This allows ECS to stream container logs to CloudWatch.

The X-Ray daemon sidecar requires `xray:PutTraceSegments`, `xray:PutTelemetryRecords` and `xray:GetSamplingRules` on the task role, granted to both Service A and Service B task roles.

The Lambda email worker execution role is granted `logs:CreateLogStream` and `logs:PutLogEvents` for its log group, `xray:PutTraceSegments` for tracing, and `kms:Decrypt` on the SQS queue's KMS key to read encrypted messages.

Cross-account observability is enabled by a resource-based policy on Account A's CloudWatch that grants Account B's monitoring role read access (`cloudwatch:GetMetricData`, `logs:FilterLogEvents`, etc.).

### AWS Backup

The AWS Backup service role is granted `rds:CreateDBSnapshot`, `rds:DescribeDBInstances`, `rds:RestoreDBInstanceFromDBSnapshot` and the corresponding KMS permissions (`kms:GenerateDataKey`, `kms:Decrypt`) on the RDS KMS key and the backup vault KMS key. For cross-region copies, the role also requires KMS permissions on the destination region's key.

The backup vault is configured with a resource-based policy that denies `backup:DeleteRecoveryPoint` to all principals except the backup account root. This prevents accidental deletion of backups.

# Extra decision notes

## CI/CD

### Image repository

The assumption has been made that each account has its own ECR image repository. Alternatively, or ideally, there would be an AWS account dedicated to hosting the image repository which contains the images that both services will pull from.