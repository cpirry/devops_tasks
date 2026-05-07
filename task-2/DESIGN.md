# Assumptions

- us-east-1 is the primary/main region (the region with the most users)
- Service A doesn't make any calls to/over the public internet

# Task deliverable

## Cross account connectivity

To enable cross account and cross region connectivity, PrivateLink will be used. In accounts/regions that host Service B, an endpoint interface service and NLB will be exposed that allows accounts/regions that host Service A to connect via an interface endpoint, created in each region that hosts Service A. Then, services in one region/account can connect via the interfaces to NLBs, and then on to further services, in other regions/accounts without having to traverse the public internet. That is to say, each region in Account A creates interface endpoints and those endpoints connect to Account B's endpoints in the corresponding region.

VPC Peering is a viable alternative to PrivateLink since it is simpler to setup but comes with the need to plan IP address CIDR allocation in all accounts and regions, since overlapping CIDR blocks can result in connectivity issues. Also, the VPCs are exposed to each other in their entirety, which in this scenario is not desired.

Transit Gateway is another alternative to PrivateLink but is more complex to setup, costly and ultimately is overkill for the scenario and was rejected as an option.

### Intra VPC connectivity

The services are hosted in a private subnet and connect to AWS services, such as SQS or Secrets Manager. To do this, an interface endpoint that connects to each AWS service will be used. Access to each interface endpoint is restricted via security groups that only allow inbound traffic from the respective service's ECS tasks security group.

The alternative, using a NAT Gateway, is more costly and was rejected for that reason. Alternatively, a self-hosted NAT Gateway can be created via an EC2 instance configured with NAT capabilities, however this comes with the downside of the need to manage and maintain the instance; things like security patches, OS upgrades, etcetera and was rejected due to added operational overhead.

## Global vs regional services

List of services which are global and which are regional:

Global:
- CloudFront distribution
- S3 bucket
- Route53
- DynamoDB Global Table

Regional:
- ALB
- NLB
- ECS 
- Aurora database instance (made global via replication)
- SQS
- Lambda
- SES
- Endpoint service + VPC interface endpoints
- Secrets Manager (made global via replication)

## Traffic routing

### How does a user in Tokyo, Frankfurt, or New York reach the closest region?

#### Frontend traffic

Since we are using CloudFront for serving the SPA, users are already served content from the closest region automatically as the CloudFront PoPs are distributed globally.

#### API traffic

The business described in the task is described as requiring low latency content serving, rather than serving content to users based on their geolocation. For this reason, latency based routing was used as a user's geographical location doesn't necessarily mean that they have the lowest latency to that respective region. 

API traffic, that is traffic destined for Service A, will be initially handled by ALBs in each region (eu-central-1, ap-northeast-1 and us-east-1) and each ALB will have an associated Route53 record, `api.my-app.com`. To route users to the appropriate region latency based routing has been chosen, which will use Route53 to measure the latency between the DNS resolver IP and each AWS region and return the lowest latency region. Each record is associated with a health check that targets the region's ALB. If/when the check fails, the record is removed from DNS responses.

The alternative, Global Accelerator, routes traffic using Anycast IPs over the AWS network to the optimal regional endpoint. This would prevent the issues seen with DNS caching and would improve failover time but was ultimately rejected due to the higher cost of operation when compared to Route53. However, it could be considered for the production environment should the DNS caching latency/failover times become burdensome. 

### What happens if the nearest region is unhealthy?

If the nearest region to the user becomes unhealthy, Route53's health check will detect that the region is unhealthy, after the health check failure threshold has been reached, and remove the record for the region's ALB from DNS responses. 

Existing client connections may have the DNS response cached, which unfortunately means that these clients could continue to be routed to the failure region until they have requested a new DNS response/their DNS entry TTL has expired. After the TTL expiry, the clients will be routed to the next-closest/next lowest-latency region to them. 

## Data layer

### How do you handle MySQL replication across regions?

To achieve a multi-regionally replicated MySQL database, Aurora Global Database will be used. This allows the creation a primary database cluster in a given region and then create secondary database cluster(s) in multiple other regions which are automatically synchronised with the primary cluster. The primary cluster acts as the write database and the secondaries as read replicas. For choosing the region of the primary cluster, it makes sense to choose the region which has the most user activity which has been assumed as us-east-1.

### What is the consistency model?

Writes are strongly consistent as they all go to the primary cluster. For read replicas the consistency model is eventual consistency as there is a small delay (usually less than 1 second) in the replicas reading and updating from the primary cluster. 

