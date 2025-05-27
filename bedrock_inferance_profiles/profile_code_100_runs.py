import boto3
import json
import time
import uuid
import datetime

# Initialize the Bedrock clients
# Explicitly set the region to ensure consistency
region = 'us-east-1'  # Change this to your desired region
bedrock_runtime = boto3.client('bedrock-runtime', region_name=region)
bedrock = boto3.client('bedrock', region_name=region)  # For management operations
print(f"Using AWS region: {region}")

def parse_converse_response(response):
    """Parse the response from the Converse API"""
    if 'output' in response and 'message' in response['output']:
        message = response['output']['message']
        if 'content' in message:
            for content in message['content']:
                if 'text' in content:
                    return content.get('text', '')
    return "No text response found"

def create_inference_profile(profile_name, model_arn, tags):
    """Create Inference Profile using base model ARN"""
    try:
        response = bedrock.create_inference_profile(
            inferenceProfileName=profile_name,
            description="test",
            modelSource={'copyFrom': model_arn},
            tags=tags
        )
        print("CreateInferenceProfile Response:", response['ResponseMetadata']['HTTPStatusCode'])
        print(f"Created profile with ARN: {response.get('inferenceProfileArn', 'Unknown')}")
        print(f"Full response: {response}\n")
        return response
    except Exception as e:
        print(f"Error creating inference profile: {str(e)}")
        # Don't use mock responses - raise the exception to see the actual error
        raise

def converse(model_id, messages):
    """Use the Converse API to engage in a conversation with the specified model"""
    try:
        response = bedrock_runtime.converse(
            modelId=model_id,
            messages=messages,
            inferenceConfig={
                'maxTokens': 300,  # Specify max tokens if needed
            }
        )
        
        status_code = response.get('ResponseMetadata', {}).get('HTTPStatusCode')
        print("Converse Response:", status_code)
        parsed = parse_converse_response(response)
        print(f"Response text (truncated): {parsed[:50]}...")
        return response
    except Exception as e:
        print(f"Error in converse: {str(e)}")
        return None

# Store the inference profile ARN globally
inference_profile_arn = None

def get_or_create_inference_profile(dept="Devs"):
    """Get existing inference profile or create a new one if it doesn't exist"""
    global inference_profile_arn
    
    # If we already have a profile ARN, return it with updated tags
    if inference_profile_arn:
        # Update tags for the existing profile based on department
        try:
            tags = [{'key': 'dept', 'value': dept}, {'key': 'project', 'value': 'cost-demo'}]
            bedrock.tag_resource(
                resourceARN=inference_profile_arn,
                tags=tags
            )
            print(f"Updated tags for profile: {inference_profile_arn} with dept: {dept}")
        except Exception as e:
            print(f"Warning: Could not update tags: {str(e)}")
            
        return inference_profile_arn
    
    # Create a new profile with a generic name
    profile_name = "demo_cost_allocation_profile"
    tags = [{'key': 'dept', 'value': dept}, {'key': 'project', 'value': 'cost-demo'}]
    base_model_arn = "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-pro-v1:0"  #anthropic.claude-3-sonnet-20240229-v1:0"
    
    try:
        print(f"Creating inference profile with dept: {dept}")
        profile_response = create_inference_profile(profile_name, base_model_arn, tags)
        inference_profile_arn = profile_response['inferenceProfileArn']
        print(f"Created profile with ARN: {inference_profile_arn}")
        return inference_profile_arn
    except Exception as e:
        if "already exists" in str(e):
            # If profile already exists, try to get its ARN
            print(f"Profile {profile_name} already exists, trying to use it")
            # Construct the ARN based on the profile name
            account_id = boto3.client('sts').get_caller_identity().get('Account')
            inference_profile_arn = f"arn:aws:bedrock:{region}:{account_id}:inference-profile/{profile_name}"
            print(f"Using existing profile with ARN: {inference_profile_arn}")
            
            # Update tags for the existing profile
            try:
                bedrock.tag_resource(
                    resourceARN=inference_profile_arn,
                    tags=tags
                )
                print(f"Updated tags for profile: {inference_profile_arn} with dept: {dept}")
            except Exception as tag_error:
                print(f"Warning: Could not update tags: {str(tag_error)}")
                
            return inference_profile_arn
        else:
            raise

