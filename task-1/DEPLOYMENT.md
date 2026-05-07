# Initial assumptions

- Each service has its own image repository (ECR) in its respective account
- Each service has its own code repository (not a monorepository)
- The services are owned by different development teams
- Database migrations are backwards compatible

# Tofu modules/repository overview

All custom Tofu modules will be hosted in a central code repository that any repository, with permission, can pull from to use the modules within. This enables module reusability anywhere and prevents the need to copy the module definitions into each repository that requires them.

The modules will be versioned via Git tags to avoid any changes made to the modules potentially breaking consumer projects. In the consumer projects, module versions will be pinned during module sourcing.

For the purposes of demonstration, the Tofu repository has been included under `repos/tofu-repo`.

## Structure

The Tofu repository has the following structure (not every module is listed):

```
aws
├── modules/
│   ├── vpc/
│   ├── ecs/
...
```

Keeping the modules under a root directory, named after the cloud provider they will interact with, keeps the repository clean and enables future cloud provider Tofu definitions to be contained within the repository. Under the `modules/` directory, each service has its own subdirectory which contains the definitions required to create that service. 

## Permissions

The Tofu repository will grant permission to the two service repositories to `read` the contents of the repository, which will enable them to pull the required modules.

## Modules

### Account and state management

A decision needs to be made on how to manage the accounts and states of the services and their environments. Each Service is isolated in its own AWS account, and then each development environment in its own account, so 6 accounts in total: 

1. Service A Dev
2. Service A Staging
3. Service A Prod
4. Service B Dev
5. Service B Staging
6. Service B Prod

To achieve state management, a dedicated AWS account will be created to store all of the states/backends, using a combination of S3 for statefile storage and DynamoDB for state locking since, the alternative, storing each state in the respective AWS account becomes burdensome to manage.

Each statefile is stored in an S3 bucket with:

- Versioning enabled
- Server-side encryption enabled
- Blocked public access, read/write access restricted to IAM roles

DynamoDB state locking will prevent any state corruption via concurrent modification.

### Cross account resources

`terraform_remote_state` is used for cross account infrastructure/resource dependencies, such as endpoint service names in PrivateLink. This configuration block retrieves root module output values from another statefile and then those outputs can be used in the local configuration. 

# Platform repository overview

The platform will be split into 2 repositories: one for the Service A code/tofu config and one for Service B.

The two repositories, for the purposes of demonstration, are represented as `repos/service-a-repo` and `repos/service-b-repo`.

## Structure

The repositories have the following structure:

```
src/ (only included for demonstration)
tofu/
├── Makefile
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── environments/
│   ├── backends/
│   │   ├──dev.tf
│   │   ├──staging.tf
│   │   ├──prod.tf
│   ├── vars/
│   │   ├──dev.tfvars
│   │   ├──staging.tfvars
│   │   ├──prod.tfvars
Dockerfile (only included for demonstration)
```

## Variables

For the purposes of demonstration, variables will be initialised in the respective directory's `vars/<env>.tfvars` file. However in a real project, repository variables would be used to allow for the definition of common variables that can be used across all environments, and repository environment variables that are used per environment. 

# Deployment strategy

By default, ECS supports rolling deployment strategy, where new services are deployed alongside the running service and deletes the running service when the new one is complete and healthy. This comes with a few problems, namely that executing a rollback means another deployment execution and there is no easy way to validate the newly deployed service before the other is removed.

Instead, the deployment strategy will be a blue/green strategy, where the new service is deployed into a "green" environment (a target group attached to the respective load balancer), alongside the previous service version in the "blue" environment (the original target group) and traffic is moved from blue to green once the green service is validated. AWS has predefined "deployment configurations" which define the rate at which traffic is shifted from blue to green, the default being to simply move all traffic at once. The chosen "configuration" for this project is `CodeDeployDefault.ECSCanary10Percent15Minutes`, which shifts 10% of the traffic in the first increment and then the remaining 90% is moved 15 minutes aftrer the initial shift. This gives ample time to detect any issues that may occur from the deployment. However, in a real project, a custom configuration could be considered.

The blue version remains for rollback capabilities, up until the defined period after which the blue version is terminated. Blue/green stategy comes with zero-downtime deployments and easy rollbacks in case of green service failure. However, the disadvantages include greater complexity to implement and a higher cost of operation, since two tasks/containers are running during deployment.

## appspec.yml

appspec.yml is a file used by CodeDeploy to manage deployments as a series of lifecycle hooks. It specifies, for example, the task definition revision of the new ("green") task, which container and port to route traffic to, etc.

The lifecycle hooks are steps for before, during and after the deployment which invoke Lambda functions to validate a service, for example. The most important hook is `AfterAllowTestTraffic`, which runs after the green tasks are registered with the test listener but before any production traffic shifts. The Lambda function for this hook can run smoke tests against the test port, validate database connectivity, check response times, and then report back to CodeDeploy with either `Succeeded` or `Failed`. A `Failed` signal triggers an automatic rollback — traffic stays on blue, green tasks are terminated, and the deployment is marked as failed.

With this, the platform has 2 rollback mechanisms:

1. **Proactive** — the `AfterAllowTestTraffic` Lambda validates the green deployment before any prod traffic reaches it
2. **Reactive** — CloudWatch alarms configured on the CodeDeploy deployment group roll back automatically if error rates spike during the canary window

## CI/CD pipeline

Since each service's code is hosted in its own repository, we can deploy both services independently of each other. This is ideal since the two services can be developed at the same time and there is no need to worry about a change in Service A's code triggering an undesired deployment of/change to Service B.

### Pipeline design

Both services A and B run the same pipelines, with the only difference being that since service B connects to a database it includes migration steps. 

The following are high-level overviews of the CICD pipelines. One pipeline on every pull request for validation:

```
PR opened

- linting/unit testing
- integration testing
- build the Docker image
- image vulnerability scan
- (service b) migration validation
- configure AWS creds
- tofu plan
- write artifacts
```

And another pipeline on merge to main:

```
Merge to main

- build the Docker image with tag (git commit SHA)
- configure AWS creds
- push to ECR
- tofu apply
- register new task definition (for appspec)
- generate appspec
- trigger codedeploy deployment
    - execute smoke tests via Lambda
    - wait for completion
- notify deployment failure/success
```

where the dev and staging environments are automatically deployed and a manual approval/trigger is required to deploy to the prod environment.