Read-your-writes is not implemented by default. Implementation options are available but require the application logic to guarantee the functionality. The simplest implementation is to identify requests which require consistency guarantees and to flag them to always read from the primary cluster. The trade-off of this is that any users making the requests from outside the primary cluster region would experience latency.

### Where do writes go? Single primary or multi-primary?

In this configuration all writes go to the single primary cluster. The simplicity of single-primary writing comes with the trade-off of latency during the secondary cluster reads. Multi-primary would cut down on latency but comes with implementation complexities. 

## Failover

### If one region goes down, what happens automatically?

If we imagine the most devastating outage, the primary region us-east-1 becoming unavailable:

1. Route53's health check would detect that the region is down and remove the record `api.my-app.com` pointing to the us-east-1 ALB
2. Traffic is rerouted to the next lowest latency region
3. The Aurora Global Database stops writing to the primary cluster and secondary clusters don't receive replication
    - A failover must be triggered in order to promote a secondary cluster to the new primary cluster
    - Achieved manually or via managed failover (`failover-global-cluster` API call)
        - Managed failover triggered via a CloudWatch alarm such as `AuroraGlobalDBReplicationLag` spiking
    - The Aurora Global Database writer endpoint is updated
4. Any messages in the failed region's SQS queue are inaccessible until recovery, no new messages can be queued
    - However, the messages are also written to at least 1 other region's SQS queue so will still be processed

### What is the expected RTO (recovery time) and RPO (data loss)?

Assuming still that the us-east-1 region is down:

|Component|RTO|Notes|
|---|---|---|
|Route53 failure detection|~30 seconds|~30 seconds assumes the lowest settings (10 second health check interval, 3 failure threshold). Using default settings would increase RTO to ~90 seconds.|
|DNS propagation|~60 seconds|The TTL of the record has been set to 60 seconds to prevent as much delay as possible for clients. External factors (ISPs, caching, etc.) could increase this time to 2-5 minutes.|
|Aurora|~2-5 minutes|Includes time for failure detection, failover triggering and promotion|
|Application reconnection|~30 seconds|Aurora global writer endpoint automatically updates when a secondary cluster is promoted to primary|

|Component|RPO|Notes|
|---|---|---|
|Aurora|<1 second|AWS specifies <1s replication lag for Aurora Global Database|
|SQS|Near-zero|Messages are written to multiple regions' SQS queues and can continue to be processed even in the event of source region failure|

### How do you handle failback when the region recovers?

Once the region becomes healthy again, Route53 will automatically add the removed records and add the region back into the routing pool. Alternatively, or perhaps ideally, the addition of the region back into the routing pool can be put behind a manual gate/require approval. This because whilst the region might become available again the root cause of the issue could be unknown and/or the region could be unstable. Adding the gate means that we can control when the region is added to the routing pool again. The gate is achieved by disabling the health check until the region can be confirmed as stable.

As for the database, if it was the primary cluster originally affected, the primary cluster will be restored and a switchover will be executed to re-designate the new primary cluster. Alternatively, the primary cluster can be left in whichever region it was promoted. If it was a secondary cluster affected by the outage, the cluster will recover and reestablish replication with the primary cluster automatically. 

## Stateful services

### How does SQS (regional by nature) work across regions?

SQS is a regional service, i.e. each region has its own SQS queue and email worker. This means that if, for example, an email worker becomes unavailable then that region's email processing won't work whilst the other regions remain unaffected.

Cross-region fallback can be configured and there are a few options available. One option is to use EventBridge to duplicate messages upon receival from a source SQS queue to another SQS queue in another region.

Another option is to use another Lambda function to read messages in the source SQS queue and queue them in another region's SQS queue. However, this is a reactive action, rather than proactive, as it would only trigger upon failure (of the Lambda email function, for example). Neither of these options mitigate the issues caused of the source region going down, as both Lambda and EventBridge would also become unavailable.

The third, and chosen, option is to write messages to the SQS queue in the source region and a secondary region, ideally based on geographical location/proximity or, optionally, to all three regions. This ensures that even if the source region goes down that the email(s) can still be processed and sent in another region. This approach also doubles (or triples) the cost, since the messages are pushed to two (or more) queues but is an acceptable trade-off given the low cost of SQS.

### How do you prevent duplicate email sends?

To ensure email idempotency, DynamoDB Global Table can be used to store the IDs of sent emails. DynamoDB Global Tables provide multi-region replication which is perfect for the given use case.