def run_test(iteration, use_profile=True):
    """Run a single test iteration"""
    print(f"\n{'='*50}")
    print(f"ITERATION {iteration} - {datetime.datetime.now()}")
    print(f"{'='*50}")
    
    if use_profile:
        # Determine which department to use based on iteration number
        # Even iterations use Dev, odd iterations use Security
        dept = "Dev" if iteration % 2 == 0 else "Dev"
        print(f"Using department: {dept}")
        
        # Get or create the inference profile with the selected department tag
        model_id = get_or_create_inference_profile(dept)
        print(f"Using inference profile: {model_id}")
    else:
        # Use the base model directly
        model_id = "amazon.nova-pro-v1:0" #"anthropic.claude-3-sonnet-20240229-v1:0"
        print(f"Using base model directly: {model_id}")
    
    # Prepare different prompts for each iteration to make it more interesting
    prompts = [
        "Write a comprehensive technical documentation for deploying a multi-region, highly available microservices architecture on AWS. Include sections on networking, security, CI/CD pipeline, monitoring, disaster recovery, and cost optimization. Provide specific service configurations, IAM policies, and architecture diagrams described in text.",
        "Analyze the current state of cloud computing in enterprise environments. Cover trends in multi-cloud adoption, challenges in cloud migration, cost management strategies, security considerations, and predictions for the next 5 years. Include case studies of successful enterprise cloud transformations and lessons learned.",
        "Compare and contrast the following AWS services in extensive detail: Amazon ECS, EKS, App Runner, Lambda, and Fargate. For each service, analyze use cases, pricing models, scalability, operational overhead, integration capabilities, monitoring options, and security features. Provide recommendations for different application scenarios.",
        "Design a real-time analytics platform that can process and visualize data from IoT devices at scale. The solution should handle millions of events per second, provide near real-time dashboards, support historical data analysis, and implement anomaly detection. Detail the AWS services you would use, how they connect, data flow, security considerations, and scaling strategies.",
    ]
    
    prompt = prompts[iteration % len(prompts)]
    print(f"Using prompt: {prompt}")
    
    # FIXED: Correct message format for the Bedrock API
    messages = [{"role": "user", "content": [{"text": prompt}]}]
    response = converse(model_id, messages)
    
    # Add a delay to avoid rate limiting
    time.sleep(1)
    return response

def main():
    """Main function to run the tests"""
    print("Starting test runs with alternating department tags...")
    
    # Track metrics
    successful_runs = 0
    failed_runs = 0
    sales_runs = 0
    marketing_runs = 0
    start_time = time.time()
    
    # Number of iterations to run
    num_iterations = 200
    for i in range(1, num_iterations + 1):
        try:
            # Always use profiles for this demo to generate tagged spend
            use_profile = True
            response = run_test(i, use_profile)
            
            if response:
                successful_runs += 1
                # Track department-specific runs
                if i % 2 == 0:
                    sales_runs += 1
                else:
                    marketing_runs += 1
            else:
                failed_runs += 1
                
        except Exception as e:
            print(f"Error in iteration {i}: {str(e)}")
            failed_runs += 1
        
        # Print progress
        if i % 5 == 0:
            print(f"\nProgress: {i}/{num_iterations} iterations completed")
            print(f"Success rate: {successful_runs}/{i} ({successful_runs/i*100:.1f}%)")
            print(f"Department split - Dev: {sales_runs}, Security: {marketing_runs}")
            
        # Add a delay between iterations to avoid rate limiting
        if i < num_iterations:  # Don't sleep after the last iteration
            time.sleep(2)
    
    # Print summary
    end_time = time.time()
    total_time = end_time - start_time
    print("\n" + "="*50)
    print("TEST SUMMARY")
    print("="*50)
    print(f"Total runs: {num_iterations}")
    print(f"Successful runs: {successful_runs}")
    print(f"Failed runs: {failed_runs}")
    print(f"Success rate: {successful_runs/num_iterations*100:.1f}%")
    print(f"Department split - Dev: {sales_runs}, Security: {marketing_runs}")
    print(f"Total execution time: {total_time:.1f} seconds")
    print(f"Average time per iteration: {total_time/num_iterations:.1f} seconds")
    print("="*50)
    
    # Print the inference profile ARN for reference
    if inference_profile_arn:
        print(f"\nUsed inference profile: {inference_profile_arn}")
        print("Look for this profile in the AWS Bedrock console")
        print("The profile tags were dynamically updated between Dev and Security")

if __name__ == "__main__":
    main()