The process: 

1. A unique message ID is generated for the email
2. The Lambda function attempts to write the message to the table with the `attribute_not_exists(message_id)` condition
    - If the write is successful then send the email
    - If unsuccessful then delete the message, it already exists in the table

It should be noted that there are cases where workers in different regions are both able to write the message to the table due to replication lag (<1s). However, this is an acceptable trade-off given the rarity of occurence and the low-severity of a duplicated email.

Aurora Global Database was considered for the scenario, especially since it is already used by Service B and wouldn't require too much further configuration, but was ultimately rejected due to potential lag when replicating between regional tables and increased latency when executing cross-region reads. 

The SQS queue is configured as a Standard queue due to the async sending requirement; the alternative being a FIFO queue. FIFO queues would provide a built-in deduplication mechanism as messages are sent with a message duplication ID and any messages with the same ID as another are dropped. However, this doesn't solve the problem in the design of sending messages to the primary queue and a secondary queue as, using FIFO, both queues will receive the message and the duplication ID but will be unaware of the other queue. The deduplication mechanism in FIFO only works regionally.

#### SES

It is also worth noting that SES is a regional service and, as such, each region will require access to production SES. Any regions which don't have access will have lower email sending quotas and could throttle email delivery.

### How are secrets (Secrets Manager, SSM) synchronized across regions?

Secrets Manager has native cross region replication/synchronisation for both static and rotational secrets. Using IAM policies, replication can be limited to specific regions, as should be the case in the given scenario as only us-east-1, eu-central-1 and ap-northeast-1 are in use. 

SSM does not have native cross region replication. To enable this, an EventBridge rule and a Lambda function would have to be created.

1. EventBridge detects that a parameter (or secret) has been added to or updated in the Parameter Store
2. The EventBridge rule, upon being triggered, invokes a Lambda function that: 
    - reads the local Parameter Store (or individual parameter)
    - writes the parameter(s) to the other region's Parameter Store

Although this comes with a few trade-offs such as the fact that Lambda has to both decrypt and reencrypt the parameter/secret if it is of type SecureString, which means that the plaintext value is briefly stored in the Lambda function's memory. There is also the need to manage the policies of the KMS keys in both regions. Also, this replication functionality would only work on newly added/updated parameters; any parameters that already exist (if the replication was added later) would need to be replicated/synchronised via another method (likely a script).

The Lambda function requires appropriate IAM permissions in both regions, namely permissions to:

- read SSM parameter (GetParameter) and decrypt KMS key in the source region
- write SSM parameter (PutParameter), delete SSM parameter (DeleteParameter) and generate KMS key data in the target region(s)

## Cost & trade-offs

### What are the main cost drivers of going multi-region?

In this multi-regional setup, we are hosting/creating 3 instances of resources like ALB and ECS (3 times the desired task count). This effectively multiplies the cost of these services by 3, but costs of ECS can be mitigated by right-sizing the task resource assignment and using Fargate Spot instances.

Aurora Global Database is also a main cost driver since we are hosting 3 database clusters instead of 1.

Route53 incurs minor costs when compared to other services but it is still worth noting that the healthcheck functionality does cost per healthcheck per month, which is tripled.

In addition to compute and database costs, inter-region data transfer is a main cost driver. Replication traffic between Aurora clusters and any cross-region service communication incur additional charges that can scale with usage.

### What would you simplify if budget were limited?

Use of Aurora Global Databases means global replication is achieved without any manual input, with the trade-off of cost. To cut costs, using RDS with cross-region replication is a viable alternative but comes with slower replication times and requires more manual intervention on failure. This would also allow for use of a less costly instance type, if it is viable to have less hardware resource to host the database.

At the cost of higher latency for some users, the move to a 2 region architecture could be considered. 

### Would you apply the same strategy to all environments (dev/stg/prod)?

I would not apply the same strategy to all environments. 

For the development environment, I would choose single region deployment since developing the functionality of the application takes higher priority than architecting for high availability. Multiple AZs could be considered depending on the budget but otherwise I would choose a single AZ for development. This environment would use a single RDS database.

For the staging environment, I would use 2 regions and multiple AZs the ability to test failover and ensure cross-account functionality works. It is essential to test these systems and detect any misconfigurations or points of failure before deploying the platform to production. This environment would use an RDS database with a cross region replica to avoid the Aurora Global Database costs.

The production environment would use the full 3 region architecture as described.